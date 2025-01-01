Module: deft
Synopsis: new workspace subcommand


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
  new(name, parent-directory: dir & as(<directory-locator>, dir));
  0
end method;

// Create a new workspace named `name` under `parent-directory`. If `parent-directory` is
// not supplied use the standard location.
//
// TODO: validate `name`
define function new
    (name :: <string>, #key parent-directory :: false-or(<directory-locator>))
 => (ws :: false-or(ws/<workspace>))
  let dir = parent-directory | fs/working-directory();
  let ws-dir = subdirectory-locator(dir, name);
  let ws-path = file-locator(ws-dir, ws/$workspace-file-name);
  let existing = ws/find-workspace-file(dir);
  if (existing)
    ws/workspace-error("Can't create workspace file %s because it is inside another"
                         " workspace, %s.", ws-path, existing);
  end;
  if (fs/file-exists?(ws-path))
    note("Workspace already exists: %s", ws-path);
  else
    fs/ensure-directories-exist(ws-path);
    fs/with-open-file (stream = ws-path,
                       direction: #"output", if-does-not-exist: #"create",
                       if-exists: #"error")
      format(stream, """
                     # Dylan workspace %=

                     {}

                     """, name);
    end;
    note("Workspace created: %s", ws-path);
  end;
  ws/load-workspace(directory: ws-dir)
end function;
