#!/usr/bin/env python
import os

this_file = os.path.realpath(__file__)
proj_dir = os.path.abspath(os.path.join(os.path.dirname(this_file), ".."))
os.chdir(proj_dir)

os.system("git submodule update --init --recursive")
os.chdir("External/objective-git")
os.system("script/bootstrap")
os.system("script/update_libgit2")
