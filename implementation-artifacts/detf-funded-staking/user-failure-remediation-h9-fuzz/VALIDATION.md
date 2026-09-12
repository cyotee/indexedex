# H9 partial-burn fuzz regression

The supplied seeds reproduce the original assertion failure in `counterexample-before.log`:
`311507608686055850945166038` and `602087665428321155436574337695299180608222456751846`.
The exchange acquired 57 native DETF units. The old bound selected 6 units, withdrawing 168 native reserve LP units, whose proportional SE-share payout rounded to zero.

The shared decimal fuzz test now derives its minimum burn from the actual reserve SE-share balance, reserve LP supply, protocol LP holdings, and DETF supply. Both inverse conversions round upward, targeting two native SE shares to allow for rated-exit rounding. The result is bounded between that minimum (or 10% of acquired DETF, whichever is larger) and half of the acquired DETF. The test asserts that this interval is valid; it neither rejects inputs nor skips cases. The burn enforces a minimum output of one SE share. Existing positive payout, conservation, exact balance changes, and no-free-inventory checks remain.

The exact seeds are retained in the H9 suite. Four deterministic payment/burn boundary combinations run in all eight decimal suites. The shared conservation fuzz method is configured for 512 runs. Only the two test source files in `changed-files.json` were changed in this follow-up; no production contracts or fixture funding were changed.

## Verification

- Before fix: exact regression reproduced the reported zero-payout failure.
- After fix: H9 regression and four boundary tests passed (`h9-boundaries-after.log`). The exact seeds select 22 native DETF units after the fix.
- Final matrix: 60 tests passed across 9 suites, zero failed or skipped. 12482 total fuzz cases, including 4162 partial-burn cases.
- `forge fmt --check` and `git diff --check` passed for the two edited sources.

Final command:

```sh
forge test --offline --match-contract '^SingleStandardExchangeDETF_Fuzz_(Test|H6|H9|P18_R6|P18_R9|P6_R18|P6_R9|P9_R18|P9_R6)$' --fuzz-runs 512 -vv
```

Full results: `single-fuzz-matrix.log` and `validation.json`. Follow-up-only diff: `remediation.patch`. This was a targeted validation, not a full repository test run.
