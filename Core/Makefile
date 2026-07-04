# WorkspaceContactsCore — headless test entry point.
#
# Package.swift already wires the CLT swift-testing framework search path + @rpath into
# the test target, so the bundle builds and *loads*. But SwiftPM decides whether to run
# its swift-testing phase by probing for the Testing module via a command-line search
# flag — a manifest setting compiles fine yet doesn't flip that decision. So a bare
# `swift test` on the Command Line Tools toolchain builds and then runs zero tests.
# Passing `-Xswiftc -F <clt-frameworks>` flips it. This target does that; nothing to copy.
#
# Usage:  make test
#         make test FILTER=EmailDomainTests
#         make clean

FW    := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
FLAGS := -Xswiftc -F -Xswiftc $(FW)

.PHONY: test clean

test:
	swift test $(FLAGS) $(if $(FILTER),--filter $(FILTER),)

clean:
	swift package clean
