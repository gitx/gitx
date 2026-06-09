---
applyTo: "Classes/git/**"
---

# Git Model Layer Instructions

## Overview
The `Classes/git/` directory contains the model layer that wraps git operations via `ObjectiveGit` (libgit2 bindings in `External/`).

## Key Classes
| Class | Responsibility |
|---|---|
| `PBGitRepository` | Central model for an open repository; owns refs, commits, index |
| `PBGitCommit` | Represents a single commit (OID, parents, tree, message) |
| `PBGitRef` | A git ref (branch, tag, remote-tracking branch, HEAD) |
| `PBGitIndex` | Staging area — tracks changed files and manages `git add`/`git reset` |
| `PBGitRevList` | Walks commit history using `git rev-list` |
| `PBGitGrapher` / `PBGitHistoryGrapher` | Builds the branch-graph layout for the history view |
| `PBGitStash` | Represents a stash entry |

## Guidelines
- Keep git operations off the main thread; post results back via notifications or callbacks
- Use `ObjectiveGit` (prefix `GTRepository`, `GTCommit`, etc.) for libgit2 access; fall back to spawning `git` subprocess via `PBGitBinary` only when libgit2 lacks support
- Avoid storing UI state in model objects — models should be UI-agnostic
