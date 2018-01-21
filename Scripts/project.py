#!/usr/bin/env python

import json
import os
from string import Template

import helpers


class Project:
    def __init__(self,  project_root, config, label=None):
        self.__label = label
        self.__config = config
        self.settings = {}

        updates_dir = os.path.join(project_root, 'updates')
        project_settings = json.load(open(os.path.join(updates_dir, 'project.json')))

        project_name = project_settings['project_name']
        self.settings['project_root'] = project_root
        self.settings['updates_dir'] = updates_dir
        self.settings['workspace'] = "%s.xcworkspace" % (project_name)
        self.settings['scheme'] = project_name
        self.settings['debug_config'] = "Debug"
        self.settings['release_config'] = "Release"
        self.settings['build_base_dir'] = os.path.join(project_root, "build")
        self.settings['build_product_name'] = "%s.app" % (project_name)
        self.settings['artifacts_dir'] = os.path.join(project_root, "release")
        self.settings['release_tag_prefix'] = ""

        self.settings.update(project_settings)

        self.settings['release_notes_tmpl'] = os.path.join(updates_dir, "release-notes.markdown.tmpl")
        self.settings['update_signing_keyfile'] = os.path.join(updates_dir, self.settings['update_signing_key'])

        try:
            os.makedirs(self.artifacts_dir())
        except OSError:
            pass

    def __repr__(self):
        return "Project settings={} config={} label={}".format(self.settings, self.__config, self.__label)

    def __getattr__(self, name):
        if name in self.settings:
            return lambda: self.settings[name]
        else:
            try:
                super(object, self).__getattr__(self, name)
            except Exception as e:
                raise AttributeError("'Project' object has no attribute '{}'".format(name))


    def current_config(self):
        return self.__config


    def label(self):
        return self.__label


    def build_number(self):
        return helpers.check_string_output(["git", "rev-list", "HEAD", "--count"])


    def build_version(self):
        return "%s.%s" % (self.base_version(), self.build_number())


    def labelled_build_version(self):
        str = self.build_version()
        if self.__label != None: str += "-%s" % (self.__label)
        return str


    def artifact_prefix(self):
        return self.project_name() if self.__label == None else "%s-%s" % (self.project_name(), self.__label)


    def current_build_config(self):
        return self.release_config() if self.current_config == "release" else self.debug_config()


    def build_dir(self):
        return os.path.join(self.build_base_dir(), self.current_build_config())


    def build_product(self):
        return os.path.join(self.build_dir(), self.build_product_name())


    def image_path(self):
        return os.path.join(self.artifacts_dir(), "%s-%s.dmg" % (self.project_name(), self.labelled_build_version()))


    def image_name(self):
        return "%s %s" % (self.project_name(), self.labelled_build_version())


    def release_notes_file(self):
        file_name = "%s-%s.markdown" % (self.project_name(), self.labelled_build_version())
        return os.path.join(self.artifacts_dir(), file_name)


    def release_tag_name(self):
        strings = {}
        strings.update(self.settings)
        # FIXME: those are method only, and this is already too messy
        strings['build_version'] = self.build_version()
        strings['build_number'] = self.build_number()
        
        tag = self.release_tag_prefix() + Template(self.release_tag_format()).substitute(strings)
        if self.__label:
            tag += '-' + self.__label
        return tag


    def release_name(self):
        name = "%s %s" % (self.project_name(), self.build_version())
        if self.__label != None:
            name += " (%s)" % (self.__label)
        return name