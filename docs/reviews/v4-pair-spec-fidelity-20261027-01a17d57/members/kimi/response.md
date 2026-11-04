# Kimi independent PairToken specification fidelity audit

## Verdict

**The report is not an accurate behavior specification of the supplied PairToken source and is not ready for a source-equivalent clean-room implementation.** It is a coherent, intentionally different vault design. Its own scope says that a PairToken source specification was not admitted, that the third-party source was not read, and that the report does not translate or reconstruct it (report `Authorization and scope`, lines 11-19; `Evidence`, lines 255-268). The comparison below confirms that this is not merely a wording gap: receipt valuation, minting, fees, redemption, deployment, and callback rules are different models.

The few important alignments are narrow: one transferable 18-decimal ERC-20, one Uniswap V4 pool position, a fixed range and zero salt, direct `PoolManager.unlock` use, and the vault contract as position owner. They do not make the report source-equivalent.

As an **independent-design brief**, the report is comparatively implementable because it defines state, equations, operation ordering, and failure cases. That is a separate judgment, not runtime or design validation. It depends on Crane/V2 evidence outside this bundle and carries explicitly rejected alternatives. It cannot be relabeled as the PairToken specification.

## Evidence and method

- Specification examined in full: `evidence/specification.md`, SHA-256 `15c6d7790aa1f8eca1c36ec0d147483359e2ff7d018c56ed8240e394d2c878e3`; original path `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md`.
- Source examined: `evidence/sourcify-sources.json` content as rendered in `evidence/sources.md`, SHA-256 `ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98`. The target is chain 4663, address `0x56C8c249d4c021e93635b120aC68A9a36eb01753`, Sourcify exact creation/runtime match; retrieval and verification metadata are in `evidence/manifest.md`.
- I read the complete specification, all of `src/pair/PairToken.sol`, and all 28 files in the supplied source bundle. I did not read peer responses.
- Source locators below use original `PairToken.sol` line numbers and symbols. Report locators use the snapshot's section and line numbers.
- This is static fidelity/completeness analysis only. Agreement or disagreement here is not a runtime correctness, security, or economic-safety claim.

### Classification

- **Contradiction:** the report requires behavior that the source does not implement.
- **Omission:** material source behavior is absent from the report.
- **Intentional departure:** a contradiction or omission the report expressly chooses as a new-design decision. This explains intent; it does not improve fidelity.
- Severity measures damage to a source-equivalent specification, not exploit likelihood.

## Findings

### F-01 - Critical - The receipt, valuation, and mint formulas are a different system

- **Report:** `Product`, `Terms`, and section `1. Receipt and mint` (lines 40-80) define internal liquidity `U`, offset `d = 9`, and `shares = floor(uReceived * (S + 10^9) / (U_before + 1))`; they reject price-based admission.
- **Source:** `PairToken.basket` (lines 221-231), `previewDeposit` (233-241), `_quoteShares` (500-519), and `deposit` (256-293). There is no stored `U` or offset 9. With `L = positionLiquidity()`, `sqrtP` the live price, `sqrtL/sqrtU` the full-range bounds, and `idle_i = currency_i.balanceOfSelf()` (less reserved native), the basket is:
  ```text
  r0 = SqrtPriceMath.getAmount0Delta(sqrtP, sqrtU, L, false) + idle0
  r1 = SqrtPriceMath.getAmount1Delta(sqrtL, sqrtP, L, false) + idle1
  ```
  These library calls round down; equivalently, for sorted prices `a <= b`, amount0 is `floor(floor(L * 2^96 * (b-a) / b) / a)` and amount1 is `floor(L * (b-a) / 2^96)` (`SqrtPriceMath.getAmount0Delta/getAmount1Delta`; `FullMath.mulDiv`).
- **Observed mint behavior:** for `S > 0` and not both reserves zero:
  ```text
  if r0 == 0: shares = floor(amount1 * S / r1), used = (0, amount1)
  if r1 == 0: shares = floor(amount0 * S / r0), used = (amount0, 0)
  otherwise:
      s0 = floor(amount0 * S / r0)
      s1 = floor(amount1 * S / r1)
      shares = min(s0, s1)
      used0 = min(amount0, ceil(shares * r0 / S))
      used1 = min(amount1, ceil(shares * r1 / S))
  ```
  If `S == 0` or both reserves are zero, quoted shares are `floor(sqrt(amount0 * amount1))` and both offered amounts are used. Actual minting is not based on the callback's liquidity increase.
