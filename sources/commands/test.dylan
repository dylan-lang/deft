Module: deft
Synopsis: test subcommand

// The deft test subcommand builds test libraries and runs the tests.  It uses heuristics
// on the library name to figure out which libraries are test libraries (see
// test-library-name?).

// Some workspaces (especially multi-library packages) may have both test executables
// (e.g., foo-test-app) and test shared libraries.  In that case we only run the
// executables, on the assumption that they will take care of running all the tests.
// Otherwise it could result in running some tests multiple times.  (The hope is that as
// `deft test` is used more there will be no need to create test apps at all.)

// If any test run fails `deft test` exits immediately with a failure status without
// running the tests in the remaining libraries.


define class <test-subcommand> (<new-subcommand>)
  keyword name = "test";
  keyword help = "Run tests for workspace packages.";
end class;

define constant $test-subcommand
  = make(<test-subcommand>,
         options:
           list(make(<flag-option>,
                     names: #("all", "a"),
                     help: "Also run tests for dependencies. [off]"),
                make(<flag-option>,
                     names: #("continue", "c"),
                     help: "Continue running test binaries even after one fails. [off]"),
                make(<flag-option>,
                     names: #("build"),
                     negative-names: #("no-build"),
                     default: #t,
                     help: "Rebuild test binaries before running them. [on]"),
                make(<positional-option>,
                     names: #("libraries"),
                     help: "Libraries to test, optionally followed by '--' and Testworks options.",
                     repeated?: #t,
                     required?: #f)));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <test-subcommand>)
 => (status :: false-or(<int>))
  let exit-status = 0;
  let build? = get-option-value(subcmd, "build");
  let libraries = get-option-value(subcmd, "libraries") | #();
  let all? = get-option-value(subcmd, "all") | ~empty?(libraries);
  local
    method is-exe-library? (lid)
      #"executable" == as(<symbol>, ws/lid-value(lid, #"target-type") | "")
    end,
    method filter-to-command-line-libraries (lids)
      choose(method (lid)
               empty?(libraries)
                 | member?(ws/library-name(lid), libraries, test: \=)
             end,
             lids)
    end;
  block (return)
    let ws = ws/load-workspace();
    let lid-map = ws/find-active-package-test-libraries(ws, all?);
    if (lid-map.empty?)
      warn("No libraries found in workspace? No tests to run.");
      exit-status := 1;
      return();
    end;
    let exes = #();
    let dlls = #();
    let seen-libraries = make(<vector*>);
    for (lids keyed-by release in lid-map)
      let lids = filter-to-command-line-libraries(lids);
      let _exes = choose(is-exe-library?, lids);
      if (empty?(_exes))
        // Only build DLL tests for this package if there are no EXE tests.
        // Assume the exe tests include the dlls.
        let _dlls = choose(complement(is-exe-library?), lids);
        if (_dlls.empty?)
          warn("No tests found for package %s.", release.pm/package-name);
        end;
        dlls := concat(dlls, _dlls);
      else
        exes := concat(exes, _exes);
      end;
    end for;
    let ws-dir = ws/workspace-directory(ws);
    if (build?)
      if (~empty?(exes))
        do(rcurry(build-library, "executable", ws-dir), exes);
      elseif (~empty?(dlls))
        build-testworks-run(ws-dir);
        do(rcurry(build-library, "dll", ws-dir), dlls);
      end;
    end;
    local method run-test (lid :: ws/<lid>, exe?)
            let library = ws/library-name(lid);
            let binary = ws/lid-value(lid, #"executable") | library;
            let build-dir = ws/build-directory(ws);
            let testworks-options = subcmd.unconsumed-arguments; // args after "--"
            let command
              = if (exe?)
                  let exe-path = as(<string>, file-locator(build-dir, "bin", binary));
                  if (~fs/file-exists?(exe-path))
                    note("Building test %s (no binary found)", library);
                    build-library(lid, "executable", ws-dir);
                  end;
                  apply(vector, exe-path, testworks-options)
                else
                  let extension = select (os/$os-name)
                                    #"win32" => ".dll";
                                    #"darwin" => ".dylib";
                                    otherwise => ".so";
                                  end;
                  let lib-name = concat("lib", binary, extension);
                  let exe-path = as(<string>, file-locator(build-dir, "bin", "testworks-run"));
                  apply(vector, exe-path, "--load", lib-name, testworks-options)
                end;
            let status = os/run-application(command, under-shell?: #f, working-directory: ws-dir);
            if (status ~== 0)
              if (~get-option-value(subcmd, "continue"))
                exit-status := 1;
                return();
              end;
              exit-status := 1;
            end;
          end method;
    if (~empty?(exes))
      do(rcurry(run-test, #t), exes);
    elseif (~empty?(dlls))
      do(rcurry(run-test, #f), dlls);
    end;
    if (exes.size + dlls.size < libraries.size)
      warn("Some tests specified on the command-line were not found.");
    end;
  end block;
  exit-status
end method execute-subcommand;

define method build-library
    (lid :: ws/<lid>, target-type :: <string>, dir :: <directory-locator>)
  build-library(lid.ws/library-name, target-type, dir)
end method;

define method build-library
    (library :: <string>, target-type :: <string>, dir :: <directory-locator>)
  let command = join(list("dylan-compiler", "-build", "-target", target-type, library), " ");
  let status = os/run-application(command, under-shell?: #t, working-directory: dir);
  if (status ~== 0)
    warn("Error building library %s:", library);
  end;
end method;

define variable *testworks-run-built?* = #f;

define function build-testworks-run
    (ws-dir :: <directory-locator>) => ()
  if (~*testworks-run-built?*)
    *testworks-run-built?* := #t;
    build-library("testworks-run", "executable", ws-dir);
  end;
end function;
