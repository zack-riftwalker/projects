#!/bin/bash
# A new cloud session starts from a clone that can be behind ph1: other sessions push to ph1 in parallel. Bring ph1 up to date before any
# work, and print its newest commits so the session knows what was just built (SessionStart output goes into the session's context).
set -uo pipefail
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

for i in 1 2 3 4; do git fetch -q origin ph1 2>/dev/null && break; sleep $((i * 2)); done
git rev-parse -q --verify origin/ph1 >/dev/null || { echo "Could not fetch origin/ph1: run 'git fetch origin ph1' before working."; exit 0; }

br=$(git rev-parse --abbrev-ref HEAD)
behind=$(git rev-list --count HEAD..origin/ph1)
if [ "$br" = "ph1" ]; then
  if [ "$behind" -gt 0 ]; then
    old=$(git rev-parse HEAD)
    if git diff --quiet && git diff --cached --quiet && git merge -q --ff-only origin/ph1 2>/dev/null; then
      echo "ph1 was $behind commits behind origin/ph1: fast-forwarded."
      # The session's instructions were read from the old CLAUDE.md before this hook ran (checked: a CLAUDE.md the hook
      # rewrites is not reloaded), so hand the session the current one.
      if ! git diff --quiet "$old" HEAD -- CLAUDE.md; then
        echo "CLAUDE.md changed in those commits. The CLAUDE.md in your instructions is the OLD one; this is the current one and it wins:"
        echo "----- CLAUDE.md -----"; cat CLAUDE.md; echo "----- end of CLAUDE.md -----"
      fi
    else
      echo "WARNING: ph1 is $behind commits behind origin/ph1 and could not fast-forward. Run 'git pull origin ph1' before reading code."
    fi
  else
    echo "ph1 is up to date with origin/ph1."
  fi
else
  echo "Note: this session is on '$br', not ph1. The Godot version, the boss docs and the boss skills live on ph1 ($behind commits not in this checkout): 'git fetch origin ph1 && git checkout ph1'."
fi
echo "Newest commits on ph1:"
git log --oneline -15 origin/ph1

# the co-op scenarios need ws (CLAUDE.md, boss-build)
[ -d node_modules ] || npm install --silent >/dev/null 2>&1 || echo "npm install failed: run it before the co-op scenarios."
exit 0
