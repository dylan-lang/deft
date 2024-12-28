Module: deft
Synopsys: status subcommand


// TODO: show active package dependencies and whether or not they're installed.

define class <status-subcommand> (<subcommand>)
  keyword name = "status";
  keyword help = "Display information about the current workspace.";
end class;

define constant $status-subcommand
  = make(<status-subcommand>,
         options: list(make(<flag-option>, // for tooling
                            name: "directory",
                            help: "Only show the workspace directory.")));

// TODO: show settings like default library name.
define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <status-subcommand>)
 => (status :: false-or(<int>))
  let workspace = ws/load-workspace();
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
