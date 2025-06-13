.. highlight:: shell

********************
deft - The Dylan CLI
********************

The :program:`deft` command-line tool makes Dylan development
easier by taking care of some of the drudgery for you, including:

* managing Dylan workspaces and package dependencies
* creating boilerplate for new projects
* downloading and installing dependencies (no need for git submodules)
* generating "registry" files
* publishing packages to the Dylan package catalog

.. toctree::
   :maxdepth: 2
   :hidden:

   The pacman Package Manager <pacman>

Terminology
===========

package
  A blob of files that can be unpacked into a directory and which has a
  :file:`dylan-package.json` file in the top-level directory. A package
  currently corresponds to a single Git repository. A package has a set of
  versioned releases. A package may contain zero or more Dylan libraries.

workspace
  The directory in which :program:`deft` operates. Effectively this
  means a workspace is where the :file:`_build` and :file:`registry`
  directories are generated. In most cases, a workspace is the directory
  containing the :file:`dylan-package.json` file, but the ultimate arbiter is
  the :file:`workspace.json` file, if it exists. See `workspaces`_ for details.

active package
  A package checked out into the top-level of a workspace. In most cases a
  workspace is the same as a package directory so there is only one active
  package. See `Workspaces`_ for discussion of multi-package workspaces.

  `deft update`_ scans active packages when creating the registry.

release
  A specific version of a package. A release has a `Semantic Version`_ associated
  with it, such as ``0.5.0``.


Requirements
============

Make sure :program:`git` is on your :envvar:`PATH` so it can be found by the
package manager, which currently exec's ``git clone`` to install
packages. (This dependency will be removed in a future release.)


Where are Packages Installed?
=============================

:program:`deft` installs package dependencies in the :file:`_packages`
directory at the root of your workspace by default.  However, you may choose to
install them globally with :command:`deft update --global`.

The package manager always caches `its catalog <pacman-catalog>`_ in the global
location (per user).

The global :file:`_packages` directory location is chosen based on environment
variables, in this order:

1. ``${DYLAN}/_packages`` if :envvar:`DYLAN` is set.

2. ``${XDG_STATE_HOME}/dylan/_packages`` (Unix) if :envvar:`XDG_STATE_HOME` is
   set, or ``${CSIDL_LOCAL_APPDATA}/dylan/_packages`` (Windows) if
   :envvar:`CSIDL_LOCAL_APPDATA` is set.

3. ``${HOME}/.local/state/dylan/_packages`` otherwise.

**See also:** `XDG spec <https://specifications.freedesktop.org/basedir-spec/latest/>`_


Building From Source
====================

If you have **Open Dylan 2024.2 or later**, :program:`deft` is already
installed as part of that release. (In all 2022 and 2023 releases and in 2024.1
the tool was named :program:`dylan` but has now been renamed to
:program:`deft`.) But :program:`deft` is still under active development so you
may want to build the latest version. Here's how....

#.  Read the `Requirements`_ section, above.

#.  Clone and build the "deft" project::

        $ git clone --recursive https://github.com/dylan-lang/deft
        $ cd deft
        $ make
        $ make test      # optional
        $ make install

#.  Make sure that ``$DYLAN/bin`` is on your ``$PATH``. If you prefer not to
    set ``$DYLAN``, make sure that ``$HOME/dylan/bin`` is on your ``$PATH``, as
    that is where the Makefile installs the executable.

You should now be able to run `deft help`_ and go through the Hello World example below.


Quick Start
===========

This section shows how to

* create a hello-world application and its test suite,
* generate a registry for the compiler to locate libraries,
* build hello-world and its test suite, and
* add a new dependency to your package file.

First, create a place to put all your Dylan workspaces (usually one per
project), and change to that directory::

    $ mkdir -p ${HOME}/dylan/workspaces
    $ cd ${HOME}/dylan/workspaces

.. note:: The above is a typical setup, but you can put your workspaces
          anywhere, and they don't need to be together in a "workspaces"
          directory.

