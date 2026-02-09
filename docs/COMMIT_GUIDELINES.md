# Commit Guidelines

FB-Mod uses strict commit message formatting:

`<type>: <summary>`

Allowed types:
- `feat`
- `fix`
- `docs`
- `style`
- `refactor`
- `test`
- `chore`

Required rules:
- Subject line must match `type: summary`
- Subject line max length is 50 characters
- Use imperative mood for the summary (e.g. `fix`, `add`, `update`)
- If a body is present, leave one blank line after the subject
- Body lines should be 72 characters or less
- Auto-generated `Merge ...` and `Revert ...` subjects are allowed

## Examples

Valid:
- `fix: correct AppImage artifact upload path`
- `chore: set ARCH for linuxdeploy AppImage builds`

Invalid:
- `Fix AppImage artifact upload path` (missing type prefix)
- `chore - set ARCH for linuxdeploy AppImage builds` (wrong separator)

## Local Enforcement (Recommended)

This repo includes a commit message hook:

`.githooks/commit-msg`

Enable it once per clone:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/commit-msg
```

After setup, invalid commit messages are rejected before commit creation.
