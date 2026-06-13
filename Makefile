.PHONY: bootstrap gen build test release run install package verify-package clean

PROJECT := Audiyo.xcodeproj
SCHEME := Audiyo
CONFIGURATION := Debug
DERIVED_DATA := .build/DerivedData
RELEASE_CONFIGURATION := Release
RELEASE_APP := $(DERIVED_DATA)/Build/Products/$(RELEASE_CONFIGURATION)/Audiyo.app
DIST_DIR := dist
DMG := $(DIST_DIR)/Audiyo-0.1.0.dmg
DMG_STAGE := .build/dmg-stage
DMG_MOUNT := .build/dmg-mount

bootstrap:
	brew install xcodegen

gen:
	xcodegen generate

build: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

release: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(RELEASE_CONFIGURATION) -derivedDataPath $(DERIVED_DATA) build

test: gen
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(DERIVED_DATA) test

run: build
	open $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Audiyo.app

install: release
	ditto $(RELEASE_APP) /Applications/Audiyo.app

package: release
	rm -rf $(DMG_STAGE) $(DMG)
	mkdir -p $(DMG_STAGE) $(DIST_DIR)
	ditto $(RELEASE_APP) $(DMG_STAGE)/Audiyo.app
	ln -s /Applications $(DMG_STAGE)/Applications
	hdiutil create -volname Audiyo -srcfolder $(DMG_STAGE) -ov -format UDZO $(DMG)

verify-package: package
	rm -rf $(DMG_MOUNT)
	mkdir -p $(DMG_MOUNT)
	hdiutil attach $(DMG) -nobrowse -mountpoint $(DMG_MOUNT)
	test -d $(DMG_MOUNT)/Audiyo.app
	test -L $(DMG_MOUNT)/Applications
	hdiutil detach $(DMG_MOUNT)
	rm -rf $(DMG_MOUNT)

clean:
	rm -rf $(PROJECT) .build $(DIST_DIR)
