param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FileBotArgs
)

$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Path $PSScriptRoot -Parent
$DistLibDir = Join-Path $RootDir "dist\\lib"
$DistJar = Join-Path $DistLibDir "filebot.jar"

function Test-RebuildNeeded {
  if (-not (Test-Path $DistJar)) {
    return $true
  }

  $jarTime = (Get-Item $DistJar).LastWriteTimeUtc

  $newerSource = Get-ChildItem -Path (Join-Path $RootDir "source") -Recurse -File |
    Where-Object { $_.LastWriteTimeUtc -gt $jarTime } |
    Select-Object -First 1
  if ($newerSource) {
    return $true
  }

  return $false
}

function Invoke-AntBuild {
  $ant = Get-Command ant -ErrorAction SilentlyContinue
  if (-not $ant) {
    return $false
  }

  Write-Host "Rebuilding dist\\lib with ant (resolve, jar)"
  Push-Location $RootDir
  try {
    & $ant.Source resolve | Out-Host
    if ($LASTEXITCODE -ne 0) {
      return $false
    }

    & $ant.Source jar | Out-Host
    if ($LASTEXITCODE -ne 0) {
      return $false
    }
  } finally {
    Pop-Location
  }

  return -not (Test-RebuildNeeded)
}

function Invoke-BootstrapBuild {
  $candidates = @(
    (Join-Path $env:ProgramFiles "Git\\bin\\bash.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Git\\bin\\bash.exe")
  )

  foreach ($candidate in $candidates) {
    if (-not $candidate -or -not (Test-Path $candidate)) {
      continue
    }

    Write-Host "Rebuilding dist\\lib via bootstrap-dev.sh --install"
    Push-Location $RootDir
    try {
      & $candidate "scripts/bootstrap-dev.sh" --install | Out-Host
      if (($LASTEXITCODE -eq 0) -and (-not (Test-RebuildNeeded))) {
        return $true
      }
    } finally {
      Pop-Location
    }
  }

  return $false
}

function Invoke-JavacPatchBuild {
  if (-not (Test-Path $DistJar)) {
    return $false
  }

  $javac = Get-Command javac -ErrorAction SilentlyContinue
  if (-not $javac) {
    return $false
  }

  Write-Host "Rebuilding by compiling sources with javac and patching filebot.jar"

  $tmpDir = Join-Path $RootDir ".tmp_rebuild_classes"
  if (Test-Path $tmpDir) {
    [System.IO.Directory]::Delete($tmpDir, $true)
  }
  [System.IO.Directory]::CreateDirectory($tmpDir) | Out-Null

  try {
    $sourceList = Join-Path $tmpDir "sources.argfile"
    Get-ChildItem -Path (Join-Path $RootDir "source") -Recurse -File -Filter *.java |
      Select-Object -ExpandProperty FullName |
      Set-Content -Path $sourceList -Encoding ascii

    $classpath = Join-Path $DistLibDir "*"
    $javaFxPath = Resolve-JavaFxLib
    $modules = "javafx.controls,javafx.fxml,javafx.graphics,javafx.media,javafx.swing,javafx.web"

    if ($javaFxPath) {
      & $javac.Source --module-path $javaFxPath --add-modules $modules -cp $classpath -sourcepath (Join-Path $RootDir "source") -d $tmpDir "@$sourceList" | Out-Host
    } else {
      & $javac.Source -cp $classpath -sourcepath (Join-Path $RootDir "source") -d $tmpDir "@$sourceList" | Out-Host
    }

    if ($LASTEXITCODE -ne 0) {
      return $false
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::Open($DistJar, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
      Get-ChildItem -Path $tmpDir -Recurse -File -Filter *.class | ForEach-Object {
        $relative = $_.FullName.Substring($tmpDir.Length + 1).Replace('\', '/')
        $entry = $zip.GetEntry($relative)
        if ($entry) {
          $entry.Delete()
        }

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
          $zip,
          $_.FullName,
          $relative,
          [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
      }
    } finally {
      $zip.Dispose()
    }
  } finally {
    if (Test-Path $tmpDir) {
      [System.IO.Directory]::Delete($tmpDir, $true)
    }
  }

  return -not (Test-RebuildNeeded)
}

function Resolve-Java {
  $candidates = @(
    $env:JAVA_CMD
    $(if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\\java.exe" })
    $(try { (Get-Command java -ErrorAction Stop).Source } catch { $null })
    (Join-Path $RootDir ".tools\\jdk-17\\bin\\java.exe")
    (Join-Path $env:ProgramFiles "Eclipse Adoptium\\jdk-17*\\bin\\java.exe")
    (Join-Path $env:ProgramFiles "Java\\jdk-17*\\bin\\java.exe")
    (Join-Path $env:ProgramFiles "Microsoft\\jdk-17*\\bin\\java.exe")
  ) | Where-Object { $_ }

  foreach ($candidate in $candidates) {
    $resolved = Get-ChildItem -Path $candidate -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) {
      continue
    }

    try {
      & $resolved.FullName -version *> $null
      return $resolved.FullName
    } catch {
      continue
    }
  }

  return $null
}

function Resolve-JavaFxLib {
  $candidates = @(
    $env:JAVAFX_LIB
    (Join-Path $RootDir "cache\\javafx-sdk-11.0.2\\lib")
    (Join-Path $env:ProgramFiles "Java\\javafx-sdk-17*\\lib")
    (Join-Path $env:USERPROFILE "javafx-sdk-17*\\lib")
  ) | Where-Object { $_ }

  foreach ($candidate in $candidates) {
    $resolved = Get-ChildItem -Path $candidate -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) {
      if (Test-Path $candidate) {
        $resolved = Get-Item $candidate
      } else {
        continue
      }
    }

    if ((Test-Path (Join-Path $resolved.FullName "javafx-base.jar")) -or (Test-Path (Join-Path $resolved.FullName "javafx.base.jar"))) {
      return $resolved.FullName
    }
  }

  return $null
}

if (Test-RebuildNeeded) {
  Write-Host "Build artifacts are missing or stale."

  if (-not (Invoke-AntBuild) -and -not (Invoke-BootstrapBuild) -and -not (Invoke-JavacPatchBuild)) {
    throw "Automatic rebuild failed. Install Ant or Git Bash, or run scripts/bootstrap-dev.sh --install manually."
  }
}

if (-not (Test-Path $DistJar)) {
  throw "Build did not produce dist\\lib\\filebot.jar"
}

$javaBin = Resolve-Java
if (-not $javaBin) {
  throw "Unable to locate Java 17+. Set JAVA_CMD or JAVA_HOME."
}

$javaFxPath = Resolve-JavaFxLib
if (-not $javaFxPath) {
  throw "Unable to locate JavaFX modules. Set JAVAFX_LIB to a lib directory containing javafx-*.jar."
}

$modules = "javafx.controls,javafx.fxml,javafx.graphics,javafx.media,javafx.swing,javafx.web"
$classpath = Join-Path $DistLibDir "*"

& $javaBin `
  --module-path $javaFxPath `
  --add-modules $modules `
  -cp $classpath `
  net.filebot.Main `
  @FileBotArgs
