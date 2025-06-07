Module: %workspaces

// Keys used to lookup values in a parsed LID file.
define constant $platforms-key = #"platforms";
define constant $files-key     = #"files";
define constant $library-key   = #"library";
define constant $lid-key       = #"lid";
define constant $origin-key    = #"origin";
define constant $idl-file-key  = #"idl-file";
define constant $prefix-key    = #"prefix";

define class <lid> (<object>)
  constant slot lid-locator :: <file-locator>,
    required-init-keyword: locator:;

  // A map from <symbol> to sequences of <lid-value>, one for each line
  // associated with the key. Ex: #"files" => #["foo.dylan", "bar.dylan"]
  constant slot lid-data :: <table>,
    required-init-keyword: data:;

  // Sequence of other <lid>s in which this <lid> is included via the "LID:"
  // keyword.
  constant slot lid-included-in :: <seq> = make(<stretchy-vector>);
end class;

define method print-object
    (lid :: <lid>, stream :: <stream>) => ()
  // TODO: use printing-object:print:io
  format(stream, "#<lid %= %=>", lid-value(lid, $library-key), address-of(lid));
end method;

define function lid-values
    (lid :: <lid>, key :: <symbol>) => (_ :: false-or(<seq>))
  element(lid.lid-data, key, default: #f)
end function;

// The potential types that may be returned from lid-value.
define constant <lid-value> = type-union(<string>, <lid>, singleton(#f));

define function lid-value
    (lid :: <lid>, key :: <symbol>, #key error? :: <bool>) => (v :: <lid-value>)
  let items = element(lid.lid-data, key, default: #f);
  if (items & items.size = 1)
    items[0]
  elseif (error?)
    workspace-error("A single value was expected for key %=. Got %=. LID: %s",
                    key, items, lid.lid-locator);
  end
end function;

define function library-name
    (lid :: <lid>, #key error? :: <bool>) => (name :: false-or(<string>))
  lid-value(lid, $library-key, error?: error?)
end function;

// Return the transitive (via files included with the "LID" header) contents of
// the "Files" LID header.
define function dylan-source-files
    (lid :: <lid>) => (files :: <seq>)
  let files = #();
  local method source-files (lid)
          map(method (filename)
                if (~ends-with?(lowercase(filename), ".dylan"))
                  filename := concat(filename, ".dylan");
                end;
                let file = file-locator(lid.lid-locator.locator-directory, filename);
                as(<string>, simplify-locator(file))
              end,
              lid-values(lid, $files-key) | #());
        end;
  local method do-lid (lid)
          files := concat(files, source-files(lid));
          for (child in lid-values(lid, $lid-key) | #())
            do-lid(child)
          end;
        end;
  do-lid(lid);
  files
end function;

define function matches-current-platform?
    (lid :: <lid>) => (matches? :: <bool>)
  let current-platform = as(<string>, os/$platform-name);
  let platform = lid-value(lid, $platforms-key);
  // Assume that if the LID is included in another LID then it contains the
  // platform-independent attributes of a multi-platform project and is not a top-level
  // library.
  platform = current-platform
    | (~platform & lid.library-name & empty?(lid.lid-included-in))
end function;

define function add-lid
    (ws :: <workspace>, active-package :: false-or(pm/<release>), lid :: <lid>)
 => ()
  if (matches-current-platform?(lid))
    let path = as(<string>, lid.lid-locator);
    unless (element(ws.%lids-by-pathname, path, default: #f))
      ws.%lids-by-pathname[path] := lid;
      let library = lid-value(lid, $library-key);
      if (library)
        let lids = element(ws.%lids-by-library, library, default: #());
        ws.%lids-by-library[library] := pair(lid, lids);
      end;
      if (active-package)
        let lids = element(ws.%lids-by-release, active-package, default: #());
        ws.%lids-by-release[active-package] := pair(lid, lids);
      end;
    end;
  end;
end function;

// Read a <lid> from `lid-path` and store it in `registry`.  Returns the <lid>,
// or #f if nothing ingested.
define function ingest-lid-file
    (ws :: <workspace>, active-package :: false-or(pm/<release>), lid-path :: <file-locator>)
 => (lid :: false-or(<lid>))
  let lid = parse-lid-file(ws, active-package, lid-path);
  if (empty?(dylan-source-files(lid)))
    warn("LID file %s has no (transitive) 'Files' property.", lid-path);
  end;
  if (skip-lid?(ws, lid))
    warn("Skipping %s, preferring previous .lid file.", lid-path);
    #f
  else
    add-lid(ws, active-package, lid);
    lid
  end
end function;

// Returns true if `lid` has "hdp" extension and an existing LID in the same
// directory has "lid" extension, since the hdp files are usually automatically
// generated from the LID.
define function skip-lid?
    (ws :: <workspace>, lid :: <lid>) => (skip? :: <bool>)
  if (string-equal-ic?("hdp", lid.lid-locator.locator-extension))
    let library = lid-value(lid, $library-key, error?: #t);
    let directory = lid.lid-locator.locator-directory;
    let existing = choose(method (x)
                            x.lid-locator.locator-directory = directory
                          end,
                          element(ws.%lids-by-library, library, default: #[]));
    // Why only size = 1?  Shouldn't I be looking for exactly lid.locator-name + ".lid"
    existing.size = 1
      & string-equal-ic?("lid", existing[0].lid-locator.locator-extension)
  end
end function;

// Read a CORBA spec file and store a <lid> into `ws` for each of the
// generated libraries.
define function ingest-spec-file
    (ws :: <workspace>, active-package :: false-or(pm/<release>), spec-path :: <file-locator>)
 => (lids :: <seq>)
  let spec :: <lid> = parse-lid-file(ws, active-package, spec-path);
  let origin = lid-value(spec, $origin-key, error?: #t);
  let lids = #();
  if (string-equal-ic?(origin, "omg-idl"))
    // Generate "protocol", "skeletons", and "stubs" registries for CORBA projects.
    // The sources for these projects won't exist until generated by the build.
    // Assume .../foo.idl generates .../stubs/foo-stubs.hdp etc.
    let idl-path = merge-locators(as(<file-locator>,
                                     lid-value(spec, $idl-file-key, error?: #t)),
                                  locator-directory(spec-path));
    let idl-name = locator-base(idl-path);
    let prefix = lid-value(spec, $prefix-key);
    for (kind in #("protocol", "skeletons", "stubs"))
      // Unsure as to why the remote-nub-protocol library doesn't need
      // "protocol: yes" in its .lid file, but what the heck, just generate a
      // registry entry for "protocol" always.
      if (kind = "protocol" | string-equal-ic?("yes", lid-value(spec, as(<symbol>, kind)) | ""))
        let lib-name = concat(prefix | idl-name, "-", kind);
        let hdp-file = concat(prefix | idl-name, "-", kind, ".hdp");
        let dir-name = iff(prefix,
                           concat(prefix, "-", kind),
                           kind);
        let hdp-path = file-locator(locator-directory(idl-path), dir-name, hdp-file);
        let lid = make(<lid>,
                       locator: simplify-locator(hdp-path),
                       data: begin
                               let t = make(<table>);
                               t[$library-key] := vector(lib-name);
                               t
                             end);
        add-lid(ws, active-package, lid);
        lids := pair(lid, lids);
      end;
    end for;
  end if;
  lids
end function;

// Parse the contents of `path` into a new `<lid>` and return it. Every LID
// keyword is turned into a symbol and used as the table key, and the data
// associated with that keyword is stored as a sequence of strings, even if the
// keyword is known to allow only a single value. There is one exception: the
// "LID:" keyword is recursively parsed into a sequence of `<lid>` objects. For
// example:
//
//   #"library" => #("http")
//   #"files"   => #("foo.dylan", "bar.dylan")
//   #"LID"     => #({<lid>}, {<lid>})
define function parse-lid-file
    (ws :: <workspace>, active-package :: false-or(pm/<release>), path :: <file-locator>)
 => (lid :: <lid>)
  let headers = sr/read-file-header(path);
  let library = element(headers, $library-key, default: #f);
  let locator = simplify-locator(path);
  let lid = make(<lid>, locator: locator, data: headers);
  let lid-header = element(headers, $lid-key, default: #f);
  if (lid-header)
    let sub-lids = #();
    local method filename-to-lid (filename)
            let sub-path = file-locator(locator-directory(path), filename);
            let sub-lid = element(ws.%lids-by-pathname, as(<string>, sub-path), default: #f)
              | ingest-lid-file(ws, active-package, sub-path);
            if (sub-lid)
              sub-lids := add-new!(sub-lids, sub-lid);
              add-new!(sub-lid.lid-included-in, lid);
            end;
            sub-lid
          end;
    // ingest-lid-file can return #f, hence remove()
    headers[$lid-key] := remove(map(filename-to-lid, lid-header), #f);
  end;
  lid
end function;
