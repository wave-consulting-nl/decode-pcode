#!/usr/bin/env bash
# Portable launcher for decode-pcode.
#
# Runs in two contexts:
#   * Build host (this Mac): falls back to the Homebrew keg-only OpenJDK if `java`
#     is not on PATH, and uses target/classes + target/lib if no fat-jar is built yet.
#   * Locked-down run host: prefers the self-contained fat-jar and `java` from PATH.
#
# Usage:
#   ./run.sh ProcessToFile               # decode PeopleCode to files (see outdir in DecodePC.properties)
#   ./run.sh ProcessToGit                # decode and commit to a Git repo
#   ./run.sh ProcessToSVN                # decode and commit to Subversion
#   ./run.sh ProcessToFile project.xml   # decode from an exported PeopleTools project .xml
#
# Prerequisites:
#   * DecodePC.properties in the current directory (filename is hardcoded in the app).
#   * Oracle JDBC driver jar (e.g. ojdbc11.jar) in ./jdbc/ unless decoding from a .xml.
#
# Build the fat-jar (on a machine with Maven):
#   mvn clean package        # -> target/decode-pcode-<version>-fat.jar
set -euo pipefail
cd "$(dirname "$0")"

# --- locate a Java runtime ---------------------------------------------------
if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
  JAVA="$JAVA_HOME/bin/java"
elif command -v java >/dev/null 2>&1; then
  JAVA="java"
elif command -v brew >/dev/null 2>&1 && [[ -x "$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home/bin/java" ]]; then
  JAVA="$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home/bin/java"
else
  echo "ERROR: no Java runtime found. Install a JRE/JDK 8+ or set JAVA_HOME." >&2
  exit 1
fi

# --- locate the application classpath ---------------------------------------
# Prefer the self-contained fat-jar; fall back to compiled classes + copied deps.
FATJAR="$(ls target/decode-pcode-*-fat.jar 2>/dev/null | head -1 || true)"
if [[ -n "$FATJAR" ]]; then
  APP_CP="$FATJAR"
elif [[ -d target/classes ]]; then
  APP_CP="target/classes:target/lib/*"
else
  echo "ERROR: no fat-jar and no target/classes. Run 'mvn clean package' first." >&2
  exit 1
fi

# JDBC driver is never bundled (licensing) — pick it up from ./jdbc/ if present.
CP="$APP_CP:jdbc/*"
if ! ls jdbc/*.jar >/dev/null 2>&1; then
  echo "WARNING: no JDBC driver found in ./jdbc/ — DB connection will fail." >&2
  echo "         (Not needed if your first arg points at a PeopleTools .xml project.)" >&2
fi

exec "$JAVA" -cp "$CP" decodepcode.Controller "$@"
