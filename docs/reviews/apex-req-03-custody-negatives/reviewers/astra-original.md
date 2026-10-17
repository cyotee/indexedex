# Astra original — remaining Stage-1 REQ-03 acceptance gaps

**Date:** 2026-10-14 review round. **Status:** Independent review and proposed bounded requirements; not implementation authorization.

**Controlling requirement:** `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:223-235`, read in full. Both named test files and the scanner were re-read in full; the production SY guard and relevant supporting implementations were also read. No peer artifacts were read. The coordinator's new PRD was not written.

## Answer

The ownership bullet is already satisfied in source. The reentrancy bullet remains partial because its nested-error assertions can be converted into the same outer transfer error that the test expects. The minimality bullet has precise rejection and substantial exact success assertions already; the remaining gap is a success-side assertion of total share issuance. The scanner explicitly includes the two custody files without an APEX marker, but full D16 inventory coverage is **unverified**, not a confirmed missing-file finding.

These are assertion/source verdicts, not passing-run claims. No production authorization or accounting defect is asserted.

## Acceptance-bullet verdicts

Abbreviations: `A` = `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol`; `F` = the sibling `RebasingAwareERC4626_Fuzz.t.sol`.

| REQ-03 acceptance bullet | Verdict | Evidence and remaining boundary |
|---|---|---|
| Allowed contract caller, precise share-accounting error, other holder unchanged | **already satisfied** | `A:50-60` deploys `AtomicPretransferCaller`, uses its address as caller, expects exact `TransferDeltaInsufficient` data, and checks Alice's shares and the reserve unchanged. The production guard at `RebasingAwareStandardYieldTarget.sol:57-59` still rejects code-less external internal-balance callers. No new requirement for this bullet. |
| Nested-guard error and no partial credit | **partial** | `A:28-32` checks the nested result inside the callback, but then unconditionally reverts. `A:140` expects only the outer `TransferFromFailed`. `A:143-146` already checks supply, recipient shares, vault assets, and reserve unchanged. The still-open portion is an independent, non-masked nested-guard oracle and proof that the callback was reached. |
| Minimality: exact rejection plus unchanged state; exact success shares/balances/reserves | **partial** | Rejection is already satisfied at `F:64-84`: exact `MaxAmountExceeded` data and unchanged shares, total supply, assets, reserve. Success at `F:96-100` already asserts exact return, Alice shares, caller/vault asset balances, and reserve. It does not assert total supply after success, although `supplyBefore` is captured at 65. Only that total-issuance gap is proposed below. |
| Scanner selects full D16 R2.4 regression inventory, including unmarked custody files | **partial — full-inventory sub-bullet unverified** | `scripts/apex_bare_expectrevert_scan.sh:18-23` explicitly includes both custody files independently of markers. Other selection remains two roots plus the APEX-content filter at 14-17 and 24-26. Neither the REQ-03 paragraph nor that script defines an authoritative exhaustive file/test inventory. Do not infer missing filenames or reopen the fixed custody inclusion. |

## Astra-REQ03-1 — Make the nested-guard assertion survive outer error normalization

- **Severity:** Medium, matching REQ-03's false-positive-security-coverage severity.
- **File and line:** `A:26-32,128-146`; supporting `contracts/test/stubs/ReentrantERC20Harness.sol:58-75`; `lib/crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol:241-252`.
- **Intended behavior:** REQ-03 line 232 requires the reentrancy test to expect the nested-guard error and assert no partial credit. Line 227 requires reaching the property named by the test.
- **Observed facts:** The observer asserts a failed nested call and exact `IsLocked`, then itself reverts `IsLocked`. The token propagates any observer failure. The safe-transfer implementation replaces a failing token call with `TransferFromFailed`; this is the error expected by the outer test. The production pull reaches that wrapper at `RebasingAwareERC4626Common.sol:274-278`, through `BetterSafeERC20.sol:48-50` and `lib/crane/contracts/utils/SafeERC20.sol:38-39`.
- **Broken requirement / impact class:** The required nested-error oracle is inside a reverted dependency frame whose failures are normalized into the expected outer error. This permits false-positive reentrancy coverage rather than establishing the exact rejection cause.
- **Inference:** Under native reverting-assertion semantics, a wrong nested result can fail an observer assertion yet still produce the outer error expected by this test. An unrelated token failure before the observer can likewise satisfy the outer error and rollback assertions. This was not executed here; it is not a claim that the production guard is absent.
- **Fix direction:** Observe callback occurrence and exact nested result in a way that the outer transfer-error conversion cannot erase or turn into success. Assert that observation from an independently evaluated test context. Keep the existing whole-operation rollback/no-partial-credit assertions. A separate observation control and rollback control are acceptable if the first genuinely witnesses the same production guard.
- **Confidence:** High on the source's normalization path and missing independent observation; runtime behavior of the installed Forge binary was not replayed.

### Proposed acceptance criteria

1. Exercise the registry-deployed production vault with the existing non-SUT callback-capable funding fixture; do not mock or replace the vault.
2. Establish that the nested money entry was actually attempted during the production funding call and was rejected with the exact `IReentrancyLock.IsLocked` error.
3. Evaluate that evidence outside the failure path that becomes `TransferFromFailed`, or use a verified observation mechanism whose failure cannot be swallowed by that conversion. An unconditional observer revert plus an outer transfer-error expectation is not sufficient.
4. An absent callback, successful nested entry, or different nested rejection must cause the test to fail, even if the outer operation ultimately reverts with the usual transfer error.
5. Preserve the existing no-partial-credit assertions for supply, recipient shares, vault asset balance, and reserve on the rollback path. Keep the actual outer transfer error where that is the production API behavior; do not force production to expose a nested selector it intentionally wraps.
6. Correct the comment at `A:26-27` so it no longer implies that an assertion inside the normalized failing frame independently certifies the guard.

