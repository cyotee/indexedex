# Astra — independent original findings

**Date:** 2026-09-26. **Scope:** research only; proposed requirements, not approved product law or implementation authorization. No peers consulted, tests executed, or code changed. Assumption: the supplied checkout is the candidate baseline, not proof of deployed bytecode.

Path abbreviations: **V/** = `contracts/protocols/dexes/uniswap/v4/`; **T/** = `test/foundry/spec/protocol/dexes/uniswap/v4/`; **C/** = `lib/crane/contracts/protocols/dexes/uniswap/v4/`. `Common` and `InBase` mean `V/UniswapV4StandardExchangeCommon.sol` and `V/UniswapV4StandardExchangeInBase.sol`.

## 1. Root cause — facts and inference

**Fact:** single-token share deposits do not swap. `V/UniswapV4StandardExchangeInTarget.sol:63–67` pulls input and delegates to `InBase:273–315`, which collects existing fees when idle, calculates shares, mints, then attempts deployment. Single-sided issuance measures growth in `sqrt(reserve0*reserve1)`; dual issuance uses the minimum proportional contribution; initial issuance requires both amounts positive (`Common:685–712`).

Rebalance only offers `max(free_i−target_i,0)` to liquidity addition (`Common:751–805`). In-range liquidity takes the minimum of the two token-supported liquidity amounts (`C/libraries/LiquidityAmounts.sol:56–76`); a zero counter-token excess therefore produces zero new liquidity (`Common:822–858`).

**Inference/example:** starting with totals `(100,100)`, deployed `(80,80)`, sleeve `(20,20)`, a token0 deposit of 10 produces sleeve `(30,20)`, targets `(22,20)`, and deployable budgets `(8,0)`. Repeated same-token deposits cannot fix this. It is a composition constraint, not merely a deadband or missing public-rebalance call. Existing external pool liquidity could facilitate a swap, but the deposit never requests one.

This follows historical local-buffer D27/D28 and full-range D32, rather than violating their intent. **Counterargument:** “just activate with two tokens” solves bootstrap, not subsequent unilateral flows.

## 2. Authority and required supersession

`contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:1153–1161,1270–1272` (D57–D59/§24) governs: maximum usable ranges including imports; exact deployed amounts plus sleeves plus earned fees once; dual-funded activation; later single-token deposits and funded blocked operations. The implementation plan §7.4 (`:370–376`) agrees. Preserve these requirements.

A new PRD must explicitly supersede **local-buffer D27**, related D10/D13 ordering/economic claims, and **D24** wherever it excludes the new user swap from previews; carve **D28** narrowly for deposit composition, and revise **full-range D32** for this route. Keep public rebalance add/remove-only unless separately approved. If Multi starts swapping, also supersede full-range **D45/D47** and its no-swap non-goal; do not silently change Multi.

Historical first-single-token activation, sum-of-assets issuance, unchanged imported ticks, and native exclusion are not current authority; both family PRDs flag supersession at line 3.

## 3. Proposed safe requirements

1. **States:** PM idle means protocol **locked**, allowing this vault to open `unlock`; PM in-session means **unlocked**, blocking nested `unlock` (`Common:310–317,676–680`). Preserve blocked sleeve deposits without swaps/deployment, covered requested-token payouts, and atomic insufficient-sleeve rejection. Do not join another caller’s session.
2. **Composition:** when idle, transform this deposit’s attributable input into a two-token contribution using a bounded swap, then deploy excess while retaining policy liquidity. Solve against the **post-swap** exact CL ratio, fees and price impact—not raw 50/50 amounts, and not automatically the possibly skewed vault-total ratio. Define acceptable dust and boundary-price behavior.
3. **Policy:** retain live oracle `p`, per-token target `free_i=p*total_i`, existing deadband, and total-book accounting. Twenty percent of total means free/deployed = 25%; “20% of deployed” incorrectly yields 16⅔% of total. Never consume scarce policy sleeve just to show more liquidity.
4. **Scope:** recommend single-token idle zap composition first; retain exactly-two-positive-input Multi in PoolKey order and no-swap behavior. Initial activation still requires actual dual funding, even if an external pool already exists. Zero-depth swaps must fail clearly; no circular promise that a single-token first deposit creates its own counter-liquidity.
5. **Backlog:** input-only composition does **not** guarantee clearing old skew from blocked deposits/donations. Specify that limit. A permissionless whole-book swap is a distinct treasury-risk feature requiring separate cost, price-protection and liveness decisions—not an incidental tail rebalance.
6. **Native:** retain WETH as ERC20 sleeve/API face of native currency0, unwrap only for PM settlement and wrap native takes (`Common:411–425,1096–1117`). Preserve PoolKey order even where WETH sorts last. Do not introduce payable ETH deposits by implication.

## 4. Economics, previews and security

**Approval-blocking economic specification:** define depositor-attributable post-swap amounts and the incumbent book used for issuance. The swap changes existing deployed balances and earns fees on the vault’s own position; neither change is new depositor capital. Mint-before-swap followed by a whole-book trade can socialize trading losses. Conversely, simply feeding transformed amounts into current dual min-ratio math may donate surplus when the incumbent book is skewed. Specify and independently verify the issuance equation, rounding and fee attribution before coding; do not invent one-token NAV.

Charge swap/protocol/hook costs and price impact explicitly; preserve existing usage-fee policy without charging twice. Full-range deployment improves fee exposure, not guaranteed APR or net returns; trading costs, adverse selection and inventory risk remain.

Previews must project swap size/output, final price, credited shares and relevant fees under the same gate. Update ordinary previews **and** transition projections (`V/UniswapV4StandardExchangeInQueryTarget.sol:15–29,61–118`) and SY consumers. Existing `V/UniswapV4QuoteService.sol:138–145` contains legacy sum-based initial zap quoting: it is not a drop-in approved solution. Its hook handling is selective (`:19–57`); arbitrary/dynamic hooks need explicit support or fail-closed quotes.

Require deadline/minShares, meaningful swap-price/output bounds, actual-fill accounting, bounded computational work, authenticated callbacks, cross-entry reentrancy protection and zero unsettled PM deltas. Test malicious hooks, sandwich/skew cycles, donations, pretransfer credit/replay, refunds, mixed decimals, and native sync/settlement. `Common:669–670` currently uses near-global price limits; these alone are not economic protection. “BestEffort” is not exception isolation: `Common:734–738` directly calls rebalance; downstream reverts can propagate. Decide atomic required composition/deployment versus explicitly permitted deferred placement—never silently convert failed zap execution into success.

## 5. Test acceptance and evidence gaps

Observed tests cover dual bootstrap, blocked deposits, public rebalance, Multi and native routes. However, `T/UniswapV4StandardExchange_LocalLiquidBuffer.t.sol:148–163` tests balanced bootstrap and no refund, not repeated unilateral deployment. Its “deadband” helper permits an extra **25%/50% of total** (`:492–514`), insufficient for a tight target guarantee. Multi tests intentionally retain surplus (`T/UniswapV4StandardExchange_MultiJoinExit.t.sol:157–195`).

Require production registry-deployed regression sequences in both directions: repeated idle unilateral deposits grow L when feasible; strict policy/dust assertions; blocked deposits cause no PM operations; later idle behavior matches the chosen backlog policy; dual activation rejection/success; preview/transition/SY parity; real nested hook integration; native/WETH ordering; 6/9/18 decimals; accrued-fee conservation; incumbent/depositor economics and adversarial round trips; rollback on every limit/fill failure. Test zero liquidity, extreme ticks, 100%-sleeve policy, imported books and gas bounds. No test results are claimed.

## Sources, versions and confidence

Read CLAUDE, current family PRDs, alignment §24, canonical Crane architecture/deployment/testing/adversarial and V4 liquidity/flash-accounting skills, local testing/adversarial skills and catalog directly.

Context7 first: `/uniswap/v4-core`, unlock/settlement documentation. Primary sources accessed **2026-09-26**:
- https://raw.githubusercontent.com/Uniswap/v4-core/main/src/PoolManager.sol — `unlock`, settlement, swap and hook deltas; source pragma **0.8.26**.
- https://raw.githubusercontent.com/Uniswap/v4-periphery/main/src/libraries/LiquidityAmounts.sol — binding-token liquidity math.

Local compiler **0.8.35**, optimizer runs 1, no via-IR (`foundry.toml:29–36`); Crane package **0.1.0-public-preview** (`lib/crane/package.json:4`); local liquidity port pragma **^0.8.24**, comment references 0.8.30 compatibility. No V4-path `VENDOR.md` found; exact upstream port commit, deployed revision, runtime tool versions, full hook compatibility and exhaustive test coverage remain unverified. Remote `main` URLs are unpinned evidence, not version equivalence.

**Confidence:** high on root cause and supersession; medium on proposed architecture; economics/solver correctness unresolved pending explicit decisions and independent invariant proofs. No exploit is asserted proven.
