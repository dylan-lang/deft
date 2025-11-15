Module: deft
Synopsis: deft update subcommand


define class <update-subcommand> (<subcommand>)
  keyword name = "update";
  keyword help = "Install active package dependencies and write registry files."
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
  update-workspace(ws/load-workspace(),
                   global?: get-option-value(subcmd, "global"));
end method;

define function update-workspace
    (ws :: ws/<workspace>, #key global? :: <bool>) => ()
  let cat = pm/catalog();
  dynamic-bind (*package-manager-directory*
                  = iff(global?,
                        *package-manager-directory*,
                        subdirectory-locator(ws/workspace-directory(ws),
                                             pm/$package-directory-name)))
    verbose("Package directory: %s", pm/package-manager-directory());
    let (releases, actives) = ws/ensure-deps-installed(ws);
    let (total :: <int>, written :: <int>, no-platform :: <seq>)
      = ws/update-registry(ws, releases, actives);
    if (~empty?(no-platform) & *verbose?*)
      warn("These libraries had no LID file for platform %s:\n  %s",
           os/$platform-name, join(sort!(no-platform), ", "));
    end;
    let reg-dir = ws/registry-directory(ws);
    if (written == 0)
      note("Registry %s is up-to-date (%d files).", reg-dir, total);
    else
      note("Updated %d of %d registry files in %s.", written, total, reg-dir);
    end;
  end;
end function;
