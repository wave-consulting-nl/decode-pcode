# SPEC.md — decode-pcode (Wave Consulting fork)

## 1. Problem Definition

PeopleCode lives inside the PeopleSoft database, not as files on disk. App Designer
is the only first-class way to view it, which makes code review, history, diffing,
and offline search painful. `decode-pcode` extracts PeopleCode out of the PeopleTools
tables and writes it to the filesystem — optionally committing it to Git or Subversion —
so the codebase can be version-controlled, diffed, grepped, and reviewed like ordinary
source.

**Goal of this fork:** stand up a working, reproducible extraction toolchain on macOS,
verify decode fidelity for our PeopleTools release, and make a live run a matter of
filling in connection details.

## 2. Background / Origin

- Upstream: `cache117/decode-pcode` (itself a fork of Eric H.'s SourceForge project, v0.61).
- Our fork: `wave-consulting-nl/decode-pcode`.
- Java (98%), Maven project, 25 source files. Last upstream activity 2017. ISC license.
- Dormant upstream — treat as a stable base we maintain ourselves.

## 3. How It Works (Architecture)

### Entry point
`decodepcode.Controller#main(String[])` — first arg selects the processing mode:
- `ProcessToFile` — write decoded PeopleCode to a directory tree (`outdir`).
- `ProcessToGit` — write and commit to a Git repository.
- `ProcessToSVN` — write and commit to Subversion.
- Optional second arg: a PeopleTools project `.xml` export — decode from the export
  instead of a live DB connection.

Configuration is loaded from `DecodePC.properties` in the working directory
(hardcoded at `Controller.java:706`).

### The two decode paths (fidelity-critical)
`Controller.java:148-192` → `JDBCPeopleCodeContainer.java:163-196`:

1. **PeopleTools >= 8.52 (PSPCMTXT present) — DEFAULT, lossless.**
   The tool queries `PSPCMTXT` for `PCTEXT` and concatenates it **verbatim**
   (`sb.append(rs2.getString("PCTEXT"))`, line 191). `PSPCMTXT` holds the canonical
   plaintext PeopleCode the database stores — the same source App Designer displays.
   **No bytecode decoding occurs**, so fidelity is guaranteed by construction.

2. **PeopleTools < 8.52 (no PSPCMTXT) — fallback, lossy-risk.**
   Falls back to `initJDBCPeopleCodeContainerViaDecode`, which runs the 917-line
   `PeopleCodeParser` against the tokenized bytecode. Only this path carries real
   fidelity risk and warrants spot-checking against App Designer.

The `AlwaysDecode=true` property forces path 2 even on 8.52+ (used only to avoid
whitespace-only diffs originating from `PSPCMTXT`).

### Multi-environment / ancestor model
Any number of environments can be declared via `process<SUFFIX>` keys (e.g. `processPROD`).
Setting `ancestor=PROD` causes an object's PROD version to be committed before its DEV
version, producing a clean `delivered -> PROD -> DEV` history per program.

## 4. Target Environment (this fork's verified context)

> **Deployment model (IMPORTANT).** The PeopleSoft database lives in a **locked-down
> environment** with no network path from this workstation. This macOS box is a
> **dev/reference build only** — it compiles, packages, and holds the docs/config
> templates, but it **cannot reach the database** and will **not** run a live decode
> (milestones M4/M5). The actual extraction must run on a **host inside the locked-down
> environment** that has JDBC reachability to the PeopleSoft DB. A self-contained,
> transferable **fat-jar** (see BACKLOG #9) is the preferred delivery into that env, since
> a hand-set `target/lib/` classpath is awkward to ship and a Homebrew JDK is not
> guaranteed there. The transferable **fat-jar now exists** (M3.5):
> `mvn clean package` → `target/decode-pcode-<version>-fat.jar` (~8 MB, app + svnkit + jgit;
> Oracle driver excluded by design).
>
> **Deploying to the locked-down run host:** copy in (a) the fat-jar, (b) the Oracle JDBC
> driver (`ojdbc11.jar`), (c) `run.sh`, and (d) a filled-in `DecodePC.properties`. Layout:
> ```
> decode-pcode/
>   decode-pcode-<version>-fat.jar     # or under target/ — run.sh finds either
>   jdbc/ojdbc11.jar
>   run.sh
>   DecodePC.properties
> ```
> Then run `./run.sh ProcessToFile`, or without bash:
> `java -cp "decode-pcode-<version>-fat.jar:jdbc/ojdbc11.jar" decodepcode.Controller ProcessToFile`
> (use `;` instead of `:` as the classpath separator on Windows). Requires only a JRE/JDK 8+.

- **PeopleTools:** >= 8.52 → lossless PSPCMTXT path. The bytecode decoder never runs.
- **Database:** Oracle (template provided). SQL Server also supported by upstream.
- **Build host (here):** macOS (Apple Silicon), Homebrew, OpenJDK 26 (keg-only),
  Maven 3.9.16. Project compiles at target 1.8 (warnings only).
- **Run host (locked-down env):** any JRE/JDK 8+ with DB reachability and the artifact above.

### Required DB grants (read-only account)
`SELECT` on: `PSPCMPROG`, `PSPCMNAME`, `PSPCMTXT`, `PSSQLDEFN`, `PSSQLTEXTDEFN`,
`PSPROJECTITEM`, `PSPACKAGEDEFN`.

### Connection property model
- `user` / `password` — the read-only account you log in as.
- `dbowner` — schema that owns the PeopleSoft tables (typically `SYSADM`).
- `url` / `driverClass` — JDBC connection. Base env uses unsuffixed keys; additional
  environments use a suffix (`userPROD`, `urlPROD`, ...). `driverClass` falls back to the
  base value if a suffixed one is absent (`Controller.java:105-108`).

## 5. Local Setup (what this fork adds)

| File | Purpose |
|------|---------|
| `run.sh` | Launcher: sets `JAVA_HOME` for the keg-only JDK, builds the classpath (`target/classes` + `target/lib/*` + `jdbc/*`), passes args to `Controller`. |
| `jdbc/` | Drop-in directory for the user-supplied JDBC driver. Jars are gitignored. |
| `DecodePC.properties.oracle.template` | Verified Oracle config; `ProcessToFile` default, with commented Git and PROD-ancestor blocks. |

### Build (once)
```bash
JAVA_HOME=$(brew --prefix openjdk)/libexec/openjdk.jdk/Contents/Home \
  mvn clean compile dependency:copy-dependencies -DoutputDirectory=target/lib
```

### Run
```bash
cp DecodePC.properties.oracle.template DecodePC.properties   # edit <PLACEHOLDER>s
# drop Oracle driver (ojdbc11.jar for JDK 11+) into jdbc/
./run.sh ProcessToFile                                       # decoded tree -> ./out/DEV
```

## 6. Constraints

- The brew JDK is **keg-only**: `java` is not on `PATH` by default. `run.sh` sets
  `JAVA_HOME` itself; any manual `mvn`/`java` invocation must export it too.
- `DecodePC.properties` filename is **hardcoded** and must sit in the working directory.
- The Oracle JDBC driver is **not bundled** (licensing) — supply it in `jdbc/`.
- Decode runs against the DB read-only; account needs only the SELECT grants above.

## 7. Security

- Real credentials live only in `DecodePC.properties`, which is guarded with
  `git update-index --skip-worktree DecodePC.properties` (local-only) so edits to it
  are never staged. Undo with `--no-skip-worktree` if the sample must be re-committed.
- `.gitignore` covers `target/`, `*.jar`, and `out/` — build artifacts, the JDBC driver,
  and decoded output are never committed.
- Use a dedicated **read-only** DB account; never a read-write or admin schema.

## 8. Non-Goals

- **Not** a full PeopleSoft object export — decodes PeopleCode (and SQL objects) only,
  not records, pages, components, or other definitions.
- **Not** a two-way sync — extraction only; it does not write code back into PeopleSoft.
- **Not** modernizing the upstream codebase (Java 8 target, 2017-era deps) beyond what is
  needed to build and run on the current macOS toolchain.
- **Not** validating the pre-8.52 bytecode decoder — out of scope for our 8.52+ target.

## 9. Status

- [x] Forked, cloned, builds clean (JDK 26 / Maven 3.9.16).
- [x] Fidelity question resolved: lossless PSPCMTXT path confirmed for PTools >= 8.52.
- [x] Launcher, JDBC drop-in, and Oracle template committed (`b2391ca`).
- [x] Credential guard (`skip-worktree`) applied locally.
- [x] Transferable fat-jar built (M3.5); `run.sh` portable; verified to DB-driver boundary.
- [ ] Live decode against a DEV database — **must run inside the locked-down PSFT env**
      (not from this workstation); pending JDBC driver + filled-in connection on the run host.
- [ ] Spot-check one decoded program against App Designer to close the loop (in that env).
