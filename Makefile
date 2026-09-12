APP_NAME := OpenGuard
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SOURCES := $(wildcard Sources/*.m)
HEADERS := $(wildcard Sources/*.h)
MIN_MACOS := 10.13

.PHONY: all app clean verify package run

all: app

app: $(MACOS_DIR)/$(APP_NAME)

$(MACOS_DIR)/$(APP_NAME): $(SOURCES) $(HEADERS) Resources/Info.plist
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	@cp Resources/Info.plist "$(CONTENTS_DIR)/Info.plist"
	xcrun clang -fobjc-arc -fmodules -Wall -Wextra -Werror \
		-Wno-deprecated-declarations -Wno-unused-parameter \
		-arch arm64 -arch x86_64 -mmacosx-version-min=$(MIN_MACOS) \
		-framework Cocoa -framework CoreServices \
		$(SOURCES) -o "$@"
	codesign --force --sign - --timestamp=none "$(APP_DIR)"

verify: app
	@file "$(MACOS_DIR)/$(APP_NAME)"
	@codesign --verify --deep --strict --verbose=2 "$(APP_DIR)"
	@plutil -lint "$(CONTENTS_DIR)/Info.plist"
	@"$(MACOS_DIR)/$(APP_NAME)" --diagnose md
	@"$(MACOS_DIR)/$(APP_NAME)" --verify-content

package: verify
	@mkdir -p dist
	ditto -c -k --sequesterRsrc --keepParent "$(APP_DIR)" "dist/$(APP_NAME)-1.1.0-universal.zip"

run: app
	open "$(APP_DIR)"

clean:
	rm -rf "$(BUILD_DIR)" dist
