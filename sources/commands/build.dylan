Module: deft
Synopsis: build subcommand


define class <build-subcommand> (<new-subcommand>)
  keyword name = "build";
  keyword help = "Build the configured default libraries.";
end class;

// deft build [--no-link --clean --unify] [--all | lib1 lib2 ...]
// Eventually need to add more dylan-compiler options to this.
define constant $build-subcommand
  = make(<build-subcommand>,
         options:
           list(make(<flag-option>,
                     names: #("all", "a"),
                     help: "Build all libraries in the workspace."),
                make(<flag-option>,
                     names: #("clean", "c"),
                     help: "Do a clean build."),
                make(<flag-option>,
                     names: #("link", "l"),
                     negative-names: #("no-link"),
                     help: "Link after compiling.",
                     default: #t),
                make(<flag-option>,
                     names: #("unify", "u"),
                     help: "Combine libraries into a single executable."),
		make(<flag-option>,
		     names: #("verbose", "v"),
		     help: "Show verbose output"),
                make(<positional-option>,
                     names: #("libraries"),
                     help: "Libraries to build.",
                     repeated?: #t,
                     required?: #f)));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <build-subcommand>)
 => (status :: false-or(<int>))
  let ws = ws/load-workspace();
  let library-names = get-option-value(subcmd, "libraries") | #[];
  let all? = get-option-value(subcmd, "all");
  if (all?)
    if (~empty?(library-names))
      warn("Ignoring --all option. Using the specified libraries instead.");
    else
      library-names := active-package-libraries(ws);
      if (empty?(library-names))
        error("No libraries found in workspace.");
      end;
    end;
  end;
  if (empty?(library-names))
    library-names
      := list(ws/workspace-default-library-name(ws)
                | if (all?)
                    error("No libraries found in workspace and no"
                            " default libraries configured.");
                  else
                    error("Please specify a library to build, use --all,"
                            " or configure a default library.");
                  end);
  end;
  for (name in library-names)
    // Let the shell locate dylan-compiler...
    let command
      = join(remove(list("dylan-compiler",
                         "-compile",
                         get-option-value(subcmd, "clean") & "-clean",
                         get-option-value(subcmd, "link") & "-link",
                         get-option-value(subcmd, "unify") & "-unify",
			 get-option-value(subcmd, "verbose") & "-verbose",
                         name),
                    #f),
             " ");
    verbose("%s", command);
    let env = make-compilation-environment(ws);
    let exit-status
      = os/run-application(command,
                           environment: env, // AUGMENTS the existing environment
                           under-shell?: #t,
                           working-directory: ws/workspace-directory(ws));
    if (exit-status ~== 0)
      error("Build of %= failed with exit status %=.", name, exit-status);
    end;
  end for;
end method;

define function make-compilation-environment
    (ws :: ws/<workspace>) => (env :: <table>)
  let val = as(<string>, ws/registry-directory(ws));
  let var = "OPEN_DYLAN_USER_REGISTRIES";
  let odur = os/environment-variable(var);
  if (odur)
    // TODO: export $environment-variable-delimiter from os/.
    val := concat(val, iff(os/$os-name == #"win32", ";", ":"), odur);
  end;
  tabling(<string-table>, var => val)
end function;

define function active-package-libraries
    (ws :: ws/<workspace>) => (libraries :: <seq>)
  collecting ()
    for (lids keyed-by release in ws/lids-by-release(ws))
      if (ws/active-package?(ws, release.pm/package-name))
        for (lid in lids)
          collect(ws/library-name(lid));
        end;
      end;
    end;
  end
end function;
