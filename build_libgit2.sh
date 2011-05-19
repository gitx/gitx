#!/bin/sh

# build_libgit2.sh
# GitX
#
# Created by BrotherBard on 7/3/10.
# Copyright 2010 BrotherBard. All rights reserved.
# 
# based on: http://log.yeahrightkeller.com/post/270155578/run-script-while-cleaning-in-xcode

buildAction () {
	echo "Building libgit2..."
	if [[ -d .git ]]
	then
		if [ "$(which git)" == "" ]; then
			echo "git not found"
			exit -1
		fi
		git submodule init
		git submodule sync
		git submodule update
		cd libgit2
		CFLAGS='-arch i386 -arch x86_64'
        ./waf --out=$TARGET_TEMP_DIR --prefix=$TARGET_BUILD_DIR configure
		if [ $? != 0 ]; then
			echo "error: failed to waf configure"
			exit -1
		fi
		./waf build-static
		if [ $? != 0 ]; then
			echo "error: failed to waf build-static"
			exit -1
		fi
		ranlib $TARGET_TEMP_DIR/static/libgit2.a
		cp $TARGET_TEMP_DIR/static/libgit2.a $TARGET_BUILD_DIR
	else
		echo "error: Not a git repository."
		echo "error: clone GitX first so that the libgit2 submodule can be updated"
		exit 1
	fi
}

cleanAction () {
	echo "Cleaning libgit2..."
	cd libgit2
	./waf clean
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# MAIN

#echo "Running with ACTION=${ACTION}"

case $ACTION in
	# NOTE: it gets set to "" rather than "build" when doing a build.
	"")
		buildAction
		;;

	"clean")
		cleanAction
		;;
esac

exit 0

