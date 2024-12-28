Module: deft
Synopsis: install subcommand


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
