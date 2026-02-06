# FB-MOD Scripts

Example using amc script:

```bash
filebot -script https://raw.githubusercontent.com/barry-allen07/FB-Mod-Scripts/master/amc.groovy --output "/path/to/output" --action move -non-strict "/path/to/input" --log-file amc.log --def excludeList=amc.txt
```

Local modernization tooling:

- `./scripts/bootstrap-dev.sh --install`
- `./scripts/smoke.sh`
- `./scripts/mirror_data.sh ./mirror`
- `./scripts/run-macos.sh`
- `./scripts/run-linux.sh`
- `powershell -ExecutionPolicy Bypass -File .\scripts\run-windows.ps1`