Now generate a new application library called "hello-world"::

    $ deft new application hello-world
    Created library hello-world.
    Created library hello-world-test-suite.
    Created library hello-world-app.
    Downloaded strings@1.1.0 to /home/you/dylan/workspaces/hello-world/_packages/strings/1.1.0/src/
    Downloaded command-line-parser@3.1.1 to /home/you/dylan/workspaces/hello-world/_packages/command-line-parser/3.1.1/src/
    Downloaded json@1.0.0 to /home/you/dylan/workspaces/hello-world/_packages/json/1.0.0/src/
    Downloaded testworks@2.3.1 to /home/you/dylan/workspaces/hello-world/_packages/testworks/2.3.1/src/
    Workspace directory is /home/you/dylan/workspaces/hello-world/.
    Updated 18 files in /home/you/dylan/workspaces/hello-world/registry/.

What did this do?

1. It created files with some initial code for your application, hello-world.
2. It created a test suite.
3. It ran ``deft update``, which downloaded all the packages your application
   depends on.
4. It created a "registry" directory, which ``dylan-compiler`` will use to
   locate dependencies.

Take a look at the generated files in the "hello-world" subdirectory. In
particular, :file:`hello-world/dylan-package.json` describes a Dylan package,
which you could eventually publish for others to use.

Also look at one or two registry files and you'll see that they simply contain
a pointer to the build file (a ".lid" file) for a library.

Now let's build! ::

    $ cd hello-world
    $ deft build --all
    ...compiler output...

    $ _build/bin/hello-world
    Hello world!

.. note:: On the initial build there are compiler warnings for the "dylan"
          library.  These are due to a known (harmless) bug and can be
          ignored. Subsequent builds will not show them, and will go much
          faster since they'll use cached build products.

Since we used the ``--all`` flag above, ``hello-world``, ``hello-world-app``,
and ``hello-world-test-suite`` were built. Run the test suite::

    $ _build/bin/hello-world-test-suite
    Running suite hello-world-test-suite:
    Running test test-greeting: PASSED in 0.000065s and 7KiB
    Completed suite hello-world-test-suite: PASSED in 0.000065s

    Ran 1 check: PASSED
    Ran 1 test: PASSED
    PASSED in 0.000065 seconds

Now let's add a new dependency to our library. Let's say we want to ``use
base64`` in our :file:`library.dylan` file. The compiler finds libraries via
the registry, but there is no "base64" registry file so the compiler won't find
it. To fix this, edit :file:`hello-world/dylan-package.json` to add the
dependency.  Change this::

    "dependencies": [  ],

to this::

    "dependencies": [ "base64" ],

and then run `deft update`_ again::

    $ deft update
    Downloaded base64@0.3.0 to /home/you/hello-world/_packages/base64/0.3.0/src/
    Updated 2 of 20 registry files in /home/you/hello-world/registry/.


Note that we didn't specify a version for "base64", so the latest version is downloaded.
For serious projects it's a good idea to specify a particular version, like "base64\@0.3"
so that dependencies don't change unexpectedly when new versions are released.

We also haven't actually changed the hello-world code to use base64. That is
left as an exercise. (Modify :file:`library.dylan` and run ``deft build -a`` again.)

Now that you've got a working project, try some other :program:`deft`
`subcommands`_, the most useful ones are:

* `deft status`_ tells you the status of the active packages. It will find the
  ``hello-world`` package but will complain that it's not a Git repository. Run
  ``git init`` if you like.

* `deft list`_ with ``--all`` lists all the packages in the catalog. (Note
  that many libraries are still included with Open Dylan. They'll be moved to
  separate packages in the future.)


.. index::
   single: workspace
   single: workspaces

Workspaces
==========

A workspace is a directory in which you work on a Dylan package, or multiple
interrelated packages. :program:`deft` often needs to find the root
of the workspace, for example to decide where to write the "registry" directory
or to invoke :program:`dylan-compiler`.  It does this by looking for one of the
following files, in the order shown, and by using the directory containing the
file:

