# AGENTS.md

Repository guidance for human and AI contributors.

## Commit Messages
- Use: `<type>: <summary>`
- Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- Subject max length: 50 characters
- Keep summary imperative
- If a body is included, use a blank separator line and wrap body lines at 72
- Auto-generated `Merge ...` and `Revert ...` subjects are allowed

See full policy:
- `docs/COMMIT_GUIDELINES.md`

## Enforce Locally
Enable the repo hook once per clone:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/commit-msg
```

## Before Opening PRs
- Run `./scripts/smoke.sh`
- Keep changes scoped to one logical concern per commit
- Prefer fixing commit messages before pushing shared branches
