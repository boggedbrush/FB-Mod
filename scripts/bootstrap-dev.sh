#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tools"
LOG_DIR="$ROOT_DIR/artifacts/logs"
APP_PROPERTIES="$ROOT_DIR/app.properties"

ANT_VERSION="1.10.15"
IVY_VERSION="2.5.2"
JFX_VERSION="$(awk -F': *' '/^jfx.version:/ {print $2; exit}' "$APP_PROPERTIES")"

INSTALL_TOOLS=0
CHECK_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      INSTALL_TOOLS=1
      ;;
    --check-only)
      CHECK_ONLY=1
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
  shift
done

mkdir -p "$TOOLS_DIR" "$LOG_DIR"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

resolve_javafx_lib() {
  local candidate
  local -a candidates=(
    "${JAVAFX_LIB:-}"
    "$ROOT_DIR/cache/javafx-sdk-$JFX_VERSION/lib"
    "/usr/share/openjfx/lib"
    "/usr/lib/jvm/javafx-sdk/lib"
    "/usr/lib/openjfx/lib"
    "/usr/lib64/openjfx/lib"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" ]] && [[ -f "$candidate/javafx-base.jar" || -f "$candidate/javafx.base.jar" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

setup_javafx() {
  local javafx_lib
  javafx_lib="$(resolve_javafx_lib || true)"
  if [[ -n "$javafx_lib" ]]; then
    JAVAFX_LIB="$javafx_lib"
    export JAVAFX_LIB
    return
  fi

  if [[ "$INSTALL_TOOLS" != "1" ]]; then
    echo "JavaFX not found. Re-run with --install or set JAVAFX_LIB to a directory containing javafx-*.jar." >&2
    exit 1
  fi

  local fetch_script="$ROOT_DIR/cache/get-jfx.sh"
  if [[ ! -f "$fetch_script" ]]; then
    echo "JavaFX fetch script is missing: $fetch_script" >&2
    exit 1
  fi

  echo "Downloading JavaFX runtime"
  (
    cd "$ROOT_DIR/cache"
    /bin/sh ./get-jfx.sh
  )

  local archive
  archive="$(find "$ROOT_DIR/cache" -maxdepth 1 -type f -name "openjfx-$JFX_VERSION*_bin-sdk.zip" | head -n 1)"
  if [[ -z "$archive" ]]; then
    echo "JavaFX archive not found after download (expected openjfx-$JFX_VERSION*_bin-sdk.zip)." >&2
    exit 1
  fi

  unzip -q -o "$archive" -d "$ROOT_DIR/cache"

  javafx_lib="$(resolve_javafx_lib || true)"
  if [[ -z "$javafx_lib" ]]; then
    echo "JavaFX download did not produce a usable lib directory. Set JAVAFX_LIB manually." >&2
    exit 1
  fi

  JAVAFX_LIB="$javafx_lib"
  export JAVAFX_LIB
}

parse_java_major() {
  ("$JAVA_BIN" -version 2>&1 || true) | awk -F '"' '/version/ {print $2}' | awk -F. '{if ($1 == 1) print $2; else print $1}'
}

setup_ant() {
  if command -v ant >/dev/null 2>&1; then
    ANT_CMD="$(command -v ant)"
    return
  fi

  if [[ "$INSTALL_TOOLS" != "1" ]]; then
    echo "Apache Ant not found. Re-run with --install to auto-download Ant." >&2
    exit 1
  fi

  local ant_home="$TOOLS_DIR/apache-ant-$ANT_VERSION"
  local archive="$TOOLS_DIR/apache-ant-$ANT_VERSION-bin.tar.gz"
  local url="https://archive.apache.org/dist/ant/binaries/apache-ant-$ANT_VERSION-bin.tar.gz"

  if [[ ! -d "$ant_home" ]]; then
    echo "Downloading Ant $ANT_VERSION"
    curl -fsSL "$url" -o "$archive"
    tar -xzf "$archive" -C "$TOOLS_DIR"
  fi

  ANT_CMD="$ant_home/bin/ant"
}

normalize_path() {
  local raw_path="$1"
  if [[ "$raw_path" =~ ^([A-Za-z]):[\\/](.*)$ ]]; then
    local drive="${BASH_REMATCH[1],,}"
    local rest="${BASH_REMATCH[2]//\\//}"
    printf '/%s/%s\n' "$drive" "$rest"
    return
  fi

  printf '%s\n' "$raw_path"
}

resolve_ant_home() {
  local ant_home_env="${ANT_HOME:-}"
  local diagnostics_home
  if [[ -n "$ant_home_env" ]]; then
    ant_home_env="$(normalize_path "$ant_home_env")"
  fi
  if [[ -n "$ant_home_env" ]] && [[ -d "${ant_home_env}/lib" ]]; then
    printf '%s\n' "$ant_home_env"
    return
  fi

  diagnostics_home="$("$ANT_CMD" -diagnostics 2>/dev/null | awk -F': ' '/^ant.home:/ {print $2; exit}' | tr -d '\r')"
  if [[ -n "$diagnostics_home" ]]; then
    diagnostics_home="$(normalize_path "$diagnostics_home")"
  fi
  if [[ -n "$diagnostics_home" ]] && [[ -d "$diagnostics_home/lib" ]]; then
    printf '%s\n' "$diagnostics_home"
    return
  fi

  cd "$(dirname "$ANT_CMD")/.." && pwd
}

resolve_user_home() {
  local diagnostics_user_home
  local java_user_home
  local home_env="${HOME:-}"

  diagnostics_user_home="$("$ANT_CMD" -diagnostics 2>/dev/null | awk -F': ' '/^user.home:/ {print $2; exit}' | tr -d '\r')"
  if [[ -n "$diagnostics_user_home" ]]; then
    diagnostics_user_home="$(normalize_path "$diagnostics_user_home")"
  fi
  if [[ -n "$diagnostics_user_home" ]]; then
    printf '%s\n' "$diagnostics_user_home"
    return
  fi

  java_user_home="$("$JAVA_BIN" -XshowSettings:properties -version 2>&1 | awk -F'= ' '/^[[:space:]]*user\.home = / {print $2; exit}')"
  if [[ -n "$java_user_home" ]]; then
    java_user_home="$(normalize_path "$java_user_home")"
  fi
  if [[ -n "$java_user_home" ]]; then
    printf '%s\n' "$java_user_home"
    return
  fi

  if [[ -n "$home_env" ]]; then
    home_env="$(normalize_path "$home_env")"
    printf '%s\n' "$home_env"
    return
  fi
}

setup_ivy() {
  local ant_home
  ant_home="$(resolve_ant_home)"
  local home_dir
  home_dir="$(resolve_user_home)"
  if [[ -z "$home_dir" ]]; then
    echo "Unable to determine user home for Ivy installation." >&2
    exit 1
  fi
  local user_ivy="$home_dir/.ant/lib/ivy.jar"

  if [[ -f "$ant_home/lib/ivy.jar" || -f "$user_ivy" ]]; then
    return
  fi

  if [[ "$INSTALL_TOOLS" != "1" ]]; then
    echo "Ivy not found in Ant lib. Re-run with --install to auto-download Ivy." >&2
    exit 1
  fi

  local ivy_url="https://repo1.maven.org/maven2/org/apache/ivy/ivy/$IVY_VERSION/ivy-$IVY_VERSION.jar"
  local ivy_target="$ant_home/lib/ivy.jar"
  if [[ ! -w "$ant_home/lib" ]]; then
    ivy_target="$user_ivy"
    mkdir -p "$(dirname "$ivy_target")"
  fi

  echo "Downloading Ivy $IVY_VERSION"
  curl -fsSL "$ivy_url" -o "$ivy_target"
}

run_ant() {
  local target="$1"
  local logfile="$LOG_DIR/ant-$target.log"
  echo "Running ant $target"
  "$ANT_CMD" "$target" 2>&1 | tee "$logfile"
}

configure_ant_args_for_xz() {
  local xz_jar="$ROOT_DIR/lib/ivy/jar/xz.jar"

  if [[ ! -f "$xz_jar" ]]; then
    return
  fi

  local ant_args="${ANT_ARGS:-}"
  if [[ "$ant_args" != *"$xz_jar"* ]]; then
    ant_args="-lib $xz_jar${ant_args:+ $ant_args}"
  fi

  export ANT_ARGS="$ant_args"
  echo "Configured ANT_ARGS for current shell."

  if [[ -n "${GITHUB_ENV:-}" ]]; then
    local delimiter="__ANT_ARGS_EOF__"
    {
      printf 'ANT_ARGS<<%s\n' "$delimiter"
      printf '%s\n' "$ant_args"
      printf '%s\n' "$delimiter"
    } >> "$GITHUB_ENV"
    echo "Configured ANT_ARGS for subsequent workflow steps."
  fi
}

require_cmd curl
require_cmd tar
require_cmd unzip

JAVA_BIN="${JAVA_BIN:-$(command -v java || true)}"
if [[ -z "$JAVA_BIN" || ! -x "$JAVA_BIN" ]]; then
  if [[ -x "$ROOT_DIR/.tools/jdk-17/bin/java" ]]; then
    JAVA_BIN="$ROOT_DIR/.tools/jdk-17/bin/java"
  fi
fi

if [[ -z "$JAVA_BIN" || ! -x "$JAVA_BIN" ]]; then
  if [[ -x "/opt/homebrew/opt/openjdk@17/bin/java" ]]; then
    JAVA_BIN="/opt/homebrew/opt/openjdk@17/bin/java"
  fi
fi

if [[ -z "$JAVA_BIN" || ! -x "$JAVA_BIN" ]]; then
  echo "Unable to locate a working Java binary. Install Temurin JDK 17." >&2
  exit 1
fi

JAVA_MAJOR="$(parse_java_major)"
if [[ -z "$JAVA_MAJOR" || "$JAVA_MAJOR" -lt 17 ]]; then
  if [[ "$JAVA_BIN" != "/opt/homebrew/opt/openjdk@17/bin/java" && -x "/opt/homebrew/opt/openjdk@17/bin/java" ]]; then
    JAVA_BIN="/opt/homebrew/opt/openjdk@17/bin/java"
    JAVA_MAJOR="$(parse_java_major)"
  fi
fi

if [[ -z "$JAVA_MAJOR" || "$JAVA_MAJOR" -lt 17 ]]; then
  echo "JDK 17+ is required. Detected major version: ${JAVA_MAJOR:-unknown}" >&2
  exit 1
fi

JAVA_HOME="${JAVA_HOME:-$(cd "$(dirname "$JAVA_BIN")/.." && pwd)}"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

setup_ant
setup_ivy
setup_javafx

echo "Java version:"
"$JAVA_BIN" -version

echo "Ant version:"
"$ANT_CMD" -version

echo "JavaFX lib:"
echo "$JAVAFX_LIB"

if [[ "$CHECK_ONLY" == "1" ]]; then
  exit 0
fi

run_ant resolve
configure_ant_args_for_xz
run_ant jar

echo "Build logs written to: $LOG_DIR"