- **Conflict/consequence:** this changes the claim's economic meaning, price exposure, rounding, inflation defense, and every mint result. An implementer following the report would not reproduce PairToken.
- **Smallest correction:** replace `U`/offset math with the exact basket and `_quoteShares` branches, including live-price and idle-balance inputs and floor/ceil rounding. Mark the report's existing formula as an intentional alternative, not a source observation of PairToken.

### F-02 - Critical - Genesis and dead-share requirements are missing

- **Report:** sections `1` and `8` (lines 64-80 and 202-228) require zero-liquidity/zero-share/min-share reverts but give no PairToken genesis ceremony.
- **Source:** `_quoteShares` (500-519) and `deposit` (256-293), constants at lines 60-67. `DEAD_SHARES = 1e3` and `DEAD = 0x000000000000000000000000000000000000dEaD`. At `S == 0`, a geometric quote `<= 1000` reverts `BadGenesis`; after pulling and `_addAll`, `added == 0` also reverts `BadGenesis`. Otherwise the vault mints 1000 shares to `DEAD`, then mints `quotedShares - 1000` to the recipient. The general `minShares` check occurs before this subtraction.
- **Conflict/consequence:** omitting this changes initial supply, recipient proceeds, minimum-acceptance behavior, and permanent residual ownership. The report's last-burn residual discussion is not a substitute for dead shares.
- **Smallest correction:** add the exact geometric genesis branch, 1000-unit threshold, actual-position-opening check, dead mint, post-check subtraction, and event amount semantics.

### F-03 - Critical - Fees are compounded and protocol-carved, not separately escrowed

- **Report:** `Terms`, section `3. Fees`, and related invariants (lines 46-62, 90-129, 230-249) require `Q = 2^128`, per-account indexes/debts/unclaimed escrow, `claimFees`, no fee ownership by the share, and no usage-fee take.
- **Source:** `compound`, `_compound`, `_carve`, `_ratioSwap`, and `_deployInLock` (PairToken lines 412-497 and 576-608). There is no fee index, debt, unclaimed balance, escrow liability, remainder, or `claimFees`. A zero-delta `modifyLiquidity` collects fees. If factory `feeManager()` is nonzero and `protocolFeeBps() > 0`, the source computes `protocol_i = floor(fees_i * protocolFeeBps / 10_000)` and attempts `notify` in kind. Native notify carries value; ERC20 notify follows an approval. Failure is best-effort: it returns zero for the carved amount, resets a failed ERC20 approval where applicable, and does not block the user action.
- **Observed compounding:** after collection/carving, idle balances above `DUST = 1000` enter `_ratioSwap` and `_deploy`; fees and other idle funds are swapped as needed and added back to the same position. This runs on permissionless `compound()` and at the start of every deposit and redeem route.
- **Conflict/consequence:** the report removes the source's actual fee yield from the share and invents a separate claims system, while omitting the real protocol-fee path. This is an intentional departure (report lines 90-129 and 281-286), but wholly non-equivalent.
- **Smallest correction:** replace the fee-escrow model with collection, gross-fee return values, protocol carve, best-effort failure behavior, idle deployment, `Compounded` event fields, and the exact permissionless/call-site ordering.

### F-04 - High - The compounding ratio-swap algorithm and caps are unspecified

- **Report:** section `3` says fee compounding is rejected and gives no source algorithm; section `4` rejects vault swaps on entry.
- **Source:** `_ratioSwap` (PairToken lines 469-497). It computes liquidity supportable by both idle amounts, rounded-up required amounts `need0/need1`, and positive leftovers. It values `left0` in token1 using two floor `mulDiv` steps by `sqrtP / 2^96`; token0 is selected when `left0In1 >= left1`, otherwise token1. A selected leftover `<= DUST` produces no swap. Otherwise `swapAmount = leftover / 2` (floor). If active pool liquidity is zero, no swap; otherwise it is capped by:
  ```text
  reserve = active-liquidity amount on the input side at the current price
  cap = floor(floor(reserve * factory.maxZapBps() / 10_000) / 4)
  swapAmount = min(swapAmount, cap)
  ```
  `_deployInLock` performs an exact-input swap with the extreme price limit, resolves deltas, then adds all supportable idle liquidity at the post-swap price.
