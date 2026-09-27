# Grok original — APEX 2026-09-17 RC-01 through RC-08 implementation plan

- **Author:** Grok (`xai/grok-4.6`), independent first pass
- **Date:** 2026-09-26
- **Status:** original findings (preserve; do not rewrite in later passes)
- **Scope:** research/planning only. This document does not authorize implementation.
- **Governing PRD:** `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` (2026-09-25). Current PRD/router supersede older APEX plans.
- **Release unit:** fresh CREATE3 / registry deployments of corrected source. No migration, live inventory, fork replay, or already-deployed instance work.

## Identity and tool limits

- Researcher identity: Grok, model `xai/grok-4.6`. Continuity: first pass of a new implementation-planning round (not a resume of historical review sessions).
- No peer council originals or cross-reviews were read.
- Tests, forge, shell, deployments, and browsers were not run. Green-test counts in older plans remain unverified claims.
- `glob` failed on broken Crane/LayerZero symlink trees under `lib/crane/`. Targeted `grep`/`read` under `contracts/` and `test/` succeeded.
- One `grep` of `lib/crane/contracts/interfaces/IReentrancyLock.sol` returned `RC_UNAVAILABLE`. A later `read` of `lib/crane/contracts/access/reentrancy/IReentrancyLock.sol` succeeded (`error IsLocked()` at lines 18–23).
- Context7 did not resolve Uniswap Permit2 as a library ID. Permit2 `approve` facts come from Uniswap docs (fetched 2026-09-26). ERC-4626 facts come from Context7 OpenZeppelin ERC4626 plus EIP-4626 (fetched 2026-09-26).

## Observed toolchain (files, not execution)

| Item | Observation |
| --- | --- |
| solc | `foundry.toml` `solc = "0.8.35"`; `via_ir = false`; optimizer on, 1 run |
| profiles | hermetic default `test = test/foundry/spec`; fork profile out of scope |
| cache/out | `cache_path = 'cache_forge'`; `out = 'out'` |
| Forge | `docs/testing/ARTIFACT_BUILDS.md` records Forge 1.5.1 on a prior checkout. Not re-verified here |
| evm_version | no `evm_version` key in `foundry.toml`. Crane `ReentrancyLockRepo` uses transient storage (`tstore`) |

## Accepted product law (do not “fix”)

Facts from the current PRD plus APEX owner clarifications in `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md`:

- **D12 / D28:** a later contract caller may consume declared unbooked credit. Integrator residual, not a defect. No sender attribution.
- **D44:** bytecode check accepts EIP-7702 delegated accounts and contract wallets (`LocalCreditLib.requirePretransferCaller` → `BetterAddress.isContract`).
- **D32:** Aave Cross-Version Loop (`AaveCrossVersionLoopExchangeInTarget.sol:47` reverts `TransferDeltaInsufficient(amountIn, 0)` when `pretransferred`) and `BalancerV3PoolStandardExchangeTarget` (`UnsupportedPoolPretransfer` at line 29) keep rejecting public pretransfer.
- **D6:** protocol residual stays booked. Not paid to `feeTo`. Do not revive `_absorbDustToFeeTo`.
- **Historical Uni V3/V4** under `contracts/protocols/dexes/uniswap/{v3,v4}/` stay inventory. Not the replacement bytecode. Do not edit them for these RCs.
- Slipstream is deprecated (CLAUDE.md / APEX D57). Compilation maintenance only. Not an RC-07 rewrite target.

## Facts vs inference vs speculation

