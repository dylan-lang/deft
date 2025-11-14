Module: deft
Synopsys: list subcommand


// TODO: this should show locally installed packages by default, but have a --global
// flag.

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
          pos => copy-seq(text, end: pos);
          space => concat(copy-seq(text, end: space), "...");
          otherwise => text;
        end
      end if
    end method,
    method package-< (p1, p2)
      p1.pm/package-name < p2.pm/package-name
    end;
  let cat = pm/catalog();
  let packages = pm/load-all-catalog-packages(cat);
  let rows = make(<vector*>);
  for (package in sort(packages, test: package-<))
    let name = pm/package-name(package);
    let versions = pm/installed-versions(name, head?: #f);
    let latest-installed = versions.size > 0 & versions[0];
    let package = pm/find-package(cat, name);
    let latest = pm/find-package-release(cat, name, pm/$latest);
    if (all? | latest-installed)
      add!(rows, vector(iff(latest-installed
                              & (latest-installed < pm/release-version(latest)),
                            "!", ""),
                        latest-installed | "-",
                        pm/release-version(latest) | "",
                        name,
                        pm/package-description(package)));
    end;
  end for;
  columnize(*standard-output*,
            vector(make(<column>),
                   make(<column>, header: "Inst."),
                   make(<column>, header: "Latest"),
                   make(<column>, header: "Name"),
                   make(<column>, header: "Description", pad?: #f, maximum-width: 50)),
            rows);
end function;
