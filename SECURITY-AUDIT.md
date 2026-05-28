# Dependency Security Audit — decode-pcode

Audit of transitive dependencies (BACKLOG #10). Scanner: **grype 0.112.0** (GitHub
Advisory + NVD data) run against both the shipped fat-jar and the 15 discrete dependency
jars. Date of scan: 2026-05-28. Build = compiler `release 8`, deps unchanged from upstream.

## Summary

| # | Component | Version | Advisory | Severity | Fixed in | Reachable here? |
|---|-----------|---------|----------|----------|----------|-----------------|
| 1 | org.eclipse.jgit | 4.7.0.201704051617-r | GHSA-3p86-9955-h393 (CVE-2023-4759) — Arbitrary File Overwrite | **High** | 5.13.3.202401111512-r | Only in `ProcessToGit`, and not by our flow |
| 2 | org.eclipse.jgit | 4.7.0.201704051617-r | GHSA-vrpq-qp53-qv56 — XML External Entity (XXE) | Medium | 5.13.4.202507202350-r | Only in `ProcessToGit`, and not by our flow |
| 3 | httpclient (Apache) | 4.3.6 | GHSA-7r82-7xv7-xcpj (assoc. CVE-2020-13956) — URI/XSS handling | Medium | 4.5.13 | Only via jgit HTTP transport |

No advisories were found for the other 12 dependencies: svnkit 1.3.5, trilead-ssh2,
sqljet 1.0.4, jna 3.2.3, jsch 0.1.54, JavaEWAH 1.1.6, httpcore 4.3.3, slf4j-api 1.7.2,
antlr-runtime 3.1.3, stringtemplate 3.2 (and the project's own classes).

## Reachability analysis (why severity ≠ effective risk)

All three findings live in the **jgit** subtree (httpclient is a transitive dep of jgit's
HTTP transport). decode-pcode only touches jgit in **`ProcessToGit`** mode. The primary,
verified use case — **`ProcessToFile`** (read PeopleCode over JDBC, write text files) —
does not load jgit or httpclient at all, so for that workflow the **effective risk is
essentially none**.

Even in `ProcessToGit` mode, the vulnerable code paths do not match our data flow:

- **#1 Arbitrary File Overwrite (CVE-2023-4759)** triggers when *cloning/checking out an
  untrusted repository* with crafted symlinks/`.gitattributes`. decode-pcode *creates and
  commits into a local repo it controls* — it does not clone untrusted remote content.
- **#2 XXE** requires parsing attacker-controlled XML from an untrusted repo. Same as
  above — not our input.
- **#3 HttpClient URI handling** only matters when jgit talks HTTP(S) to a *malicious*
  server. In a controlled internal environment pushing to your own Git server, this does
  not apply.

**Conclusion:** for `ProcessToFile` (the intended PeopleCode-to-files extract), there is no
practical exposure. For `ProcessToGit` against a trusted internal repository, residual risk
is low. None of the three is reachable by simply decoding PeopleCode.

## Remediation options

1. **Accept, documented (default for `ProcessToFile`).** No code change; this file is the
   record. Justified by the non-reachability above.
2. **Upgrade jgit to `5.13.4.202507202350-r` (recommended if `ProcessToGit` will be used).**
   This is the last Java-8-compatible jgit line (6.x+ needs Java 11+, which would break our
   `release 8` pin). It fixes **both** jgit findings and pulls a newer httpclient, clearing
   all three. Requires a rebuild + re-test of the Git path (cannot be tested on the
   air-gapped build host — must be validated where a Git target exists).
3. **Pin httpclient to 4.5.13** via dependency management — clears #3 only; leaves the jgit
   findings. Inferior to option 2.

## Recommendation

- Shipping **`ProcessToFile`** only → **option 1** (accept; risk is non-reachable).
- Planning to use **`ProcessToGit`** → **option 2** (bump jgit to 5.13.4.x), validated in an
  environment with a Git remote before relying on it.

## Reproduce

```bash
brew install grype
mvn clean package
grype target/decode-pcode-*-fat.jar          # scans the shipped artifact
# fuller per-dependency view:
mvn dependency:copy-dependencies -DoutputDirectory=target/lib
for j in target/lib/*.jar; do grype "$j"; done
```
