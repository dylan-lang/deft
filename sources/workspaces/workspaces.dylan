module: %workspaces
synopsis: Manage developer workspaces

// See the doc at https://package.opendylan.org/deft/index.html#workspaces for an
// explanation of single- and multi-package workspace layouts.

// TODO:
// * Display the number of registry files updated and the number unchanged.
//   It gives reassuring feedback that something went right when there's no
//   other output.

// The class of errors explicitly signalled by this module.
define class <workspace-error> (<simple-error>)
end class;

define function workspace-error
    (format-string :: <string>, #rest args)
  error(make(<workspace-error>,
             format-string: format-string,
             format-arguments: args));
end function;

define constant $workspace-file-name = "workspace.json";
define constant $dylan-package-file-name = "dylan-package.json";
// TODO: remove support for deprecated pkg.json file in the 1.0 version or once
// all catalog packages are converted, whichever comes first.
define constant $pkg-file-name = "pkg.json";
define constant $default-library-key = "default-library";

// See the section "Workspaces" in the documentation.
define class <workspace> (<object>)
  constant slot workspace-directory :: <directory-locator>,
    required-init-keyword: directory:;
  constant slot workspace-active-packages :: <seq> = #[], // <package>s
    init-keyword: active-packages:;
  constant slot multi-package-workspace? :: <bool> = #f,
    init-keyword: multi-package?:;

  // Default library to build, for the LSP server to open, etc.
  slot workspace-default-library-name :: false-or(<string>) = #f;

  // These three %lids-by-* slots are computed lazily rather than in load-workspace
  // because some deft commands don't need them.

  // A map from library names to sequences of <lid>s that define the library.  (A library
  // with platform-specific definitions may have multiple lids.)  There are mappings here
  // for active package libraries and for dependency libraries.
  constant slot %lids-by-library :: <istring-table> = make(<istring-table>);

  // A map from full absolute pathname of a LID file to the associated <lid>. There are
  // mappings here for active package libraries and for dependency libraries.
  constant slot %lids-by-pathname :: <table>
    //= make(<string-table>);   // works, but not correct
    //= iff(os/$os-name == #"win32", make(<istring-table>), make(<string-table>));  // slot is set to #f!
    = if (os/$os-name == #"win32") make(<istring-table>) else make(<string-table>) end; // works

  // A map from active package <release> to a sequence of <lid>s it contains.
  constant slot %lids-by-active-package :: <table> = make(<table>);

  // Prevent infinite recursion when scanning a workspace that has no active packages.
  slot active-packages-scanned? :: <bool> = #f;
end class;

define function lids-by-library
    (ws :: <workspace>) => (t :: <istring-table>)
  if (ws.%lids-by-library.empty?)
    scan-workspace(ws);
  end;
  ws.%lids-by-library
end function;

define function lids-by-pathname
    (ws :: <workspace>) => (t :: <table>)
  if (ws.%lids-by-pathname.empty?)
    scan-workspace(ws);
  end;
  ws.%lids-by-pathname
end function;

define function lids-by-active-package
    (ws :: <workspace>) => (t :: <table>)
  if (~ws.active-packages-scanned?)
    scan-workspace(ws)
  end;
  ws.%lids-by-active-package
end function;

define function registry-directory
    (ws :: <workspace>) => (dir :: <directory-locator>)
  subdirectory-locator(ws.workspace-directory, "registry")
end function;

// Loads the workspace definition by looking up from `directory` to find the workspace
// root and loading the workspace.json file. If no workspace.json file exists, the
// workspace is created using the dylan-package.json file (if any) and default values. As
// a last resort `directory` is used as the workspace root. Signals `<workspace-error>`
// if either JSON file is found but is invalid.
define function load-workspace
    (#key directory :: <directory-locator> = fs/working-directory())
 => (workspace :: <workspace>)
  let ws-file = find-workspace-file(directory);
  let dp-file = find-dylan-package-file(directory);
  ws-file
    | dp-file
    | workspace-error("Can't find %s or %s. Not inside a workspace?",
                      $workspace-file-name, $dylan-package-file-name);
  let ws-dir = locator-directory(ws-file | dp-file);
  let active-packages = find-active-packages(ws-dir);
  let ws = make(<workspace>,
                directory: ws-dir,
                active-packages: active-packages,
                multi-package?: (active-packages.size > 1
                                   | (ws-file
                                        & dp-file
                                        & (ws-file.locator-directory ~= dp-file.locator-directory))));
  ws-file & load-workspace-config(ws, ws-file);
  ws
end function;

// Scan the workspace to find all active packages, from which the lids-by-* tables are
// populated and deps can be determined.
define function scan-workspace
    (ws :: <workspace>) => ()
  // First do active packages to populate %lids-by-active-package.
  for (package in find-active-packages(ws.workspace-directory))
    let directory = active-package-directory(ws, package);
    fs/do-directory(curry(scan-workspace-file, ws, package), directory);
  end;
  ws.active-packages-scanned? := #t; // Prevent infinite recursion in empty workspaces.
  // Install dependencies and further update the %lids-by-* tables with them.
  let (releases, actives) = ensure-deps-installed(ws);
  for (release in releases)
    let directory = active-package-directory(ws, pm/release-package(release));
    fs/do-directory(curry(scan-workspace-file, ws, release), directory);
  end;
end function;

define function scan-workspace-file
    (ws, active-package, dir, name, type) => ()
  select (type)
    #"file" =>
      let lid-path = file-locator(dir, name);
      if (~element(ws.%lids-by-pathname, as(<string>, lid-path), default: #f))
        let comparator = iff(os/$os-name == #"win32", char-compare-ic, char-compare);
        select (name by rcurry(ends-with?, test: comparator))
          ".lid", ".hdp" =>
            ingest-lid-file(ws, active-package, lid-path);
          ".spec" =>
            ingest-spec-file(ws, active-package, lid-path);
          otherwise
            => #f;
        end;
      end;
    #"directory" =>
      // TODO: Git submodules could indicate a project in transition from Git
      // submodules to Deft, or they could indicate use of a repository that isn't
      // available in the package catalog. Ignore them and assume all packages are
      // available in the catalog for now. Ultimately we should have an escape hatch
      // like the ability to use a local package catalog IN ADDITION to the main
      // catalog. Or just make this configurable?
      let subdir = subdirectory-locator(dir, name);
      let subdir/git = subdirectory-locator(subdir, ".git");
      if (name ~= ".git" & ~fs/file-exists?(subdir/git))
        fs/do-directory(curry(scan-workspace-file, ws, active-package), subdir);
      end;
    #"link" =>
      #f;
  end select;
end function;

// Load the workspace.json file
define function load-workspace-config
    (ws :: <workspace>, file :: <file-locator>) => ()
  local method find-default-library ()
          block (return)
            let fallback = #f;
            for (lids keyed-by package in ws.lids-by-active-package)
              for (lid in lids)
                let name = lid.library-name;
                fallback := fallback | name;
                if (ends-with?(name, "-test-suite-app")
                      | ends-with?(name, "-test-suite")
                      | ends-with?(name, "-tests"))
                  return(name);
                end;
              end for;
            end for;
            fallback
          end block;
        end method;
  let json = load-json-file(file);
  ws.workspace-default-library-name
    := element(json, $default-library-key, default: #f) | find-default-library();
end function;

define function load-json-file (file :: <file-locator>) => (config :: <table>)
  fs/with-open-file(stream = file, if-does-not-exist: #f)
    let object = parse-json(stream, strict?: #f, table-class: <istring-table>);
    if (~instance?(object, <table>))
      workspace-error("Invalid JSON file %s, must contain at least {}", file);
    end;
    object
  end
end function;

// Find the workspace directory. The nearest directory containing
// workspace.json always takes precedence. Otherwise the nearest directory
// containing dylan-package.json.
define function find-workspace-directory
    (start :: <directory-locator>) => (dir :: false-or(<directory-locator>))
  let ws-file = find-workspace-file(start);
  (ws-file & ws-file.locator-directory)
    | begin
        let pkg-file = find-dylan-package-file(start);
        pkg-file & pkg-file.locator-directory
      end
end function;

define function find-workspace-file
    (directory :: <directory-locator>) => (file :: false-or(<file-locator>))
  find-file-in-or-above(directory, as(<file-locator>, $workspace-file-name))
end function;

define function find-dylan-package-file
    (directory :: <directory-locator>) => (file :: false-or(<file-locator>))
  find-file-in-or-above(directory, as(<file-locator>, $dylan-package-file-name))
    | find-file-in-or-above(directory, as(<file-locator>, $pkg-file-name))
end function;

define function current-dylan-package
    (directory :: <directory-locator>) => (p :: false-or(pm/<release>))
  let dp-file = find-dylan-package-file(directory);
  dp-file & pm/load-dylan-package-file(dp-file)
end function;

// Return the nearest file or directory with the given `name` in or above
// `directory`. `name` is expected to be a locator with an empty path
// component.
define function find-file-in-or-above
    (directory :: <directory-locator>, name :: <locator>)
 => (file :: false-or(<locator>))
  let want-dir? = instance?(name, <directory-locator>);
  iterate loop (dir = simplify-locator(directory))
    if (dir)
      let file = merge-locators(name, dir);
      if (fs/file-exists?(file)
            & begin
                let type = fs/file-type(file);
                (type == #"directory" & want-dir?)
                  | (type == #"file" & ~want-dir?)
              end)
        file
      else
        loop(dir.locator-directory)
      end
    end
  end
end function;

// Look for dylan-package.json or */dylan-package.json relative to the workspace
// directory and turn it/them into a sequence of `<release>` objects.
define function find-active-packages
    (directory :: <directory-locator>) => (pkgs :: <seq>)
  let subdir-files
    = collecting ()
        for (locator in fs/directory-contents(directory))
          if (instance?(locator, <directory-locator>))
            let dpkg = file-locator(locator, $dylan-package-file-name);
            let pkg = file-locator(locator, $pkg-file-name);
            if (fs/file-exists?(dpkg))
              collect(dpkg);
            elseif (fs/file-exists?(pkg))
              warn("Please rename %s to %s; support for %= will be"
                     " removed soon.", pkg, $dylan-package-file-name, $pkg-file-name);
              collect(pkg);
            end;
          end;
        end for;
      end collecting;
  local method check-file (file, warn-obsolete?)
          if (fs/file-exists?(file))
            if (~empty?(subdir-files))
              warn("Workspace has both a top-level package file (%s) and"
                     " packages in subdirectories (%s). The latter will be ignored.",
                   file, join(map(curry(as, <string>), subdir-files), ", "));
            end;
            if (warn-obsolete?)
              warn("Please rename %s to %s; support for %= will be"
                     " removed soon.", file, $dylan-package-file-name, $pkg-file-name);
            end;
            vector(pm/load-dylan-package-file(file))
          end
        end method;
  check-file(file-locator(directory, $dylan-package-file-name), #f)
    | check-file(file-locator(directory, $pkg-file-name), #t)
    | map(pm/load-dylan-package-file, subdir-files)
end function;

define method active-package-directory
    (ws :: <workspace>, package :: pm/<release>) => (d :: <directory-locator>)
  active-package-directory(ws, pm/package-name(package))
end method;

define method active-package-directory
    (ws :: <workspace>, package :: pm/<package>) => (d :: <directory-locator>)
  active-package-directory(ws, pm/package-name(package))
end method;

define method active-package-directory
    (ws :: <workspace>, pkg-name :: <string>) => (d :: <directory-locator>)
  if (ws.multi-package-workspace?)
    subdirectory-locator(ws.workspace-directory, pkg-name)
  else
    ws.workspace-directory
  end
end method;

define function active-package-file
    (ws :: <workspace>, pkg-name :: <string>) => (f :: <file-locator>)
  let dir = active-package-directory(ws, pkg-name);
  let dpkg = file-locator(dir, $dylan-package-file-name);
  let pkg = file-locator(dir, $pkg-file-name);
  if (fs/file-exists?(pkg) & ~fs/file-exists?(dpkg))
    pkg
  else
    dpkg
  end
end function;

define function active-package?
    (ws :: <workspace>, pkg-name :: <string>) => (_ :: <bool>)
  member?(pkg-name, ws.workspace-active-packages,
          test: method (name, package)
                  string-equal-ic?(name, pm/package-name(package))
                end)
end function;

// Resolve active package dependencies and install them.
define function ensure-deps-installed
    (ws :: <workspace>) => (releases :: <seq>, actives :: <istring-table>)
  let (releases, actives) = find-active-package-deps(ws, pm/catalog(), dev?: #t);
  for (release in releases)
    if (~element(actives, release.pm/package-name, default: #f))
      pm/install(release, deps?: #f, force?: #f, actives: actives);
    end;
  end;
  values(releases, actives)
end function;

// Find the transitive dependencies of the active packages in workspace
// `ws`. If `dev?` is true then include dev dependencies in the result.
define function find-active-package-deps
    (ws :: <workspace>, cat :: pm/<catalog>, #key dev?)
 => (releases :: <seq>, actives :: <istring-table>)
  let actives = make(<istring-table>);
  let deps = make(<stretchy-vector>);
  // Dev deps could go into deps, above, but they're kept separate so that
  // pacman can give more specific error messages.
  let dev-deps = make(<stretchy-vector>);
  for (lids keyed-by release in ws.lids-by-active-package)
    actives[pm/package-name(release)] := release;
    for (dep in pm/release-dependencies(release))
      add-new!(deps, dep, test: \=)
    end;
    if (dev?)
      for (dep in pm/release-dev-dependencies(release))
        add-new!(dev-deps, dep, test: \=);
      end;
    end;
  end;
  let deps = as(pm/<dep-vector>, deps);
  let dev-deps = as(pm/<dep-vector>, dev-deps);
  let releases-to-install = pm/resolve-deps(cat, deps, dev-deps, actives);
  values(releases-to-install, actives)
end function;
