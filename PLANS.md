# PLANS.md — decode-pcode (Wave Consulting fork)

Milestone-based plan. Each milestone has acceptance criteria and validation commands.
See [SPEC.md](./SPEC.md) for problem definition, architecture, and constraints.

Conventions:
- All `mvn`/`java` commands assume `JAVA_HOME` is set (brew JDK is keg-only):
  `export JAVA_HOME=$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home`
- `./run.sh` sets `JAVA_HOME` itself.

---

## M1 — Toolchain & Build  ✅ DONE

Stand up a reproducible build on macOS.

**Acceptance criteria**
- [x] JDK + Maven installed via Homebrew.
- [x] Project compiles clean (warnings-only) to `target/classes`.
- [x] Runtime dependencies resolved into `target/lib/`.

**Validation**
```bash
export JAVA_HOME=$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home
mvn clean compile dependency:copy-dependencies -DoutputDirectory=target/lib
ls target/classes/decodepcode/Controller.class   # exists
ls target/lib/*.jar | wc -l                       # 15 deps
```

---

## M2 — Launcher & Config  ✅ DONE

Make a run a matter of filling in connection details.

**Acceptance criteria**
- [x] `run.sh` handles keg-only JDK, classpath, and arg passthrough.
- [x] `jdbc/` drop-in directory for the user-supplied driver (jars gitignored).
- [x] Verified Oracle config template with `ProcessToFile` default.
- [x] Credential guard applied: `git update-index --skip-worktree DecodePC.properties`.

**Validation**
```bash
./run.sh                       # rejects with "First argument should be ProcessToFile or similar"
git ls-files -v DecodePC.properties   # leading "S" = skip-worktree active
```

---

## M3 — Documentation  ✅ DONE

**Acceptance criteria**
- [x] `SPEC.md` committed (problem, architecture, fidelity finding, constraints, non-goals).
- [x] `PLANS.md` + `BACKLOG.md` committed.

**Validation**
```bash
git log --oneline | grep -E "SPEC|PLANS|BACKLOG"
```

---

## M3.5 — Package a Transferable Artifact  ✅ DONE

The DB lives in a locked-down environment unreachable from the build workstation
(see SPEC.md §4 deployment model). Produced a self-contained fat-jar that can be
handed into that environment.

**Acceptance criteria**
- [x] Fat-jar via maven-shade-plugin bundling app + deps (svnkit, jgit) →
      `target/decode-pcode-<version>-fat.jar`. Oracle driver excluded by design.
- [x] Manifest `Main-Class: decodepcode.Controller`; launches via `java -jar` and
      reaches `main()` with all deps resolved.
- [x] `run.sh` made portable: prefers the fat-jar, uses `java` from PATH (no
      Homebrew/Maven assumptions on the run host).
- [x] Transfer + run instructions documented in SPEC.md §4.

**Validation**
```bash
mvn clean package                                  # -> target/decode-pcode-*-fat.jar
java -jar target/decode-pcode-*-fat.jar            # usage message, deps resolved
./run.sh ProcessToFile                             # reaches DB-driver boundary (CNFE on
                                                   #   oracle.jdbc.OracleDriver until driver added)
```

---

## M4 — Live Decode (DEV)  ⬜ PENDING — RUNS INSIDE LOCKED-DOWN ENV

Run an end-to-end extraction against a read-only DEV database. **Cannot run from the
build workstation** — executes on a host inside the locked-down PSFT environment with
JDBC reachability.

**Prerequisites (in the locked-down env)**
- Transferable artifact from M3.5 + a JRE/JDK 8+.
- Oracle JDBC driver (`ojdbc11.jar`) placed in `jdbc/`.
- Read-only DEV account with SELECT grants (see SPEC.md §4).
- `DecodePC.properties` filled in from the Oracle template.

**Acceptance criteria**
- [ ] `./run.sh ProcessToFile` completes without connection/SQL errors.
- [ ] Decoded PeopleCode tree written under `./out/DEV`.
- [ ] Log confirms the PSPCMTXT (plaintext) path was used — i.e. line
      "Can read PSPCMTXT (tools >= 8.52)" appears, not the decode fallback.

**Validation**
```bash
cp DecodePC.properties.oracle.template DecodePC.properties   # edit connection
./run.sh ProcessToFile 2>&1 | tee out/decode-dev.log
grep -c "Can read PSPCMTXT" out/decode-dev.log               # >= 1
find out/DEV -type f | head                                  # decoded files present
```

---

## M5 — Fidelity Spot-Check  ⬜ PENDING — INSIDE LOCKED-DOWN ENV

Confirm decoded output matches what App Designer shows (formality on 8.52+, but
closes the loop). Performed in the locked-down env where both the decoded output and
App Designer are available.

**Acceptance criteria**
- [ ] Pick 2-3 known programs (1 delivered, 1 customized, 1 App Package).
- [ ] Diff decoded file against the App Designer view — byte-for-byte or
      whitespace-only differences acceptable.
- [ ] Findings recorded (in SPEC.md §9 status or a short note).

**Validation**
- Manual: open each program in App Designer, compare to the file under `out/DEV`.

---

## M6 — Optional: VCS Pipeline  ⬜ FUTURE — INSIDE LOCKED-DOWN ENV

Wire the extract into Git for ongoing history. Runs in the locked-down env (DB access
required); a destination repo reachable from that env is needed. See BACKLOG.md for sub-tasks.

**Acceptance criteria**
- [ ] `./run.sh ProcessToGit` commits decoded code into a target repo.
- [ ] Author mapping (`gituser*`) attributes delivered vs. custom code correctly.
- [ ] Repeatable nightly run produces meaningful diffs (no spurious churn).