1. :file:`workspace.json` -- A place to put workspace configuration
   settings. If this file exists, it takes precedence over the following two
   options in determining the workspace root.
2. :file:`dylan-package.json` -- The package definition file.
3. The current working directory is used if neither of the above are found.

Usually, the workspace root is just the package directory (i.e., the directory
containing :file:`dylan-package.json`), because most of the time you will be
working on one package at a time. In this case there is no need for a
:file:`workspace.json` file unless you need to provide workspace settings not
contained in the package file.

In the less common case of working on multiple, interrelated Dylan packages at
the same time, the :file:`workspace.json` file is necessary in order to put the
workspace root above the level of the package directories. For example, your
multi-package workspace might look like this::

    my-workspace/_build               // created by dylan-compiler
    my-workspace/package-1/*.dylan
    my-workspace/package-1/*.lid
    my-workspace/package-1/dylan-package.json
    my-workspace/package-2/*.dylan
    my-workspace/package-2/*.lid
    my-workspace/package-2/dylan-package.json
    my-workspace/registry             // created by deft
    my-workspace/workspace.json       // created by you

Most :program:`deft` subcommands need to be run inside a workspace so that
they can

* find or create the "registry" directory,
* invoke :program:`dylan-compiler` in the workspace root directory, so that
  compiler always uses the same :file:`_build` subdirectory,
* find the "active packages" in the workspace, and
* find settings in the :file:`workspace.json` file.

If you create a :file:`workspace.json` file it must contain at least an empty
JSON dictionary, ``{}``.

.. code-block:: json

   {
       "default-library": "cool-app-test-suite"
   }

The ``"default-library"`` attribute is currently the only valid attribute and
is used by the `deft build`_ command to decide which library to build when no
other library is specified. A good choice would be your main test suite
library. It may also be left unspecified.

The Registry
============

Open Dylan uses "registries" to locate used libraries. Setting up a development
workspace historically involved a lot of manual Git cloning, creating registry
files for each used library, and adding Git submodules.

`deft update`_ takes care of that for you. It scans each active package and
its dependencies for ".lid" files and writes a registry file for each one (but
see below for platform-specific libraries), and it downloads and installs
package dependencies for you.

.. note:: If you use the same workspace directory on multiple
          platforms (e.g., a network mounted directory or shared by a
          virtual machine) you will need to run `deft update`_ on
          **each** platform so that the correct platform-specific
          registry entries are created.  :program:`deft`
          makes no attempt to figure out which packages are "generic"
          and which are platform-specific, so it always writes
          registry files specifically for the current platform, e.g.,
          ``x86_64-linux``.

Git Submodules
--------------

It generally shouldn't be necessary to use Git submodules when using Deft. In fact, if
your workspace has a submodule which is also pulled in as a package dependency it will
confuse Deft because it will find multiple LID files for the same library. In that case
Deft will issue a warning and choose one arbitrarily.  Use the package instead of a
submodule.

If you need to pull in some code from another repository that doesn't have a Deft package
there should be no conflict.


Platform-specific Libraries
---------------------------

.. note:: If you're new to Dylan you may want to skip this section as it's
          likely you won't need to worry about it yet.

Open Dylan supports multi-platform libraries via the registry and per-platform
`LID files
<https://opendylan.org/library-reference/lid.html>`_. Among other
things, LID files tell the compiler which files to compile, and in which
order. To write platform-specific code, put it in a separate Dylan source file
and only include it in that platform's LID file.

To complicate matters, one LID file may include another LID file via the
``LID`` header.

In order for `deft update`_ to generate the registry it must figure out which
LID files match the current platform. For example, when on Linux it shouldn't
generate a registry file for a Windows-only library.

To accomplish this the ``Platforms`` LID header was introduced. In your LID
file you may specify the platforms on which the library runs::

  Platforms: x86_64-linux
             riscv64-linux

If the current platform matches one of the platforms listed in the LID file, a
registry file is generated for the library. (If there is no ``Platforms``
header, the library is assumed to run on all platforms.)

If a LID **is included** in another LID file and **does not** explicitly match
the current platform via the ``Platforms`` keyword, then no registry entry is
written for that LID file. The assumption being that the included LID file only
contains shared data and isn't a complete LID file on its own.

This effectively means that if you *include* a LID file in one
platform-specific LID file then you must either create one LID file per
platform for that library, or you must use the ``Platforms`` header in the
**included** LID file to specify all platforms that *don't* have a
platform-specific LID file.

For example, the base "dylan" library itself has a `dylan-win32.lid
<https://github.com/dylan-lang/opendylan/blob/master/sources/dylan/dylan-win32.lid>`_
file so that it can specify some Windows resource files. "dylan-win32.lid"
includes "dylan.lid" and has ``Platforms: x86-win32``. Since there's nothing
platform-specific for any other platform, creating 8 other platform-specific
LID files would be cumbersome. Instead, "dylan.lid" just needs to say which
platforms it explicitly applies to by adding this::

  Platforms: aarch-64-linux
             arm-linux
             x86_64-freebsd
             ...etc, but not x86-win32...

Package Manager
===============

:program:`deft` relies on :doc:`pacman`, the Dylan package manager
(unrelated to the Arch Linux tool by the same name), to install dependencies.
See :doc:`the pacman documentation <pacman>` for information on how to define a
package, version syntax, and how dependency resolution works.

Global ``deft`` Options
=======================

Note that global command line options must be specified between "deft" and the
first subcommand name. Example: ``deft --debug build --all``

``--debug``
  Disables error handling so that when an error occurs the debugger will be
  entered, or if not running under a debugger a stack trace will be printed.
  When used with the ``--verbose`` flag this also enables tracing of dependency
  resolution, which can be fun! ``:-)``.

``--verbose``
  Enables more verbose output, such as displaying which packages are
  downloaded, which registry files are written, etc.

  When used with the ``--debug`` flag this also enables tracing of dependency
  resolution.


Subcommands
===========


.. index::
   single: deft help subcommand
   single: subcommand; deft help

deft help
---------

Displays overall help or help for a specific subcommand.

Synopsis:
  ``deft help``

  ``deft help <subcommand> [<sub-subcommand> ...]``

  ``deft <subcommand> [<sub-subcommand> ...] --help``


.. index::
   single: deft build subcommand
   single: subcommand; deft build

deft build
----------

Build the configured default library or the specified libraries.

Synopsis:
  ``deft build [options] [--all | lib1 lib2 ...]``

`deft build`_ is essentially a wrapper around :program:`dylan-compiler` that
has a few advantages:

#. Invoke it from any directory inside your workspace and it will run the build
   in the top-level workspace directory so that the :file:`_build` and
   :file:`registry` directories are used.

#. Configure a set of libraries to build by default, in
   :file:`dylan-package.json`.

#. Use the ``--all`` flag to build all libraries in the workspace. For example,
   normally this builds both the main library and the test suite.

#. Specify multiple libraries on one command line, unlike with
   :program:`dylan-compiler`.

`deft build`_ exits after the first library that generates serious compiler
warnings, i.e., if :program:`dylan-compiler` exits with an error
status. (Requires an Open Dylan release later than 2020.1.)

.. note:: This subcommand is purely a convenience; it is perfectly valid to run
          :program:`dylan-compiler` directly instead, after changing to the
          workspace top-level directory.

**Options:**

``--all``
  Build all libraries found in the active packages of the current workspace.
  This option is ignored if specific libraries are requested on the command
  line also.

``--clean``
  Do not use cached build products; rebuild from scratch.

``--link``
  Link the executable or shared library. Defaults to true. Use ``--no-link``
  for faster builds when iterating through compiler warnings.

``--unify``
  Combine all used libraries into a single executable. Note that
  :program:`dylan-compiler` puts the generated executable in
  :file:`_build/sbin` instead of :file:`_build/bin` when this flag is used.
  (Requires Open Dylan 2022.1 or later.)

.. index::
   single: deft install subcommand
   single: subcommand; deft install

deft install
------------

Install packages.

Synopsis: ``deft install <package> [<package> ...]``

This command is primarily useful if you want to browse the source code in a
package locally without having to worry about where to clone it from. If you
are in a workspace directory the packages are installed in the workspace's
"_packages" subdirectory. Otherwise, see `Where are Packages Installed?`_.


.. index::
   single: deft list subcommand
   single: subcommand; deft list

.. _deft-list:

deft list
---------

Display a list of installed packages along with the installed version number
and the latest version available in the catalog, plus a short description. With
the ``--all`` option, list all packages in the catalog whether installed or
not.

An exclamation point is displayed next to packages for which the latest
installed version is lower than the latest published version.

Example::

   $ deft list
        Inst.   Latest  Package               Description
        0.1.0    0.1.0  base64                Base64 encoding
      ! 3.1.0    3.2.0  command-line-parser   Parse command line flags and subcommands
        0.1.0    0.1.0  concurrency           Concurrency utilities
        0.6.0    0.6.0  deft                  Manage Dylan workspaces, packages, and registries
        ...


.. index::
   single: deft new application subcommand
   single: subcommand; deft new application

deft new application
--------------------

Generate the boilerplate for a new executable application.

Synopsis: ``deft new application [options] <name> [<dependency> ...]``

This command is the same as `deft new library`_ except that in addition to the
``<name>`` library it also generates a ``<name>-app`` executable library with a
``main`` function.

Here's an example of creating an executable named "killer-app" which depends on
http version 1.0 and the latest version of logging. ::

  $ deft new application killer http@1.0 logging
  $ deft build --all
  $ _build/bin/killer-test-suite
  $ _build/bin/killer-app

.. note:: The executable is named "killer-app" because it can't have the same name as the
          shared library, "killer". The compiler would complain that "killer" depends on
          itself. Instead, a :file:`Makefile` is generated for the purpose of renaming the
          executable file to "killer" during installation. Just run ``make install``.

          You may of course rename the executable to "killer" and the shared library to
          "killer-lib" or whatever you like.  Naming is hard.

You must run `deft update`_ whenever dependencies are changed, to install the new
dependencies and update the registry files.

**See also:** `deft new library`_

**Options:**

``--force-package``, ``-p``
  Create :file:`dylan-package.json` even if already inside a package. This is
  intended for testing and continuous integration use.

``--git``
  Generate a ``.gitignore`` file. The default is false.

``--simple``
  Generate only an executable application, without a separate shared library or
  test suite. This also generates all files in the top-level directory. This option
  is intended to be useful for making "throw away" libraries for learning or testing
  purposes.

.. index::
   single: deft new library subcommand
   single: subcommand; deft new library

deft new library
----------------

Generate code for a new shared library.

Synopsis: ``deft new library [options] <name> [<dependency> ...]``

This command is the same as `deft new application`_ except that it doesn't
generate the corresponding ``<name>-app`` executable library or the associated
:file:`Makefile`.

Specifying dependencies is optional. They should be in the same form as
specified in the :file:`dylan-package.json` file. For example, "strings\@1.0".

This command generates the following code:

* A main library and module definition and initial source files.
* A corresponding test suite library and initial source files.
* A :file:`dylan-package.json` file (unless this new library is being added to
  an existing package).

You must run `deft update`_ whenever dependencies are changed, to install the new
dependencies and update the registry files.

**See also:** `deft new application`_

**Options:**

``--force-package``, ``-p``
  Create :file:`dylan-package.json` even if already inside a package. This is
  intended for testing and continuous integration use.

``--git``
  Generate a ``.gitignore`` file. The default is false.

Here's an example of creating a library named "http" which depends on "strings"
version 1.0 and the latest version of "logging". ::

  $ deft new library http strings@1.0 logging
  $ deft build --all
  $ _build/bin/killer-app-test-suite

Edit the generated :file:`dylan-package.json` file to set the repository URL,
description, and other attributes for your package.


.. index::
   single: deft new workspace subcommand
   single: subcommand; deft new workspace

deft new workspace
------------------

Create a new workspace.

Synopsis: ``deft new workspace [options] <name>``

.. note:: In most cases there is no need to explicitly create a workspace since
          the package directory (the directory containing
          :file:`dylan-package.json`) will be used as the workspace by
          :program:`deft` subcommands if no workspace.json file is
          found. Explicit workspaces are mainly needed when working on multiple
          interrelated packages at the same time.

**Options:**

``--directory=DIR``
  Create the workspace under ``DIR`` instead of in the current working
  directory.

`deft new workspace`_ creates a new workspace directory and initializes it
with a :file:`workspace.json` file. The workspace name is the only required
argument. Example::

  $ deft new workspace my-app
  $ cd my-app
  $ ls -l
  total 8
  -rw-r--r-- 1 you you   28 Dec 29 18:03 workspace.json

Clone repositories in the top-level workspace directory to create active
packages (or create them with `deft new library`_ and `deft new
application`_), then run `deft update`_.

**See also:** `Workspaces`_


.. index::
   single: deft publish subcommand
   single: subcommand; deft publish

deft publish
------------

The "publish" subcommand adds a new release of a package to the package
catalog.

Synopsis: ``deft publish <pacman-catalog-directory>``

.. note:: For now, until a fully automated solution is implemented, the publish
   command works by modifying a local copy of the `pacman-catalog`_ Git
   repository and you must manually submit a pull request with the changes. In
   a future release this manual step will be eliminated.

This command publishes a package associated with the current workspace. It
searches up from the current directory to find
:file:`dylan-package.json`. *Note that this means you can't be in the root of a
multi-package workspace.* Once you're satisfied that you're ready to release a
new version of your package (tests pass, doc updated, etc.) follow these steps:

#.  Update the ``"version"`` attribute in :file:`dylan-package.json` to be the
    new release's version.

    Also update any dependencies as needed. Normally this will happen naturally
    during development as you discover you need newer package versions, but
    this is a good time to review deps and update to get bug fixes if desired.
    **Remember to** `deft update`_ **and re-run your tests if you change
    deps!**

    Push the above changes, if any, to your main branch.

#.  Make a new release on GitHub with a tag that matches the release version.
    For example, if the ``"version"`` attribute in :file:`dylan-package.json`
    is ``"0.5.0"`` the GitHub release should be tagged ``v0.5.0``.

#.  Clone https://github.com/dylan-lang/pacman-catalog somewhere and create a
    new branch. ::

      $ cd /tmp
      $ git clone https://github.com/dylan-lang/pacman-catalog
      $ cd pacman-catalog
      $ git switch -t -c my-package

    In the next step the `deft publish`_ command will make changes in this
    directory for you.

#.  Run :command:`deft publish /tmp/pacman-catalog`, pointing to where you
    just cloned the pacman catalog.

#.  Commit the changes to `pacman-catalog`_ and submit a pull request.  The
    tests to verify the catalog will be run automatically by a GitHub workflow.

#.  Once your PR has been merged, verify that the package is available in the
    catalog by running :command:`deft install my-package@0.5.0`, substituting
    your new package name and release version.

.. note:: If you remove `optional package attributes
          <pacman.html#optional-package-attributes>`_ from
          :file:`dylan-package.json` they will be removed from the catalog
          entry for *all releases* of your package.


.. index::
   single: deft status subcommand
   single: subcommand; deft status

deft status
-----------

Display the status of the current workspace.

Synopsis: ``deft status``

**Options:**

``--directory``
  Only show the workspace directory and skip showing the active packages.
  This is intended for use by tooling.

**Example:**

::

    $ deft status
    Workspace: /home/cgay/dylan/workspaces/dt/
    Active packages:
      http                     : ## master...origin/master (dirty)
      deft                     : ## dev...master [ahead 2] (dirty)
      pacman-catalog           : ## publish...master [ahead 1] (dirty)


.. index::
   single: deft test subcommand
   single: subcommand; deft test

deft test
---------

Run tests for packages in the current workspace.

Synopsis: ``deft test [options] [library ...] [--] [...testworks options...]``

`deft test`_ determines which test binaries to run by choosing the first option below
that is not empty.

1. Library names that are passed on the command line.
2. The library specified by ``"default-test-library"`` in the :file:`workspace.json`
   file.
3. Any executable test libraries in the workspace's active packages. (This assumes
   that the executable will include the other test libraries in the package.)
4. Any non-executable test libraries in the workspace's active packages.

Executable test libraries are invoked directly (it is assumed that they call the
Testworks `run-test-application`_ function) and non-executable test libraries are run via
`testworks-run`_.  Any options following ``--`` on the command line are passed to the
test executable (which is sometimes `testworks-run`_).

If any test run fails `deft test`_ exits immediately with a failure status without
running the tests in the remaining libraries.

**Options:**

``--build``
  Rebuild test libraries before running the tests. The default is to rebuild; use
  ``--no-build`` to disable the build and use the existing test binary.

``--continue``
  If a test binary fails, continue running the remaining test binaries instead of
  exiting immediately with a failure status.

``--all``
  In addition to the active package tests, run tests for all dependencies.

  .. note:: There is no guarantee that the tests for all dependencies will be able to
            compile without error because they themselves may have dependencies that
            can't be satisfied. The prime example is if the dependency's tests depend on
            a different major version of Open Dylan and its bundled libraries.


.. index::
   single: deft update subcommand
   single: deft subcommand; update
   single: subcommand; deft update
   single: LID file
   single: active package
   single: dependencies
   single: workspace.json file

deft update
-----------

Update the workspace based on the current set of active packages.

Synopsis: ``deft update``

The "update" command may be run from anywhere inside a workspace directory and
performs two actions:

#.  Installs all active package dependencies, as specified in their
    :file:`dylan-package.json` files. Any time these dependencies are changed
    you should run `deft update`_ again.

#.  Updates the registry to have an entry for each library in the workspace's
    active packages or their dependencies.

    The :file:`registry` directory is created in the root of the workspace and
    all registry files are written to a subdirectory named after the local
    platform.

    If a dependency is also an active package in this workspace, the active
    package is preferred over the specific version listed as a dependency.

.. note:: Registry files are only created if they apply to the platform of the
          local machine. For example, on the ``x86_64-linux`` platform LID
          files that specify ``Platforms: win32`` will not cause a registry
          file to be generated.

**Example:**

Create a workspace named ``dt``, with one active package, "deft", update
it, and build the test suite::

   $ deft new workspace dt
   $ cd dt
   $ git clone --recursive https://github.com/dylan-lang/deft
   $ deft update
   $ deft build deft-test-suite


.. index::
   single: deft version subcommand
   single: subcommand; deft version

deft version
------------

Show the version of the :program:`deft` command you are using. This is the Git
version from which `deft <https://github.com/dylan-lang/deft>`_ was
compiled.

Synopsis: ``deft version``


Index and Search
================

* :ref:`genindex`
* :ref:`search`


.. _pacman-catalog:    https://github.com/dylan-lang/pacman-catalog.git
.. _semantic version:  https://semver.org/spec/v2.0.0.html
.. _run-test-application: https://package.opendylan.org/testworks/reference.html#testworks:testworks:run-test-application
.. _testworks-run:        https://package.opendylan.org/testworks/reference.html#testworks-run
