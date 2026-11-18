#!/usr/bin/env bash
# skills-harvest: walk sibling trae88 repos for git-tracked SKILL.md files,
# hash each skill directory, and diff against skills-harvest/state.json.
#
# Excludes composio-skills/ (a vendored bulk third-party catalog bundled
# with the connect-apps-plugin in this repo, not an organically-added skill).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/state.json"

cd "$ROOT"
echo "[]" > /tmp/harvest-current.json
first=true
echo -n "[" > /tmp/harvest-current.json

for repo_dir in */; do
  repo="${repo_dir%/}"
  [ -d "$repo/.git" ] || continue
  while IFS= read -r skill_path; do
    [ -z "$skill_path" ] && continue
    case "$skill_path" in composio-skills/*) continue ;; esac
    skill_dir="$repo/$(dirname "$skill_path")"
    hash=$(git -C "$repo" ls-files -s -- "$(dirname "$skill_path")" 2>/dev/null \
      | awk '{print $2, $4}' | sort -k2 | sha256sum | cut -d' ' -f1)
    name=$(basename "$(dirname "$skill_path")")
    if [ "$first" = true ]; then first=false; else echo -n "," >> /tmp/harvest-current.json; fi
    printf '{"repo":"%s","path":"%s","name":"%s","hash":"%s"}' \
      "$repo" "$skill_path" "$name" "$hash" >> /tmp/harvest-current.json
  done < <(git -C "$repo" ls-files -- '*SKILL.md' '**/SKILL.md' 2>/dev/null)
done
echo -n "]" >> /tmp/harvest-current.json
python3 -m json.tool /tmp/harvest-current.json > /tmp/harvest-current.pretty.json
mv /tmp/harvest-current.pretty.json /tmp/harvest-current.json
echo "Wrote $(python3 -c "import json;print(len(json.load(open('/tmp/harvest-current.json'))))") entries to /tmp/harvest-current.json"
