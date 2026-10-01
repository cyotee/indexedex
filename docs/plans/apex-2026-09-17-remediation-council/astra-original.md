# Astra — independent original implementation-plan research

Date/access date: 2026-09-26. Status: research, not implementation authorization or verification. This original is preserved for sharing. No peer artifacts were opened; the requested remediation PRD necessarily contains historical attributions, which are not independent evidence. No shell, tests, deployments, chain reads, code/config edits or delegation occurred.

## Authority and assumptions

The current `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` (2026-09-25 clarity pass) governs RC-01–08, fresh deployments and allowed evidence exceptions (55–67, 179–184, 226–244, 252–254). No new product decision is needed. Its scope supersedes older live-inventory/fork requirements and `BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:47`'s historical unchecked-by-policy deficit behavior on D16 routes. Preserve D12 resting-credit risk, D32 rejection surfaces, D44 bytecode acceptance, D6 booked residuals, fees and economics.

Read directly: CLAUDE, agent law/catalog, canonical Crane deployment/architecture/testing/adversarial/access skills and implementation-test DoD, local testing/adversarial/hook-package skills; APEX task PRD including R14 shared-accounting requirements; BasicVault, single-CP and orbital family PRD sections relevant to these paths. Older hook descriptions allowing missing buffered-leg rate providers and the hook skill's package-specific profile example lose to current CLAUDE/agent law. Production hook fixtures require rate providers and staged finalization, not just a deployed bootstrap address.

Observed configuration: `foundry.toml:7–45` pins solc **0.8.35**, optimizer enabled/runs **1**, `via_ir=false`, default hermetic test root, `out/`, `cache_forge/`, fuzz runs **16**, invariant runs **16**/depth **8**. These are file settings, not observed executable versions or effective environment overrides. Installed Forge, EVM default, git/submodule revision and artifact freshness are unverified. Historical Forge 1.5.1/Prague claims are not current-runtime evidence.

## Sequencing and ownership

1. Capture current source/artifact provenance and production selector/deployment-source manifest; classify historical consumers before any shared edit. Add failing assertions without changing production.
2. Independent tracks: RC-01; RC-02 plus ERC comment parts of RC-04; RC-03; RC-05; RC-07 plus RC-08. Serialize shared-file edits, especially ERC4626 Common and Stata Common.
3. RC-06 shares orbital acceptance with RC-02: implement removal independently, but establish the rounding regression against the pre-RC-02 dependency and finish composed green afterward.
4. Finish RC-04 documentation, affected-family hermetic regressions, selectors/code-size checks, preservation checks, and evidence ledger. The moderator owns `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md`, not a new plan under reviews.

## RC-01 — operation lock and bounded approvals

**Facts:** `contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:22,69–107,131–196` has no operation lock. Funding, approvals, router calls, refunds and payouts precede reserve sync. Lines 263–275 ignore nonzero approval magnitude and grant maxima. The adversarial suite at the PRD's exact path deploys real artifact bytecode via CREATE3 (72–88) and already checks all three approval amounts become zero (103–118), but that does not test in-flight authorization.

**Recommended touch set:** that adapter; `Adversarial_BalancerV3SinglePoolSE.t.sol`; a callback-capable ERC20 fixture under `contracts/test/stubs/` if no suitable existing fixture. Inherit Crane `ReentrancyLockModifiers` and put `nonReentrant` on both public money entries. Its actual modifier locks before the body and unlocks afterward (`lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:21–29`). No new lock implementation or adapter diamond conversion.

Approve exact-in `actualAmountIn`/`actualBptIn`; exact-out approve the existing route's bounded `spendable` budget (credit for true flag, quotedUsed for false), never global maxima. Keep router maximum, funding and refund semantics aligned. Bound/check Permit2's uint160 conversion; do not silently truncate. Clear direct-router ERC20, Permit2 ERC20 and Permit2-to-router authorization on successful return. Retain full-transaction propagation on failure; no catch cleanup. Replace the stale M3 comment. Reuse `LocalCreditLib.available` for the adapter's already-saturating availability copy while touching it.

**Red/green:** callback probes at funding, nonzero approval, router-driven transfer, reset approval, refund and payout; nested In→In/In→Out/Out→In/Out→Out must return the precise lock error, not merely fail downstream. Swallow nested failures in the fixture to permit funded outer success and persistent probe assertions. Separately propagate a callback failure and assert balances/books/allowances roll back. Seed booked reserve by a normal completed route, not writes. Ordinary-token controls cover joins/exits and both flags, exact recipient delta, authorized refund, zero allowances and post-settlement book. Internal book observation can use read-only storage evidence plus a second no-credit production call, not a new public getter solely for testing.

**Confidence:** high on source defect/fix; callback stage reachability and concrete exploit extraction unexecuted. A router lock is not an adapter lock. No lasting extraction claim is necessary.

## RC-02 — exact local-first payout

