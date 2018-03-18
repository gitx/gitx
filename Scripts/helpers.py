#!/usr/bin/env python

import subprocess
import base64

class BuildError(RuntimeError):
    pass


def sign_file(filename, signing_key_file):
    hashProc = subprocess.Popen(['openssl', 'dgst', '-sha1', '-binary', filename],
                                stdout=subprocess.PIPE)
    hash = hashProc.communicate()[0]
    signProc = subprocess.Popen(['openssl', 'dgst', '-dss1', '-sign', signing_key_file],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    signProc.stdin.write(hash)
    binsig = signProc.communicate()[0]
    return base64.b64encode(binsig).decode()


def check_string_output(command):
    return subprocess.check_output(command).decode('utf-8').strip()


def assert_clean():
    status = check_string_output(["git", "status", "--porcelain", "--untracked-files=no"])
    if len(status):
        raise BuildError("Working copy must be clean\n%s" % status)


def assert_branch(branch="master"):
    ref = check_string_output(["git", "rev-parse", "--abbrev-ref", "HEAD"])
    if ref != branch:
        raise BuildError("HEAD must be %s, but is %s" % (branch, ref))


def set_version(build_version, label):
    marketing_version = build_version
    if label != None:
        marketing_version += " %s" % (label)
    subprocess.check_call(["xcrun", "agvtool", "new-marketing-version", marketing_version])
    subprocess.check_call(["xcrun", "agvtool", "new-version", "-all", build_version])


def xcodebuild(scheme, workspace, config, commands, build_dir):
    cmd = ["xcrun", "xcodebuild", "-workspace", workspace, "-scheme", scheme, "-configuration", config]
    cmd = cmd + commands
    cmd.append('BUILD_DIR=%s' % (build_dir))
    try:
        output = check_string_output(cmd)
        return output
    except subprocess.CalledProcessError as e:
        raise BuildError(str(e))

