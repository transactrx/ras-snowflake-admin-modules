# AGENTS.md

Guidance for Claude Code and other agents working in this repository. `CLAUDE.md` is a symlink to this file.

Shared Terraform modules for the `ras-snowflake-admin-*` projects. See `README.md`. The family's conventions (sharing maps between projects, apply order, providers, state) are in the `AGENTS.md` of any `ras-snowflake-admin-*` project.

## Rules

- **Every change is a release.** Callers pin `?ref=<module>-v<MAJOR>.<MINOR>.<PATCH>`. Cut a new tag for each change and say in the PR which callers should bump. Never move or delete an existing tag.
- **MAJOR** when a change can alter what an existing caller plans: a renamed or removed input, a changed default, a changed resource address. **MINOR** for a new optional input or resource type. **PATCH** for fixes that plan no differently.
- **Inputs stay optional.** Every map defaults to `{}`, and every `optional()` field used as a condition gets a default, so a project passes only what it owns.
- **Never change a resource address casually.** Renaming a resource or its `for_each` key makes every caller plan a destroy and recreate. Use a `moved` block and a MAJOR bump.
- **Least privilege per resource:** pick the smallest provider alias that can do the job. Resources on the default provider (account roles, alerts) run as whatever role the caller's default provider uses.
- **Test through the example.** `snowflake_administration/examples/users-only` must `terraform validate` and pass a mocked `terraform test` before a tag is cut.
- **`snowflake_administration` came from `SnowflakeWHAdministration/snowflake_administration`.** Until `SnowflakeWHAdministration` uses this repo, port any change to its local copy too.
- **The repo stays public.** CI fetches modules without a token. Never commit secrets or account-specific values.