**Facts:** `ERC4626StandardExchangeCommon.sol:80–92` redeems rounded-up shares directly to recipient. InTarget 144–151 returns the previously calculated due; OutTarget 108–115 promises exact assets. R14 test 120–138 uses near-unit accounting and does not assert recipient delta.

**Recommendation:** change only Common payout logic to `withdraw(shortfall, recipient, address(this))`, retaining local-first transfer and existing route sync. This is preferable to the allowed redeem-to-SE/forward-due alternative: fewer custody transitions and no new remainder to manage. Do not alter share-pricing or fee formulas. Exact-asset withdrawal may consume preview-rounded shares; the standard guarantees a preview upper bound, not universal equality for every implementation. Assert equality for the deterministic fixture and preserve production-family rounding rules.

**Tests/touch set:** extend `test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_APEX_R14.t.sol` and orbital `UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol` or its ERC4626 matrix fixture. Existing `CappedPausableERC4626` inherits `simulateYield` and ceil previewWithdraw (`SimpleYieldERC4626.sol:124–127,164–188`): establish a funded non-unit rate, cap deposits to retain booked cash, choose a shortfall whose rounded receipt redemption exceeds due, and assert that precondition explicitly. Test exact-in and exact-out, mixed cash/receipt, local-only and receipt-only controls, actual recipient delta, return value, burned shares and ending reserves. Orbital must use the real SE proxy, configured rate provider, real PoolManager/router, non-identity buffered output leg and actual capped unwrap. With and without D12 resting face, closing face equals opening unconsumed face; no new surplus or feeTo payout. Current Apex008 188–218 supplies useful swap/resting-balance scaffolding, not proof of rounding/cap coverage.

**Confidence:** high. Alternative redeem-to-SE remains valid only with exact forwarding and remainder booked after settlement.

## RC-03 — one backing implementation

**Facts:** Stata Common 52–58 excludes aToken, while `ReceiptBackedERC4626Target.sol:183–198` includes booked additional hold-set assets for Stata. DFPkg 245–263 registers aToken when present; BasicVault Common 43–50 books the set. Stata InTarget 50,73,85,155 uses `_stataBacking` for issuance and quote snapshots.

**Recommendation/touch set:** extend existing internal `ReceiptBackedERC4626AccountingLib.sol` with the shared storage-reading backing/hold-set calculation; route adapter `_totalReceiptBacking`, Stata `_stataBacking`, and generic `_receiptBacking` through it. Preserve explicit proxy-marker dispatch in the adapter, generic no-aToken mode, and current sum/conversion units; do not inherit an external ERC4626 Target or self-call fee-bearing SE entries. Read/test Stata SY rate and both In/Out transition consumers; edit them only if they bypass the common path. Keep input subtraction timing, held-receipt limits and rewards 182–198 unchanged.

**Red/green:** extend `ReceiptBackedERC4626_SharedFacet.t.sol` and `AaveV3StataStandardExchange_APEX_R14.t.sol`. Acquire aToken through the real hermetic Aave pool, transfer it to the proxy, then book through a funded completed adapter/SE operation. Assert nonzero book before comparison. On one state compare IERC4626 totalAssets/conversions, SE previews/execution, SY rate and transition quotes in matched native units with explicit fee adjustments. Later receipt/underlying/aToken deposits cannot use a smaller denominator or double-count their input. Generic wrapper (including generic-over-Stata receipt) has no extra term; absent hold-set term is zero. Current shared-facet test 143–160 checks slot membership only. Confidence high; funded reachability has not been executed.

## RC-04 — documentation only

Touch precisely ERC4626 OutTarget 17–20, Common 201–211/277–281, InTarget 126, FullSpread `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32–38`; adapter 262 travels with RC-01. Explain saturating availability, exact pull-delta equality, sufficient—not equal—push credit, exact self burn, true-flag credit-minus-used refund, quoted-used false-flag funding and residual book retention. Keep D12 integrator warning. No executable refund change for comment compliance. Close by line/body inspection and rerun ERC R14 plus one current FullSpread exact-out suite. Confidence high.

## RC-05 — delete the unused entry

Recommend deleting only `exchangeOut` from `UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol:736–768`, not deleting the file or recutting facets. Scoped production search found only the abstract declaration, no importing/inheriting consumer. Reconfirm imports/inheritance across source/test/scripts during implementation. Thin delegation to the installed guarded helper is allowed but adds coupling without benefit for unused code.

Acceptance: source-absence check is the explicit PRD exception; installed `_Surface.t.sol` must retain selector mapping and proxy calls (71–95 already includes both money selectors). Supplement with funded installed-SeTarget exact-out/caller checks; a passing loupe check alone cannot close retained unsafe source. Confidence high within searched contracts, medium for full consumer absence.

## RC-06 — remove unused return

