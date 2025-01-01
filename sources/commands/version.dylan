Module: deft
Synopsys: version subcommand


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