- **Conflict/consequence:** a clean-room implementer cannot reproduce when or how fees/idle balances change the position or price.
- **Smallest correction:** add this algorithm, including tie-breaking, rounding, dust threshold, active-pool reserve calculation, quarter cap, empty hook data, and post-swap add ordering.

### F-05 - Critical - Redemption and retention are not the report's target-only exit

- **Report:** section `5. Share exit` (lines 143-161) requires `uOut = floor(shares * (U+1)/(S+10^9))`, removal of exactly that liquidity, sale of only removed opposing principal, no idle/donation inclusion, and one configured target asset.
- **Source:** `redeem`, `redeemZap`, and `_redeemToSelf` (PairToken lines 351-409). There is no configured target and no stored `U`. Both routes first compound. For pre-burn supply `S`:
  ```text
  payoutShares = floor(shares * (10_000 - 10) / 10_000)
                   = floor(shares * 9_990 / 10_000)
  liqOut = floor(positionLiquidity * payoutShares / S)
  amount0 = removed0 + floor(idle0 * payoutShares / S)
  amount1 = removed1 + floor(idle1 * payoutShares / S)
  ```
  `liqOut` is downcast to `uint128`. Shares are burned before removal. `redeem` pays both currencies and enforces `min0/min1`; `redeemZap` exact-input swaps the unwanted redeemed leg through the same pool and pays the wanted leg plus swap output, enforcing only aggregate `minOut`. Reversion undoes the whole call. The 10 bps not paid remain in the position/idle balances for remaining holders.
- **Conflict/consequence:** formulas, asset choice, retention, residual lifecycle, slippage controls, and inclusion of idle balances all differ. The report's floor-only residual explanation also omits systematic retention and genesis dead shares.
- **Smallest correction:** specify both redemption routes and the exact payout formula, burn/remove/swap/pay order, idle inclusion, 10 bps retention, and actual errors/minimum checks; remove offset-based target-only requirements from the PairToken specification.

### F-06 - High - Initialization binds full range and zero salt, not a configurable target/range

- **Report:** section `2` (lines 82-88) says initialization binds pool key, selected ticks, salt, and target currency; section `6` places these in diamond storage.
- **Source:** `initialize`, `positionLiquidity`, and `_modify` (PairToken lines 138-153, 214-218, 610-626). Initialization requires a nonzero manager and one-shot `initialized == false`; it sets `factory = msg.sender`, stores the key and `poolId = keccak256(abi.encode(key))`, and sets `tickLower = TickMath.minUsableTick(key.tickSpacing)` and `tickUpper = TickMath.maxUsableTick(key.tickSpacing)`. Every position call uses `salt = bytes32(0)`. There is no target-currency field. Name and symbol are also initialized.
- **Conflict/consequence:** a custom-range/target implementation would expose different state and position identity. No later source call changes the key/range, which is a limited alignment.
- **Smallest correction:** document the one-shot initializer, factory-caller observation, derived full-range ticks, hard-coded zero salt, lack of target configuration, and actual public getters.

### F-07 - High - Entry, zap, native handling, and token transfer behavior are incomplete or contradicted

