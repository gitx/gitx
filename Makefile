# Common GitX developer commands. Run `make help` for the list.
#
# Targets deliberately mirror the steps in .github/workflows/BuildPR.yml so the
# two stay in sync; the CI step each one matches is named below.
# Changing a command here means changing it there too, and the other way round.
#
#   deps           "pre build"
#   unit-test      "Run unit tests"
#   all-tests      "Run tests"
#   archive        "Build project"
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

# Set to anything to have the packaging commands name every file they pack.
VERBOSE ?=
ZIP_QUIET := $(if $(VERBOSE),,-q)

# Set to a path to have xcodebuild write an .xcresult bundle, which is where CI
# reads the screenshots back out of a test run.
RESULT_BUNDLE ?=
RESULT_BUNDLE_ARG := $(if $(RESULT_BUNDLE),-resultBundlePath $(RESULT_BUNDLE))

XCODEBUILD := xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) ARCHS="$(ARCH)"

MAKEFILE := $(firstword $(MAKEFILE_LIST))

# Column the map target lines its descriptions up in.
MAP_WIDTH := 24

# The tests sign ad-hoc, so they drop the hardened runtime too: a Dev.xcconfig
# turns it on, and it refuses to map an ad-hoc signed framework into the host.
TEST_SETTINGS := CODE_SIGN_IDENTITY="-" ENABLE_HARDENED_RUNTIME=NO

.PHONY: help git-submodule-sync deps pre-build bootstrap build unit-test test \
	ui-test all-tests archive build-project app smoke-test run dmg map \
	export-signed \
	package-signed \
	dmg-signed clean git-clean-dry-run

help: ## Show this help
	@grep -hE '^[A-Za-z][A-Za-z.-]*:.*## ' $(MAKEFILE_LIST) \
		| awk -F':.*## ' '{printf "  %-20s %s\n", $$1, $$2}'

# Reads the edges out of make's own rule database, so a target that gains a
# prerequisite appears here without anyone maintaining a second copy of the
# graph. The descriptions alongside are the help text above, in a column.
map: ## Show which targets pull in which, with the help text
	@{ make -pnr -f $(MAKEFILE) 2>/dev/null \
	   | sed -n 's/^\([a-zA-Z][A-Za-z0-9_.-]*\):\([^=]*\)$$/EDGE \1\2/p' \
	   | grep -v '^EDGE $(MAKEFILE)' | sort -u; \
	   sed -n 's/^\([a-zA-Z][A-Za-z0-9_.-]*\):.*## \(.*\)$$/DESC \1 \2/p' $(MAKEFILE_LIST); } \
	| awk -v width=$(MAP_WIDTH) '$$1 == "EDGE" { target = $$2; $$1 = ""; $$2 = ""; sub(/^ +/, ""); prerequisites[target] = $$0; order[++found] = target; next } \
	       $$1 == "DESC" { target = $$2; $$1 = ""; $$2 = ""; sub(/^ +/, ""); description[target] = $$0; next } \
	       function label(indent, name,   left) { \
	           left = indent name; \
	           return (name in description ? sprintf("%-" width "s - %s", left, description[name]) : left) \
	       } \
	       function walk(name, indent,   i, count, needs) { \
	           count = split(prerequisites[name], needs, " "); \
	           for (i = 1; i <= count; i++) { print label(indent "\\_ ", needs[i]); walk(needs[i], indent "   ") } \
	       } \
	       END { \
	           if (found == 0) exit 1; \
	           print "Make Targets Map _______________________________________________________________"; print ""; \
	           print "Targets that pull something in _________"; print ""; \
	           for (i = 1; i <= found; i++) if (prerequisites[order[i]] != "") { print label("", order[i]); walk(order[i], ""); print "" } \
	           print "Targets that stand alone _______________"; print ""; \
	           for (i = 1; i <= found; i++) if (prerequisites[order[i]] == "") print label("", order[i]) \
	       }' \
	|| { echo "map: no targets found in $(MAKEFILE)" >&2; exit 1; }

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

bootstrap: pre-build ## (alias)

build: ## Build the app for local use
	$(XCODEBUILD) -destination "$(DESTINATION)" build

unit-test: ## Run the unit tests, needing no signing, repo or network
	$(XCODEBUILD) -destination "$(DESTINATION)" \
		-only-testing:GitXTests $(TEST_SETTINGS) $(RESULT_BUNDLE_ARG) test

test: unit-test ## (alias)

