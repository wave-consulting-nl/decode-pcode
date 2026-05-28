# BACKLOG.md — decode-pcode (Wave Consulting fork)

Ordered list of future tasks, refactors, and follow-ups. Each has a short rationale.
Tracked milestones live in [PLANS.md](./PLANS.md); this file is the longer-horizon queue.

## Near-term (unblocks live use)

1. **Provision a read-only DEV DB account + JDBC driver.**
   Rationale: hard prerequisite for M4. Account needs only the SELECT grants in
   SPEC.md §4; driver (`ojdbc11.jar`) goes in `jdbc/`. Owner: ops/DBA.

2. **First live decode against DEV (M4).**
   Rationale: validates the whole toolchain against a real database and confirms
   the lossless PSPCMTXT path is taken.

3. **Fidelity spot-check (M5).**
   Rationale: closes the loop; cheap confidence that decoded output equals the
   App Designer source on our PeopleTools release.

## Pipeline / automation

4. **Stand up the Git pipeline (`ProcessToGit`, M6).**
   Rationale: the real payoff — PeopleCode under version control with diff/blame.
   Configure `gitdir`, `gitbase`, and `gituser*` author mappings.

5. **Author-mapping table for our OPRIDs.**
   Rationale: without `gituser*` entries, all commits collapse to one default
   author. Map `PPLSOFT` -> delivered and each developer OPRID -> name/email so
   `git blame` is meaningful.

6. **Scheduled nightly extract + commit.**
   Rationale: snapshots give environment drift detection (DEV/TEST/PROD) over time.
   Adapt the repo's `nightly.sh`; run on a box with DB access and `JAVA_HOME` set.

7. **Multi-environment + ancestor history.**
   Rationale: declare `processPROD` and `ancestor=PROD` so each object's history
   reads `delivered -> PROD -> DEV`. Useful for understanding customization layers.

## Hardening / maintenance

8. **Pin a `maven-compiler-plugin` release in `pom.xml`.**
   Rationale: currently relies on the implicit target 1.8 default (obsolescence
   warnings on JDK 26). Pin to an explicit release (e.g. 11 or 17) to stop relying
   on deprecated defaults that future JDKs will remove.

9. **Build a runnable fat-jar (assembly/shade plugin).**
   Rationale: `run.sh` works but depends on `target/lib`. A self-contained jar
   simplifies deployment to a scheduling host.

10. **Audit transitive deps for CVEs.**
    Rationale: 2017-era svnkit 1.3.5 / jgit 4.7 pull old transitive libraries.
    Run `mvn dependency:tree` + OWASP Dependency-Check before any networked use.

11. **Evaluate broader object export vs. PeopleCode-only.**
    Rationale: this tool covers PeopleCode (+ SQL objects) only. If we want records,
    pages, and components under VCS too, assess a complementary tool or extend scope.

## Notes

- Upstream (`cache117/decode-pcode`) is dormant; we maintain this fork. Avoid drift
  from upstream unless a specific fix is needed.
- Keep real credentials out of git — `DecodePC.properties` is skip-worktree guarded.
