Module: dylan-user


define library deft-app
  use common-dylan;
  use command-line-parser;
  use deft;
  use io;
  use logging;
  use system;
end library;

define module deft-app
  use common-dylan;
  use command-line-parser;
  use deft;
  use format-out;
  use logging;
  use operating-system, prefix: "os/";
  use shared;
end module;
