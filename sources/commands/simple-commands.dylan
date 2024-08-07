Module: deft
Synopsis: Various command implementations not big enough to warrant their own file


/// deft install

define class <install-subcommand> (<subcommand>)
  keyword name = "install";
  keyword help = "Install Dylan packages.";
end class;

define constant $install-subcommand
  = make(<install-subcommand>,
         options: list(make(<parameter-option>,
                            // TODO: type: <version>
                            names: #("version", "v"),
                            default: "latest",
                            help: "The version to install."),
                       make(<positional-option>,
                            name: "pkg",
                            repeated?: #t,
                            help: "Packages to install.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <install-subcommand>)
 => (status :: false-or(<int>))
  for (package-name in get-option-value(subcmd, "pkg"))
    let vstring = get-option-value(subcmd, "version");
    let release = pm/find-package-release(pm/catalog(), package-name, vstring)
      | begin
          note("Package %= not found.", package-name);
          abort-command(1);
        end;
    pm/install(release);
  end;
end method;


/// deft list

define class <list-subcommand> (<subcommand>)
  keyword name = "list";
  keyword help = "List installed Dylan packages.";
end class;

define constant $list-subcommand
  = make(<list-subcommand>,
         options: list(make(<flag-option>,
                            names: #("all", "a"),
                            help: "List all packages whether installed"
                              " or not.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <list-subcommand>)
 => (status :: false-or(<int>))
  list-catalog(all?: get-option-value(subcmd, "all"))
end method;

// List installed package names, summary, versions, etc. If `all` is
// true, show all packages. Installed and latest versions are shown.
define function list-catalog
    (#key all? :: <bool>)
  local
    // Search for the first '.' that is < maxlen characters from the
    // beginning. If not found, elide at the nearest whitespace.
    method brief-description (text :: <string>)
      let maxlen = 90;
      if (text.size < maxlen)
        text
      else
        let space = #f;
        let pos = #f;
        iterate loop (p = min(text.size - 1, maxlen))
          case
            p <= 0         => #f;
            text[p] == '.' => pos := p + 1;
            otherwise      =>
              if (whitespace?(text[p]) & (~space | space == p + 1))
                space := p;
              end;
              loop(p - 1);
          end;
        end iterate;
        case
          pos => copy-sequence(text, end: pos);
          space => concat(copy-sequence(text, end: space), "...");
          otherwise => text;
        end
      end if
    end method,
    method package-< (p1, p2)
      p1.pm/package-name < p2.pm/package-name
    end;
  let cat = pm/catalog();
  let packages = pm/load-all-catalog-packages(cat);
  // %8s is to handle versions like 2020.1.0
  note("  %8s %8s  %-20s  %s",
       "Inst.", "Latest", "Package", "Description");
  for (package in sort(packages, test: package-<))
    let name = pm/package-name(package);
    let versions = pm/installed-versions(name, head?: #f);
    let latest-installed = versions.size > 0 & versions[0];
    let package = pm/find-package(cat, name);
    let latest = pm/find-package-release(cat, name, pm/$latest);
    if (all? | latest-installed)
      note("%c %8s %8s  %-20s  %s",
           iff(latest-installed
                 & (latest-installed < pm/release-version(latest)),
               '!', ' '),
           latest-installed | "-",
           pm/release-version(latest),
           name,
           brief-description(pm/package-description(package)));
    end;
  end;
end function;


/// deft new workspace

define class <new-workspace-subcommand> (<new-subcommand>)
  keyword name = "workspace";
  keyword help = "Create a new workspace.";
end class;

define constant $new-workspace-subcommand
  = make(<new-workspace-subcommand>,
         options: list(make(<parameter-option>,
                            names: #("directory", "d"),
                            help: "Create the workspace in this directory."),
                       make(<positional-option>,
                            name: "name",
                            help: "Workspace directory name.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <new-workspace-subcommand>)
 => (status :: false-or(<int>))
  let name = get-option-value(subcmd, "name");
  let dir = get-option-value(subcmd, "directory");
  ws/new(name, parent-directory: dir & as(<directory-locator>, dir));
  0
end method;


/// deft update

define class <update-subcommand> (<subcommand>)
  keyword name = "update";
  keyword help = "Update the workspace based on the active packages.";
end class;

define constant $update-subcommand
  = make(<update-subcommand>,
         options: list(make(<flag-option>,
                            names: #("global"),
                            help: "Install packages globally instead of in the"
                              " workspace. [%default%]")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <update-subcommand>)
 => (status :: false-or(<int>))
  let global? = get-option-value(subcmd, "global");
  ws/update(global?: global?);
end method;


/// deft status

define class <status-subcommand> (<subcommand>)
  keyword name = "status";
  keyword help = "Display information about the current workspace.";
end class;

define constant $status-subcommand
  = make(<status-subcommand>,
         options: list(make(<flag-option>, // for tooling
                            name: "directory",
                            help: "Only show the workspace directory.")));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <status-subcommand>)
 => (status :: false-or(<int>))
  let workspace = ws/load-workspace();
  if (~workspace)
    note("Not currently in a workspace.");
    abort-command(1);
  end;
  note("Workspace: %s", ws/workspace-directory(workspace));
  if (get-option-value(subcmd, "directory"))
    abort-command(0);
  end;

  // Show active package status
  // TODO: show current branch name and whether modified and whether ahead of
  //   upstream (usually but not always origin/master).
  let active = ws/workspace-active-packages(workspace);
  if (empty?(active))
    note("No active packages.");
  else
    note("Active packages:");
    for (package in sort(active, test: method (a, b)
                                         pm/package-name(a) < pm/package-name(b)
                                       end))
      let directory = ws/active-package-directory(workspace, pm/package-name(package));
      let command = "git status --untracked-files=no --branch --ahead-behind --short";
      let (status, output) = run(command, working-directory: directory);
      let line = split(output, "\n")[0];

      let command = "git status --porcelain --untracked-files=no";
      let (status, output) = run(command, working-directory: directory);
      let dirty = ~whitespace?(output);

      note("  %-25s: %s%s",
           pm/package-name(package), line, (dirty & " (dirty)") | "");
    end;
  end;
  0
end method;


/// deft version

define class <version-subcommand> (<subcommand>)
  keyword name = "version";
  keyword help = "Display the current version of deft.";
end class;

define constant $version-subcommand = make(<version-subcommand>);

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <version-subcommand>)
 => (status :: false-or(<int>))
  note("%s", $deft-version);
  0
end method;
