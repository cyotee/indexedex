# Implementation plan — APEX 2026-09-17 remediation council (RC-01..08)

- **Author:** Kimi K3 (independent first pass, round 2026-09-26). Original; do not rewrite.
- **Status:** DRAFT plan. Writing this plan does not authorize implementation.
- **Requirements source:** `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` (2026-09-25, final clarity pass). Current PRD supersedes older narratives.
- **Router/law:** `CLAUDE.md`; `foundry.toml`; `.claude/skills/indexedex-adversarial-testing/SKILL.md`; `lib/crane/.claude/skills/crane-adversarial-testing/` (referenced by the local skill).
- **Observed toolchain:** solc `0.8.35` (`foundry.toml:29`), optimizer `runs = 1` (`foundry.toml:34`), `via_ir = false` (`foundry.toml:36`), hermetic test root `test/foundry/spec` (`foundry.toml:11`), fuzz/invariant runs 16 (`foundry.toml:40-45`). `pragma solidity ^0.8.0` in all touched sources. Installed forge runtime version not observed (no shell run permitted).

## Global execution law (applies to every RC)

1. Fresh deployments only. No live-instance inventory, migration, fork replay, or registry disablement (PRD L55).
2. Production-first tests on the real deploy path (CREATE3 FactoryServices; DFPkgs via IndexedEx manager vault registry). No mocks of SUT. Callback-capable token fixtures and non-unit ERC-4626 stubs are fixtures, not SUT mocks (PRD L226).
3. `forge build` before `forge test`; after each production edit use `python3 scripts/forge-artifacts.py test <edited-source.sol> --test-root <suite>` (CLAUDE.md L61).
4. Hermetic profile only; no `via_ir`; no live RPC.
5. Red-then-green with the same assertion; the current working tree is the red baseline (PRD L226, L241).
6. Preserved Uniswap V3/V4 trees under `contracts/protocols/dexes/uniswap/{v3,v4}/` are inventory; never edit, never select their bytecode (PRD L67).
7. Do not fix away accepted law: D12/D28 resting-credit consumption, D44 EIP-7702 acceptance, D32 public-pretransfer rejections, D6 booked protocol residual (PRD L61-67).

## Dependency order

No RC shares a production touch-set with another, except RC-04's Balancer comment which ships inside RC-01's edit. Recommended sequence: RC-01 → RC-02 → RC-03 → RC-05 → RC-06 → RC-07 → RC-08, with RC-04 comment edits bundled per-file as each file is touched, and the README edit as its own commit. RC-07 is sequenced late because its consumer listing must be finalized after no other edit adds `_unbookedSurplus` callers (none of RC-01..06 do).

---

## RC-01 — Standalone Balancer adapter reentrancy guard (Medium)

**Verified evidence (this pass):** `BalancerV3SinglePoolStandardExchange.sol:22` declares `contract BalancerV3SinglePoolStandardExchange is IStandardExchange` — no `ReentrancyLockModifiers`. `exchangeIn` (L69-107) and `exchangeOut` (L131-196) have no lock. Credit/pull happens at L83/L94/L162, allowance opens at L84/L95/L167/L182 via `_approvePermit2ToRouter` (L263-276, infinite approves at L271-274), router is called at L85/L98/L168/L183, and `_syncReserve` lands only at L88-89/L101-102/L175-176/L190-191. The stale "(M3)" comment is at L262. `ReentrancyLockModifiers` exists at `lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:16` and is the family-standard guard (`ERC4626StandardExchangeOutTarget.sol:8,26`).

**Touch set:**
- `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol`
  - Inherit `ReentrancyLockModifiers`; add `nonReentrant` to `exchangeIn` and `exchangeOut`.
  - Rewrite `_approvePermit2ToRouter` (L263-276): approve exactly `amount_` (`forceApprove(router, amount_)`, `forceApprove(permit2_, amount_)`, Permit2 `approve(token, router, uint160(amount_), uint48(expiration))`) instead of `type(uint256).max`/`type(uint160).max`; keep the existing zero-clear branch (L265-269). Replace the L262 comment with the exact-amount + zero-on-return rule. No `try`/`catch` — reverts roll allowances back with the transaction (PRD L79).
