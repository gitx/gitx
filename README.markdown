GitX (L)
---------------

# What is GitX (L)?

GitX (L) is a gitk like clone written for OS X Leopard and higher.
This means that it has a native interface and tries to integrate with the
operating system as good as possible. Examples of this are drag and drop
support and QuickLook support.

# Features

The project is currently still in its starting phases. As time goes on,
hopefully more features will be added. Currently GitX (L) supports the following:

  * Commit view
    * Commit/Parents/Tree SHA links
    * File changes counts
    * File Diffs
    * Commit Tags and Refs
  * File view
    * Source Code Highlight
    * Blame
    * File History (log)
    * Diff with local and HEAD
  * Sidebar
    * Branches
    * Remotes
    * Stashes
    * Submodules
  * Stage view
    * Unstaged/Staged files
    * Stage/Discard by lines
    * Amend
    * File diff

# License

GitX is licensed under the GPL version 2. For more information, see the attached COPYING file.

# Downloading

GitX (L) is currently hosted at GitHub. It's project page can be found at
https://github.com/laullon/gitx
Recent binary releases can be found at
http://gitx.laullon.com

If you wish to follow GitX (L) development, you can download the source code
through git:

git clone https://github.com/laullon/gitx.git

# Installation

The easiest way to get GitX (L) running is to download the binary release from 
http://gitx.laullon.com
If you wish to compile it yourself, you will need XCode 3.0 or later. As
GitX makes use of features available only on Leopard (such as garbage
collection), you will not be able to compile it on previous versions of OS X.

To compile GitX (L), open the GitX.xcodeproj file and hit "Build".

# Usage

GitX (L) itself is fairly simple. Most of its power is in the 'gitx' binary, which
you should install through the menu. the 'gitx' binary supports most of git
rev-list's arguments. For example, you can run `gitx --all' to display all
branches in the repository, or `gitx -- Documentation' to only show commits
relating to the 'Documentation' subdirectory. With `gitx -Shaha', gitx will
only show commits that contain the word 'haha'. Similarly, with 'gitx
v0.2.1..', you will get a list of all commits since version 0.2.1.

# Helping out

Any help on GitX (L) is welcome. 
