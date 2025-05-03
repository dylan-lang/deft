Module: dylan-user

define library deft
  use collections,
    import: { collectors, table-extensions };
  use columnist;
  use command-line-parser;
  use dylan,
    import: { dylan-extensions, threads };
  use io,
    import: { format, format-out, print, standard-io, streams };
  use json;
  use regular-expressions;
  use file-source-records;
  use strings;
  use system,
    import: { date, file-system, locators, operating-system };
  use uncommon-dylan,
    import: { uncommon-dylan, uncommon-utils };

  export
    deft,
    deft-shared,
    pacman, %pacman,
    workspaces, %workspaces;
end library;

// Utilities shared by all Deft modules, and also a set of shared imports.
define module deft-shared
  use collectors,          export: all;
  use command-line-parser, export: all;
  use date,                export: all, import: { current-date, <duration> };
  use dylan-extensions,    export: all, import: { address-of };
  use file-source-records, export: all, prefix: "sr/";
  use file-system,         export: all, prefix: "fs/";
  use format-out,          export: all;
  use format,              export: all;
  use json,                export: all;
  use locators,            export: all;
  use operating-system,    export: all, prefix: "os/";
  use print,               export: all;
  use regular-expressions, export: all;
  use standard-io,         export: all;
  use streams,             export: all;
  use strings,             export: all;
  use threads,             export: all, import: { dynamic-bind };
  use uncommon-dylan,      export: all;
  use uncommon-utils,      export: all;

  export
    *debug?*,
    *verbose?*,
    debug, note, verbose, trace, warn,
    file-content,
    load-json-file;
end module;

define module pacman
  export
    <catalog-error>,
    catalog,
    dylan-directory,
    package-manager-directory,
    *package-manager-directory*,
    $package-directory-name,

    <catalog>,
    catalog-directory,
    find-package,
    find-package-release,
    validate-catalog,
    write-package-file,

    <package>,
    package-category,
    package-contact,
    package-description,
    package-keywords,
    package-locator,
    package-name,
    package-releases,

    <package-error>,
    download,
    install,
    install-deps,
    installed-versions,
    installed?,
    load-all-catalog-packages,
    load-catalog-package,
    load-dylan-package-file,
    package-directory,
    release-directory,
    source-directory,

    <release>,
    publish-release,
    release-dependencies,
    release-dev-dependencies,
    release-license,
    release-package,
    release-to-string,
    release-url,
    release-version,

    <dep-vector>,
    <dep>,
    dep-to-string, string-to-dep,
    dep-version,
    resolve-deps,
    resolve-release-deps,

    $latest,
    <branch-version>,
    <semantic-version>,
    <version>,
    version-branch,
    version-major,
    version-minor,
    version-patch;
end module;

define module %pacman
  use deft-shared;
  use pacman;

  // For the test suite.
  export
    $dylan-env-var,
    <dep-conflict>,
    <dep-error>,
    <latest>,
    add-release,
    cache-package,
    cached-package,
    catalog-package-cache,
    find-release,
    max-release,
    string-parser,                 // #string:...
    string-to-version, version-to-string;
end module;

define module workspaces
  create
    $dylan-package-file-name,
    $workspace-file-name,
    <workspace-error>,
    workspace-error,
    <workspace>,
    active-package-directory,
    active-package-file,
    active-package?,
    build-directory,
    current-dylan-package,
    ensure-deps-installed,
    find-active-package-test-libraries,
    find-dylan-package-file,
    find-workspace-directory,
    find-workspace-file,
    library-name,
    <lid>,
    lid-value,
    lid-values,
    lids-by-library,
    lids-by-pathname,
    lids-by-release,
    load-workspace,
    registry-directory,
    update-registry,
    workspace-active-packages,
    workspace-default-library-name,
    workspace-directory;
end module;

define module %workspaces
  use deft-shared;
  use workspaces;
  use pacman,
    prefix: "pm/",
    // Because pm/*... is seen as a /* comment by dylan-mode.
    rename: { *package-manager-directory* => *package-manager-directory* };

  // Exports for the test suite.
  export
    $lid-key,
    lid-data,
    parse-lid-file;
end module;

define module deft
  use columnist;
  use deft-shared;
  use pacman,
    prefix: "pm/",
    // Because pm/*... is seen as a /* comment by dylan-mode.
    rename: { *package-manager-directory* => *package-manager-directory* };
  use workspaces, prefix: "ws/";

  export
    deft-command-line;
end module;