- **Report:** section `4` and deposit sequence (lines 131-141, 204-216) forbid a vault entry swap and mint from received liquidity. It gives no PairToken zap constraints or detailed native behavior.
- **Source - paired deposit:** `deposit` (256-293) reserves `msg.value`, compounds, snapshots basket/supply, quotes and checks `shares != 0 && shares >= minShares`, pulls the quoted amounts, adds all idle liquidity, handles genesis, mints, and refunds unused native to `msg.sender`. ERC20 `_pull` (661-668) balance-measures actual receipt and updates `used0/used1`, but does not recompute the already quoted shares. Unused ERC20 is not pulled. A native leg is currency0 and requires `msg.value == amount0`; otherwise `NativeMismatch` (`_checkNative`, 651-658). `_reservedNative` excludes the current native deposit/refund from idle accounting. Native refund failure reverts `TransferFailed`.
- **Source - zap:** `zapDeposit` (308-348) is a public single-leg route. It requires existing supply and both basket reserves nonzero; validates `tokenIn`; requires `0 < amountIn <= floor(reserveIn * factory.maxZapBps()/10_000)` or reverts `ZapTooLarge`; pulls the input and swaps exactly `amountIn/2`. Absolute tick movement above `factory.maxZapTickMove()` reverts `ZapMovesPrice`. Shares are `min(floor(used0*S/r0), floor(used1*S/r1))` against the pre-zap basket and pre-zap supply, then checked against `minShares`.
- **Conflict/consequence:** omitting the zap removes a material money path; following the report's no-swap rule intentionally changes the product. Missing balance-measurement and native reservation/refund rules prevent equivalent boundary behavior.
- **Smallest correction:** add both routes with exact ordering and formulas, factory caps, tick check, pre-zap quote basis, native `msg.value` rules, balance-measured ERC20 receipt, and refund/failure semantics. Keep the report's no-zap rule only in a clearly separate alternative design.

### F-08 - High - Donations, previews, and `getRate` do not match

- **Report:** `Product`, sections `5` and `7` (lines 40-44, 143-161, 177-200) say shares do not own donations or idle escrow and define a normalized, target-denominated one-share `getRate` with post-removal sale simulation and enumerated reverts.
- **Source:** `_idle`, `basket`, `previewDeposit`, and `previewRedeem` (PairToken lines 221-250 and 646-649). Native and ERC20 transfers to the vault become idle balances (apart from transient native reservation), enter `basket`, affect deposit quotes and redemption, and may be compounded. Pending uncollected pool fees are not in `basket`. `previewDeposit` quotes against current basket/supply without compounding. `previewRedeem` returns `(0,0)` when supply or shares is zero; otherwise it returns both basket legs using the 10-bps-retained payout formula. It does not simulate a redeemZap sale.
- **Conflict/consequence:** the report's exclusion of donations is directly false for PairToken. There is no `getRate`, no target-normalized rate, no post-removal preview, and no report-specified hook fail-closed domain. An integrator using the report would call nonexistent functions and misprice deposits/redemptions.
- **Smallest correction:** document `basket` and both real previews, idle/donation inclusion and pending-fee exclusion, and remove `getRate` as a PairToken requirement. If desired for a new design, keep it explicitly additive.

### F-09 - Medium - ERC20 transfers and allowances are plain, with no fee synchronization

- **Report:** section `3` and invariant 11 (lines 110-123 and 247) require transfer-time crystallization and sender-retained unclaimed fees.
- **Source:** `approve`, `transfer`, `transferFrom`, `_transfer` (PairToken lines 156-181). Approval overwrites allowance and emits `Approval`; infinite allowance is not decremented, while other allowances subtract and underflow on overspend. Transfers reject a zero recipient, subtract from sender, add to recipient unchecked, and emit `Transfer`. They do not compound, collect, sync, or alter position/supply.
- **Conflict/consequence:** the report invents state transitions that do not exist and omits observable ERC20 allowance/failure behavior.
- **Smallest correction:** specify the plain ERC20 operations and remove all transfer-time fee-debt rules from the PairToken document.

### F-10 - Critical - Deployment, callback arming, reentrancy, and factory boundaries differ

