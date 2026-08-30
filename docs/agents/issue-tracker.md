# Issue tracker: GitHub

Issues and specifications for this repository live in GitHub Issues at `JoshuaSayo/callcenter-issabel5`.
Use the `gh` CLI from this repository so it infers the correct remote.

## Authorization

- Read-only GitHub operations may be performed when they are relevant to the current task.
- Creating, editing, commenting on, labeling, assigning, or closing an issue requires an explicit user request or approval.
- Do not publish private staging credentials, database contents, private keys, VPN profiles, or raw logs containing secrets.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --comments`, including labels when they affect the workflow.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments` with appropriate label and state filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`.
- **Apply or remove labels**: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`.
- **Close an issue**: `gh issue close <number> --comment "..."`.

Infer the repository from `git remote -v`; `gh` does this automatically when run inside the clone.

## Pull requests as a triage surface

**PRs as a request surface: no.**

When this setting is changed to `yes`, external pull requests use the corresponding `gh pr` read, comment, label, and close operations. GitHub shares one number space across issues and pull requests, so resolve a bare `#42` with `gh pr view 42` and fall back to `gh issue view 42`.

## Skill terminology

- When a skill says **publish to the issue tracker**, create a GitHub issue after the required approval.
- When a skill says **fetch the relevant ticket**, run `gh issue view <number> --comments`.

## Wayfinding operations

Used by the `wayfinder` skill when it is installed:

- **Map**: one issue labelled `wayfinder:map`, holding the current notes, decisions, and unresolved questions.
- **Child ticket**: a GitHub sub-issue linked to the map. Where sub-issues are unavailable, use a task list in the map and start the child body with `Part of #<map>`.
- **Blocking**: prefer GitHub's native issue dependencies. Where unavailable, use a `Blocked by: #<n>` line at the top of the child issue.
- **Claim**: assign the unblocked ticket to the current developer only when implementation is beginning.
- **Resolve**: record the result, close the ticket, and update the map's decisions.
