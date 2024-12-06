# Low-tech Makefile to build and install deft.

DYLAN		?= $${HOME}/dylan
install_dir     = $(DYLAN)/install/deft
install_bin     = $(install_dir)/bin
install_lib     = $(install_dir)/lib
link_target     = $(install_bin)/deft-app
link_source     = $(DYLAN)/bin/dylan

git_version := "$(shell git describe --tags --always --match 'v*')"

.PHONY: build build-with-version clean install install-debug really-install remove-deft-artifacts test dist distclean

build: remove-deft-artifacts
	OPEN_DYLAN_USER_REGISTRIES=${PWD}/registry dylan-compiler -build -unify deft-app

# Hack to add the version to the binary with git tag info. Don't want this to
# be the normal build because it causes unnecessary rebuilds.
build-with-version: remove-deft-artifacts
	file="sources/commands/utils.dylan"; \
	  orig=$$(mktemp); \
	  temp=$$(mktemp); \
	  cp -p $${file} $${orig}; \
	  cat $${file} | sed "s,/.__./.*/.__./,/*__*/ \"${git_version}\" /*__*/,g" > $${temp}; \
	  mv $${temp} $${file}; \
	  OPEN_DYLAN_USER_REGISTRIES=${PWD}/registry \
	    dylan-compiler -build -unify deft-app; \
	  cp -p $${orig} $${file}

# Until the install-deft GitHub Action is no longer referring to deft-app
# we also create a link named deft-app.
really-install:
	mkdir -p $(DYLAN)/bin
	cp _build/sbin/deft-app $(DYLAN)/bin/deft
	ln -f $(DYLAN)/bin/deft $(DYLAN)/bin/deft-app

install: build-with-version really-install

# Build and install without the version hacking above.
install-debug: build really-install

# Deft needs to be buildable with submodules so that it can be built on
# new platforms without having to manually install deps.
test: build
	OPEN_DYLAN_USER_REGISTRIES=${PWD}/registry \
	  dylan-compiler -build deft-test-suite \
	  && DYLAN_CATALOG=ext/pacman-catalog _build/bin/deft-test-suite

dist: distclean install

# Sometimes I use deft to develop deft, so this makes sure to clean
# up its artifacts.
remove-deft-artifacts:
	rm -rf _packages
	find registry -not -path '*/generic/*' -type f -exec rm {} \;

clean: remove-deft-artifacts
	rm -rf _build
	rm -rf _test

distclean: clean
	rm -rf $(install_dir)
	rm -f $(link_source)
