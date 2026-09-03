# Planning

Tracks planning-with-files (PWF) artifacts for structured task execution.

## Structure

```
planning/
  active/           <- Current work-in-progress PWF files
    task_plan.md
    findings.md
    progress.md
  archive/          <- Completed issues
    YYYY-MM-issue-N-slug/
```

## Workflow

See the `feature-workflow.md` convention in CLAUDE.md for the full sequence:
issue -> /planning-init <N> -> tests -> code-check -> atomic commits -> /planning-archive.

## Skills

- `/planning-init` — create this structure (you already ran it)
- `/planning-init <N>` — start issue N (branch + PWF baseline derived from issue body)
- `/planning-update` — sync checkboxes mid-session
- `/planning-archive` — archive completed work, create fresh active/

## A note on issues that live elsewhere

Some work here originates from an issue in a private repo. `/planning-init <N>` resolves
the number against *this* repo, so it cannot be used for those — it would look for a
spacehakr issue that does not exist.

Reference the originating issue by hand in `task_plan.md` instead, and keep project
context out of this public repo: describe the change on its own technical merits and
leave the provenance in the private issue.
