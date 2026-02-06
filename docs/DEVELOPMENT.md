# FB-Mod Development

## Toolchain (Pinned)
- Java: Temurin JDK 17
- Ant: 1.10.x
- Ivy: 2.5.x

## Bootstrap
Run from repo root:

```bash
./scripts/bootstrap-dev.sh --install
```

This will:
- Validate Java 17+
- Install local Ant/Ivy tooling into `.tools` if missing
- Run `ant resolve` and `ant jar`
- Save build logs under `artifacts/logs`

Check-only mode:

```bash
./scripts/bootstrap-dev.sh --install --check-only
```

## Smoke Test
After building:

```bash
./scripts/smoke.sh
```

Smoke checks include:
- `-version`
- `-help`
- Non-destructive rename test (`--action test`)

## GUI Launch Scripts
Use the platform-specific launcher to ensure JavaFX modules are loaded:

- macOS:
  - `./scripts/run-macos.sh`
- Linux:
  - `./scripts/run-linux.sh`
- Windows (PowerShell):
  - `powershell -ExecutionPolicy Bypass -File .\scripts\run-windows.ps1`

No arguments opens GUI mode. If you append FileBot arguments, they are forwarded to `net.filebot.Main` for CLI-style execution.

Example:

```bash
./scripts/run-macos.sh -version
```

## Runtime Configuration
Use one of:
- `--config /path/to/config.properties`
- Environment variables (see `config/runtime-config.example.properties`)

On first launch, FB-Mod auto-creates a template config at:

- `~/.config/fb-mod/config.properties`

Precedence:
1. CLI options
2. Environment variables
3. Config file
4. Bundled defaults

## Data Mirror / Decoupled Operation
Create a local mirror:

```bash
./scripts/mirror_data.sh ./mirror
```

Run with local mirror:

```bash
java -cp "dist/lib/*" net.filebot.Main --data-source ./mirror -version
```