- Test: extend `test/foundry/spec/protocols/dexes/balancer/v3/pools/adversarial/Adversarial_BalancerV3SinglePoolSE.t.sol` — callback-capable configured pool token (fixture) that reenters `exchangeIn`/`exchangeOut` during the funding pull and during the router call; plus a no-callback fixed-behavior token negative control.

**Chosen vs alternatives:** Chosen = family `ReentrancyLockModifiers` + exact-amount approvals. Allowed alternative = a bespoke lock flag; rejected (duplicates the canonical crane guard and weakens audit comparability).

**Red/green:** Red = callback reentry completes a second money entry against the unguarded adapter (or the test cannot revert it); Green = the same test reverts on the reentry with the lock's error, allowances end at zero, `_tokenReserve == balanceOf` post-settlement, and the no-callback control completes with quoted deltas.

**Non-goals honored:** no public pretransfer on D32 surfaces; no D12 sender attribution; no demonstrated-extraction claim.

## RC-02 — ERC-4626 local-first payout exactness (Medium)

**Verified evidence:** `ERC4626StandardExchangeCommon.sol:82-92` — `_payUnderlyingLocalFirst` does `vault.redeem(vault.previewWithdraw(shortfall), recipient, address(this))` (L88) and accepts any `got >= shortfall` (L89). Callers: `ERC4626StandardExchangeOutTarget.sol:113` (exact-out unwrap) and `ERC4626StandardExchangeInTarget.sol:149` (exact-in unwrap). Orbital composing check: `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:559-564` accepts `balanceDelta >= amountOut`.