Recommend make orbital Common `_unwrapExactTokenOut` void, use a local quoted-share variable, replace zero/identity value returns with bare returns, and remove `seIn = maxIn` (550–565). All seven located callers ignore its return: Common 586/604/1899, SeTarget 125/185/250, WithdrawTarget 177. No caller-expression rewrite appears necessary, but compile them all. Preserve cap approval/reset and short-output error. Alternative retaining SE-reported actual spend is valid, but testing an internal unused return should not force a new public selector. Reuse RC-02 composed unwrap tests for exact output, actual share delta, allowance reset and rollback; source inspection proves return removal. Confidence high; not a claim of current user-facing loss.

## RC-07 — isolate D16 semantics from historical base users

**Observed inventory:** production imports of BasicVaultCommon are Uni V2, Camelot V2, Aerodrome V1 and Stata Common. Their overrides already enforce caller checks and saturation: respectively 420–447, 158–185, 946–973, 200–227. Shared refunds still call base `_unbookedSurplus` (BasicVault 120–135). Camelot OutTarget 430 also calls it directly; Aerodrome OutExecute has multiple direct `_refundExcess` calls. Preserved Uni V3/V4 have their own transfer implementations, not an observed BasicVault import.

**Historical protection list:** `test/foundry/spec/vaults/basic/BasicVaultCommon_{TokenTransfer,TrustFlags,Permit2}.t.sol`; fork BasicVault Permit2 harnesses under `base_main` and `eth_main`; any additional non-D16 consumers found in final source closure. TokenTransfer 107–138 exposes the legacy base directly. Do not rewrite old expectations or run forks.

**Recommendation:** make base `_unbookedSurplus` virtual without changing its body, override it in the active family Commons to call `LocalCreditLib.available`; inherited refund calls then dispatch to D16 saturation. Leave base pull behavior unchanged and prove every active public token/share entry reaches its guarded override. This avoids global base caller/deficit changes. A global change is an allowed alternative only after complete consumer enumeration proves no outside-D16 semantic change.

Extend Uni V2/Camelot SecRemediation and Aerodrome E6/A0/I1/secure-pull suites: balance below/equal/above book, zero credit, exact insufficient-credit error, no booked payout, bounded refund, EOA rejection and funded contract/pull controls. First seek a supported deficit route; no rebasing/FoT product support or SUT-storage manipulation to manufacture it. If unreachable, document why and use the PRD-permitted direct test of the actual production helper, not copied arithmetic; retain production entry/guard tests. Confidence high on override code, medium on full reachability and historical closure.

## RC-08 — named LP deficit check

Change only the backing assertion in Uni V2 OutTarget 575–580 to a proposed `InsufficientLpBacking(uint256 held, uint256 required)` with the measured balance and `vault.vaultLpReserve`. Preserve comparison, refund order and rollback. Extend its SecRemediation suite with funded LP pass-through success and attempted reachable deficit preconditions. Earlier empty-revert A0 tests at 157–183 are other branches, not evidence this branch is reachable.

If supported routes cannot reach the deficit, extract the identical production comparison into a small internal pure check called at this site; a thin test exposure asserts exact error/arguments for held<required and success for equality/greater. This exercises production code without fake vault state; it does not prove end-to-end reachability. Record that limit and retain funded production controls. Do not postpone the named-error correction pending an owner question. Confidence high on required edit, low on natural deficit reachability.

## Release evidence and limits

For each behavioral case record the same assertion's red failure and green pass, exact selector/arguments, balances/supply/books/allowances, positive twin, source revision/file hashes and runtime artifact identity. Comment/source-removal and documented RC-07/08 helper exceptions are not falsely labeled exploitable red traces. Refresh artifacts before tests per CLAUDE 59–61; use the existing `forge-artifacts.py` workflow, default hermetic profile and unchanged config. Report effective fuzz settings rather than treating default 16 as a release-strength campaign. Check runtime size and selectors of affected concrete consumers, full relevant family suites, historical source preservation and fresh deployment selection of replacement—not preserved—Uni implementations. No migration/inventory/fork work.

External evidence accessed 2026-09-26: Context7 `/websites/openzeppelin_contracts_5_x`, https://docs.openzeppelin.com/contracts/5.x/api/token/erc20 (5.x documentation, not a claim about installed OZ); primary https://eips.ethereum.org/EIPS/eip-4626, sections withdraw/redeem/previewWithdraw. Exact assets versus exact shares is standards fact; precise fixture equality is implementation-specific.

Missing read recorded once, not retried: `lib/crane/contracts/access/reentrancy/ReentrancyLock.sol` does not exist. The separately referenced actual modifier source was read successfully. Some long family/task documents were read in relevant sections, not exhaustively; no audit PDF replay or full D16 body audit occurred. Future implementation must finish consumer closure, callback fixtures, capped-unwrap branch evidence, Stata funded-aToken setup, SY body trace and deficit reachability evidence. These are engineering/evidence tasks, not reopened product questions. Consensus or passing tests alone cannot establish security or economic soundness.
