# Connections registry

One line per connected system Claude can reach. Names and purposes only — never tokens,
credentials, or URLs containing secrets. Drift is flagged during the weekly review
(`/devos-weekly-review` drift checks); like every other brain update, a correction is
filed as a `brain/inbox/` candidate and only lands here via `/devos-promote` — never
edited directly. "Last verified" is set only after actually exercising the connection
(a real tool call succeeded), not merely being told it's authenticated — leave it `—`
otherwise.

| System | Kind | Used for | Auth status | Last verified |
|---|---|---|---|---|
| git | CLI | Version control in every project | Local, no auth needed | 2026-07-13 |
| gh | CLI | GitHub PRs, issues, API | Not exercised this session | — |
| Notion | MCP connector (claude.ai) | Notion pages/databases | Reported connected by harness at session start; not exercised via a tool call | — |
| Atlassian Rovo | MCP connector (claude.ai) | Jira issues, Confluence pages | Reported connected by harness at session start; not exercised via a tool call | — |
| Google Drive | MCP connector (claude.ai) | Drive files | Needs auth — authorize via claude.ai connector settings | — |

<!-- Add a row when a new MCP server, CLI, or connector becomes available; remove rows
when a connection is retired. This file is an index like brain/projects.md — detail
about how a connection is used belongs in playbooks or project docs. -->
