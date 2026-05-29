---
name: sync-circle-upstream
description: Sync Zed upstream/main into the user's zrm625/zed Circle branch while keeping the fork main clean. Use when asked to update, sync, merge, or bring upstream changes into circle/main, preserve a fork-only Circle branch, or prepare the Circle branch for a possible future upstream PR without opening one now.
---

# Sync Circle Upstream

## Overview

Use this skill for the Zed fork workflow where `upstream` is `zed-industries/zed`, `origin` is `zrm625/zed`, `main` stays clean for syncing, and `circle/main` carries the user's Circle work.

Do not open a PR to `zed-industries/zed` as part of this workflow. The upstream PR path is intentionally blocked for now.

## Default Workflow

Run the bundled script from the repository root:

```bash
.agents/skills/sync-circle-upstream/scripts/sync_circle_upstream.sh
```

The script:

- Requires a clean worktree.
- Fetches `upstream/main`, `origin/main`, and `origin/circle/main`.
- Verifies fork `main` commits are preserved in `origin/circle/main` before rewriting fork `main`.
- Updates `origin/main` to match `upstream/main` with `--force-with-lease` when needed.
- Switches to `circle/main`.
- Merges `upstream/main` into `circle/main` with a merge commit when needed.
- Pushes `circle/main` to `origin`.

When the script cannot proceed, it prints a clear `error:` message and a `next:` line with the immediate fix. If merge conflicts occur, resolve them in the working tree, run `git status`, commit the merge, then push `circle/main` to `origin`.

## Local Branch Roles

- `main`: local clean upstream branch, should track `upstream/main`.
- `fork-main`: optional local clean fork branch, should track `origin/main`.
- `circle/main`: local working integration branch, should track `origin/circle/main`.
- `archive/*`: preservation branches only; do not delete them unless the user explicitly asks.

## Safety Rules

- Preserve work before cleaning fork `main`. If `origin/main` has commits that are not contained in `origin/circle/main`, stop and create or request a preservation branch.
- Use `--force-with-lease`, never plain force-push.
- Push only to `origin` unless the user explicitly asks for an upstream PR or upstream branch operation.
- Prefer merging `upstream/main` into `circle/main` to avoid rewriting the shared Circle branch. Rebase only when the user explicitly requests an upstream-ready cleanup branch.
- If the script stops because the worktree is dirty, inspect the changes and ask before stashing, committing, or discarding anything.
- Report blockers explicitly in the final response. Include the current branch, failed command if known, and whether local files were left in a merge-conflict state.

## Upstream-Ready Variant

When the user later wants to prepare work for upstream, do not use `circle/main` directly if it has accumulated integration merge commits. Create a fresh topic branch from `upstream/main` and port the intended commits or changes there, then follow normal PR hygiene.
