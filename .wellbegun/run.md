---
mode: companion
cycle: 3
---

- [x] 1.1 verified (fresh, high-tier) — commit `4c094bb`; boundary tests: Flutter 58 pass, Firebase 71 pass; probes: 0 written, 0 committed; findings: downstream profileThemeKey compile migration belongs to steps 2.1/2.2
- [x] 1.2 verified (fresh, high-tier) — commit `e8e5d5f`; round 1 REJECT: surfaceContainer roles escaped named surface → fixed in production; round 2 pass; probes: 4 written, 0 committed; findings: AppThemeScope/root propagation owned by step 3.1
- [x] 1.3 verified (fresh, high-tier) — commit `665029b`; boundary tests 4 pass + hooks/analyze; probes: 0 written, 0 committed; findings: Step 2 must map ThemeMode.system sentinel to KST auto
- [x] 1.4 verified (basic, mid-tier) — core.hooksPath restored; four enforcement checks exit 0
- [x] 1.5 verified (basic, mid-tier) — commit `4c094bb` (overlapping profile-schema hunk shared with 1.1); boundary tests: Flutter 14 pass, Firebase matrix 7 pass; implementation finding: actual pre-cycle-3 `profileThemeKey` survived A/auto backfill and failed Firestore `hasOnly` → transaction now removes it and both matrices use the historical shape; full regression observed: Flutter 960 pass, Firebase 78 pass; superseded fresh-verifier probes remain uncommitted and preserved; outside-contract legacy stamp-before-profile-patch deferred
- [x] phase 1 integration verified (fresh, high-tier) — round 1 unbuildable fixed, round 2 fake shim fixed, round 3 exposed legacy patch rejection → Step 1.5 split and verified, round 4 pass; targeted Flutter 48 pass, full Firebase 80 pass, design analyze/pre-commit/diff-check pass; probes: 2 written, 0 committed (retained); findings: untouched legacy first-stamp failure confirmed outside the explicit nickname/team contract and deferred
- [x] 2.1 verified (fresh, high-tier) — commit `ccd7162`; boundary tests 56 pass; full Flutter regression 971 pass, 1 skip; probes: 1 written (`test/features/team_select/cycle3_no_team_fresh_probe_test.dart`, 4 pass), 0 committed and retained; findings: rendered B-family restoration belongs to Step 3.1 global-theme seam
- [x] 2.2 verified (basic, mid-tier) — commits `85e19f5`, `47f74f5`, `0f17206`, `eb10743`; boundary tests 3 pass; targeted analyze exit 0; integration-owned fixes: automatic-brightness timer lifecycle, post-splash profile subscription, revision-gated optimistic settings; no per-step fresh verifier by S/M policy
- [x] phase 2 integration accepted at round cap by user — round 1: Step 2.2 pending-family choice cleared by unrelated team-clear snapshot, allowing older B to override latest A → fixed in `eb10743`; round 2: slow optimistic LG selection overwritten to null by a B-setting profile snapshot → Step 2.1 fixed in `b9bcc55` + onboarding convergence regression fixed in `0393860`; conductor boundary/probes: 78 pass; full Flutter before round 3: 982 pass, 1 skip; round 3 REJECT accepted open: account A's old in-flight light write can overwrite A's later successful dark write after A→B→A because the settings queue resets on owner change (owner Step 2.2, deferred); verifier boundary 59 pass, targeted analyze clean, full Flutter with new probe 984 pass, 1 skip, 1 fail; probes: 3 written (`cycle3_phase2_fresh_r1_probe_test.dart`, `cycle3_phase2_fresh_journey_probe_test.dart`, `cycle3_phase2_round3_independent_probe_test.dart`), 0 committed and retained
- [x] 3.1 verified (fresh, high-tier) — commit `741df13`; boundary tests 9 pass; full Flutter 985 pass, 1 skip, 1 known accepted-deferred Phase 2 probe failure; verifier round 1 ACCEPT; probes: 1 written (`test/cycle3_step3_1_independent_probe_test.dart`), 0 committed and retained; outside-contract fixed palette in `PlaceDetailSheet` attached to Step 3.2
- [x] 3.2 verified (basic, mid-tier) — commit `121483d`; targeted analyze and hardcoded/registry hooks pass; feature/shared boundary 584 pass with 1 known accepted-deferred Phase 2 probe failure; conductor full Flutter 987 pass, 1 skip, same single deferred failure; no fresh verifier by S/M policy
- [>] 3.3 implementing — fresh high-tier implementer; split by user decision after Phase 3 integration round 5 exposed destination `TeamThemeScope` overriding the global accent
- [ ] phase 3 integration — rounds 1–5 before Step 3.3 split: light-palette dark-surface text fixed in `fa11636`; dark TeamSelect/LocationConsent/ScratchCard and KT nav contrast fixed in `a9b1e13`; NC dark `DdayHeader` contrast fixed in `f1194bd`; non-splash sign-in/home AppBar role leaks fixed in `9bfa91e`; round 5 found destination `TeamThemeScope` overriding global accent in the actual recommendation→stadium route and was split into Step 3.3 by user decision; restart with a new fresh high-tier verifier after Step 3.3 passes; retained uncommitted probes: 5
- [ ] 4.1
- [ ] 4.2
- [ ] phase 4 integration
- [ ] 5.1
- [ ] whole-run review

## Deferred

- phase 1: `flutter build apk --debug` requires Android SDK 37 because locked permission_handler_android 14.0.0 exceeds current compileSdk 36; address before final release gate.
- step 1.5: a cycle-2 profile that writes a stamp before any nickname/team patch may still fail current rules because stamp writes do not migrate the removed `profileThemeKey` or add A/auto; outside the user-confirmed backfill-on-write contract, grade M.
- phase 2 / step 2.2: after account A starts a slow theme-setting write, switching to B and back to A resets the settings queue; A's older write can then finish after and overwrite A's newer successful setting. User accepted this open at the round-3 cap.
