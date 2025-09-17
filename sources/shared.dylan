Module: deft-shared


// Whether to do verbose output. This is set based on the --verbose command
// line option.
define variable *verbose?* :: <bool> = #f;

// Whether to run in debug mode, which has two effects:
// * Errors aren't caught and printed, so they result in entering the debugger
//   or printing a backtrace.
// * In combination with *verbose?* it results in trace-level output.
define variable *debug?* :: <bool> = #f;


//// Output

// Using these instead of calling format-out directly is intended to make it
// easier to make global changes in what the output looks like. For example, we
// don't have to call force-out after each output if we want line-buffered
// output (which we do).

define inline function note (fmt, #rest args) => ()
  apply(format-out, fmt, args);
  format-out("\n");
  force-out();
end;

define inline function debug (fmt, #rest args) => ()
  *debug?* & apply(note, fmt, args);
end;

define inline function verbose (fmt, #rest args) => ()
  *verbose?* & apply(note, fmt, args);
end;

define inline function trace (fmt, #rest args) => ()
  *debug?* & *verbose?* & apply(note, fmt, args);
end;

define inline function warn (fmt, #rest args) => ()
  apply(note, concat("WARNING: ", fmt), args);
end;

// https://github.com/dylan-lang/opendylan/issues/1358
define function load-json-file (file :: <file-locator>) => (config :: <table>)
  block ()
    fs/with-open-file(stream = file, if-does-not-exist: #"signal")
      let object = parse-json(stream, strict?: #f, table-class: <istring-table>);
      if (~instance?(object, <table>))
        error("Invalid JSON file %s, must contain at least {}", file);
      end;
      object
    end
  exception (fs/<file-does-not-exist-error>)
    make(<istring-table>)
  end
end function;

// Read the full contents of a file and return it as a string.  If the file doesn't exist
// return #f. (I thought if-does-not-exist: #f was supposed to accomplish this without
// the need for block/exception.  https://github.com/dylan-lang/opendylan/issues/1358)
define function file-content (path :: <locator>) => (text :: false-or(<string>))
  block ()
    fs/with-open-file(stream = path, if-does-not-exist: #"signal")
      read-to-end(stream)
    end
  exception (fs/<file-does-not-exist-error>)
    #f
  end
end function;
