---
name: skills-harvest
description: Use when asked to harvest, sync, or refresh your personal Claude Code skill set from your own trae88 GitHub repos — as opposed to skills-reap (pagecast-only, third-party pinned skills). Walks every sibling repo cloned alongside this one for git-tracked SKILL.md files, hashes each skill directory, diffs against skills-harvest/state.json, safety-scans anything new or changed, installs the clean ones into ~/.claude/skills/, and reports the diff with use cases for what's new.
---

# skills-harvest

Personal, account-wide counterpart to `pagecast/skills/skills-reap`: that one
restores a curated set of *third-party* skills pinned in one repo's
`skills-lock.json`. This one scans *your own* trae88 repos for skills you've
written or vendored, and keeps your personal `~/.claude/skills/` in sync
with all of them. Run it end to end; don't stop after discovery.

## 1. Discover

```sh
bash skills-harvest/harvest.sh
```

Walks every sibling directory next to this repo (i.e. everything cloned
under the session's home directory) that's a git repo, and collects every
git-tracked `SKILL.md` — `git ls-files`, so gitignored install caches
(`.agents/skills/`, etc. from `npx skills`) are naturally excluded, only
checked-in skills count.

**Exclusion**: `composio-skills/` in this repo is a vendored bulk catalog
of 800+ third-party API-integration skills bundled with the
`connect-apps-plugin` — not something anyone organically added. The script
skips it. If another repo ever bundles a similarly bulk, auto-generated
skill catalog, add it to the exclusion list in `harvest.sh` rather than
treating each entry as a personal "new skill."

Output lands in `/tmp/harvest-current.json`: one entry per skill with
`repo`, `path`, `name`, and a content `hash` (sha256 over the git blob
hashes of every tracked file under that skill's directory — catches
changes to scripts/assets, not just `SKILL.md` prose).

## 2. Diff against last run

Compare `/tmp/harvest-current.json` to this directory's `state.json`
(committed from the previous run) by `(repo, path)`:

- **New**: in current, not in state.
- **Changed**: same `(repo, path)`, different `hash`.
- **Removed**: in state, not in current (skill directory deleted or repo
  removed from the session).

First run ever: `state.json` doesn't exist yet, so everything is "new" —
that's expected, not a bug.

## 3. Safety-scan new + changed entries

Same superficial grep as `skills-reap`, run only against directories that
are new or changed (not the whole tree every time):

```sh
git -C <repo> grep -niE "curl .*\| *sh|curl .*\| *bash|wget .*\| *sh|eval\(|base64 -d|bash -c|/dev/tcp|rm -rf /|chmod \+x" -- <skill-dir>
```

Read every hit in context before deciding — `chmod +x` and `curl | bash`
show up legitimately in install instructions and contributor docs. Flag
genuinely suspicious content to the user; don't silently install it, but
don't block on pattern-matches you've actually read and understood either.

## 4. Install the clean ones

For every new/changed entry that passed step 3, copy (not symlink — this
survives the source repo being removed from the session later) into:

```
~/.claude/skills/<repo>-<skill-name>/
```

The `<repo>-` prefix avoids collisions between repos that happen to name a
skill the same thing. If two paths in the *same* repo produce the same
`(repo, name)` (e.g. a skill checked in twice for two different agents,
like pagecast's `publish-report`), the later one in scan order wins —
they're expected to be identical or near-identical content for different
agent targets, not two different skills.

For entries in "Removed" (step 2), leave the installed copy in
`~/.claude/skills/` alone — don't auto-delete. Report them so the user can
decide (a repo being temporarily out of session scope looks identical to a
real deletion from here).

## 5. Update state and commit

Overwrite `skills-harvest/state.json` with the full current scan (not just
the diff — it's the baseline for next time), commit, and push. This state
file is the only durable record between sessions; without committing it,
every run looks like a first run.

## 6. Report back

Concretely, not just "done":

- **New skills**: name, source repo, one-line description (from its
  `SKILL.md` frontmatter), and 2-3 concrete use cases each. Group by
  source repo when there are many — don't write 60 individual blurbs for
  a first run, summarize clusters and call out a few standouts.
- **Changed skills**: name + what changed if it's discernible from the
  diff (new capability, renamed, script added, etc).
- **Removed**: name + source repo + last known path, with the caveat above.
- **How to use them now**: they're in `~/.claude/skills/`, which Claude
  Code picks up as personal (cross-project) skills — say whether a
  restart is needed rather than assuming.
