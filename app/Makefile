APP        := build/Schwips.app
BIN        := .build/release/schwips
CATALOG    := Resources/Localizable.xcstrings
INSTALLED  := /Applications/Schwips.app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
XCSTRINGSTOOL := xcrun xcstringstool
SOURCES    := $(shell find Sources -name '*.swift') Package.swift
STRINGS_DIR := $(CURDIR)/build/strings

# Signing. The app is sandboxed and signed with the Apple Development
# certificate. It uses no restricted entitlement (no iCloud yet), so no
# provisioning profile is needed.
SIGN_ID      := Apple Development
ENTITLEMENTS := Resources/Schwips.entitlements

.DEFAULT_GOAL := build

.PHONY: build app install test strings icon clean

# Rebuilt only when a source file is newer than the binary.
$(BIN): $(SOURCES)
	swift build -c release

build: $(BIN)

# build/Schwips.app: the binary, Info.plist, the icon and the compiled catalog
# (en.lproj, de.lproj) in the main bundle, where SwiftUI and the core find
# their texts. Signed with the hardened runtime and the sandbox entitlements.
app: $(BIN) $(CATALOG) Resources/Info.plist Resources/AppIcon.icns $(ENTITLEMENTS)
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BIN) $(APP)/Contents/MacOS/Schwips
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	$(XCSTRINGSTOOL) compile $(CATALOG) --output-directory $(APP)/Contents/Resources
	codesign --force --options runtime --entitlements $(ENTITLEMENTS) --sign "$(SIGN_ID)" $(APP)
	$(LSREGISTER) -f $(APP)

# Replaces /Applications/Schwips.app. Only on the user's request.
install: app
	rm -rf $(INSTALLED)
	cp -R $(APP) $(INSTALLED)
	$(LSREGISTER) -u $(CURDIR)/$(APP)
	$(LSREGISTER) -f $(INSTALLED)

test:
	swift test

# Syncs the texts the compiler finds (String(localized:), Text literals) into
# the catalog. New keys arrive without translations; add English and German.
strings:
	rm -rf $(STRINGS_DIR) build/strings-build
	mkdir -p $(STRINGS_DIR)
	swift build --scratch-path build/strings-build \
		-Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc $(STRINGS_DIR)
	$(XCSTRINGSTOOL) sync $(CATALOG) --stringsdata $(STRINGS_DIR)/*.stringsdata

# Redraws the app icon (Scripts/make-icon.swift) into Resources/AppIcon.icns,
# which is committed, so `make app` needs no drawing step.
icon:
	rm -rf build/AppIcon.iconset
	mkdir -p build
	swift Scripts/make-icon.swift build/AppIcon.iconset
	iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns

clean:
	rm -rf .build build