| Kind | Claim |
| --- | --- |
| Fact | Cited production lines match the PRD’s broken-requirement descriptions (re-read below). |
| Fact | `LocalCreditLib.available` already returns `0` on `balance <= booked` (`contracts/utils/LocalCreditLib.sol:13-16`). |
| Fact | Standalone Balancer adapter `_unbookedSurplus` already uses the zero-on-deficit form (`BalancerV3SinglePoolStandardExchange.sol:218-221`) but money entries have no lock and still max-approve. |
| Fact | No `is UniswapV4SingleStandardExchangeBufferConstantProductHookTarget` inheritor under `contracts/`. Installed SE cut is `...HookSeTarget.sol`. |
| Inference | Nested reentry can observe stale `balance - _tokenReserve` before `_syncReserve`. Lasting extraction was not executed. |
| Inference | Nonzero booked aToken is reachable because package init puts `aToken()` in the expected-hold set and full-set sync books it. Not observed on a live proxy. |
| Speculation | Whether a configured Balancer pool token can callback into RC-01. The missing lock does not depend on that proof. |

## Dependency order

1. **RC-07 inventory (read-only, before any `BasicVaultCommon` edit).**
2. **RC-04 comments** — no bytecode coupling; can proceed in parallel once RC-01’s line-262 comment is reserved to the RC-01 edit.
3. **RC-01** (adapter lock + exact approve). Independent of 02/03/05/06/08.
4. **RC-02** (exact local-first payout). Orbital face assertion depends on RC-02 production behavior; RC-06 can share the same orbital suite.
5. **RC-03** (Stata backing includes booked aToken). Independent of RC-02 except shared ERC-4626 TestBases.
6. **RC-05** (delete unused hook `exchangeOut`). Independent. Do not recut.
7. **RC-06** (truthful orbital return). After or with RC-02 if the same ERC-4626 SE fixture is reused.
8. **RC-07 production edit** only after the inventory below is in the implementer notes.
9. **RC-08** named Uni V2 backing error. Independent.
10. **Artifact refresh + red/green** per touch set. Hermetic only.

Do not serialize comment-only RC-04 behind money fixes except the Balancer “(M3)” comment, which ships with RC-01.

## Artifact freshness (mandatory after production edits)

FactoryServices load creation bytecode from `out/` (`CLAUDE.md` item 10; `docs/testing/ARTIFACT_BUILDS.md`). `forge test` alone can deploy stale bytecode.

```bash
python3 scripts/forge-artifacts.py test <edited-source.sol> \
  --test-root <suite-file-or-directory> -- -vv
```

Repeat `--test-root` for several suites. Do not change `FOUNDRY_TEST`, do not enable `via_ir`, do not delete `out/` or `cache_forge/`. Seed both dirs in a new worktree before first compile. `via_ir` remains forbidden.

---

## RC-01 — Standalone Balancer adapter reentrancy + exact approve

**Severity:** Medium (PRD). Guard required even without a demonstrated booked-inventory extraction.

**Current (fact):** `BalancerV3SinglePoolStandardExchange` inherits only `IStandardExchange` (line 22). `exchangeIn` 69–107 and `exchangeOut` 131–196 credit input, then `_approvePermit2ToRouter` grants `type(uint256).max` ERC-20 and `type(uint160).max` / `type(uint48).max` Permit2 allowances (262–276), then call the router, then `_syncReserve`. Until sync, unbooked credit is `balance - _tokenReserve`. Comment at 262 still says “Infinite approve … (M3)”. `_unbookedSurplus` is already zero-on-deficit.

Sibling D16 money routes (Uni V2 In/Out, ERC-4626 In/Out) take `ReentrancyLockModifiers.nonReentrant`. Crane lock is transient (`ReentrancyLockRepo`, slot `crane.access.reentrancy.lock`) and is valid on this non-diamond CREATE3 adapter. Downstream router lock is not a substitute (PRD non-goal).

**Design (required):**

1. Inherit `ReentrancyLockModifiers`. Mark `exchangeIn` and `exchangeOut` `nonReentrant` from the first credit through approval reset, router return, refund, payout, and `_syncReserve`.
2. `_approvePermit2ToRouter(token, amount)`: `forceApprove(router, amount)`, `forceApprove(permit2, amount)`, `IAllowanceTransfer.approve(token, router, uint160(amount), expiration)`. `amount == 0` already clears ERC-20 and Permit2 (expiration `0` expires at `block.timestamp` per Uniswap AllowanceTransfer docs, accessed 2026-09-26). Do not add `try/catch`.
3. If `amount > type(uint160).max`, revert rather than silent downcast (Permit2 amounts are `uint160`; `type(uint160).max` is unlimited).
4. Nested entry must revert `IReentrancyLock.IsLocked()`. Outer revert rolls back allowances (EVM, not catch-and-clear).
5. Do not add D12 sender attribution. Do not enable D32 public pretransfer.