- **Report:** section `6. Diamond boundary` (lines 163-175) requires a Crane diamond, facet/repo storage, CREATE3/DFPkg/registry deployment, and a single-use armed flag binding caller, receiver, pool, range, salt, operation, and budgets.
- **Source:** PairToken NatSpec (lines 35-44) describes an EIP-1167 clone deployed by `PairTokenFactory`; state is ordinary contract storage. `_unlock` directly calls `poolManager.unlock` (546-548), and `unlockCallback` (550-574) checks only `msg.sender == poolManager`. ABI-decoded `Op.Add/Remove/Collect/Deploy` selects behavior; there is no armed flag or the report's bound context. Operations use stored key/ticks and zero salt. The callback settles/takes deltas through `_modify` and `_resolve`; `IPoolManager.unlock` documents final `CurrencyNotSettled` enforcement.
- **Guards:** `nonReentrant` (PairToken lines 113-117) protects paired deposit, zap deposit, both redeems, and public compound. It does not decorate ERC20 methods, initialize, views, receive, or the callback. `receive()` accepts native currency. `factory` is used for `feeManager`, `maxZapBps`, `maxZapTickMove`, and `protocolFeeBps`; no factory implementation is supplied. The declared `NotFactory` error is not used by any function in this file.
- **Conflict/consequence:** only direct unlock and `address(this)` position ownership align. An implementation following the report would have different deployment, storage, access control, and integration surfaces.
- **Smallest correction:** replace the Crane package requirements with the actual clone-oriented contract boundary and guards; specify each callback operation and delta settlement without inventing arming. Keep factory/fee-manager behavior explicitly dependency-bound.

### F-11 - Medium - Observable errors, events, and public query surface are not specified

- **Report:** no complete API appendix; sections `4-8` prescribe a different error and query surface.
- **Source:** public getters and functions enumerated below; events `Transfer`, `Approval`, `Deposit`, `Redeem`, and `Compounded`; errors `AlreadyInitialized`, `NotFactory`, `NotPoolManager`, `Reentrancy`, `BadGenesis`, `MinShares`, `MinOut`, `ZapTooLarge`, `ZapMovesPrice`, `BadToken`, `NativeMismatch`, `TransferFailed`, and `ZeroAddress`. `Deposit` for genesis emits recipient shares after dead-share subtraction; `Redeem` on redeemZap emits pre-swap two-leg amounts, not the final single-leg output.
- **Conflict/consequence:** callers cannot build an exact interface, decode lifecycle events, or reproduce observable failure behavior from the report.
- **Smallest correction:** add a public API/events/errors appendix with argument order, return values, and the special event semantics above. This is a specification addition, not a request to change source.

### F-12 - High - The proposed sequences and invariants test the alternative, not PairToken

- **Report:** sections `8` and `9` (lines 202-249) order fee-index settlement around `U` changes and prescribe invariants for offset minting, fee escrow, target-only exit, and `getRate`.
- **Source:** actual order is compound -> quote/pull/deploy/mint for deposits; compound -> burn/remove/(optional swap)/pay for exits; plain transfers; no `U`, fee index, escrow, or `getRate` (`deposit` 256-293, `zapDeposit` 308-348, `_redeemToSelf` 391-409).
- **Conflict/consequence:** passing the report's tests would not establish PairToken equivalence, and a source-equivalent implementation would fail many of them by design.
- **Smallest correction:** rewrite sequences and invariant requirements around the source formulas and routes above. Do not merely append source tests to the existing alternative invariants.

## Coverage matrix - every report section

