APP_NAME := OpenGuard
VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
DMG_STAGING_DIR := $(BUILD_DIR)/dmg
ZIP_PATH := dist/$(APP_NAME)-$(VERSION)-universal.zip
DMG_PATH := dist/$(APP_NAME)-$(VERSION)-universal.dmg
CHECKSUM_PATH := dist/SHA256SUMS.txt
SOURCES := $(wildcard Sources/*.m)
HEADERS := $(wildcard Sources/*.h)
APP_SOURCES := $(filter-out Sources/main.m,$(SOURCES))
WINDOW_TEST := $(BUILD_DIR)/OpenGuardWindowLifecycleTest
MIN_MACOS := 10.13

.PHONY: all app clean verify test-window-lifecycle package run

all: app

app: $(MACOS_DIR)/$(APP_NAME)

$(MACOS_DIR)/$(APP_NAME): $(SOURCES) $(HEADERS) Resources/Info.plist Resources/OpenGuard.icns
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	@cp Resources/Info.plist "$(CONTENTS_DIR)/Info.plist"
	@cp Resources/OpenGuard.icns "$(RESOURCES_DIR)/OpenGuard.icns"
	xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Werror \
		-Wno-deprecated-declarations -Wno-unused-parameter \
		-arch arm64 -arch x86_64 -mmacosx-version-min=$(MIN_MACOS) \
		-framework Cocoa -framework CoreServices \
		$(SOURCES) -o "$@"
	codesign --force --sign - --timestamp=none "$(APP_DIR)"

$(WINDOW_TEST): Tests/OGWindowLifecycleTest.m $(APP_SOURCES) $(HEADERS)
	@mkdir -p "$(BUILD_DIR)"
	xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Werror \
		-Wno-deprecated-declarations -Wno-unused-parameter \
		-I Sources -mmacosx-version-min=$(MIN_MACOS) \
		-framework Cocoa -framework CoreServices \
		$(APP_SOURCES) Tests/OGWindowLifecycleTest.m -o "$@"

test-window-lifecycle: $(WINDOW_TEST)
	@"$(WINDOW_TEST)"

verify: app test-window-lifecycle
	@file "$(MACOS_DIR)/$(APP_NAME)"
	@codesign --verify --deep --strict --verbose=2 "$(APP_DIR)"
	@plutil -lint "$(CONTENTS_DIR)/Info.plist"
	@"$(MACOS_DIR)/$(APP_NAME)" --diagnose md
	@"$(MACOS_DIR)/$(APP_NAME)" --verify-content

package: verify
	@mkdir -p dist "$(DMG_STAGING_DIR)"
	@rm -rf "$(DMG_STAGING_DIR)/$(APP_NAME).app" "$(DMG_STAGING_DIR)/Applications"
	@ditto "$(APP_DIR)" "$(DMG_STAGING_DIR)/$(APP_NAME).app"
	@ln -s /Applications "$(DMG_STAGING_DIR)/Applications"
	ditto -c -k --sequesterRsrc --keepParent "$(APP_DIR)" "$(ZIP_PATH)"
	hdiutil create -volname "$(APP_NAME) $(VERSION)" -srcfolder "$(DMG_STAGING_DIR)" \
		-ov -format UDZO "$(DMG_PATH)"
	@cd dist && shasum -a 256 "$(notdir $(ZIP_PATH))" "$(notdir $(DMG_PATH))" | tee "$(notdir $(CHECKSUM_PATH))"

run: app
	open "$(APP_DIR)"

clean:
	rm -rf "$(BUILD_DIR)" dist
