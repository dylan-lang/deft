Module: deft
Synopsis: Utilities for use by deft commands


// The Makefile replaces this string with the actual tagged version before
// building. DON'T MOVE THE /*__*/ MARKERS since they're part of the regex.
// Using the comment markers enables recovery if someone commits a string
// other than "HEAD" by accident. git's `ident` attribute doesn't use tag
// names and `filter` looks more complex than it's worth.
define constant $deft-version :: <string> = /*__*/ "HEAD" /*__*/;


// Run an executable or shell command. `command` may be a string or a sequence
// of strings. If a string it is run with `/bin/sh -c`. If a sequence of
// strings the first element is the executable pathname. Returns the exit
// status of the command and the combined output to stdout and stderr.
define function run
    (command :: <seq>, #key working-directory :: false-or(<directory-locator>))
 => (status :: <int>, output :: <string>)
  let stream = make(<string-stream>, direction: #"output");
  let status
    = os/run-application(command,
                         under-shell?: instance?(command, <string>),
                         working-directory: working-directory,
                         outputter: method (string, #rest ignore)
                                      write(stream, string)
                                    end);
  values(status, stream.stream-contents)
end function;
