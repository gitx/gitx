# Easier build flow

1. `brew install carthage`
2. `carthage update`
3. I didn't manage how to sign spark crap, so: `rm -rf Carthage/Build/Mac/Sparkle.framework/Versions/A/Resources/*.app`
4. `GitX.xcworkspace`, build&archive


# What is GitX?

[![GitHub Actions Build Status](https://github.com/gitx/gitx/workflows/build-gitx/badge.svg)](https://github.com/gitx/gitx/actions?query=workflow%3Abuild-gitx)

GitX is an OS X (MacOS) native graphical client for the `git` version
control system.

GitX has a long history of various branches and versions maintained by
various people over the years. This github org & repo are an attempt to
consolidate and move forward with a current, common, community-maintained
version. See discussion at [**Forking, and plans for the future of
GitX**](https://github.com/gitx/gitx.github.io/issues/1).

### How to Build & Install:

See [the wiki page](https://github.com/gitx/gitx/wiki/Build-instructions)
for build instructions.

### Screenshots

![Staging View](screenshot-stage.png)

![History View](screenshot-history.png)