**Touch set:** `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol` only (plus tests).

**Tests (extend):** `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol`. Existing coverage: I1 skip-pull, E6 refund, leftover-approval-after-return (`_assertNoMaxAllowances`). Missing: reentry during funding, approval, or router call.

| Case | Fixture | Red (current) | Green (after) |
| --- | --- | --- | --- |
| C-reentry `exchangeIn` and `exchangeOut` | Callback-capable ERC-20 as a **configured pool token** on the production CREATE3 adapter (`create3Factory.create3WithArgs` + `ArtifactCreationCode`, same as `_deployAdapter`). Hostile token is a fixture, not a mock of the adapter | Nested second money entry succeeds **or** is not attempted; test must fail if nested call succeeds | `reentryAttempts == 1`, `nestedCallSucceeded == false`, selector `IsLocked()`; outer success: router and Permit2 allowances `0`, `_tokenReserve` equals post-settlement `balanceOf`; outer revert: booked reserves and caller balances unchanged |
| Negative control | Ordinary DAI/USDC 80/20 pool (existing suite) | n/a | Quoted deltas still complete; allowances `0` |

Catalog IDs: **C**, **M3**, **E6**. Do not claim a booked-inventory extraction PoC.

---

## RC-02 — ERC-4626 local-first payout exactness

**Current (fact):** `_payUnderlyingLocalFirst` (`ERC4626StandardExchangeCommon.sol:80-92`) does `vault.redeem(vault.previewWithdraw(shortfall), recipient, address(this))` and accepts `got >= shortfall`. Callers: OutTarget 108–115, InTarget 144–151. Orbital `_unwrapExactTokenOut` (`UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-565`) checks `balance delta >= amountOut` then assigns `seIn = maxIn`.

**External law (2026-09-26):** EIP-4626 `withdraw` “sends exactly `assets`”. `redeem` burns exact shares and sends `previewRedeem` assets (floor). OpenZeppelin ERC4626: `previewWithdraw` Ceil, `withdraw` pays exact assets; `redeem` may pay more than a Ceil-share shortfall if the vault over-delivers relative to `shortfall`. That is the defect.

**Design (required):** replace the redeem-of-preview with **`vault.withdraw(shortfall, recipient, address(this))`**. That is the PRD-allowed exact-asset withdrawal. Share charge matches `previewWithdraw`. An exact-asset withdrawal is **not** required to create a remainder. If a non-compliant vault cannot `withdraw` exactly, do not invent `feeTo` absorption. Do not reintroduce exact-input refunds. Stata `_payUnderlying` already uses `stata_.withdraw(shortfall, to_, address(this))` (`AaveV3StataStandardExchangeCommon.sol:87-96`) — leave that path, keep it as the pattern.

**Touch set:** `ERC4626StandardExchangeCommon.sol` (`_payUnderlyingLocalFirst`); no fee/oracle changes. Orbital assertion is test-only unless RC-06 edits the same unwrap.

**Tests:** extend `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol` (`test_APEX_R14_exits_localFirst_receiptOutNeedsReceipts` currently uses `assertApproxEqRel` / `assertApproxEqAbs`, not exact recipient delta).

