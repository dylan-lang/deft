Module: dylan-user

define library deft-test-suite
  use testworks;

  use deft;
end library;

define module deft-test-suite
  use testworks;

  use deft-shared;              // where we get the dylan module from
  use pacman;
  use %pacman;
  use workspaces;
  use %workspaces;
end module;