| Report section (snapshot lines) | Examined | Fidelity/completeness result |
| --- | --- | --- |
| `Question` (3-9) | Yes | Explicitly requests a new price-free design and says not to reconstruct PairToken; not a source-specification question. |
| `Authorization and scope` (11-19) | Yes | Expressly excludes the requested source reconstruction and forbids later source gap-filling; confirms intentional departure. |
| `Participation` (21-34) | Yes | Process metadata only; no PairToken behavior. |
| `Conclusions` framing (36-38) | Yes | Calls the text a specification for a later agent, not a source audit; no runtime evidence. |
| `Product` (40-44) | Yes | Partial: one pool/position and transferable ERC20 align. Diamond, target-only exit, and separate fee escrow contradict source. |
| `Terms` (46-62) | Yes | `S` and 18 decimals have analogues. `U`, `d=9`, fee index/debt/escrow/remainder, and target decimals do not exist. |
| `1. Receipt and mint` (64-80) | Yes | Critical contradiction; source uses live-price basket and geometric/pro-rata mint, not liquidity-unit offset math (F-01/F-02). |
| `2. One share, one range` (82-88) | Yes | Partial: one immutable pool position aligns. Source is full-range, zero-salt, no target; idle donations are included (F-06/F-08). |
| `3. Fees` (90-129) | Yes | Critical contradiction plus omissions: source auto-compounds and carves protocol fees; all escrow/claim mechanics are invented (F-03/F-04/F-09). |
| `4. Entry` (131-141) | Yes | Paired deposit/minShares/refund concept partially aligns; mint basis and no-zap rule contradict source; native/ERC20 boundary omitted (F-07). |
| `5. Share exit` (143-161) | Yes | Critical contradiction: source has dual and single-leg exits, pro-rata basket, idle inclusion, and 10 bps retention (F-05). |
| `6. Diamond boundary` (163-175) | Yes | Only direct unlock, callback on vault, and contract ownership align. Diamond/DFPkg/storage/armed flag do not (F-10). |
| `7. getRate` (177-200) | Yes | No source counterpart. Real `basket`, `previewDeposit`, and `previewRedeem` are omitted (F-08). |
| `8. Sequences` (202-228) | Yes | Alternative ordering, not PairToken ordering (F-01-F-07/F-12). |
| `9. Invariants a later agent must test` (230-249) | Yes | Mostly inapplicable to source; immutable pool/range/salt and unlock settlement are the limited overlaps (F-12). |
| `What this does not deliver` (251-253) | Yes | Explicitly confirms intentional omissions/design changes, including no entry zap; several statements are opposite to PairToken. |
| `Evidence` (255-268) | Yes | Contains V2/Crane evidence, no PairToken source evidence; says excluded source was not read. |
| `Coverage` (270-279) | Yes | Accurately records third-party source as not examined; therefore cannot establish source fidelity. |
| `Disagreement and missing responses` (281-286) | Yes | Confirms compounding and zap were consciously rejected alternatives, not source observations. |
| `Advisory review` (288-295) | Yes | Process metadata only; advisory review was of the alternative draft, not source fidelity. |
| `Recommendations` (297-301) | Yes | `Do not add a vault zap` directly conflicts with PairToken's public `zapDeposit`. |
| `Limitations` (303-309) | Yes | Static limitations noted; no claim of source comparison or runtime verification. |
| `Publication` (311-321) | Yes | Process metadata only; no behavioral coverage. |

## Coverage matrix - PairToken public/external surface

“Covered” means faithfully specified for PairToken, not merely mentioned as an alternative.

| Source entrypoint or getter | Report coverage | Required source behavior to add/correct |
| --- | --- | --- |
| `initialize` (138-153) | Contradicted/partial | One-shot manager/key/name/symbol setup, factory caller, derived full-range ticks and poolId; no target. |
| `name`, `symbol`, `decimals` | Partial | Only 18 decimals is documented; metadata initialization/getters are omitted. |
| `totalSupply`, `balanceOf`, `allowance` | Partial | `S` is analogous to totalSupply; actual mappings and allowance semantics are omitted. |
| `approve`, `transfer`, `transferFrom` (156-172) | Contradicted | Plain ERC20 behavior; no fee sync; infinite allowance exception and zero-recipient check (F-09). |
| `BPS`, `DEAD_SHARES`, `RETENTION_BPS`, `DUST`, `DEAD` getters | Missing | Constants `10_000`, `1e3`, `10`, `1e3`, and dead address respectively. |
| `factory`, `poolManager`, `poolId`, `tickLower`, `tickUpper`, `initialized` | Partial/contradicted | Actual clone state and initialization values, not diamond repo/target state. |
| `poolKey`, `token0`, `token1` (201-212) | Partial | Stored key and unwrapped currency addresses; no target abstraction. |
| `positionLiquidity` (214-218) | Partial | Direct manager read for `(address(this), ticks, salt=0)`; not a stored `U` ledger. |
| `basket` (221-231) | Missing | Live-price full-range principal plus both idle balances, rounded down (F-01/F-08). |
| `previewDeposit` (233-241) | Missing | Exact `_quoteShares` result against current basket/supply; no compound simulation. |
| `previewRedeem` (243-250) | Missing | Two-leg retained pro-rata quote; zero-on-zero-supply/zero-shares behavior. |
| `deposit` (256-293) | Contradicted/partial | Compound -> basket quote -> pull -> add all -> genesis -> mint -> native refund (F-01/F-02/F-07). |
| `zapDeposit` (308-348) | Directly rejected | Existing-supply single-leg half-swap, caps/tick bound, pre-zap basket mint (F-07). |
| `redeem` (351-364) | Contradicted | Two-leg payout with retention and independent `min0/min1`. |
| `redeemZap` (366-389) | Partial concept, wrong mechanics | Both-leg retained redemption then same-pool unwanted-leg swap and aggregate `minOut` (F-05). |
| `compound` (412-445) | Contradicted/missing | Permissionless fee collection, protocol carve, ratio swap, liquidity add, event (F-03/F-04). |
| `unlockCallback` (550-574) | Contradicted/partial | Manager-only check and four op branches; no armed flag; exact returned ABI data and settlement. |
| `receive` (133) | Missing | Accepts native deposits/donations; idle accounting includes them outside reservation. |
| `getRate`, `claimFees`, `redeemTarget` | Report-only | No PairToken counterparts; must not be presented as source API. |

