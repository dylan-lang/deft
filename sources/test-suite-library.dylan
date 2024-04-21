Module: dylan-user

define library deft-test-suite
  use common-dylan;
  use deft;
  use io;
  use strings;
  use system;
  use testworks;
end library;

define module deft-test-suite
  use common-dylan;
  use file-system;
  use format;
  use locators;
  use operating-system;
  use pacman;
  use %pacman;
  use shared;
  use standard-io;
  use streams;
  use strings;
  use testworks;
  use threads;
  use workspaces;
  use %workspaces;
end module;
