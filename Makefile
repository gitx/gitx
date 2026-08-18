XCODEBUILD ?= xcodebuild
ARCH ?= $(shell uname -m)
CONFIGURATION ?= Debug
DERIVED_DATA ?= build/DerivedData

.DEFAULT_GOAL := build

.PHONY: build clean rebuild

build:
	$(XCODEBUILD) \
		-workspace GitX.xcworkspace \
		-scheme GitX \
		-configuration $(CONFIGURATION) \
		-destination 'platform=macOS,arch=$(ARCH)' \
		-derivedDataPath $(DERIVED_DATA) \
		build

clean:
	$(XCODEBUILD) \
		-workspace GitX.xcworkspace \
		-scheme GitX \
		-configuration $(CONFIGURATION) \
		-destination 'platform=macOS,arch=$(ARCH)' \
		-derivedDataPath $(DERIVED_DATA) \
		clean

rebuild: clean build
