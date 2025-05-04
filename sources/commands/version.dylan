Module: deft
Synopsys: version subcommand


// The Makefile replaces this string with Git version info before building.
define constant $deft-version :: <string> = "_NO_VERSION_SET_";

define constant $no-version = "_NO" "_VERSION_" "SET_";

define class <version-subcommand> (<subcommand>)
  keyword name = "version";
  keyword help = "Display the current version of deft.";
end class;

define constant $version-subcommand = make(<version-subcommand>);

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <version-subcommand>)
 => (status :: false-or(<int>))
  if ($deft-version = $no-version)
    note("*** No version set. This is a development binary. ***");
  else
    note("%s", $deft-version);
  end;
  0
end method;
