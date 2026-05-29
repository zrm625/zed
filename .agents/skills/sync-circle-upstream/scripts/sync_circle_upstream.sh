#!/usr/bin/env bash
set -euo pipefail

base_remote="${BASE_REMOTE:-upstream}"
fork_remote="${FORK_REMOTE:-origin}"
base_branch="${BASE_BRANCH:-main}"
circle_branch="${CIRCLE_BRANCH:-circle/main}"

run() {
  local command=("$@")
  printf '+ %q' "$1"
  shift
  for argument in "$@"; do
    printf ' %q' "$argument"
  done
  printf '\n'
  "${command[@]}"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

advise() {
  printf 'next: %s\n' "$*" >&2
}

die_with_advice() {
  printf 'error: %s\n' "$1" >&2
  printf 'next: %s\n' "$2" >&2
  exit 1
}

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository"
cd "$repo_root"

if [[ -n "$(git status --porcelain)" ]]; then
  git status --short >&2
  die_with_advice \
    "worktree has local changes" \
    "inspect these changes before syncing; commit, stash, or ask the user how to handle them"
fi

git remote get-url "$base_remote" >/dev/null || die_with_advice \
  "missing remote: $base_remote" \
  "add the upstream remote for zed-industries/zed or set BASE_REMOTE"
git remote get-url "$fork_remote" >/dev/null || die_with_advice \
  "missing remote: $fork_remote" \
  "add the fork remote for zrm625/zed or set FORK_REMOTE"

run git fetch "$base_remote" "+refs/heads/$base_branch:refs/remotes/$base_remote/$base_branch" --prune
run git fetch "$fork_remote" \
  "+refs/heads/$base_branch:refs/remotes/$fork_remote/$base_branch" \
  "+refs/heads/$circle_branch:refs/remotes/$fork_remote/$circle_branch" \
  --prune

base_ref="refs/remotes/$base_remote/$base_branch"
fork_main_ref="refs/remotes/$fork_remote/$base_branch"
circle_remote_ref="refs/remotes/$fork_remote/$circle_branch"

git show-ref --verify --quiet "$base_ref" || die "missing fetched ref: $base_ref"
git show-ref --verify --quiet "$fork_main_ref" || die "missing fetched ref: $fork_main_ref"
git show-ref --verify --quiet "$circle_remote_ref" || die "missing fetched ref: $circle_remote_ref"

base_sha="$(git rev-parse "$base_ref")"
fork_main_sha="$(git rev-parse "$fork_main_ref")"

if [[ "$fork_main_sha" != "$base_sha" ]]; then
  if ! git merge-base --is-ancestor "$fork_main_ref" "$circle_remote_ref"; then
    die_with_advice \
      "$fork_remote/$base_branch has commits not preserved in $fork_remote/$circle_branch" \
      "create a preservation branch from $fork_remote/$base_branch or merge those commits into $fork_remote/$circle_branch before cleaning fork main"
  fi

  if ! run git push "--force-with-lease=$base_branch:$fork_main_sha" "$fork_remote" "$base_ref:$base_branch"; then
    die_with_advice \
      "failed to update $fork_remote/$base_branch" \
      "fetch again and inspect whether $fork_remote/$base_branch moved before retrying"
  fi
  run git fetch "$fork_remote" "+refs/heads/$base_branch:refs/remotes/$fork_remote/$base_branch" --prune
fi

if git show-ref --verify --quiet "refs/heads/$circle_branch"; then
  run git switch "$circle_branch"
else
  run git switch --track -c "$circle_branch" "$fork_remote/$circle_branch"
fi

run git branch --set-upstream-to="$fork_remote/$circle_branch" "$circle_branch"

if git show-ref --verify --quiet "refs/heads/$base_branch"; then
  run git branch --set-upstream-to="$base_remote/$base_branch" "$base_branch"
  run git branch -f "$base_branch" "$base_ref"
fi

if git show-ref --verify --quiet "refs/heads/fork-main"; then
  run git branch --set-upstream-to="$fork_remote/$base_branch" fork-main
  run git branch -f fork-main "$fork_remote/$base_branch"
fi

if git merge-base --is-ancestor "$base_ref" HEAD; then
  printf '%s already contains %s/%s\n' "$circle_branch" "$base_remote" "$base_branch"
else
  if ! run git merge --no-ff "$base_ref" -m "Merge upstream main into Circle"; then
    git status --short >&2
    advise "resolve conflicts, run git status, commit the merge, then push $circle_branch to $fork_remote"
    exit 1
  fi
fi

if ! run git push "$fork_remote" "$circle_branch"; then
  die_with_advice \
    "failed to push $circle_branch to $fork_remote" \
    "fetch $fork_remote/$circle_branch and inspect whether the remote branch moved before retrying"
fi

printf '\nDone. %s is synced with %s/%s and pushed to %s.\n' \
  "$circle_branch" "$base_remote" "$base_branch" "$fork_remote"
