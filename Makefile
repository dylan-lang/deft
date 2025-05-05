# Low-tech Makefile to build and install deft.

DYLAN		?= $${HOME}/dylan

.PHONY: build clean install remove-deft-artifacts test dist distclean

git_version := $(shell git describe --tags --always --match 'v*')

# Hack to add the version to the binary with Git tag info. During development I (cgay)
# just build with "deft build" so the unnecessary rebuilds that this would cause aren't
# an issue.
build:
	dylan update
	file="sources/commands/version.dylan"; \
	  orig=$$(mktemp); \
	  temp=$$(mktemp); \
	  cp -p $${file} $${orig}; \
	  cat $${file} | sed "s|_NO_VERSION_SET_|${git_version} built on $$(date -Iseconds)|g" > $${temp}; \
	  mv $${temp} $${file}; \
	  dylan build deft-app; \
	  cp -p $${orig} $${file}

install: build
	mkdir -p $(DYLAN)/bin
	mkdir -p $(DYLAN)/install/deft/bin
	mkdir -p $(DYLAN)/install/deft/lib
	cp _build/bin/deft-app $(DYLAN)/install/deft/bin/deft
	cp -r _build/lib/lib* $(DYLAN)/install/deft/lib/
	# For unified exe these could be hard links but for now they must be symlinks so
	# that the relative paths to ../lib are correct. With --unify I ran into the
	# "libunwind.so not found" bug.
	ln -s -f $$(realpath $(DYLAN)/install/deft/bin/deft) $(DYLAN)/bin/deft
	# For temp backward compatibility...
	ln -s -f $$(realpath $(DYLAN)/install/deft/bin/deft) $(DYLAN)/bin/deft-app
	ln -s -f $$(realpath $(DYLAN)/install/deft/bin/deft) $(DYLAN)/bin/dylan

test:
	dylan update
	OPEN_DYLAN_USER_REGISTRIES=${PWD}/registry dylan-compiler -build deft-test-suite \
	  && _build/bin/deft-test-suite

dist: distclean install

clean:
	rm -rf _packages
	rm -rf registry
	rm -rf _build
	rm -rf _test
	rm -rf *~

distclean: clean
	rm -rf $(DYLAN)/install/deft
	rm -f $(DYLAN)/bin/deft
	rm -f $(DYLAN)/bin/deft-app
	rm -f $(DYLAN)/bin/dylan