ui-test: ## Run the UI tests that drive the app and take the screenshots
	$(XCODEBUILD) -destination "$(DESTINATION)" \
		-only-testing:GitXUITests $(TEST_SETTINGS) \
		GITX_SCREENSHOT_REPO="$(GITX_SCREENSHOT_REPO)" $(RESULT_BUNDLE_ARG) test

# Runs the unit tests a second time, since the scheme tests every target. That
# is what CI's "Run tests" step does today, and this target exists to match it.
all-tests: ## Run every test target in the scheme, screenshots included
	$(XCODEBUILD) -destination "$(DESTINATION)" \
		$(TEST_SETTINGS) \
		GITX_SCREENSHOT_REPO="$(GITX_SCREENSHOT_REPO)" $(RESULT_BUNDLE_ARG) test

# Only for the goals that need the real identity: CI and `dmg` sign ad-hoc.
ifneq (,$(filter smoke-test dmg-signed,$(MAKECMDGOALS)))
archive: Dev.xcconfig
endif

archive: ## Build a release GitX.xcarchive, which the dmg targets export from
	$(XCODEBUILD) -archivePath $(ARCHIVE) $(ARCHIVE_SETTINGS) archive

build-project: archive ## (alias)

app: archive ## Copy the app out of the archive to build/GitX.app
	rm -rf $(APP)
	cp -R $(ARCHIVE)/Products/Applications/GitX.app $(APP)

# Covers what no test does: the Release build turns the hardened runtime on,
# and library validation then refuses to map a framework whose team differs
# from the tool loading it. Reads the output rather than the exit status,
# since gitx exits 1 after printing its version, while a bundle it cannot
# load dies in dyld before main and prints nothing. Wants the real identity
# `archive` builds with, so an ad-hoc archive proves nothing here.
#
# The guard keeps that from passing silently: asking for `dmg` in the same
# invocation turns the hardened runtime off for the archive they share, and
# without it library validation never runs and the check proves nothing.
smoke-test: app ## Check the packaged gitx tool can load the app frameworks
	@codesign -dv --verbose=2 "$(APP)" 2>&1 | grep -q "flags=.*runtime" \
		|| { echo "$(APP) carries no hardened runtime; run smoke-test on its own"; exit 1; }
	"$(APP)/Contents/Resources/gitx" --version | grep -q "GitX version"

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
export-signed: ## Export the signed app from an archive that already exists
	@test -f $(EXPORT_OPTIONS) \
		|| { echo "No $(EXPORT_OPTIONS); see EXPORT_OPTIONS in the Makefile"; exit 1; }
	rm -rf $(EXPORT_DIR)/GitX.app $(BUILD_DIR)/dist $(DMG) $(ZIP)
	mkdir -p $(EXPORT_DIR)
	xcodebuild -exportArchive -archivePath $(ARCHIVE) \
		-exportPath $(EXPORT_DIR) -exportOptionsPlist $(EXPORT_OPTIONS)

# Kept apart from the export so that notarization can staple the exported app
# before it is sealed into anything: a dmg or zip made ahead of the stapler
# carries no ticket, whatever is done to the app afterwards.
package-signed: ## Package the exported app (run export-signed first)
	rm -rf $(BUILD_DIR)/dist $(DMG) $(ZIP)
	mkdir -p $(BUILD_DIR)/dist
	cp -R $(EXPORT_DIR)/GitX.app $(BUILD_DIR)/dist/
	ln -s /Applications $(BUILD_DIR)/dist/
	hdiutil create -fs HFS+ -srcfolder $(BUILD_DIR)/dist -volname GitX $(DMG)
	rm -rf $(BUILD_DIR)/dist
	# -y stores the symlinks rather than following them, which is what keeps
	# the frameworks' Versions/Current a link and the signature verifiable.
	cd $(EXPORT_DIR) && zip -r -y $(ZIP_QUIET) $(abspath $(ZIP)) GitX.app

# Packaging runs as its own make so that it cannot start before the archive
# has finished. CI archives in a step of its own and calls package-signed.
dmg-signed: archive ## Build and package a signed disk image and zip
	$(MAKE) export-signed
	$(MAKE) package-signed

clean: ## Remove the build directory and Xcode's build products
	rm -rf $(BUILD_DIR)
	$(XCODEBUILD) clean

# Lists only, and nothing depends on it: the real `git clean -Xdf` throws away
# every ignored file in the tree, not just the ones a build made, so deciding
# to run it is left to you.
git-clean-dry-run: ## List the ignored files a `git clean -Xdf` would remove
	git clean -Xdn --exclude='!/Dev.xcconfig'
