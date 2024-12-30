# Low-tech Makefile to build and install deft. You will need a working "dylan" binary on
# your PATH somewhere.

DYLAN		?= $${HOME}/dylan

.PHONY: build clean install remove-deft-artifacts test dist distclean

git_version := $(shell git describe --tags --always --match 'v*')

build:
	dylan update
	dylan build deft-app

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
	dylan build deft-test-suite && _build/bin/deft-test-suite

dist: distclean install

clean:
	rm -rf _packages
	rm -rf registry
	rm -rf _build
	rm -rf _test
	rm -rf *~

distclean: clean
	rm -rf $(DYLAN)/install/deft
	rm $(DYLAN)/bin/deft
	rm $(DYLAN)/bin/deft-app
	rm $(DYLAN)/bin/dylan
