# decode-pcode — Run Book (locked-down environment)

Self-contained instructions for extracting PeopleCode from a PeopleSoft database to
files, using the prebuilt `decode-pcode-*-fat.jar`. You do **not** need the source
repo, Maven, or internet access — only a Java runtime and a JDBC driver.

---

## 1. What this does

Reads PeopleCode out of the PeopleTools tables and writes it to a directory tree as
plain text, so it can be diffed, searched, reviewed, or put under version control.
It is **read-only** against the database and writes nothing back to PeopleSoft.

On PeopleTools **8.52 or newer** it reads the plaintext PeopleCode from `PSPCMTXT`
verbatim — there is no lossy "decode" step, so output matches what App Designer shows.

---

## 2. Prerequisites

- **Java 8 or newer** (JRE or JDK). Check: `java -version`.
- **Oracle JDBC driver** jar — `ojdbc11.jar` (JDK 11+) or `ojdbc8.jar` (JDK 8).
- **A read-only database account** with `SELECT` on these tables (owner schema,
  usually `SYSADM`):
  `PSPCMPROG`, `PSPCMNAME`, `PSPCMTXT`, `PSSQLDEFN`, `PSSQLTEXTDEFN`,
  `PSPROJECTITEM`, `PSPACKAGEDEFN`.
- Network reachability from this host to the database listener (e.g. Oracle 1521).

---

## 3. Files to place in one folder

```
decode-pcode/
  decode-pcode-1.0-SNAPSHOT-fat.jar     # the application (this artifact)
  run.sh                                # optional launcher (Linux/macOS)
  DecodePC.properties                   # your connection + output config (see §4)
  jdbc/
    ojdbc11.jar                         # the Oracle driver you provide
  out/                                  # created automatically; decoded files land here
```

The application reads `DecodePC.properties` **from the current working directory**, so
always run the command from inside this folder.

---

## 4. Configure `DecodePC.properties`

Create a file named exactly `DecodePC.properties` with the following. Replace every
`<...>` value. Keep this file private — it contains a database password.

```properties
# --- DEV database connection (read-only account) ---
user=<RO_USER>
password=<RO_PASSWORD>
dbowner=SYSADM
driverClass=oracle.jdbc.OracleDriver

# Oracle thin URL — choose ONE form:
#   service name (12c+/pluggable, most common):
url=jdbc:oracle:thin:@<HOST>:1521/<SERVICE_NAME>
#   SID (older instances):
#url=jdbc:oracle:thin:@<HOST>:1521:<SID>

# --- output ---
# Decoded PeopleCode tree is written under this directory.
outdir=./out/DEV
```

Notes:
- `user` is the account you log in as; `dbowner` is the schema that owns the PS tables
  (almost always `SYSADM`).
- Do **not** set `AlwaysDecode=true` on PeopleTools 8.52+ — leaving it off keeps the
  lossless plaintext path.

---

## 5. Run

**Linux / macOS (with the launcher):**
```bash
./run.sh ProcessToFile
```

**Any platform (direct java call):**
```bash
# Linux / macOS — note the ':' classpath separator
java -cp "decode-pcode-1.0-SNAPSHOT-fat.jar:jdbc/ojdbc11.jar" decodepcode.Controller ProcessToFile

# Windows — note the ';' classpath separator
java -cp "decode-pcode-1.0-SNAPSHOT-fat.jar;jdbc/ojdbc11.jar" decodepcode.Controller ProcessToFile
```

Capture the log if you want a record:
```bash
./run.sh ProcessToFile 2>&1 | tee out/decode-dev.log
```

---

## 6. What success looks like

In the console/log you should see, near the start:
```
INFO: Can read PSPCMTXT (tools >= 8.52)
```
That line confirms the lossless plaintext path is being used. (If instead you see
`Can NOT access PSPCMTXT`, the account is missing the `PSPCMTXT` grant or the tools
release is older — see §8.)

When it finishes, the decoded tree is under `out/DEV`:
```bash
find out/DEV -type f | head
```
Each PeopleCode program is written as a text file mirroring its PeopleTools location
(record/field/event, App Package path, etc.).

---

## 7. Verify fidelity (one-time confidence check)

Pick 2–3 programs you know — ideally one delivered, one customized, and one App Package
method — open each in Application Designer, and compare to the matching file under
`out/DEV`. On 8.52+ they should match exactly (whitespace-only differences are fine).
This is a formality on 8.52+ but closes the loop.

---

## 8. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `ClassNotFoundException: oracle.jdbc.OracleDriver` | Driver jar not on the classpath. Put `ojdbc*.jar` in `jdbc/` (run.sh picks it up) or name it in `-cp`. |
| `ORA-01017: invalid username/password` | Wrong `user`/`password` in `DecodePC.properties`. |
| `ORA-12514` / `The Network Adapter could not establish the connection` | Wrong host/port/service in `url`, or no network path to the listener. Try the SID form vs service-name form. |
| `ORA-00942: table or view does not exist` | Missing `SELECT` grant, or wrong `dbowner` (should usually be `SYSADM`). |
| Log says `Can NOT access PSPCMTXT` | Missing grant on `PSPCMTXT`, or PeopleTools < 8.52. With the grant present and tools ≥ 8.52 you get the lossless path; without it the tool falls back to bytecode decoding (acceptable but less proven). |
| `Unsupported class file` / Java version error | Java too old. Use Java 8+ (`java -version`). |
| Nothing written to `out/DEV` | Check `outdir` path and that the account can actually see PeopleCode rows; re-run with the log captured (§5). |

---

## 9. Optional: other modes

- `ProcessToFile <project.xml>` — decode from an exported PeopleTools **project .xml**
  instead of a live DB (no driver/connection needed).
- `ProcessToGit` / `ProcessToSVN` — decode and commit straight into a Git/Subversion
  repo. These need extra `git*`/`svn*` keys in `DecodePC.properties`; ask the maintainer
  for the extended template if you want this.

---

## 10. Security reminders

- Use a dedicated **read-only** account — never a read-write or admin schema.
- `DecodePC.properties` holds a live password — keep it off shared drives and out of
  any version control.
- The decoded output is your source code; treat the `out/` tree per your normal code
  handling policy.
