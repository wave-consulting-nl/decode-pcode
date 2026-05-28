#!/usr/bin/env bash
# Launcher for decode-pcode on macOS (Homebrew keg-only OpenJDK).
#
# Usage:
#   ./run.sh ProcessToFile               # decode PeopleCode to files (see outdir in DecodePC.properties)
#   ./run.sh ProcessToGit                # decode and commit to a Git repo
#   ./run.sh ProcessToSVN                # decode and commit to Subversion
#   ./run.sh ProcessToFile project.xml   # decode from an exported PeopleTools project .xml instead of the DB
#
# Prerequisites:
#   1. Build once:   JAVA_HOME=$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home mvn clean compile dependency:copy-dependencies -DoutputDirectory=target/lib
#   2. Drop your JDBC driver jar into ./jdbc/   (e.g. ojdbc8.jar for Oracle, mssql-jdbc-*.jar for SQL Server)
#   3. Edit DecodePC.properties with your read-only DEV connection + outdir.
#
# Required DB grants (read-only): SELECT on PSPCMPROG, PSPCMNAME, PSPCMTXT (PTools>=8.52),
#   PSSQLDEFN, PSSQLTEXTDEFN, PSPROJECTITEM, PSPACKAGEDEFN.
set -euo pipefail
cd "$(dirname "$0")"

export JAVA_HOME="${JAVA_HOME:-$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home}"
JAVA="$JAVA_HOME/bin/java"

if [[ ! -d target/classes ]]; then
  echo "target/classes missing — run the build step from the header comment first." >&2
  exit 1
fi

# classpath: compiled classes + maven deps + any JDBC driver you dropped in ./jdbc/
CP="target/classes:target/lib/*:jdbc/*"

if ! ls jdbc/*.jar >/dev/null 2>&1; then
  echo "WARNING: no JDBC driver found in ./jdbc/ — DB connection will fail." >&2
  echo "         (Not needed if your first arg points at a PeopleTools .xml project.)" >&2
fi

exec "$JAVA" -cp "$CP" decodepcode.Controller "$@"
