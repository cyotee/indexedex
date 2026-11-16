---
name: git-clean-worktree
description: >
  Commit all current changes so the git worktree is clean. Use when the user
  says "please commit all changes so we have a clean worktree", "haave a clean
  worktree", or "thank you, please commit all changes." Do not push. Do not
  merge with commit-and-push.
user-invocable: true
---

# git-clean-worktree

Commit local changes so `git status` is clean. Do not push. Do not open a PR.

## Triggers

- "Please commit all changes so we have a clean worktree"
- "haave a clean worktree"
- "thank you, please commit all changes."

## Steps

1. Run `git status` and `git diff` in the worktree the user is in.
2. Stage the changes that belong to the current work. Do not add secrets, `.env`, private keys, or unrelated files.
3. Write a commit message that names the change. Use the user's words when they gave a subject.
4. Commit. Stop. Show `git status` as clean (or list leftover untracked files you refused to add).
5. Do not `git push`. Do not `git pull --rebase` unless the user asked. Do not amend a pushed commit.
