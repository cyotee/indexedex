# Focused universal DETF regressions

`SelectedRegression.t.sol` imports the original 15 regression files. It does not replace their production contracts or factory fixtures. The verified selection is 18 suites and 137 tests, including two zero-backing claim regressions. Latest result: 136 passed, one raw/pair preview regression failed, none skipped.

Keep the normal `contracts/` source root. Narrow only the test root, and keep it identical for build and test:

```sh
FOUNDRY_TEST=docs/security/universal-detf-audit/validation forge build
FOUNDRY_TEST=docs/security/universal-detf-audit/validation forge test --fuzz-runs 128 -vvv
```

Do not add match or inverse-match filters to this already bounded selection. In Foundry 1.5.1 a nonempty effective filter triggers a separate ABI discovery compilation of the project before normal compilation. Environment/config filters also count.

The normal default profile, optimizer and non-IR compilation remain in effect. Keep output/cache paths consistent between commands. Build before testing changed production code because factory services load deployment artifacts.

This is an iteration suite, not the full audit or deployment gate. The strict raw/pair deposit preview regression currently records an unresolved overquote; it has not been removed or weakened. See the working report and coverage matrix for outstanding work. The matching-root build recompiled six sources in 123.97 compiler seconds (144.98 wall seconds). The following unfiltered run skipped compilation and completed in 484.08 wall seconds, with 421.42 seconds reported for suite execution. Evidence: `../evidence/focused-harness-latest-build.log` and `../evidence/focused-harness-unfiltered.log`. These observations establish cache reuse and selection completeness; they are not a controlled runtime-speedup benchmark.
