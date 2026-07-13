BINARY   := load-spinner
APP      := $(BINARY).app
DIST     := dist
VERSION  := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
BUNDLE_ID := jp.nlink.load-spinner

.PHONY: all build test run clean

all: build

## test: run the unit test suite
test:
	swift test

## build: compile release binary and assemble dist/load-spinner.app
build:
	swift build -c release
	@rm -rf $(DIST)/$(APP)
	@mkdir -p $(DIST)/$(APP)/Contents/MacOS
	@cp .build/release/$(BINARY) $(DIST)/$(APP)/Contents/MacOS/$(BINARY)
	@sed -e 's|@VERSION@|$(VERSION)|g' -e 's|@BUNDLE_ID@|$(BUNDLE_ID)|g' \
		Resources/Info.plist.in > $(DIST)/$(APP)/Contents/Info.plist
	@printf 'APPL????' > $(DIST)/$(APP)/Contents/PkgInfo
	@echo "Built $(DIST)/$(APP) ($(VERSION))"

## run: build then launch the app from the bundle
run: build
	$(DIST)/$(APP)/Contents/MacOS/$(BINARY)

## clean: remove build artifacts
clean:
	swift package clean
	rm -rf $(DIST)
