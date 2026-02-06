# FB-Mod

Modernized personal-use fork of FileBot with cross-platform baseline support.

## Quick Start
1. Bootstrap build toolchain and compile:
   - `./scripts/bootstrap-dev.sh --install`
2. Run local smoke checks:
   - `./scripts/smoke.sh`
3. Launch GUI (platform script):
   - macOS: `./scripts/run-macos.sh`
   - Linux: `./scripts/run-linux.sh`
   - Windows (PowerShell): `powershell -ExecutionPolicy Bypass -File .\scripts\run-windows.ps1`

No arguments opens the GUI. Any appended FileBot arguments are forwarded (e.g. `-version`, `-rename ...`) for CLI-style runs.

## Runtime Configuration
- Example config: `config/runtime-config.example.properties`
- Auto-generated first-run config: `~/.config/fb-mod/config.properties`
- CLI overrides:
  - `--config <path>`
  - `--data-source <path|url>`
  - `--provider-order <csv>`

## Data Mirror
Create and use a local mirror to avoid upstream runtime dependency:

- `./scripts/mirror_data.sh ./mirror`
- Run with mirror: `--data-source ./mirror`

## Documentation
- Build / tooling / smoke docs: `docs/DEVELOPMENT.md`
- Legacy compile notes: `COMPILING.md`
