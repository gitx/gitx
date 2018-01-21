#!/usr/bin/env python

import argparse
import subprocess
import os

import helpers
from project import Project


def build(project):
    print "Building scheme {} ({})".format(project.scheme(), project.current_config())
    helpers.xcodebuild(project.scheme(), project.workspace(), project.current_build_config(), ["build"], project.build_base_dir())


def clean(project):
    print "Cleaning scheme {} ({})".format(project.scheme(), project.current_config())
    helpers.xcodebuild(project.scheme(), project.workspace(), project.current_build_config(), ["clean"], project.build_base_dir())


def build_cmd(args):
    if args.action == 'clean':
        project = Project(os.getcwd(), "debug")
        clean(project)
        project = Project(os.getcwd(), "release")
        clean(project)
    else:
        project = Project(os.getcwd(), args.action, None)
        build(project)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['debug', 'release', 'clean'], nargs='?', default='debug')
    parser.set_defaults(func=build_cmd)

    args = parser.parse_args()
    args.func(args)
