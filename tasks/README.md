# Task files

Lightweight, per-item work trackers that complement `CLAUDE.md`'s Open
Issues table. The table stays the compact index; a task file is where an
item that needs real detail (background, work items, a status log) lives —
linked from the table by number where useful.

## Format

`tasks/NNN-short-slug.md`, one file per item:

```
---
status: todo | in-progress | blocked | done
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# Title

## Summary
## Background
## Work items
- [ ] ...
## Status log
- YYYY-MM-DD: created
```

## Convention

- Claude reads and updates these as work happens (status, checkboxes, a
  dated status-log line per real change); humans edit them too.
- Cross-repo references are by repo name + path (e.g.
  `science-operations-support-tool/tasks/001-....md`) — `cosmosv5` and the
  `src/tools/*` projects are independent git repos, so it's a pointer for
  whoever's browsing the full checkout, not a working link.
- Same convention as `science-operations-support-tool/tasks/README.md` —
  keep both in sync if the format changes.
