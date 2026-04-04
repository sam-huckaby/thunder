# Feature Plans

This file is the index of feature plans for `thunder`.

Future agents should use this file as the starting point when planning or implementing
new features. Detailed feature plans live under `PLANS/`, typically in a feature-specific
directory such as `PLANS/TH-001/`. New plans should generally be created from
`PLANS/_TEMPLATE.md` and then customized for the specific feature.

## Current Active Plans

1. `PLANS/TH-004/CLOUDFLARE_PROVISIONING_PLAN.md` - Thunder-managed Cloudflare resource provisioning, bootstrap deploy, and JSON-first status.
2. `PLANS/TH-003/ASYNC_BINDINGS_PLAN.md` - Async handlers, full Cloudflare async binding access, binary responses, and Zephyr interoperability.

## Historical Plans

1. `PLANS/TH-000/RUNTIME_MVP_PLAN.md` - Original Thunder MVP backlog and runtime roadmap.
2. `PLANS/TH-001/FRAMEWORKIFICATION_PLAN.md` - Frameworkification plan for generated apps and install flow.
3. `PLANS/TH-002/JS_TARGET_PLAN.md` - Dual JS/Wasm target roadmap.

## Current Working Plan

The current feature plan being worked on is:

- `PLANS/TH-004/CLOUDFLARE_PROVISIONING_PLAN.md`

## Plan Frontmatter Schema

All feature plans under `PLANS/` should start with YAML frontmatter using this schema:

```yaml
---
id: TH-XXX
title: Replace With Plan Title
status: todo
type: feature
priority: medium
owner: null
created: YYYY-MM-DD
updated: YYYY-MM-DD
related_plans: []
depends_on: []
blocks: []
labels: []
---
```

Field guidance:

- `id` - Stable plan identifier, typically matching the plan directory.
- `title` - Short human-readable feature name.
- `status` - One of `todo`, `in_progress`, or `done`.
- `type` - Work type such as `feature`, `refactor`, `infra`, or `research`.
- `priority` - One of `low`, `medium`, `high`, or `critical`.
- `owner` - Human or agent owner when known; use `null` if unassigned.
- `created` - Date the plan was created in `YYYY-MM-DD` format.
- `updated` - Date the plan metadata or contents were last meaningfully updated.
- `related_plans` - Other plan ids or plan paths that are related.
- `depends_on` - Plans that must land first.
- `blocks` - Plans that are blocked by this plan.
- `labels` - Short tags that help categorize the work.

## Instructions For Future Agents

- Read this file first to discover active feature plans.
- Treat the "Current Working Plan" entry as authoritative when it points to a specific plan.
- When a new feature plan is introduced, add it to the plan list in this file.
- New plan files under `PLANS/` should use the standard frontmatter schema defined in this file.
- Use `PLANS/_TEMPLATE.md` as the recommended starting point for new plan files.
- Keep frontmatter current as the plan evolves, especially `status`, `updated`, and cross-plan relationship fields.
- Keep this file brief. Put detailed design, architecture, API, schema, UI, and implementation phase information in the referenced plan file under `PLANS/`.
