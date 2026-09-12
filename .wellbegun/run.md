---
mode: companion
cycle: 3
---

- [x] 1.1 verified (fresh, high-tier) — boundary tests: Flutter 58 pass, Firebase 71 pass; probes: 0 written, 0 committed; findings: downstream profileThemeKey compile migration belongs to steps 2.1/2.2
- [x] 1.2 verified (fresh, high-tier) — round 1 REJECT: surfaceContainer roles escaped named surface → fixed in production; round 2 pass; probes: 4 written, 0 committed; findings: AppThemeScope/root propagation owned by step 3.1
- [x] 1.3 verified (fresh, high-tier) — boundary tests 4 pass + hooks/analyze; probes: 0 written, 0 committed; findings: Step 2 must map ThemeMode.system sentinel to KST auto
- [x] 1.4 verified (basic, mid-tier) — core.hooksPath restored; four enforcement checks exit 0
- [x] 1.5 verified (basic, mid-tier) — boundary tests: Flutter 14 pass, Firebase matrix 7 pass; implementation finding: actual pre-cycle-3 `profileThemeKey` survived A/auto backfill and failed Firestore `hasOnly` → transaction now removes it and both matrices use the historical shape; full regression observed: Flutter 960 pass, Firebase 78 pass; superseded fresh-verifier probes remain uncommitted and preserved; outside-contract legacy stamp-before-profile-patch deferred
- [x] phase 1 integration verified (fresh, high-tier) — round 1 unbuildable fixed, round 2 fake shim fixed, round 3 exposed legacy patch rejection → Step 1.5 split and verified, round 4 pass; targeted Flutter 48 pass, full Firebase 80 pass, design analyze/pre-commit/diff-check pass; probes: 2 written, 0 committed (retained); findings: untouched legacy first-stamp failure confirmed outside the explicit nickname/team contract and deferred
- [ ] 2.1 — paused before restart while Phase 1 commit ownership is restored
- [ ] 2.2
- [ ] phase 2 integration
- [ ] 3.1
- [ ] 3.2
- [ ] phase 3 integration
- [ ] 4.1
- [ ] 4.2
- [ ] phase 4 integration
- [ ] 5.1
- [ ] whole-run review

## Deferred

- phase 1: `flutter build apk --debug` requires Android SDK 37 because locked permission_handler_android 14.0.0 exceeds current compileSdk 36; address before final release gate.
- step 1.5: a cycle-2 profile that writes a stamp before any nickname/team patch may still fail current rules because stamp writes do not migrate the removed `profileThemeKey` or add A/auto; outside the user-confirmed backfill-on-write contract, grade M.
