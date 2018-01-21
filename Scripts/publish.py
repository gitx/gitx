#!/usr/bin/env python

import argparse
import subprocess
import os
from string import Template

import helpers
from project import Project
import build
from package import package
import sign


def generate_changelog(project):
    tag_format = project.release_tag_prefix() + "*"
    released_tags = helpers.check_string_output(["git", "tag", "-l", tag_format, '--sort', 'v:tag']).split("\n")
    if project.label() == None:
        # If this is a normal "release", ignore all labelled tags
        released_tags = list(filter(lambda tag: "-" not in tag, released_tags))

    # Also ignore our own "current tag"
    released_tags = list(filter(lambda tag: tag != project.release_tag_name(), released_tags))

    last_released_tag = released_tags[-1]
    print "Using {} as the changelog baseline".format(last_released_tag)

    revspec = "%s..%s" % (last_released_tag, project.release_branch())
    git_log = helpers.check_string_output(['git', 'log', revspec,
        '--format=- %h %<(100,trunc)%s',
        '--grep', 'Fix',
        '--grep', 'Merge pull request'
    ])

    # We have to trim each line because of %< above
    changelog = str.join("\n", list(map(lambda line: line.strip(), git_log.split("\n"))))

    return changelog



def generate_release_notes(project):
    artifact_signature = helpers.sign_file(project.image_path(), project.update_signing_keyfile())

    attrs = dict()
    attrs['version'] = project.build_version()
    attrs['changelog'] = generate_changelog(project)
    attrs['signature'] = "" if artifact_signature == None else "DMG Signature: %s" % (artifact_signature)

    template_source = open(project.release_notes_tmpl(), 'r').read()
    release_notes_text = Template(template_source).substitute(attrs)

    with open(project.release_notes_file(), 'w') as release_notes_file:
        release_notes_file.write(release_notes_text)


def commit_release(project):
    add = ['git', 'add']
    add += [
        "GitX.xcodeproj/project.pbxproj",
        "Resources/Info-gitx.plist",
        "Resources/Info.plist",
    ]
    subprocess.check_call(add)

    commit_msg = "Release {}".format(project.labelled_build_version())
    commit = ['git', 'commit', '-m', commit_msg]
    subprocess.check_call(commit)

    helpers.assert_clean()



def tag_release(release_name, force=False):
    tag = ['git', 'tag', release_name]
    if force:
        tag.append('-f')
    subprocess.check_call(tag)
    pass


def publish_release(project, as_prerelease, as_draft, dry_run):
    print("Publishing {}{}{}".format("draft of " if as_draft else "", project.release_name(), " as prerelease" if as_prerelease else ""))
    hub_release = ['hub', 'release',
        'create', project.release_tag_name(),
        '-a', project.image_path(),
        '-f', project.release_notes_file()]
    if as_prerelease:
        hub_release.append('-p')
    if as_draft:
        hub_release.append('-d')

    if dry_run:
        print "dry-run: {}".format(hub_release)
    else:
        subprocess.check_call(hub_release)
 

def publish_cmd(args):
    label = None if args.prerelease == False else "pre"
    
    project = Project(os.getcwd(), "release", label)

    print "Preparing release {}".format(project.release_tag_name())
    helpers.assert_clean()
    helpers.assert_branch(project.release_branch())
    helpers.set_version(project.build_version(), project.label())

    print("Building: {}".format(project.build_product()))
    build.build(project)

    print("Signing product with identity \"{}\"".format(project.codesign_identity()))
    sign.sign_everything_in_app(project.build_product(), project.codesign_identity())

    print("Packaging {} to {} as {}".format(project.build_product(), project.image_path(), project.image_name()))
    package(project.build_product(), project.image_path(), project.image_name())

    print("Generating release notes...")
    generate_release_notes(project)


    print("Committing and tagging \"{}\"".format(project.release_tag_name()))
    commit_release(project)
    tag_release(project.release_tag_name(), args.force)

    publish_release(project, args.prerelease, args.draft, args.dry_run)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--prerelease', action='store_true')
    parser.add_argument('-d', '--draft', action='store_true')
    parser.add_argument('-f', '--force', action='store_true')
    parser.add_argument('-n', '--dry-run', action='store_true')
    parser.set_defaults(func=publish_cmd)

    args = parser.parse_args()
    args.func(args)
