# Astra — independent original findings

Access date: 2026-10-04. Research-only static inspection; no execution, peer findings, or prior-session memory used. Confidence: high on traced routes and law; medium on economic consequences; no verified exploit or gas benchmark.

Path shorthand: `O/` = `contracts/hooks/uniswap/v4/standardExchange/orbital/`; `W/` = sibling `weighted/`. Within these, `Common`, `Math`, `ExitQuoteLib`, `DepositCore`, `WithdrawTarget`, `ClaimLib`, and `JoinCore` mean the corresponding full `UniswapV4StandardExchange{Orbital|Weighted}BufferHook*.sol` filenames.

## Recommendation

**Use raw concrete inventory for liquidity ownership; rated coordinates for actual swaps, including swaps inside zaps.** “Only zap types” is closest among the proposed choices, but is not literally complete: first-mint scale and protocol-fee accounting can also need rates. Classify sub-operations, not API names. Never replace buffering/unwrap execution quotes with raw 1:1 assumptions.

### 1. Controlling law and versions — facts

Orbital PRD header is draft v0.6 (2026-08-04); its implementation plan still says v0.5. The PRD’s **2026-09-22 addendum, lines 828–835**, supersedes old effective-book liquidity language: buffered LP issuance follows share ratios; exits follow raw shares/tokens. APEX `docs/audits/apex-2026-09-17-open-item-10-cp-hook-rate-providers-PRD.md:7–15` separates raw liquidity from rated swaps and requires providers on buffered legs.

Importantly, `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md:149–153` includes **D63**, confirming later raw joins/exits while first-mint scale and `kLast` remain rated (context: D60 work package 2). Do not silently extend that CP-focused clarification over Weighted’s explicit different fee law. Observed Solidity pragmas are `^0.8.0`; compiler 0.8.35 is recorded by the aperture plan, not independently executed/version-checked. No commit identity established.

### 2. Actual proportional versus composed routes — facts

* `O/DepositCore:158–190`: proportional entry calls `_addLiquidity`, not `ExitQuoteLib.planDeposit`. `O/Common:1187–1212,952–1089` computes full-book joins from effective balances and rated buffer inflows. Thus the policy question is **not confined to the accused zap planner**.
* `O/WithdrawTarget:107–134` routes proportional exit to `_removeLiquidity`. `O/Common:1287–1356` explicitly slices raw reserve/SE-share inventory pro rata, then unwraps those shares. This is not selling the basket into one output.
* `O/DepositCore:218–256` routes single-asset entry through a zap; SE-share input is first redeemed. `O/Common:1974–2033` selects a two-swap plan or single-sided partial-NAV fallback; `1870–1884` executes swaps, buffers contributions, then mints.
* `O/WithdrawTarget:153–177` performs proportional withdrawal **then swaps residual legs**, optionally buffering the final output into SE shares. The old PRD’s “no zap-out” prose is not a description of today’s code.

**Inference:** use rated sphere pricing for those exchanges, raw ratios for the terminal proportional admission/distribution. The no-swap partial-NAV fallback is not proportional liquidity: it changes composition and requires its own owner-approved economic/fee specification. “Single asset” alone does not determine whether rates are needed.

### 3. The moderator’s alleged bug is not established

`O/ExitQuoteLib:272–294,376–381` rates both minted contribution shares and held shares using the same per-leg rate, then applies `fullBookShares`. Algebraically,

`(minted_i × rate_i)/(held_i × rate_i) = minted_i/held_i`.

Rates need only match **within each leg**, not across all legs. Hence rated variable names and `fullBookShares` alone prove neither manipulation nor overminting.

However, integers do not cancel generally. Illustrative arithmetic, not an executed exploit: held=3, contribution=1, rate=1.5 WAD, supply=12 gives raw issuance 4 but separately floored rated issuance `floor(12×1/4)=3`. `O/ClaimLib:315–329` floors rated conversion; `O/Math:23–41,146–171` adds scaling and used-amount floors. Tiny conversions, different state reads, overflow/domain gates, and fee dilution need analysis. `ExitQuoteLib:378–381` even falls back to face amounts when minted/rated amounts are zero, breaking straightforward cancellation assumptions.

**Recommendation:** raw share-ratio computation makes the intended independence exact and auditable; rate presence is evidence of avoidable coupling, not by itself proof of an exploit. Require floor/ceil backing checks and differential tests, not only preview parity.

### 4. Fees and failure liveness

Raw ownership arithmetic does **not** currently imply rate-free execution. `O/Common:899–948` mints protocol LP from rated growth; `459–487` refreshes rated reserve views, radius checks and sphere state. Proportional exit invokes those updates (`1359–1366`), so provider failure can revert an otherwise raw withdrawal, even with growth fees off.

Rated growth can dilute user shares after a rate move without any raw inventory increase. That is separate fee policy, not cancellation failure. Preserve adopted fee semantics unless explicitly revised. Trading residuals on actual zap swaps and SE wrapping costs also remain distinct (`ExitQuoteLib:135–145`).

**Recommendation:** swaps fail closed; never silently substitute rate=1. If rate-failure exit liveness is required, specify a raw in-kind recovery route and treatment of pending growth fees/cached sphere state. Unwrapped exits still depend on SE availability. Raw accounting limits valuation manipulation; it does not eliminate swap manipulation or underlying SE risk.

### 5. Rate reads, simulation, Weighted, and gas

`O/ExitQuoteLib:49–82,332–381` threads SE transition states. `_faceForClaim` repeatedly runs deposit transitions; `ClaimLib:250–275` performs another inverse search. `libs/UniswapV4SeBufferHookLegLib.sol:133–149` chooses projected `quoteRate` or ordinary `getRate`. A provider read is not synonymous with the expensive transition planner, nor guaranteed cheap. Removing rate reads does not remove necessary state-sensitive buffer quotes.

Weighted differs: `W/UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md:61–75,99–100` explicitly specifies native inventory LP accounting and invariant single-asset joins, not Orbital’s multi-swap zap. `W/JoinCore:208–280,593–611` confirms inventory-domain proportional and single-token calculations.

`test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol:171–176` inherits `TestBase_UniswapV4Detf_Weighted`, whose `setUp:47–56` deploys **SimpleYieldERC4626-backed wrapper SEs, not FullSpread**. It cannot prove FullSpread compatibility. The separate Orbital position suite has 31M capped calls (`V4FundedBindings:385–400`); source assertions are not passing-run evidence.

The aperture PRD (updated 2026-10-04) excludes rewriting Orbital inversions (`docs/plans/UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.md:62`); its plan D11 (`:44`) demands matched-state gas evidence. Neither establishes that the old planner fits gas. Missing: authenticated baseline/results, call-count profiles, hostile-rate and mixed-decimal backing tests.

### External evidence and limitations

Context7 `/balancer/docs`, followed by primary https://raw.githubusercontent.com/balancer/docs/main/docs/reference/lp-tokens/underlying.md (accessed 2026-10-04), corroborates balance×LP-fraction accounting only; it is unpinned and not evidence for all Balancer V3 rate policies. Recovery-mode URL returned 404. Initial broad glob encountered broken Crane dependency links; guessed `contracts/vaults/detf/uniswap/v4` search path was absent. No ordinary file-read denial was bypassed. No peers or linked council research were read.
