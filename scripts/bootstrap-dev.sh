#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/.tools"
LOG_DIR="$ROOT_DIR/artifacts/logs"

ANT_VERSION="1.10.15"
IVY_VERSION="2.5.2"

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

setup_ivy() {
  if command -v ivy >/dev/null 2>&1; then
    return
  fi

  local ant_home
  ant_home="$(cd "$(dirname "$ANT_CMD")/.." && pwd)"

  if [[ -f "$ant_home/lib/ivy.jar" ]]; then
    return
  fi

  if [[ "$INSTALL_TOOLS" != "1" ]]; then
    echo "Ivy not found in Ant lib. Re-run with --install to auto-download Ivy." >&2
    exit 1
  fi

  local ivy_url="https://repo1.maven.org/maven2/org/apache/ivy/ivy/$IVY_VERSION/ivy-$IVY_VERSION.jar"
  echo "Downloading Ivy $IVY_VERSION"
  curl -fsSL "$ivy_url" -o "$ant_home/lib/ivy.jar"
}

run_ant() {
  local target="$1"
  local logfile="$LOG_DIR/ant-$target.log"
  echo "Running ant $target"
  "$ANT_CMD" "$target" 2>&1 | tee "$logfile"
}

require_cmd curl
require_cmd tar

JAVA_BIN="${JAVA_BIN:-$(command -v java || true)}"
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

echo "Java version:"
"$JAVA_BIN" -version

echo "Ant version:"
"$ANT_CMD" -version

if [[ "$CHECK_ONLY" == "1" ]]; then
  exit 0
fi

run_ant resolve
run_ant jar

echo "Build logs written to: $LOG_DIR"
