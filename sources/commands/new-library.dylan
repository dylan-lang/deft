Module: deft
Synopsis: Create the initial boilerplate for new Dylan libraries and applications


define class <new-application-subcommand> (<new-subcommand>)
  keyword name = "application";
  keyword help = "Create a new application and its test library.";
end class;

define class <new-library-subcommand> (<new-subcommand>)
  keyword name = "library";
  keyword help = "Create a new shared library and its test library.";
end class;

define constant $deps-option
  = make(<positional-option>,
         names: #("deps"),
         required?: #f,
         repeated?: #t,
         help: "Package dependencies in the form pkg@version."
           " 'pkg' with no version gets the current latest"
           " version. pkg@1.2 means a specific version. The generated test"
           " suite automatically depends on testworks.");

define constant $git-flag-option
  = make(<flag-option>,
         names: #("git"),
         help: "Create a .gitignore file with default values.",
         default: #f);

define constant $git-gitignore-template
  = #:string:"# backup files
*~
*.bak
.DS_Store

# auto-generated project file
*.hdp

# compiler build directory
_build/

# Deft-generated package cache
_packages/

# Deft-generated registry folder
registry/
";

// deft new application foo http json ...
define constant $new-application-subcommand
  = make(<new-application-subcommand>,
         options:
           list(make(<flag-option>,
                     names: #("force-package", "p"),
                     help: "Create dylan-package.json even if"
                       " already in a package",
                     default: #f),
                make(<positional-option>,
                     names: #("name"),
                     help: "Name of the application"),
                make(<flag-option>,
                     names: #("simple"),
                     help: "Create only an executable library, without"
                       " a corresponding shared library or test suite.",
                     default: #f),
                $git-flag-option,
                $deps-option));

// deft new library foo http json ...
define constant $new-library-subcommand
  = make(<new-library-subcommand>,
         options:
           list(make(<flag-option>,
                     names: #("force-package", "p"),
                     help: "Create dylan-package.json even if"
                       " already in a package",
                     default: #f),
                make(<positional-option>,
                     names: #("name"),
                     help: "Name of the library"),
                $git-flag-option,
                $deps-option));

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <new-application-subcommand>)
 => (status :: false-or(<int>))
  let name = get-option-value(subcmd, "name");
  let dep-specs = get-option-value(subcmd, "deps") | #[];
  let force-package? = get-option-value(subcmd, "force-package");
  let git? = get-option-value(subcmd, "git");
  new-library(name,
              dependencies: dep-specs,
              executable?: #t,
              force-package?: force-package?,
              simple?: get-option-value(subcmd, "simple"),
              git?: git?);
  0
end method;

define method execute-subcommand
    (parser :: <command-line-parser>, subcmd :: <new-library-subcommand>)
 => (status :: false-or(<int>))
  let name = get-option-value(subcmd, "name");
  let dep-specs = get-option-value(subcmd, "deps") | #[];
  let force-package? = get-option-value(subcmd, "force-package");
  let git? = get-option-value(subcmd, "git");
  new-library(name,
              dependencies: dep-specs,
              executable?: #f,
              force-package?: force-package?,
              git?: git?);
  0
end method;

// While technically any Dylan name is valid, we prefer to restrict the names
// to the style that is in common use since this tool is most likely to be used
// by beginners.
define constant $library-name-regex = compile-regex("^[a-z][a-z0-9-]*$");

define function new-library
    (name :: <string>,
     #key directory :: <directory-locator> = fs/working-directory(),
          dependencies :: <seq> = #[], executable? :: <bool>,
          force-package? :: <bool>, simple? :: <bool>, git? :: <bool>)
  if (~regex-search($library-name-regex, name))
    error("%= is not a valid Dylan library name."
            " Names are one or more words separated by hyphens, for example"
            " 'cool-stuff'. Names must match the regular expression %=.",
          name, regex-pattern($library-name-regex));
  end;
  let lib-dir = subdirectory-locator(directory, name);
  if (fs/file-exists?(lib-dir))
    error("Directory %s already exists.", lib-dir);
  end;
  // Parse dep specs before writing any files, in case of errors.
  let deps = parse-dep-specs(dependencies);
  make-dylan-library(name, lib-dir, executable?,
                     deps, force-package?, simple?, git?);
end function;

// Creates source files for a new library (app or shared lib), its
// corresponding test library app, and a dylan-package.json file.

// Define #:string: syntax.
define function string-parser (s) s end;


//// Templates for a "simple" executable app with no shared library or test
//// suite. For this one we don't add "-app" to the name of the library. The
//// idea is that this is for quick, one-off apps like benchmarks and such.

define constant $simple-exe-lid-template
  = #:string:"Library: %s
Files: library.dylan
       %s.dylan
Target-Type: executable
";

// library.dylan file for an simple executable library.
define constant $simple-exe-library-definition-template
  = #:string:"Module: dylan-user
Synopsis: Module and library definition for simple executable application

define library %s
  use common-dylan;
  use io, import: { format-out };
end library;

define module %s
  use common-dylan;
  use format-out;
end module;
";

define constant $simple-exe-main-template
  = #:string:'Module: %s

define function main
    (name :: <string>, arguments :: <vector>)
  format-out("Hello, world!\n");
  exit-application(0);
end function;

// Calling our top-level function (which may have any name) is the last
// thing we do.
main(application-name(), application-arguments());
';


//// Shared library templates.

define constant $lib-lid-template
  = #:string:"Library: %s
Files: library.dylan
       %s.dylan
Target-Type: dll
";

define constant $lib-library-definition-template
  = #:string:'Module: dylan-user

define library %s
  use common-dylan;
  use io, import: { format-out };

  export
    %s,
    %s-impl;
end library;

// Interface module creates public API, ensuring that an implementation
//  module exports them.
define module %s
  create
    greeting;                   // Example. Delete me.
end module;

// Implementation module implements definitions for names created by the
// interface module and exports names for use by test suite.  %%foo, foo-impl,
// or foo-internal are common names for an implementation module.
define module %s-impl
  use common-dylan;
  use %s;                  // Declare that we will implement "greeting".

  // Additional exports for use by test suite.
  export
    $greeting;                  // Example code. Delete me.
end module;
';

define constant $lib-main-code-template
  = #:string:'Module: %s-impl

// Internal
define constant $greeting = "Hello world!";

// Exported
define function greeting () => (s :: <string>)
  $greeting
end function;
';


//// Templates for a full executable library that is designed to use the base
//// shared library.

define constant $exe-lid-template
  = #:string:"Library: %s
Files: library.dylan
       main.dylan
Target-Type: executable
";

// library.dylan file for an non-simple executable library.
define constant $exe-library-definition-template
  = #:string:"Module: dylan-user
Synopsis: Module and library definition for executable application

define library %s
  use common-dylan;
  use %s;
  use io, import: { format-out };
end library;

define module %s
  use common-dylan;
  use format-out;
  use %s;
end module;
";

// Main program for the executable.
define constant $exe-main-template
  = #:string:'Module: %s-app

define function main
    (name :: <string>, arguments :: <vector>)
  format-out("%%s\n", greeting());
  exit-application(0);
end function;

// Calling our main function (which could have any name) should be the last
// thing we do.
main(application-name(), application-arguments());
';


//// Templates for test suite library.

define constant $test-lid-template
  = #:string:"Library: %s-test-suite
Files: library.dylan
       %s-tests.dylan
Target-Type: executable
";

define constant $test-library-definition-template
  = #:string:'Module: dylan-user

define library %s
  use common-dylan;
  use testworks;
  use %s;
end library;

define module %s
  use common-dylan;
  use testworks;
  use %s;
  use %s-impl;
end module;
';

define constant $test-main-code-template
  = #:string:'Module: %s

define test test-$greeting ()
  assert-equal("Hello world!", $greeting);
end test;

define test test-greeting ()
  assert-equal("Hello world!", greeting());
end test;

// Use `_build/bin/%s-test-suite --help` to see options.
run-test-application()
';

// TODO: We don't have enough info to fill in "location" here. Since this will
// be an active package, location shouldn't be needed until the package is
// published in the catalog, at which time the user should be gently informed.
define constant $dylan-package-file-template
  = #:string:'{
    "dependencies": [ %s ],
    "dev-dependencies": [ %s ],
    "description": "YOUR DESCRIPTION HERE",
    "name": %=,
    "version": "0.1.0",
    "url": "https://github.com/%s/%s",
    "keywords": [ ],
    "contact": "https://github.com/%s/%s/issues",
    "license": "",
    "license-url": ""
}
';


define class <template> (<object>)
  constant slot %format-string :: <string>, required-init-keyword: format-string:;
  constant slot %format-arguments :: <seq> = #(), init-keyword: format-arguments:;
  constant slot %output-file :: <file-locator>, required-init-keyword: output-file:;
  constant slot %library-name :: false-or(<string>) = #f, init-keyword: library-name:;
end class;

define function write-template
    (template :: <template>) => ()
  fs/ensure-directories-exist(template.%output-file);
  fs/with-open-file (stream = template.%output-file,
                     direction: #"output",
                     if-does-not-exist: #"create",
                     if-exists: #"error")
    apply(format, stream, template.%format-string, template.%format-arguments);
  end;
end function;

// Write project files. `library-name` is the name of the library specified on the
// command line. If --simple was used then `library-name` is the name of the executable,
// otherwise it's the name of the main shared library.
define function make-dylan-library
    (library-name :: <string>, dir :: <directory-locator>, exe? :: <bool>, deps :: <seq>,
     force-package? :: <bool>, simple? :: <bool>, git? :: <bool>)
  let file = curry(file-locator, dir);
  // dylan-package-json is handled specially, so it's not in top-templates.
  // TODO: README, LICENSE, ...
  let templates
    = if (simple?)
        // With the --simple flag just output exe app code at top level.
        // No test suite, no shared library, no documentation.
        list(make(<template>,
                  library-name: library-name,
                  output-file: file(concat(library-name, ".lid")),
                  format-string: $simple-exe-lid-template,
                  format-arguments: list(library-name, library-name)),
             make(<template>,
                  output-file: file("library.dylan"),
                  format-string: $simple-exe-library-definition-template,
                  format-arguments: list(library-name, library-name)),
             make(<template>,
                  output-file: file(concat(library-name, ".dylan")),
                  format-string: $simple-exe-main-template,
                  format-arguments: list(library-name)))
      else
        // We really need a generic template library that accepts a <string-table> or
        // plist with which to specify the template parameters....
        let exe-name = iff(simple?,
                           library-name,
                           concat(library-name, "-app"));
        let app-templates
          = list(make(<template>,
                      library-name: exe-name,
                      output-file: file("src", "app", concat(exe-name, ".lid")),
                      format-string: $exe-lid-template,
                      format-arguments: list(exe-name)),
                 make(<template>,
                      output-file: file("src", "app", "library.dylan"),
                      format-string: $exe-library-definition-template,
                      format-arguments: list(exe-name, library-name, exe-name,
                                             library-name)),
                 make(<template>,
                      output-file: file("src", "app", "main.dylan"),
                      format-string: $exe-main-template,
                      format-arguments: list(library-name)),
                 make(<template>,
                      output-file: file("Makefile"),
                      format-string: $makefile-template,
                      format-arguments: list(exe-name, library-name, library-name,
                                             exe-name, library-name, library-name,
                                             library-name, library-name, library-name,
                                             library-name, library-name, library-name)));
        let lib-templates
          = list(make(<template>,
                      library-name: library-name,
                      output-file: file("src", "lib", concat(library-name, ".lid")),
                      format-string: $lib-lid-template,
                      format-arguments: list(library-name, library-name)),
                 make(<template>,
                      output-file: file("src", "lib", "library.dylan"),
                      format-string: $lib-library-definition-template,
                      format-arguments: list(library-name, library-name, library-name,
                                             library-name, library-name, library-name)),
                 make(<template>,
                      output-file: file("src", "lib", concat(library-name, ".dylan")),
                      format-string: $lib-main-code-template,
                      format-arguments: list(library-name)));
        let test-library-name
          = concat(library-name, "-test-suite");
        let test-templates
          = list(make(<template>,
                      library-name: test-library-name,
                      output-file: file("src", "tests", concat(test-library-name, ".lid")),
                      format-string: $test-lid-template,
                      format-arguments: list(library-name, library-name)),
                 make(<template>,
                      output-file: file("src", "tests", "library.dylan"),
                      format-string: $test-library-definition-template,
                      format-arguments: list(test-library-name, library-name,
                                             test-library-name, library-name,
                                             library-name)),
                 make(<template>,
                      output-file: file("src", "tests", concat(library-name, "-tests.dylan")),
                      format-string: $test-main-code-template,
                      format-arguments: list(test-library-name)));
        concat(iff(exe?, app-templates, #()),
               lib-templates,
               test-templates)
      end;
  if (git?)
    templates
      := add(templates, make(<template>,
                             output-file: file(".gitignore"),
                             format-string: $git-gitignore-template,
                             format-arguments: list()));
  end;
  let pkg-file = ws/find-dylan-package-file(dir);
  let old-pkg-file = pkg-file & simplify-locator(pkg-file);
  let new-pkg-file = simplify-locator(file(ws/$dylan-package-file-name));
  if (old-pkg-file & ~force-package?)
    warn("Package file %s exists. Skipping creation.", old-pkg-file);
  else
    if (old-pkg-file)
      warn("This package is being created inside an existing package.");
    end;
    verbose("Edit %s if you need to change dependencies or if you plan"
              " to publish this library as a package.",
            new-pkg-file);
    local method dep-string (dep)
            format-to-string("%=", pm/dep-to-string(dep))
          end;
    let deps = join(map-as(<vector>, dep-string, deps), ", ");
    let dev-deps = iff(simple?, "", "\"testworks\"");
    templates
      := add(templates,
             make(<template>,
                  output-file: new-pkg-file,
                  format-string: $dylan-package-file-template,
                  format-arguments: list(deps, dev-deps, library-name, os/login-name(),
                                         library-name, os/login-name(), library-name)));
  end;
  for (template in templates)
    write-template(template);
    let name = template.%library-name;
    if (name)
      note("Created library %s.", name)
    end;
  end;
  let ws = ws/load-workspace(directory: dir);
  update-workspace(ws);
end function;

// Parse dependency specs like lib, lib@latest, or lib@1.2. Deps are always
// resolved to a specific released semantic version.
define function parse-dep-specs
    (specs :: <seq>) => (deps :: pm/<dep-vector>)
  let cat = pm/catalog();
  map-as(pm/<dep-vector>,
         method (spec)
           let dep = pm/string-to-dep(spec);
           let ver = pm/dep-version(dep);
           let rel = pm/find-package-release(cat, pm/package-name(dep), ver)
             | error("No released version found for dependency %=.", spec);
           if (ver = pm/$latest)
             make(pm/<dep>,
                  package-name: pm/package-name(dep),
                  version: pm/release-version(rel))
           else
             dep
           end
         end,
         specs)
end function;

// This is at the end of the file until we can use multi-line string syntax (i.e., a
// release after 2024.1) because it breaks dylan-mode code hightlighting.
define constant $makefile-template
  = #:string:[
DYLAN	?= $${HOME}/dylan

.PHONY: build install test dist clean distclean

build:
	deft update
	deft build %s

install: build
	mkdir -p $(DYLAN)/bin
	mkdir -p $(DYLAN)/install/%s/bin
	mkdir -p $(DYLAN)/install/%s/lib
	cp _build/bin/%s $(DYLAN)/install/%s/bin/%s
	cp -r _build/lib/lib* $(DYLAN)/install/%s/lib/
	ln -s -f $$(realpath $(DYLAN)/install/%s/bin/%s) $(DYLAN)/bin/%s

test:
	deft update
	deft test

dist: distclean install

clean:
	rm -rf _packages
	rm -rf registry
	rm -rf _build
	rm -rf _test
	rm -rf *~

distclean: clean
	rm -rf $(DYLAN)/install/%s
	rm -f $(DYLAN)/bin/%s
];
