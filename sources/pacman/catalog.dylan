Module: %pacman

// Catalog format version string, names a subdirectory in the catalog
// repository. When changing the format of the catalog we'll write a converter
// from the old format to the new format and use a new subdirectory for it, to
// allow for easily reverting to the old format.
define constant $catalog-format = "v1";

// Point this at your checkout of pacman-catalog when testing additions to the
// catalog and the catalog will be loaded from the subdirectory named the same
// as $catalog-format.
define constant $catalog-env-var = "DYLAN_CATALOG";

define constant $catalog-local-directory-name = "pacman-catalog";

define class <catalog-error> (<package-error>)
end class;

define class <package-missing-error> (<catalog-error>)
  constant slot package-name :: <string>,
    required-init-keyword: package-name:;
end class;

define function catalog-error
    (fmt :: <string>, #rest args)
  error(make(<catalog-error>,
             format-string: fmt,
             format-arguments: args));
end function;

// Packages with no category are categorized thusly.
define constant $uncategorized = "Uncategorized";

define constant $pacman-catalog-release :: <release>
  = begin
      let releases = make(<stretchy-vector>);
      let package = make(<package>,
                         name: "pacman-catalog",
                         releases: releases,
                         description: "The pacman catalog",
                         contact: "carlgay@gmail.com",
                         category: $uncategorized,
                         keywords: #[]);
      let release = make(<release>,
                         package: package,
                         version: make(<branch-version>, branch: "master"),
                         dependencies: as(<dep-vector>, #[]),
                         license: "MIT",
                         url: "https://github.com/dylan-lang/pacman-catalog",
                         license-url: "https://github.com/dylan-lang/pacman-catalog/LICENSE");
      add!(releases, release);
      release
    end;

// The catalog knows what packages (and releases thereof) exist.
define sealed class <catalog> (<object>)
  // The root of the catalog directory. This is not the pacman-catalog
  // repository root directory, it's the directory containing the one- or
  // two-letter subdirectories. Currently it's the pacman-catalog/v1 directory
  // and will change when the catalog format changes.
  constant slot catalog-directory :: <directory-locator>,
    required-init-keyword: directory:;
  // Lowercase package name string -> <package>
  constant slot catalog-package-cache :: <istring-table> = make(<istring-table>);
end class;

// Loading the catalog once per session should be enough, so cache it here.
// This is a thread-local variable so that we can bind it to a dummy catalog
// while installing the catalog package itself, to prevent infinite recursion.
// Access this via catalog() rather than directly.
define thread variable *catalog* :: false-or(<catalog>) = #f;

define variable *override-logged?* = #f;

// Get the package catalog. Packages are loaded lazily and stored in the
// catalog's cache. If the DYLAN_CATALOG environment variable is set then that
// directory is used and no attempt is made to download the latest catalog.
define function catalog
    (#key directory) => (c :: <catalog>)
  if (*catalog*)
    *catalog*
  else
    let override = directory | os/environment-variable($catalog-env-var);
    let directory
      = if (override)
          if (~*override-logged?*)
            warn("Using override catalog from $%s: %s", $catalog-env-var, override);
            *override-logged?* := #t;
          end;
          subdirectory-locator(as(<directory-locator>, override), $catalog-format)
        else
          subdirectory-locator(package-manager-directory(),
                               $catalog-local-directory-name,
                               $pacman-catalog-release.release-version.version-to-string,
                               $source-directory-name,
                               $catalog-format)
        end;
    // We pass deps?: #f here to prevent infinite recursion when `catalog` is
    // called again. pacman-catalog is a data-only package and will never have
    // any deps.
    if (~override)
      install($pacman-catalog-release,
              force?: too-old?(directory),
              deps?: #f);
    end;
    *catalog* := make(<catalog>, directory: directory)
  end
end function;

define function find-package
    (cat :: <catalog>, name :: <string>) => (pkg :: false-or(<package>))
  let name = lowercase(name);
  let cache = catalog-package-cache(cat);
  cached-package(cat, name)
    | begin
        let package = load-catalog-package(cat, name);
        package & cache-package(cat, package)
      end
end function;

define function load-all-catalog-packages
    (cat :: <catalog>) => (packages :: <seq>)
  let packages = make(<stretchy-vector>);
  local
    method load-one (dir, name, type)
      select (type)
        #"directory" =>
          fs/do-directory(load-one, subdirectory-locator(dir, name));
        #"file" =>
          add!(packages, load-catalog-package-file(cat, name, file-locator(dir, name)));
      end;
    end method;
  fs/do-directory(load-one, cat.catalog-directory);
  packages
end function;

// Fetch the catalog again if it's older than this.
define constant $catalog-freshness :: <duration> = make(<duration>, minutes: 10);

define function too-old?
    (path :: <locator>) => (old? :: <bool>)
  block ()
    let mod-time = fs/file-property(path, #"modification-date");
    let now = current-date();
    now - mod-time > $catalog-freshness
  exception (fs/<file-system-error>)
    // TODO: catch <file-does-not-exist-error> instead
    // https://github.com/dylan-lang/opendylan/issues/1147
    #t
  end
end function;

define function cached-package
    (cat :: <catalog>, name :: <string>) => (pkg :: false-or(<package>))
  element(cat.catalog-package-cache, name, default: #f)
end function;

define function cache-package
    (cat :: <catalog>, pkg :: <package>) => (pkg :: <package>)
  let cache = cat.catalog-package-cache;
  let name = pkg.package-name;
  let cached = element(cache, name, default: #f);
  if (~cached)
    cache[name] := pkg
  elseif (cached ~== pkg)
    catalog-error("attempt to cache different instance of package %s", pkg);
  end;
  pkg
end function;

// Exported
define generic find-package-release
    (catalog :: <catalog>, name :: <string>, version :: <object>)
 => (release :: false-or(<release>));

define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <string>)
 => (rel :: false-or(<release>))
  find-package-release(cat, name, string-to-version(ver))
end method;

// Find the latest released version of a package.
define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <latest>)
 => (rel :: false-or(<release>))
  let package = find-package(cat, name);
  let releases = package & package.package-releases;
  if ((releases | #[]).size > 0)        // does 0 releases even make sense?
    releases[0]
  end
end method;

define method find-package-release
    (cat :: <catalog>, name :: <string>, ver :: <version>)
 => (rel :: false-or(<release>))
  let package = find-package(cat, name);
  package & find-release(package, ver, exact?: #t)
end method;

// Signal an indirect instance of <package-error> if there are any problems
// found in the catalog. If `cached?` is true, don't try to load packages. This
// is intended for tests that construct a catalog in memory instead of with
// files.
define function validate-catalog
    (cat :: <catalog>, #key cached? :: <bool>) => ()
  // A reusable memoization cache (release => result).
  let cache = make(<table>);
  let packages = if (cached?)
                   value-sequence(cat.catalog-package-cache)
                 else
                   load-all-catalog-packages(cat)
                 end;
  if (empty?(packages))
    catalog-error("no packages found in catalog. Wrong directory?");
  end;
  for (package in packages)
    for (release in package.package-releases)
      // We pass `dev?: #f` here because it is valid for a package to have a dependency
      // on itself if it is an active package _during development_. Since that catalog
      // can't know what the active packages are we can't validate the dev dependencies
      // and expect no errors. https://github.com/dylan-lang/pacman-catalog/issues/40
      resolve-release-deps(cat, release, dev?: #f, cache: cache);
    end;
  end;
end function;

// Write a package to the catalog in JSON format.
define function write-package-file
    (cat :: <catalog>, package :: <package>) => (file :: <file-locator>)
  let file = package-locator(cat.catalog-directory, package);
  fs/ensure-directories-exist(file);
  fs/with-open-file (stream = file, direction: #"output", if-exists: #"replace")
    print-json(package, stream, indent: 2, sort-keys?: #t);
  end;
  file
end function;

// Generate a locator for the given package (or package name). `root` is the
// directory that contains the 1-or-2 letter subdirectory names, which is
// usually a version directory like "v1".
define generic package-locator
    (root :: <directory-locator>, package) => (file :: <file-locator>);

define method package-locator
    (root :: <directory-locator>, package :: <package>) => (file :: <file-locator>)
  package-locator(root, package.package-name)
end method;

define method package-locator
    (root :: <directory-locator>, name :: <string>) => (file :: <file-locator>)
  let dir = select (name.size)
              1 => subdirectory-locator(root, "1");
              2 => subdirectory-locator(root, "2");
              otherwise =>
                subdirectory-locator(root,
                                     copy-sequence(name, end: 2),
                                     copy-sequence(name, start: 2, end: min(4, name.size)))
            end;
  file-locator(dir, name)
end method;

// The JSON printer calls do-print-json. We convert most objects to tables,
// which the JSON printer knows how to print.

define method do-print-json
    (package :: <package>, stream :: <stream>)
  // TODO: Once https://github.com/dylan-lang/json/pull/12 is in a release,
  // update to use that json release and remove the keyword args in the three
  // calls to json/print below.
  print-json(to-table(package), stream, indent: 2, sort-keys?: #t);
end method;

define method do-print-json
    (release :: <release>, stream :: <stream>)
  print-json(to-table(release), stream, indent: 2, sort-keys?: #t);
end method;

define method do-print-json
    (dep :: <dep>, stream :: <stream>)
  let t = make(<istring-table>);
  t["name"]    := dep.package-name;
  t["version"] := dep.dep-version;
  print-json(t, stream, indent: 2, sort-keys?: #t);
end method;

define method do-print-json
    (version :: <version>, stream :: <stream>)
  print-json(version-to-string(version), stream, indent: 2, sort-keys?: #t);
end method;

define function load-catalog-package
    (cat :: <catalog>, name :: <string>) => (package :: false-or(<package>))
  let file = package-locator(cat.catalog-directory, name);
  load-catalog-package-file(cat, name, file)
end function;

define generic load-catalog-package-file
    (cat :: <catalog>, name :: <string>, file-or-stream :: <object>)
 => (package :: false-or(<package>));

define method load-catalog-package-file
    (cat :: <catalog>, name :: <string>, file :: <file-locator>)
 => (package :: false-or(<package>))
  verbose("Loading %s", file);
  // We need the block here because if-does-not-exist: #f doesn't work.
  // https://github.com/dylan-lang/opendylan/issues/1358
  block ()
    fs/with-open-file (stream = file, direction: #"input")
      load-catalog-package-file(cat, name, stream)
    end
  exception (fs/<file-does-not-exist-error>)
    #f
  end
end method;

define method load-catalog-package-file
    (cat :: <catalog>, name :: <string>, stream :: <stream>)
 => (package :: false-or(<package>))
  let json = parse-json(stream);
  let stored-name = json["name"];
  if (stored-name ~= name)
    warn("%s: loaded package name is %=, expected %=",
         fs/stream-locator(stream), stored-name, name);
  end;
  let package = make(<package>,
                     name: name,
                     description: json["description"],
                     contact: json["contact"],
                     keywords: json["keywords"],
                     category: json["category"]);
  local
    method to-release (t :: <table>) => (r :: <release>)
      let deps = element(t, "dependencies", default: #f)
        | element(t, "deps", default: #()); // deprecated name
      let release
        = make(<release>,
               package: package,
               version: string-to-version(t["version"]),
               dependencies: map-as(<dep-vector>, string-to-dep, deps),
               dev-dependencies:
                 map-as(<dep-vector>,
                        string-to-dep, element(t, "dev-dependencies", default: #[])),
               url: element(t, "url", default: #f)
                 | element(t, "location", default: ""),
               license: t["license"],
               license-url: element(t, "license-url", default: #f));
      add-release(package, release);
    end;
  for (dict in json["releases"])
    add-release(package, to-release(dict))
  end;
  cat.catalog-package-cache[name] := package
end method;

// Publish a new catalog file that contains the given release. Signals
// <catalog-error> if the release is not newer than any existing releases for
// the package.
define function publish-release
    (cat :: <catalog>, release :: <release>) => (file :: <file-locator>)
  let name = package-name(release);
  let cat-package = find-package(cat, name);
  let new-package = release-package(release);
  if (cat-package)
    // Include the releases from the existing package when we write the file.
    // new-package was created by loading dylan-package.json, and doesn't have
    // any of the existing releases in it. Doing it this way, instead of adding
    // the new-package release and attributes to cat-package, allows optional
    // package-level attributes to be removed by removing them from
    // dylan-package.json.
    for (rel in package-releases(cat-package))
      add-release(new-package, rel);
    end;
  end;
  let latest = find-package-release(cat, name, $latest);
  if (release & latest & release <= latest)
    catalog-error("New release (%s) must have a higher version than the"
                    " latest release (%s)",
                  release-to-string(release), release-to-string(latest));
  end;
  // Note that we write new-package rather than cat-package, meaning that the
  // package-level attributes from dylan-package.json (e.g., "description")
  // will replace the package-level attributes from the catalog.
  write-package-file(cat, new-package)
end function;
