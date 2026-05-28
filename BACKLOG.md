# BACKLOG.md — decode-pcode (Wave Consulting fork)

Ordered list of future tasks, refactors, and follow-ups. Each has a short rationale.
Tracked milestones live in [PLANS.md](./PLANS.md); this file is the longer-horizon queue.

> **Deployment reality:** the PSFT database is in a **locked-down environment**
> unreachable from the build workstation. Nothing past item 1 runs from here — the
> live steps execute on a host *inside* that environment. See SPEC.md §4.

## Near-term (unblocks live use)

1. ~~**Package a transferable artifact (M3.5) — fat-jar.**~~ ✅ DONE
   Built via maven-shade-plugin → `target/decode-pcode-<version>-fat.jar` (app + svnkit +
   jgit; Oracle driver excluded by design). `run.sh` made portable (PATH `java`, no
   Homebrew/Maven on the run host). Deploy steps in SPEC.md §4. Next blocker is now item 2.

2. **Provision a read-only DEV DB account + JDBC driver (in the locked-down env).**
   Rationale: hard prerequisite for M4. Account needs only the SELECT grants in
   SPEC.md §4; driver (`ojdbc11.jar`) goes in `jdbc/` on the run host. Owner: ops/DBA.

3. **First live decode against DEV (M4) — inside the locked-down env.**
   Rationale: validates the whole toolchain against a real database and confirms
   the lossless PSPCMTXT path is taken. Cannot be run or observed from this workstation.

4. **Fidelity spot-check (M5) — inside the locked-down env.**
   Rationale: closes the loop; cheap confidence that decoded output equals the
   App Designer source on our PeopleTools release.

## Pipeline / automation

5. **Stand up the Git pipeline (`ProcessToGit`, M6) — in the locked-down env.**
   Rationale: the real payoff — PeopleCode under version control with diff/blame.
   Configure `gitdir`, `gitbase`, and `gituser*`; needs a destination repo reachable
   from that env.

6. **Author-mapping table for our OPRIDs.**
   Rationale: without `gituser*` entries, all commits collapse to one default
   author. Map `PPLSOFT` -> delivered and each developer OPRID -> name/email so
   `git blame` is meaningful.

7. **Scheduled nightly extract + commit (on a run host inside the env).**
   Rationale: snapshots give environment drift detection (DEV/TEST/PROD) over time.
   Adapt the repo's `nightly.sh`; run on a box with DB access and a JRE available.

8. **Multi-environment + ancestor history.**
   Rationale: declare `processPROD` and `ancestor=PROD` so each object's history
   reads `delivered -> PROD -> DEV`. Useful for understanding customization layers.

## Hardening / maintenance

9. ~~**Pin a `maven-compiler-plugin` release in `pom.xml`.**~~ ✅ DONE
   Pinned maven-compiler-plugin 3.13.0 with `maven.compiler.release=8` → deterministic
   Java 8 bytecode (class major version 52), runnable on any JRE 8+. NOTE: JDK 26 warns
   that `release 8` is obsolete and may be removed in a future JDK — if a future *build*
   JDK drops it, bump the release to 11 or 17 and update the "Java 8+" claim in
   RUNBOOK.md/SPEC.md accordingly.

   (The fat-jar that previously lived here is now near-term item 1 — it became the
   top blocker once we knew the run host is a separate, locked-down environment.)

10. ~~**Audit transitive deps for CVEs.**~~ ✅ DONE — see [SECURITY-AUDIT.md](./SECURITY-AUDIT.md)
    Scanned 15 deps with grype. 3 findings, all in the jgit subtree (1 High jgit file-overwrite,
    1 Medium jgit XXE, 1 Medium httpclient). All only reachable in `ProcessToGit`, and none
    match our data flow → effective risk ~none for `ProcessToFile`. FOLLOW-UP (item 12): if
    `ProcessToGit` is adopted, bump jgit to 5.13.4.202507202350-r (last Java-8 line) to clear
    all three; must be validated where a Git remote exists.

11. **Evaluate broader object export vs. PeopleCode-only.**
    Rationale: this tool covers PeopleCode (+ SQL objects) only. If we want records,
    pages, and components under VCS too, assess a complementary tool or extend scope.

12. **Bump jgit to 5.13.4.202507202350-r (only if `ProcessToGit` is adopted).**
    Rationale: clears all 3 audit findings (SECURITY-AUDIT.md). Last Java-8-compatible
    jgit line — 6.x+ needs Java 11+ and would break the `release 8` pin. Conditional on
    using the Git pipeline; must be rebuilt + validated against a real Git remote (cannot
    be tested on the air-gapped build host). Not needed for `ProcessToFile`.

## Notes

- Upstream (`cache117/decode-pcode`) is dormant; we maintain this fork. Avoid drift
  from upstream unless a specific fix is needed.
- Keep real credentials out of git — `DecodePC.properties` is skip-worktree guarded.