| Case | Fixture | Assertions |
| --- | --- | --- |
| Non-unit receipt rate | `SimpleYieldERC4626` + `simulateYield` as protocol vault (non-SUT harness), registry-deployed ERC-4626 SE | Recipient underlying delta **equals** accounted due; exact-in return **equals** that delta; leftover local + receipts booked on SE; `feeTo` unchanged |
| Mixed local + shortfall | Seed booked local cash, then exit more than local | Local spent first; `withdraw` shortfall exact; receipts decrease by preview shares, not more |
| Orbital capped unwrap | `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeMatrix_ERC4626StandardExchange.t.sol` (or Surface) | Successful swap leaves no **operation-created** face above opening balance on a non-identity buffered leg. Pre-existing D12 resting face accounted separately and not paid by an unrelated pull-funded op |

Red: current `redeem` + `>= shortfall` can pay recipient `> due` on a non-unit vault. Green: exact due.

---

## RC-03 — Stata backing must include booked aToken (mandatory)

**Current (fact):** `_stataBacking` (`AaveV3StataStandardExchangeCommon.sol:52-58`) is `held Stata + convertToShares(booked underlying)` only. `_totalReceiptBacking` (`ReceiptBackedERC4626Target.sol:183-198`) also adds `_bookedATokenEquiv`: sum of `_reserveOfToken` for expected-hold tokens that are neither receipt nor underlying. Package init (`AaveV3StataStandardExchangeDFPkg.sol:245-258`) registers `aToken()` when present. `BasicVaultCommon._syncAllExpectedHoldReserves` (43–50) books that balance.

D45 / R14 already require one local-plus-receipt backing calculation. **Exclusion is not an implementer choice.**

**Design:** make `_stataBacking` use the same booked-aToken term as the adapter. Preferred: a single internal helper (on the Stata common or a tiny shared lib used by both) that returns `convertToShares(booked underlying + booked aToken-as-underlying-equiv)` plus held Stata, matching `ReceiptBackedERC4626AccountingLib.receiptUnits`. If aToken is absent from `_vaultTokens()`, the helper contributes **zero**. Do not read `aToken.balanceOf` outside the expected-hold book. Do not invent a second share ledger. Do not change `_collectAndForwardRewards` (182–198). Do not treat an unsolicited aToken transfer as depositor-attributed; it becomes book at end-of-route sync and prices **all** shares.

**Touch set:** `AaveV3StataStandardExchangeCommon.sol`; `ReceiptBackedERC4626Target.sol` only if extracting a shared helper. Not DFPkg init unless aToken registration is already missing (it is present).

**Tests:** `ReceiptBackedERC4626_SharedFacet.t.sol` (today: marker dispatch + aToken **slot** present, no funded book compare) and `AaveV3StataStandardExchange_APEX_R14.t.sol` (today: supply-cap booking of **underlying**, not aToken).

| Case | Setup | Assertions |
| --- | --- | --- |
| Funded aToken book | Production Stata proxy (`TestBase_AaveV3StataStandardExchange_Decimals`). Transfer aToken onto the proxy, then one honest money route so full-set sync books it | `IERC4626.convertToShares` / `previewDeposit` / `previewRedeem` / SE `previewExchangeIn` / `previewExchangeOut` / one live exchange agree on the **same** backing. Later depositor is not priced on the smaller (Stata-only) basis |
| Generic ERC-4626 | existing `gSe` | still no aToken term (`vaultTokens` has no aToken) |
| Fees / receipt limits | existing R14.18 fee matrix | unchanged |

---

## RC-04 — Stale security comments (comment-only)

**Touch set (exact):**