The report also omits the exact public event/error surface summarized in F-11.

## Dependency coverage

- **Examined in depth for behavior:** `PairToken.sol`; `IPoolManager.sol`; `IUnlockCallback.sol`; `PoolKey.sol`; `PoolId.sol`; `Currency.sol`; `BalanceDelta.sol`; `TickMath.sol`; `StateLibrary.sol`; `Position.sol`; `SqrtPriceMath.sol`; `FullMath.sol`; `LiquidityAmounts.sol`; `PriceMath.sol`.
- **Supporting supplied files also read:** `IHooks.sol`, `IERC6909Claims.sol`, `IProtocolFees.sol`, `IExtsload.sol`, `IExttload.sol`, `IERC20Minimal.sol`, `CustomRevert.sol`, `SafeCast.sol`, `BitMath.sol`, `FixedPoint128.sol`, `LiquidityMath.sol`, `UnsafeMath.sol`, `FixedPoint96.sol`, and `BeforeSwapDelta.sol`.
- **Not supplied, therefore not examined:** PairTokenFactory implementation, fee-manager implementation, PoolManager implementation behind the interface, hook implementations, pool token implementations, EIP-1167 deployment transaction, and chain state. The factory/fee-manager interface observations above come only from PairToken's declared interfaces and calls.
- Hook behavior is not assumed away by PairToken: it passes empty hook data to modify/swap, while `IPoolManager`/`IHooks` document that hooks can affect deltas. The report's special `getRate` hook restrictions are not source requirements.

## Clean-room readiness and provenance

**Source-equivalent readiness: NOT READY.** The blocking corrections are F-01 through F-12, especially the core mint, fee, redemption, and architecture replacements. Adding a few caveats cannot repair the document; its main behavioral sections must be rewritten around PairToken.

**Independent-design usability: potentially usable as a separate new-vault brief, subject to its own review.** Its formulas and sequences are substantive, but this audit does not prove that design correct, and its Crane/V2 dependencies were not the target evidence here. It must remain clearly labeled as an intentional alternative rather than a PairToken handoff.

**Provenance is not legal clearance.** The original report records no PairToken source exposure and explicitly declines reconstruction. This audit necessarily compares exposed source; the manifest also states that the evidence is not an unexposed-implementer handoff. Source exposure, lack of exposure, or documentary accuracy alone does not establish legal authorization or its absence. No speculative licensing conclusion is made here. A handoff process should preserve these provenance facts and obtain whatever separate authorization the project requires.

## Outstanding blockers and limitations

1. Replace the alternative `U`/offset, fee escrow, target-only redemption, and diamond requirements with source behavior.
2. Add genesis/dead shares, retention, both zap routes, idle/donation accounting, compounding/protocol fees, native/ERC20 boundaries, and exact public APIs/events/errors.
3. Rewrite sequences and invariants so they test PairToken rather than the rejected design.
4. Keep external factory, fee-manager, manager, hook, and token behavior bounded by the supplied interfaces; do not invent unavailable implementation details.
5. This review used only the frozen snapshot. It ran no tests, transactions, bytecode reconstruction, or chain queries and makes no runtime correctness or security claim. Live source and external dependencies can change after retrieval.
