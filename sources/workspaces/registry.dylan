Module: %workspaces
Synopsis: Scan for LID files and generate a registry


// Return a registry file locator for the library named by `lid`.
define function registry-file-locator
    (ws :: <workspace>, lid :: <lid>) => (_ :: <file-locator>)
  let platform = as(<string>, os/$platform-name);
  let directory = subdirectory-locator(ws.workspace-directory, "registry", platform);
  // The registry file must be written in lowercase so that on unix systems the
  // compiler can find it.
  let lib = lowercase(lid-value(lid, $library-key, error?: #t));
  file-locator(directory, lib)
end function;

// Write a registry file for `lid` if it doesn't exist or the content changed.
define function write-registry-file
    (ws :: <workspace>, lid :: <lid>) => (written? :: <bool>)
  let registry-file = registry-file-locator(ws, lid);
  let lid-file = simplify-locator(lid.lid-locator);
  // Write the absolute pathname of the LID file rather than
  // abstract://dylan/<relative-path> because the latter doesn't work reliably
  // on Windows. For example abstract://dylan/../../pkg/...  resolved to
  // C:\..\pkg\... when compiling in c:\users\cgay\dylan\workspaces\dt
  let new-content = format-to-string("%s\n", lid-file);
  let old-content = file-content(registry-file);
  if (new-content = old-content)
    trace("Not writing %s (still points to %s)", registry-file, lid-file);
    #f
  else
    fs/ensure-directories-exist(registry-file);
    fs/with-open-file(stream = registry-file,
                      direction: #"output",
                      if-exists?: #"replace")
      write(stream, new-content);
    end;
    verbose("Wrote %s (%s)", registry-file, lid-file);
    #t
  end
end function;

// Read the full contents of a file and return it as a string.  If the file
// doesn't exist return #f. (I thought if-does-not-exist: #f was supposed to
// accomplish this without the need for block/exception.)
define function file-content (path :: <locator>) => (text :: false-or(<string>))
  block ()
    fs/with-open-file(stream = path, if-does-not-exist: #"signal")
      read-to-end(stream)
    end
  exception (fs/<file-does-not-exist-error>)
    #f
  end
end function;

// Create/update a single registry directory having an entry for each library
// in each active package and all transitive dependencies.  This traverses
// package directories to find .lid files. Note that it assumes that .lid files
// that have no "Platforms:" section are generic, and writes a registry file
// for them (unless they're included in another LID file via the LID: keyword,
// in which case it is assumed they're for inclusion only).
define function update-registry
    (ws :: <workspace>, releases :: <seq>, actives :: <istring-table>)
 => (total :: <int>, written :: <int>, no-platform-libs :: <seq>)
  let current-platform = as(<string>, os/$platform-name);
  let total = 0;
  let written = 0;
  let no-platform = make(<stretchy-vector>);
  for (lids keyed-by library in ws.lids-by-library)
    let candidates
      = choose(method (lid)
                 let platform = lid-value(lid, $platforms-key);
                 platform = current-platform
                   | (~platform & empty?(lid.lid-included-in))
               end,
               lids);
    select (candidates.size)
      0 =>
        // We'll display these at the end, as a group.
        add-new!(no-platform, library, test: \=);
      1 =>
        inc!(total);
        write-registry-file(ws, candidates[0])
          & inc!(written);
      otherwise =>
        warn("Library %= has multiple .lid files for platform %=.\n"
               "  %s\nRegistry will point to the first one, arbitrarily.",
             library, current-platform,
             join(candidates, "\n  ", key: method (lid)
                                             as(<string>, lid.lid-locator)
                                           end));
        inc!(total);
        write-registry-file(ws, candidates[0])
          & inc!(written);
    end select;
  end for;
  values(total, written, no-platform)
end function;
