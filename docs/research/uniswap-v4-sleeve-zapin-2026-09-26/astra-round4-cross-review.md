# Astra — round 4 combined cross-review

**2026-09-27. Research only.** Read Grok, MiniMax M3 and Kimi K3 round-4 originals together as untrusted evidence. No cross-review artifact read; all originals preserved. No implementation, shell, tests or delegation. **V/** abbreviates `contracts/protocols/dexes/uniswap/v4/`; **Common** is its `UniswapV4StandardExchangeCommon.sol`.

## 1. Accepted direction and principal dissent

Latest owner permits **repeated bounded public repair swaps**, overriding the historical no-swap prohibition. Deposit composition still uses only its credited current-call basket. Public repair uses vault inventory, mints no shares, and charges all holders its net fees/impact; own-LP fee recycling offsets only the vault's actual earned share. Do not mix the repair transaction's inventory spending with deposit attribution or automatically add whole-book swaps to every deposit tail.

Grok/Kimi and Astra recognize that change. **Reject MiniMax §§4–5's contradictory restoration of swap-free public rebalance/out-of-scope repair.** The latest instruction wins. Preserve post-swap incumbent B, full caller C including sleeve, mint-last and literal 20%-of-owned-deployed policy.

Pretransfer origin-provenance restrictions and discretionary hook admission whitelists are withdrawn, not open questions.

## 2. Numeric recommendation: practical starting envelope

These values are **nonempirical proposals**, not validated safety thresholds:

| Quantity | Corrected recommendation |
|---|---|
| Terminal spot movement | **25 bp/public repair**, **50 bp/deposit composition**; 50 bp repair is a reasonable less-conservative alternative requiring explicit selection |
| Execution slippage | **10 bp** adverse shortfall against a fee-inclusive executable quote |
| Aggregate repair travel | **100 bp cumulative absolute log-price travel over a 30-minute window**, shared by callers and both directions, not reset by each transaction/block |
| Churn limiter | Also cap gross repair input at **10% per token of window-start owned inventory**, or approve an equivalent anchored cost/turnover budget |
| Alignment/rounding loss | **1 bp** realized uncompensated contribution; no absolute-floor escape |
| Sleeve deadband | Existing **5% of target F***, plus specified absolute token floor |

Use actual token price ratios, not raw slot0 subtraction or a same-sized percentage of sqrtPrice. An additive conservative implementation may debit absolute log changes; define its units and rounding precisely. Intermediate checkpoints and hook effects must not evade the budget.

**Corrections:**
- MiniMax's `1e-4` is **1 bp**, not 10 bp. Its 50-bp sleeve deadband is also wrong: 5% of F* is **500 bp of F***. Its suggested cumulative 20-bp alignment allowance is looser, not tighter, than 10 bp.
- Kimi's execution slippage `>=2×LP fee` is unnecessary for a **fee-inclusive** quote. Fees already appear in that expected output; 10-bp additional tolerance does not reject a correctly modeled 30-bp pool simply because its fee is larger.
- After two full debits against a budget of twice the per-call cap, nothing remains; MiniMax's additional half-call example is arithmetically invalid.

**Risk-model dissent remains:** Grok accepts per-block reset with independent reference off. This explicitly leaves multi-block price walks possible. Its first-anchor net displacement also does not constrain back-and-forth churn. Kimi's campaign turnover concept addresses more than net price movement, but the asserted geometric convergence is not established for changing prices, fees and endogenous LP backing. Budget bounds are not proofs of profit, damage limits or finite convergence.

I recommend retaining my original independent-reference option for permissionless shareholder-funded repair: candidate **200-bp start/end deviation**, validated **30-minute reference window**, latest observation **≤5 minutes old**, no same-block-only initialization. This is proposed protection, not a DETF-imposed TWAP mandate. If no independently defensible reference exists, use a trusted/fixed campaign anchor with an explicit reset policy and disclose its weaker market-price protection, or defer swaps while permitting add/remove progress. No caller-reset anchor. A reference alone does not stop churn; retain gross/absolute budgets. A rolling-window implementation or explicitly bounded reset-boundary burst is engineering work.

My original **100-bp effective swap-charge ceiling** is an optional configuration default within the same risk decision, not a hook allowlist. Fee, impact, execution shortfall and reference deviation must remain separately described. Refilling the reference or budget may permit later progress; immediate unlimited repair is not promised.

## 3. Best effort without changing share law

**Reject Grok:56's silent fallback to raw single-sided invariant-growth issuance.** The owner accepted best effort, not a replacement for the accepted idle proportional equation. Partial deployment and retained inventory are not permission for arbitrary misalignment or changed mint economics.

For positive B and C, keep:

```
m = floor(S * min(C0/B0, C1/B1))
epsilon = max_i(1 - m*Bi/(S*Ci))
recommended epsilon <= 1e-4
```

This metric includes share flooring as well as alignment. Safe cross-product comparisons are required. Kimi's relative alignment metric is useful but its added absolute token-floor exception can authorize a large percentage donation for small deposits; reject that escape. Grok's relative metric likewise needs final-share rounding covered separately if used instead.

MiniMax:84 wrongly excludes placement residue from caller credit, contradicting its own §6. **The caller's full credited basket, deployed or retained, earns ownership.** Unclaimed push surplus is a different quantity, absorbed without caller shares under settled pretransfer law.

Recommend bounded solver/search and placement progress; if a deposit cannot mint positive proportional shares within the approved loss ceiling and user minimum, revert atomically. Public repair may take a partial bounded step or stop without minting. Residual handling and reasons are reported. Exact-in has no refund. An alternative successful idle raw-deposit fallback would need explicit owner approval; it is not adopted by this report.

## 4. Hook admission and execution: no hidden whitelist

Agree with owner fallback: **deployer-supplied PoolKey is assumed compatible**, with deployer responsibility. Source findings are settled:
- Universal Router `V4_POSITION_MANAGER_CALL` is restricted by `modules/V3ToV4Migrator.sol::_checkV4PositionManagerCall`, rejecting increase/increaseFromDeltas/decrease/burn. MiniMax's broad “arbitrary PositionManager call” wording does not override this primary source.
- PositionManager itself supports those liquidity actions. The vault uses direct PoolManager with empty hookData (`Common:1015–1062`), so Universal Router mint success does not certify its add/remove/swap lifecycle.
- Address flags mark callback execution, not arbitrary logic or compatibility for a different caller/hookData. No-liquidity-callback flags are limited evidence; simulation is not a future guarantee. Selector matching alone does not prove implementation parity.

Reject MiniMax's requirement that the existing `_supportsProjectedHook` identity set must pass as an execution condition: that can recreate the forbidden discretionary whitelist. **Runtime economic checks remain universal.** Use faithful quote/projection/simulation where available; otherwise expose quote unavailability rather than fabricate vanilla results. Execution may proceed only when its actual fills, accounting and approved protection can genuinely be checked, regardless of hook identity. If required numerical checks cannot be evaluated, fail that operation with a truthful reason—not “hook not whitelisted.” Grok's impact-cap-plus-settlement-only wording is insufficient to establish fee/quote accuracy.

The directly fetched upstream PositionManager also warns that delta-derived mint/increase lacks minimum-liquidity protection. This supports requiring actual liquidity/share/cost checks; it is **not evidence of an exploit in this vault** or authorization to copy those paths.

Primary evidence retained from Astra's original: Universal Router `main/contracts/base/Dispatcher.sol`, `main/contracts/modules/V3ToV4Migrator.sol`; v4-periphery `main/src/PositionManager.sol`; v4-core `main/src/libraries/Hooks.sol`, fetched after Context7 on **2026-09-27**. They remain unpinned remote sources, not deployed-revision proofs. No new API claim was needed here.

## 5. Pretransfer corrections and directly traced implementation gaps

Settled law permits eligible contracts to claim unbooked held inventory without provenance; credit precedes fee collection/sync; exact-in refunds nothing; every successful workflow end-syncs its expected held set. No exemption or pull-only vote is needed.

**Snapshot correction:** Grok:43 incorrectly says V4 must retain `U=held−(R−currentDeployed)` as a durable rule. It can reconstruct held book at a matching snapshot but drifts afterward. MiniMax's claim that any positive deployment proves overcredit is equally wrong. Its example `R=100,D=80,held=50` can simply mean held snapshot 20 plus valid new inflow 30.

A genuine drift example: economic R=120 records held20+deployed100, with no fees. Later deployed110 and held20 yields inferred local book10 and apparent credit10, although no new held inflow occurred. Uncollected fees in economic R further complicate the subtraction. Separate durable local snapshots from economic share reserves; do not blindly apply BasicVault `held−R` to economic R, nor silently change all consumers' economic views.

**EOA guard trace:** `InFacet:11–12,23–26` exposes inherited `InTarget.exchangeIn`; target `:45–65` invokes nonReentrant, disable/deadline checks and the V4 credit override `Common:1270–1288`. Reentrancy modifier `lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:21–29` only locks/unlocks; disable helper `Common:68–71` checks disabled status. Neither checks caller bytecode. The delegate calls InBase directly (`InExecutionDelegate:9–14`). This inspected entry chain lacks the required pretransfer caller guard—not merely a grep inference or a claim about every repository route.

**End-sync trace:** correct both peer overstatements. Direct swap **does** sync at `InBase:85`, before its tail rebalance; therefore MiniMax's “does not call sync” is false. Rebalance synchronizes through `_emitRebalanceEvent` **only if moved** (`Common:808–819`). Fee collection or other no-move cases still require a final full-set checkpoint. Zap-out syncs **before payout** (`InBase:213–215`); a no-move tail does not guarantee a final correction. Deposit sync `:307` precedes tail work, contrary to Kimi's claim that timing alone satisfies final-sync law. These are source-level obligations to repair/test; no end-to-end exploit or runtime failure is asserted. Single-transaction execution does not itself exclude callback reentry/double claims—guards and end-state invariants must prove that.

## 6. At most two remaining decision bundles

1. **Numeric/configuration/risk bundle:** approve 25/50-bp impact, 10-bp fee-inclusive slippage, 100-bp aggregate travel, 1-bp alignment and any fee/turnover/reference envelope; select immutable defaults versus existing-authority configuration, reference availability and reset policy. Per-block-only protection is a weaker alternative requiring explicit risk acceptance. No global reinterpretation of other families' oracle settings.
2. **Only if desired, best-effort fallback bundle:** default to bounded progress/residual with accepted proportional issuance or atomic deposit revert. Ask explicitly only if the owner wants successful uncomposed idle deposits when protection prevents alignment; Grok's formula fallback is not presumed authorized.

Public repair, deployer hook responsibility and reserve-delta pretransfer need no further permission votes. Confidence high in corrections/source paths; numeric calibration, generalized hook quoting, cumulative-risk adequacy and full runtime safety remain unproved. Return to moderator; no further loop.
