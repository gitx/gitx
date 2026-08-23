# Common GitX developer commands. Run `make help` for the list.
#
# Targets deliberately mirror the steps in .github/workflows/BuildPR.yml so the
# two stay in sync; the CI step each one matches is named below.
# Changing a command here means changing it there too, and the other way round.
#
#   deps           "pre build"
#   unit-test      "Run unit tests"     (alias: test)
#   all-tests      "Run tests"
#   archive        "Build project"      (alias: build-project)
#   package-signed "Prepare artifact"
#
# `pre-build` is `deps` plus the submodule checkout that CI gets from its own
# checkout step, so a fresh local clone wants pre-build and CI wants deps.
#
# `ui-test` runs the UI tests on their own. CI's "Run tests" runs the whole
# scheme, repeating the unit tests it has already run in its own step, so
# `all-tests` is the one that matches CI today and `ui-test` is the narrower
# target to reach for otherwise.
#
# Signing: without a Dev.xcconfig the build is signed ad-hoc, and the hardened
# runtime rejects that, leaving the app unable to load its own frameworks. So
# `dmg` builds with the hardened runtime off and stays runnable either way,
# while `archive` and `dmg-signed` keep it and want a real identity, which the
# README explains how to set up; `make Dev.xcconfig` writes one for you. The
# tests need no identity at all.
#
# Override the architecture on an Intel Mac or for a cross build:
#   make build ARCH=x86_64

ARCH ?= $(shell uname -m)

WORKSPACE := GitX.xcworkspace
SCHEME := GitX
DESTINATION := platform=macOS,arch=$(ARCH)

BUILD_DIR := build
ARCHIVE := $(BUILD_DIR)/GitX.xcarchive
APP := $(BUILD_DIR)/GitX.app
DMG := $(BUILD_DIR)/GitX-$(ARCH).dmg

# Repo the UI screenshot tests open. CI points this at a fixed snapshot so the
# screenshots stay comparable; locally this checkout is good enough.
GITX_SCREENSHOT_REPO ?= $(CURDIR)

# Signing options for `dmg-signed`, in the format `xcodebuild -exportArchive`
# expects. Not in the repo: create your own, or export one from Xcode.
EXPORT_OPTIONS ?= ExportOptions.plist

# Extra build settings for the archive, as `xcodebuild` NAME=VALUE arguments.
ARCHIVE_SETTINGS ?=

# Where `dmg-signed` exports the signed app, and the zip it packs alongside the
# disk image. CI overrides both, since it notarizes the app where it lands.
EXPORT_DIR ?= $(BUILD_DIR)/export
ZIP ?= $(BUILD_DIR)/GitX-$(ARCH).zip

# Set to a path to have xcodebuild write an .xcresult bundle, which is where CI
# reads the screenshots back out of a test run.
RESULT_BUNDLE ?=
RESULT_BUNDLE_ARG := $(if $(RESULT_BUNDLE),-resultBundlePath $(RESULT_BUNDLE))

XCODEBUILD := xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) ARCHS="$(ARCH)"

.PHONY: help git-submodule-sync deps pre-build bootstrap build unit-test test \
	ui-test all-tests archive build-project app run dmg package-signed \
	dmg-signed clean git-clean-dry-run

help: ## Show this help
	@grep -hE '^[A-Za-z][A-Za-z.-]*:.*## ' $(MAKEFILE_LIST) \
		| awk -F':.*## ' '{printf "  %-20s %s\n", $$1, $$2}'

# A real file, not a phony target, so that make leaves an existing config
# alone rather than writing over settings you may have edited by hand.
Dev.xcconfig: ## Write the local signing settings from the keychain certificate
	scripts/make-dev-xcconfig.sh $@

git-submodule-sync: ## Check out the submodules at the revisions this tree wants
	git submodule sync
	git submodule update --init --recursive

deps: ## Build the objective-git and libgit2 dependencies
	cd External/objective-git && script/bootstrap && script/update_libgit2

# CI gets the submodules from actions/checkout and so calls `deps` on its own;
# a fresh local clone needs both halves.
pre-build: git-submodule-sync deps ## Check out the submodules, then build the dependencies

bootstrap: pre-build

build: ## Build the app for local use
	$(XCODEBUILD) -destination "$(DESTINATION)" build

unit-test: ## Run the unit tests, needing no signing, repo or network
	$(XCODEBUILD) -destination "$(DESTINATION)" \
		-only-testing:GitXTests CODE_SIGN_IDENTITY="-" test

