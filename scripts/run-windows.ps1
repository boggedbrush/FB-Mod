param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$FileBotArgs
)

$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Path $PSScriptRoot -Parent
$DistLibDir = Join-Path $RootDir "dist\\lib"

if (-not (Test-Path $DistLibDir)) {
  throw "Missing dist\\lib. Build first (scripts\\bootstrap-dev.sh --install)."
}

function Resolve-Java {
  $candidates = @(
    $env:JAVA_CMD
    $(if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME "bin\\java.exe" })
    $(try { (Get-Command java -ErrorAction Stop).Source } catch { $null })
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

    if (Test-Path (Join-Path $resolved.FullName "javafx-base.jar")) {
      return $resolved.FullName
    }
  }

  return $null
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