**Touch set:**
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol` L82-92.
- Tests: `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol` (extend `test_APEX_R14_exits_localFirst_receiptOutNeedsReceipts`) plus one orbital capped-unwrap suite under `test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/`.

**Chosen vs alternatives:** Chosen = replace the redeem with an exact-asset withdrawal: `vault.withdraw(shortfall, recipient, address(this))`. Per EIP-4626, `withdraw` delivers exactly `shortfall` assets and burns `previewWithdraw(shortfall)` shares, so the share charge matches the preview and no remainder is created — the clarity pass expressly does not require a remainder (PRD L254). Allowed alternative = keep `redeem` but cap the payout at `shortfall` and retain/report the over-delivery as booked; rejected (adds a second accounting path and a report-the-larger-amount obligation in exact-in, more surface for regression).

**Red/green:** Red = on a non-unit receipt rate with a mixed local-cash + vault shortfall, recipient delta exceeds the accounted due amount (or exact-in return disagrees with recipient delta). Green = recipient delta == accounted amount on exact-in and exact-out; exact-in return == recipient delta; ending reserve book asserted; orbital unwrap leaves no operation-created face above opening balance on a non-identity buffered leg (pre-existing D12 face measured separately).

## RC-03 — Stata SE backing must include booked aToken (Medium)

**Verified evidence:** `AaveV3StataStandardExchangeCommon.sol:52-58` — `_stataBacking` = held Stata + `convertToShares(booked underlying)`; no aToken term. Shared adapter `ReceiptBackedERC4626Target.sol:183-198` — `_totalReceiptBacking` adds `_bookedATokenEquiv` (sums `_reserveOfToken` over every `_vaultTokens` entry except receipt and underlying) when the Stata marker is set. Package init registers aToken when `aToken()` returns one: `AaveV3StataStandardExchangeDFPkg.sol:247-264`. Full-set sync books it: `BasicVaultCommon.sol:43-51` / `ReceiptBackedERC4626Target.sol:215-221`.

**Touch set:**
- `contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeCommon.sol` (`_stataBacking`).
- Preferably one shared helper so the two surfaces cannot drift again: move the "sum booked non-receipt, non-underlying holds" iteration into `ReceiptBackedERC4626AccountingLib` (or a small shared internal used by both `ReceiptBackedERC4626Target` and the Stata common), then have `_stataBacking` compute `booked_ = _bookedReserve(underlying) + sharedHelper(...)` before `convertToShares`. The iteration naturally contributes zero when aToken is absent from the expected-hold set (PRD L109).
- Tests: `test/foundry/spec/vaults/standard/erc4626/ReceiptBackedERC4626_SharedFacet.t.sol` and `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_APEX_R14.t.sol`.

**Chosen vs alternatives:** Chosen = shared helper consumed by both sites. Allowed alternative = duplicate the loop inside `_stataBacking` with a cross-reference comment; accepted only if the shared-helper move proves invasive (library dependency cycle).

**Red/green:** Red = funded control with nonzero booked aToken shows different share entitlement between adapter preview and SE issuance/redemption/transition quotes. Green = identical entitlement across both surfaces; a later depositor is priced on the same (larger, correct) basis; generic ERC-4626 mode still has no aToken term; reward forwarding to `feeTo` (L182-198) untouched.

## RC-04 — Stale security-critical comments (Low)

**Verified evidence:** `ERC4626StandardExchangeOutTarget.sol:17-20` still describes residual-to-`feeTo`; `ERC4626StandardExchangeCommon.sol:207` says "Pull overshoot is refunded immediately (D38)" and L280 says "Refund leftover free shares on diamond to `owner`"; `ERC4626StandardExchangeInTarget.sol:126` says "Pull overshoot already refunded in _securePull"; README L32 says short **and excess** exact-in deliveries revert and L36 says "V3 token exact-out pulls its quote plus the existing capped buffer; V4 pulls max. Dual exits pull max shares" — all stale against D6/D15/D17/D28. Executable bodies already implement the new law (e.g. `_securePull` L213-235 has no overshoot refund; `_refundCreditMinusUsed` L251-255 pays only `credit - used`).

**Touch set:** comment/NatSpec edits only at the five cited sites (Balancer L262 comment lands with RC-01); README `contracts/vaults/standard/exchange/protocols/uniswap/README.md` L32-38 rewritten to: exact-in credits exactly `amountIn` when unbooked availability suffices (surplus does not revert), false-flag exact-out pulls quoted `used` and refunds only `credit - used`, dust retained as book.

**Red/green:** no new money test. Green = existing `ERC4626StandardExchange_APEX_R14.t.sol` and one FullSpread exact-out suite stay green; a line-by-line reviewer check finds no removed behavior described as current. No executable change is made to match a comment (PRD L129).

## RC-05 — Unused single-CP HookTarget exact-out refund (Low)

**Verified evidence:** `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736-754` — `exchangeOut` pulls/credits nothing on the true flag, then `safeTransfer(msg.sender, maxAmountIn - amountIn)` (L753); no `LocalCreditLib.budget`, no `requirePretransferCaller`. Grep over `contracts/` for the contract name finds only the abstract declaration (L49) and its own PRD/plan docs — **no inheritor** (independent confirmation of the coordinator's search).

**Touch set:** that one file. Chosen = **delete** the `exchangeOut` function (L736-768); keep `previewExchangeOut` (L727-734). The contract is abstract, so removing an external function is safe with zero inheritors. Allowed alternative = reimplement it as a thin entry calling the installed guarded pull/refund helper (LocalCreditLib budget + `requirePretransferCaller` + `credit - used` refund); chosen deletion is preferred because a second public money implementation is exactly what the PRD forbids retaining (L142).

**Red/green:** `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol` stays green (installed cut unchanged); a recorded source search shows no remaining public `exchangeOut` refunding `maxAmountIn - amountIn` without the credit cap and caller check. Installed selectors verified unchanged.

## RC-06 — Orbital capped unwrap mis-reports shares spent (Low)

**Verified evidence:** `UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:550-566` — the SE's `exchangeOut` return is discarded (L560-562) and `seIn = maxIn` (the approval cap) is assigned at L565.

**Touch set:** that one file. Chosen = capture the SE return: `seIn = IStandardExchangeOut(se).exchangeOut(...)` and delete the `seIn = maxIn` assignment. This keeps the signature and every caller stable while making the value truthful (D25). Allowed alternative = remove the return value and update all callers; rejected (more churn for an admittedly unused return; PRD limits the requirement to honest-or-removed, L156).

**Red/green:** Green = existing orbital unwrap/surface suite passes; a production-hook test asserts the returned share count equals the share-balance delta around the SE call; approve-cap → approve-zero sequence (L558/L563) preserved; short delivery still reverts `InsufficientTokenOut` (L564). MiniMax's dissent (unused return ⇒ not a defect) is recorded; the requirement is truthfulness, not new economics.

## RC-07 — Shared availability math panics on book deficit (Low)

**Verified evidence:** `BasicVaultCommon.sol:34-36` — `_unbookedSurplus` = `balanceOf - reserveOfToken` checked subtraction (panics when balance < book); the pretransfer branch of `_secureTokenTransfer` does `uint256 U = B0 - R` (L98) and never calls `requirePretransferCaller` (delegated at L72-73); `_refundExcess` consumes `_unbookedSurplus` at L128. Consumer census (this pass, grep over `contracts/`): the `BasicVaultCommon._unbookedSurplus` has exactly two consumers — `_refundExcess` (`BasicVaultCommon.sol:128`) and `CamelotV2StandardExchangeOutTarget.sol:430`. The Balancer adapter's same-name copy (`BalancerV3SinglePoolStandardExchange.sol:218-222`) is already saturating and is not a consumer. `LocalCreditLib.available` (`contracts/utils/LocalCreditLib.sol:14-16`) is the canonical saturating helper.

**Touch set:**
- `contracts/vaults/basic/BasicVaultCommon.sol`: `_unbookedSurplus` → `LocalCreditLib.available(balance, booked)` semantics (`balance > booked ? balance - booked : 0`); pretransfer branch L98 → same saturating `U` so a deficit yields `TransferDeltaInsufficient(claimed, 0)` instead of an arithmetic-underflow panic.
- Tests: existing Uni V2, Camelot, Aerodrome secure-pull suites plus one deficit-case test; a companion test enumerating each public D16 entry showing the base pull's unguarded branch is unreachable without a prior `requirePretransferCaller` (D16 heirs such as `AaveV3StataStandardExchangeCommon._secureTokenTransfer` L200-228 already override with the check at L207).

**Chosen vs alternatives:** Chosen = saturate in the base helper + enumeration test for the caller check (PRD L167 option B). Allowed alternative = add `requirePretransferCaller` directly in the base pull; rejected because non-D16 historical consumers were not shown to be contract-only and the PRD forbids silently changing them (L163, L168). Historical consumer listing (required before the base edit): `_refundExcess` and Camelot L430 only; Camelot's deficit behavior changes from panic to zero-credit, which is the intended D16 semantics.

**Red/green:** Red = a prepared `balance < book` state makes a D16 refund/credit path revert with an opaque panic. Green = zero credit authorized, `TransferDeltaInsufficient` on any positive claim, no booked-inventory payout, no-bytecode callers still rejected on the named public entries.

## RC-08 — Uni V2 pass-through zap-out backing check named error (Low)

**Verified evidence:** `UniswapV2StandardExchangeOutTarget.sol:578-580` — `if (indexSource.pool.balanceOf(address(this)) < vault.vaultLpReserve) { revert(); }` immediately after the bounded refund at L575 and before `_syncAllExpectedHoldReserves` at L581.

**Touch set:** `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol` — declare (in the family's errors surface) and revert a named error carrying both compared values, e.g. `error PassThroughBackingDeficit(uint256 poolTokenBalance, uint256 vaultLpReserve);`. Test: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol`.

**Red/green:** If a supported production route can drive pool-token balance below `vaultLpReserve` without mocks or storage writes, that route is the red/green test (fails unnamed before, named after, success control beside it). If unreachable, record the attempted preconditions and assert the production check itself reverts the named error — the PRD's documented fallback (L183-184), not a new completion gate. Backing comparison and refund amounts unchanged.

## Evidence gaps and limits (carried forward)

- No forge/solc execution performed this round (research-only); all green claims are plans, not results. solc 0.8.35 is from `foundry.toml`, not an observed runtime.
- Audit PDF (`docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf`) not read by this reviewer; audit dispositions rest on the remediation PRD restatement plus current source.
- Whether a configured Balancer pool token can actually callback into RC-01, and whether a live Stata proxy carries nonzero booked aToken, were not executed; neither fix depends on those proofs (PRD L221-222).
- Reachability of the RC-08 deficit branch via a production route is unverified; the fallback assertion path is pre-authorized by the PRD.
- Peer originals/cross-reviews listed at PRD L21-28 were not read in this pass by design.
