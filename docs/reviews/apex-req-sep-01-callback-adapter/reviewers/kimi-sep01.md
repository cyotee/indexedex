# Kimi K3 — REQ-SEP-01 callback adapter: readiness and exact fix (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Nothing was edited. I did not run Forge.
- **Controlling text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-SEP-01 (`:110-120`, read in full). Current test read this round: `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` — helper `:108-122`, RC-01 test `:492-522`, rollback twin `:524-552`, and every `_assertNoMaxAllowances` call site (`:330, :341, :374, :388, :520`).

## Answer: No blocking question.

The PRD's acceptance criteria are complete and determine the whole change: the zero-allowance assertions must name the adapter that executed the callback route, both allowance families must be zero after success, and the nested-entry lock assertion stays. The only residual is mechanical (how the helper names the owner address), which the plan can fix by naming it — no product, economic, or API decision remains for the owner.

## Verified facts behind the answer

- The exercised instance is `locked_` (`:495` deployed by `_deployProbePool`, `:511` executes the outer `exchangeIn`, `:508` arms the nested attempt against it). The helper at `:108-122` reads allowances with owner `address(adapter)` — the separate fixture set at `:73`. So the M3 cleanup assertions at `:520` measure a contract that never ran the route. The PRD's statement of the gap is accurate.
- The helper has four other call sites (`:330, :341` with `bpt`; `:374, :388` with `dai`). Those tests exercise the fixture `adapter`, so `address(adapter)` is correct for them and their semantics must not change.
- The rollback twin already demonstrates the intended pattern: `:552` asserts `probe.allowance(address(locked_), address(router)) == 0` — naming the exercised instance.
- The helper's six assertions already cover the required surfaces: ERC20 `allowance(owner, router)`, ERC20 `allowance(owner, permit2)`, and the Permit2 packed `allowance(owner, token, router)` uint160 — each checked `!= max` and `== 0` (`:110-122`).

## The exact assertion change (closed; no implementer choice)

1. **Helper signature:** `_assertNoMaxAllowances(IERC20 token_)` → `_assertNoMaxAllowances(IERC20 token_, address owner_)` (`:108`).
2. **Variable:** inside the helper, replace the three reads of `address(adapter)` with `owner_` (`:110`, `:114`, and the Permit2 packed read at `:118`). No assertion content changes: the three `!= type(uint256).max` / `!= type(uint160).max` guards and the three `== 0` resets stay exactly as written.
3. **Call sites:** `:330`, `:341`, `:374`, `:388` pass `address(adapter)` (their exercised fixture — semantics unchanged). `:520` passes `address(locked_)` — this is the fix.
4. **Which allowances (acceptance criterion 2):** after the successful callback route, on owner `address(locked_)`: ERC20 allowance to `address(router)` == 0, ERC20 allowance to `address(permit2)` == 0, and Permit2 packed amount for `(locked_, probe, router)` == 0.
5. **What must not change:** the nested-entry lock assertions (`:514-516` — attempts ran, every nested money entry hit `IsLocked`, no nested success), the in-flight route-budget assertions (`:517-519`), outer success (`:513`) and join-consumed (`:521`) assertions, the rollback twin `:524-552` (already names `locked_`), the helper's `internal view` nature, and every other test in the file. No `catch` is added anywhere; no production file is touched; this gap is not evidence of a production allowance leak (PRD non-goal).

## One-sentence closure for the plan

"Parameterize `_assertNoMaxAllowances` with the allowance-owner address, pass `address(adapter)` at the four fixture call sites and `address(locked_)` at line 520, and leave every assertion's content and every other statement of both RC-01 tests byte-identical."

I did not run Forge.