test: unit-test

ui-test: ## Run the UI tests that drive the app and take the screenshots
	$(XCODEBUILD) -destination "$(DESTINATION)" \
		-only-testing:GitXUITests CODE_SIGN_IDENTITY="-" \
		GITX_SCREENSHOT_REPO="$(GITX_SCREENSHOT_REPO)" $(RESULT_BUNDLE_ARG) test

# Runs the unit tests a second time, since the scheme tests every target. That
# is what CI's "Run tests" step does today, and this target exists to match it.
all-tests: ## Run every test target in the scheme, screenshots included
	$(XCODEBUILD) -destination "$(DESTINATION)" \
		CODE_SIGN_IDENTITY="-" \
		GITX_SCREENSHOT_REPO="$(GITX_SCREENSHOT_REPO)" $(RESULT_BUNDLE_ARG) test

archive: ## Build a release GitX.xcarchive, which the dmg targets export from
	$(XCODEBUILD) -archivePath $(ARCHIVE) $(ARCHIVE_SETTINGS) archive

build-project: archive

app: archive ## Copy the app out of the archive to build/GitX.app
	rm -rf $(APP)
	cp -R $(ARCHIVE)/Products/Applications/GitX.app $(APP)

# Runs the Debug build, not the archive: Release turns on the hardened runtime,
# and an ad-hoc signature plus the hardened runtime leaves the app unable to
# load its own frameworks. -n forces a new instance, since an installed GitX
# claims the same bundle id and `open` would just bring that one to the front.
run: build ## Open the app that was just built
	open -n "$$($(XCODEBUILD) -showBuildSettings \
		| awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $$2}')/GitX.app"

# Drops the hardened runtime so that an ad-hoc signed image still runs; with a
# real identity to hand, `make dmg ARCHIVE_SETTINGS=` keeps it instead.
dmg: ARCHIVE_SETTINGS = ENABLE_HARDENED_RUNTIME=NO
dmg: app ## Package build/GitX.app into an unsigned disk image that runs locally
	rm -rf $(BUILD_DIR)/dist $(DMG)
	mkdir $(BUILD_DIR)/dist
	cp -R $(APP) $(BUILD_DIR)/dist/
	ln -s /Applications $(BUILD_DIR)/dist/
	hdiutil create -fs HFS+ -srcfolder $(BUILD_DIR)/dist -volname GitX $(DMG)
	rm -rf $(BUILD_DIR)/dist

# Clears the exported app rather than the directory holding it, since CI
# exports into the checkout itself and that is not ours to delete.
package-signed: ## Package an archive that already exists (needs ExportOptions.plist)
	@test -f $(EXPORT_OPTIONS) \
		|| { echo "No $(EXPORT_OPTIONS); see EXPORT_OPTIONS in the Makefile"; exit 1; }
	rm -rf $(EXPORT_DIR)/GitX.app $(BUILD_DIR)/dist $(DMG) $(ZIP)
	mkdir -p $(EXPORT_DIR)
	xcodebuild -exportArchive -archivePath $(ARCHIVE) \
		-exportPath $(EXPORT_DIR) -exportOptionsPlist $(EXPORT_OPTIONS)
	mkdir -p $(BUILD_DIR)/dist
	cp -R $(EXPORT_DIR)/GitX.app $(BUILD_DIR)/dist/
	ln -s /Applications $(BUILD_DIR)/dist/
	hdiutil create -fs HFS+ -srcfolder $(BUILD_DIR)/dist -volname GitX $(DMG)
	rm -rf $(BUILD_DIR)/dist
	cd $(EXPORT_DIR) && zip -r $(abspath $(ZIP)) GitX.app

# Packaging runs as its own make so that it cannot start before the archive
# has finished. CI archives in a step of its own and calls package-signed.
dmg-signed: archive ## Build and package a signed disk image and zip
	$(MAKE) package-signed

clean: ## Remove the build directory and Xcode's build products
	rm -rf $(BUILD_DIR)
	$(XCODEBUILD) clean

# Lists only, and nothing depends on it: the real `git clean -Xdf` throws away
# every ignored file in the tree, not just the ones a build made, so deciding
# to run it is left to you.
git-clean-dry-run: ## List the ignored files a `git clean -Xdf` would remove
	git clean -Xdn --exclude='!/Dev.xcconfig'