**Non-goals:** No production reentrancy/transfer-library rewrite, new public vault selector, weakened bytecode check, broader `expectRevert()`, new attack scenario, or replacement of the SUT. Do not remove already-correct rollback assertions.

### Assertion-semantics evidence

`remappings.txt:1` selects the local Forge standard library. Its `StdAssertions.sol:91-94,273-274` uses native `vm.assertFalse`/`vm.assertEq`. The repository `foundry.toml` search found no `assertions_revert` override. Context7's Foundry reference documents native `assertions_revert = true` as the default. The primary Foundry implementation's `handle_assertion_result_mono` returns an error when this setting is enabled and sets the global failure storage flag only in the alternative mode:

- https://github.com/foundry-rs/book/blob/master/src/pages/config/reference/default-config.mdx
- https://github.com/foundry-rs/foundry/blob/master/crates/cheatcodes/src/test/assert.rs

These external references are documentation/source evidence, not proof of the exact installed binary or environment overrides. No proprietary source or environment values were sent externally. The proposed requirement avoids depending on a swallowed assertion regardless of runner configuration.

## Astra-REQ03-2 — Complete the minimality success oracle with total issuance

- **Severity:** Medium, inherited from REQ-03; impact is limited to test coverage, not a demonstrated excess mint.
- **File and line:** `F:65,85-100`.
- **Intended behavior:** REQ-03 line 233 requires exact shares, balances, and reserves on success, as well as unchanged state on rejection.
- **Observed facts:** The rejection checks total supply at 81. The success half checks the recipient's shares at 97 and exact assets/reserve at 98-100, but does not check total supply. Production exact-output minting routes through `RebasingAwareStandardExchangeTarget.sol:114-115` to `RebasingAwareERC4626Common.sol:370-396`, which mints the requested shares to the receiver at 392.
- **Broken requirement / impact class:** Exact issuance coverage is incomplete: correct recipient credit does not constrain additional issuance elsewhere.
- **Inference:** An extra mint to another account could escape this success oracle while all current recipient/asset/reserve assertions still match. No such production defect is claimed.
- **Fix direction:** Add an exact success-side total-supply delta assertion relative to the captured pre-operation supply and requested shares. Preserve the already-correct error and accounting checks; do not rewrite the test as though it only checked a return value.
- **Confidence:** High.

### Proposed acceptance criteria

1. After the successful exact-output call from the restored prepared state, total supply equals the captured supply plus the requested shares, alongside the existing exact recipient-share, payment, vault-asset, and reserve assertions.
2. Retain the exact `MaxAmountExceeded` rejection and every existing unchanged-state assertion in the rejection half.
3. Preserve the current fresh-vault fixture and fuzz domain unless a separately demonstrated test problem requires otherwise. The current absolute recipient-share assertion is consistent with the initially empty vault deployed in `TestBase_RebasingAwareERC4626.sol:62-74`; no nonempty-holder scenario is required by this repair.

**Non-goals:** No new fee policy, production mint changes, broader fuzz campaign, unrelated holder enumeration, weaker error expectation, or replacement of the production proxy. Do not add duplicate requirements for the exact caller/vault asset and reserve checks already present.

## Scanner inventory: evidence needed, not an invented repair list

The known custody-selection omission is fixed. The scanner explicitly includes `A` and `F`; the content filter is not their inclusion gate. Its bare-expectation matching and nonzero check exit remain visible at `scripts/apex_bare_expectrevert_scan.sh:27-46`.

Full D16 coverage cannot be established from the cited REQ-03 paragraph and script alone. **No missing-file finding or unconditional scanner rewrite is proposed.** The needed authority is a current approved D16 regression inventory mapping the R2.4 acceptance criterion to concrete test files/suites, including later scope withdrawals. The locked audit implementation plan `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` is the starting document: its Step 1 at 240-245 requires the package/surface and suite inventory, and its R2.4 acceptance statement at 472 specifies precise negative and exact positive assertions. Family scope alone is not a complete file manifest.

A later closure session should cite that authoritative inventory or obtain its approved current mapping, then compare it with the scanner's selected paths. Only actual uncovered in-scope entries justify a bounded scanner change. Until then, the full-inventory sub-bullet remains unverified, not satisfied and not demonstrably violated.

## Already-satisfied portions and boundaries

- Ownership test `A:50-60`: no new repair proposed. It uses a contract caller, pins the share-accounting error, and preserves the other holder's shares. Production `takeShares` at `RebasingAwareERC4626Common.sol:321-325` supplies that precise insufficient vault-held-share error.
- Production bytecode guard `RebasingAwareStandardYieldTarget.sol:57-59`: leave unchanged. The test must reach share accounting by using the permitted caller, not by bypassing this guard.
- Reentrancy rollback checks `A:143-146`: retain; the gap is error observation, not absence of these state checks.
- Minimality rejection `F:70-84` and success recipient/assets/reserve checks `F:96-100`: retain; their exact assertions are already present.
- Scanner custody inclusion `scripts/apex_bare_expectrevert_scan.sh:18-23`: retain; it no longer depends on an APEX marker.

No supplied-path read failed. No shell, tests, build, scanner execution, deployment, or peer review occurred. This review does not certify runtime passes, and it does not reopen adjacent comment or product-law issues outside REQ-03. Only the assigned reviewer Markdown was written.

I did not run Forge.