- `ERC4626StandardExchangeOutTarget.sol:17-20` — still sends residual dust to `feeTo`. Executable body does not.
- `ERC4626StandardExchangeCommon.sol:201-211` (`_securePull` NatSpec still says pull overshoot is refunded) and `277-281` (`_burnSeShares` leftover free shares refunded to owner). Bodies: exact pull-delta, exact self-share burn, no leftover refund.
- `ERC4626StandardExchangeInTarget.sol:126` — “Pull overshoot already refunded”.
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32-38` — exact-in surplus revert / V3 quote-buffer pull / V4 pull-max / dual-exit pull-max shares. Current law: no exact-input refund; exact pull-delta equality; exact self-share burn; exact-out refund capped at `credit - used`; dust retained as book; false-flag exact-out pulls quoted used (D15/D17/D28).
- Balancer line 262 ships with **RC-01**, not as a second edit.

**Non-goals:** do not change FullSpread pull code; do not edit preserved Uni V3/V4 source; no executable refund/fee/pull change solely to match comments.

**Tests:** no new money test. Re-run `ERC4626StandardExchange_APEX_R14.t.sol` and one FullSpread exact-out suite, e.g. `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/remediation/UniswapV3FullSpreadStandardExchangeVault_Delivery.t.sol` (or V4 Delivery / V3 `PretransferParity`). Record that cited lines no longer describe pull-max, overshoot refund, leftover-share refund, or dust-to-fee.

---

## RC-05 — Unused single-CP HookTarget `exchangeOut`

**Current (fact):** abstract `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget` (header: “Legacy monomorph… Does **not** implement `IHook`”). `exchangeOut` 736–754 refunds `maxAmountIn - amountIn` on true flag, no `LocalCreditLib`, no `requirePretransferCaller`. Installed cut: `...HookSeTarget.sol:836-877` uses `_pullExactOutInput` (D15). Repository search found no inheritor.

**Implementer choice:** delete **or** thin wrapper through the installed guarded helper. **Recommendation: delete** the unused `exchangeOut` (and only that function unless a follow-up explicitly expands). No inheritor; recut forbidden; a second public `maxAmountIn - amountIn` refund must not remain.

**Touch set:** that HookTarget file only. Do not recut facets/DFPkg. Do not change SeTarget behavior.

**Tests:** `UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol` still green. Source search: no second public `exchangeOut` with unguarded `maxAmountIn - amountIn` refund. Installed selectors unchanged.

---

## RC-06 — Orbital capped unwrap return

**Current (fact):** after `exchangeOut`, line 565 assigns `seIn = maxIn` (approval cap), discarding the SE return. Commenters note current callers ignore it.

**Implementer choice:** truthful return **or** remove unused return and update callers. **Recommendation: keep the return; assign `seIn = IStandardExchangeOut(se).exchangeOut(...)`.** That is the shares the SE pulled. Alternative: share-balance delta around the call. Do not turn the call into a surplus-creating unwrap. Do not pay unused share cap. Keep approve-to-cap and approve-back-to-zero (558–563). Short SE delivery still reverts `InsufficientTokenOut` (564).

**Touch set:** `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-565`. Callers in SeTarget / WithdrawTarget only if the signature changes (not needed if return stays).

**Tests:** existing orbital unwrap or `UniswapV4StandardExchangeOrbitalBufferHook_Surface.t.sol` / ERC-4626 SeMatrix. If return remains: assert returned share count equals SE share-balance delta around the call. If removed: same unwrap still pays quoted token amount and clears SE allowance.

---

## RC-07 — Shared availability math; inventory before edit

### Historical-consumer inventory (required before any base-helper edit)

**`_unbookedSurplus` definitions (production):**

| Location | Behavior |
| --- | --- |
| `BasicVaultCommon.sol:33-36` | checked `balance - booked` → panic on deficit |
| `BalancerV3SinglePoolStandardExchange.sol:218-221` | already `balance > reserve ? balance - reserve : 0` |

**Production inheritors of `BasicVaultCommon`:**

| Consumer | `_secureTokenTransfer` | `_refundExcess` / `_unbookedSurplus` | D16? |
| --- | --- | --- | --- |
| `UniswapV2StandardExchangeCommon.sol` | overrides with `LocalCreditLib.available` + `requirePretransferCaller` (420–448) | inherits base `_refundExcess` | yes |
| `CamelotV2StandardExchangeCommon.sol` | same override (158–186) | inherits base `_refundExcess` | yes |
| `AerodromeStandardExchangeCommon.sol` | same override (946–974) | Common + `AerodromeStandardExchangeOutExecuteTarget` call `_refundExcess` | yes |
| `AaveV3StataStandardExchangeCommon.sol` | same override (200+) | uses `_bookedReserve` / `LocalCreditLib` on pull | yes |

**Do not edit (not `BasicVaultCommon` heirs, or out of scope):**

- Preserved `contracts/protocols/dexes/uniswap/{v3,v4}/` (own `_secureTokenTransfer`; historical source).
- FullSpread V3/V4 commons (own pull/refund; replacement source, not this helper).
- Slipstream (own pull; deprecated).
- DETF `RebasingDETFTokenTarget` / `ComposedStableCommonDetfCommon` (own `_secureTokenTransfer`, not this base).
- ERC-4626 `_refundExcess` is a different function (unconditional transfer of `excess`).

**Test-only heirs:** `test/foundry/spec/vaults/basic/BasicVaultCommon_*.t.sol` and fork Permit2 variants. Expect panic→zero-credit if they call the base helper.

**D16 public entries that already cannot reach the unguarded base pull:** Uni V2 / Camelot / Aerodrome / Stata `exchangeIn`/`exchangeOut` (and Stata prepaid) go through the overrides above. Name these in the test NatSpec.

### Design

1. Change `BasicVaultCommon._unbookedSurplus` to `LocalCreditLib.available(balance, booked)` so D16 `_refundExcess` returns **zero** credit on deficit and never panics `0x11` (Solidity 0.8 checked underflow; docs.soliditylang.org v0.8.37, accessed 2026-09-26).
2. Base `_secureTokenTransfer` pretransfer branch (97–98) still does `U = B0 - R`. Either (a) add `requirePretransferCaller` and use `LocalCreditLib.available` there too, or (b) prove every D16 public entry cannot reach it. **Recommendation: (a)+named tests**, because NatSpec already delegates the caller check and the four production heirs override anyway. Do not mechanically replace every historical caller outside this set.
3. Opaque panic replaced on D16 paths by zero-credit, then `TransferDeltaInsufficient` when the caller requests more than zero.

**Touch set:** `BasicVaultCommon.sol` only for the helper. Do not touch preserved Uni trees.

**Tests:** existing Uni V2 / Camelot / Aerodrome secure-pull suites plus a direct helper test only if no production route can create `balance < book`.

| Case | Assertions |
| --- | --- |
| D16 refund/credit with `balance < book` | authorizes 0 new credit; does not pay booked inventory; `TransferDeltaInsufficient` if requested `> 0`; **not** arithmetic panic |
| EOA `pretransferred=true` on named public entries | `EOAPretransferNotAllowed()` |
| Happy exact-in / exact-out from same prepared state | beside every rejection |

---

## RC-08 — Uni V2 zap-out named backing error

**Current (fact):** `UniswapV2StandardExchangeOutTarget.sol:578-580` `if (pool.balanceOf(this) < vault.vaultLpReserve) revert();` after refund, before `_syncAllExpectedHoldReserves`. Comparison stays.

**Design:** named error carrying **both** compared values, e.g. `ZapOutLpBackingInsufficient(uint256 balance, uint256 vaultLpReserve)` on the OutTarget (or a Uni V2 errors interface). Do **not** reuse `TransferDeltaInsufficient` (wrong meaning). Do not weaken the comparison. Do not change refund amounts. Do not invent an owner gate.

**Reachability (inference):** zap-out pulls via overridden `_secureTokenTransfer` (unbooked-only). If only unbooked LP is burned, remaining LP should be `>=` booked reserve, so the branch may be **unreachable** without mocking the vault or writing storage.

**Attempted preconditions to record in NatSpec (then execute if possible):**

1. Honest join books LP; zap-out exact-out of unbooked LP only — expect success, reserve intact.
2. Fat `max` + transfer only `used` + booked `R` (E6) — refund unused inbound, not `R`.
3. Donate LP without sync, then zap — unbooked donation may be consumed as D12 credit; not this check.
4. Any supported sequence that reduces LP below `vaultLpReserve` **without** `vm.store` / mock SUT.

If none reach the branch: document that attempt; **still ship the named-error edit**; assert the production check (same comparison) reverts the named error when a future supported route hits it. A focused production-check test that compiles the error and keeps successful zap-out green is the allowed evidence fallback. Do not hold the edit.

**Tests:** `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol`. Success control: existing zap-out still passes; LP reserve unchanged on the failure path if reached.

---

## Shared test rules

- Production TestBases and registry/CREATE3 deploy. No mock of vault, hook, adapter, manager, registry, fee oracle, DFPkg.
- Callback token / non-unit ERC-4626 / mintable aToken = fixtures, not SUT mocks.
- Same assertion red then green. Do not loosen amounts.
- Exact-in and exact-out controls from the same prepared state beside every rejection.
- Assert balances, reserves, allowances, named errors — not “did not revert”.
- Hermetic profile only. No live RPC, no fork of an already-deployed instance, no `via_ir`.
- Matcher hygiene: `--match-contract` / unique names; do not treat colliding `test_C*` extras as this WP.

## Acceptance gates

| ID | Gate |
| --- | --- |
| RC-01 | nested money entry blocked on production adapter; allowances 0 on success; full rollback on revert; no-callback control green |
| RC-02 | recipient delta == accounted due; exact-in return == delta; remainder booked not `feeTo`; orbital no new face |
| RC-03 | adapter and SE quotes identical with nonzero booked aToken; generic mode has no aToken term |
| RC-04 | cited comments/README match D6/D15/D17; existing R14 + one FullSpread suite green |
| RC-05 | unused unguarded `exchangeOut` gone or guarded; surface selectors unchanged |
| RC-06 | return == shares pulled **or** return removed and callers updated; allowance cleared |
| RC-07 | inventory recorded; D16 deficit → 0 credit / named insufficient-credit; no panic; EOA still rejected on named entries |
| RC-08 | named error with both values; success zap-out green; reachable red/green **or** documented unreachable + focused production-check |
| Law | D12/D28, D44, D32, D6, historical Uni V3/V4 untouched as required |
| Artifacts | `forge-artifacts.py test` after each production edit |

## Evidence gaps

- No Foundry executed this round.
- Callback-capable Balancer pool-token reentry not executed.
- Nonzero booked aToken on a current Stata proxy not chain-read (out of scope; source inconsistency remains).
- RC-08 branch reachability without storage writes not demonstrated.
- FullSpread README still claims 654 tests / 12,288 invariant ops — unverified; do not treat as proof.
- `foundry.toml` has no `evm_version`; transient reentrancy lock assumes Cancun+ (project previously recorded Prague in ARTIFACT_BUILDS). Confirm at implement time.
- DETF_ALIGNMENT D32–D66 are a **different D-number series** from APEX D32. This plan uses APEX D32 (public-pretransfer reject).

## Counterarguments

- **RC-01 High vs Medium:** lasting extraction not shown. Guard still required.
- **RC-02 withdraw vs redeem-to-self-then-transfer:** withdraw is the EIP-4626 exact-asset API and matches Stata. Redeem-to-self would create a remainder that must stay booked; allowed but unnecessary if `withdraw` exists.
- **RC-05 delete vs helper:** delete is smaller and cannot drift. A thin guarded wrapper is allowed if someone prefers ABI stability on dead source; there is no inheritor.
- **RC-06 unused return:** MiniMax-style “not a functional defect” is acknowledged; PRD still requires honest or removed return.
- **RC-07 global helper vs per-heir:** four D16 heirs already override pull; the remaining production bug is `_refundExcess` → `_unbookedSurplus`. Editing the helper is the R9 canonical fix. Historical Uni V3/V4 are not heirs.

## Confidence

- Defect-to-source mapping: **high** (cited lines re-read).
- Test-fixture feasibility (hostile pool token, non-unit 4626, aToken book): **medium** (patterns exist; not executed).
- RC-08 production reachability: **low**.
- Economic soundness of “no lasting extraction” for RC-01: **not proven**; absence of a PoC is not a pass.
