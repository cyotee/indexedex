## Identity

- Member label: `kimi`
- Profile: research
- Phase: initial independent response
- Owned path: `members/kimi/response.md`
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Other Native identity metadata: not exposed
- Peers read before submission: no
- Context: fresh

## Question and targets

Question: Does WeirVaults' own internal accounting resolve the B-02 losses, or does a caller-moved pool price still leave that loss with the other holders?

Targets read: `WeirVaults.sol` (`deposit`, `withdraw`, `compound`, `unlockCallback`, `_deposit`, `_withdraw`, `_compound`, `_balance`, `_swap`), `LiquidityAmounts.sol`, B-02 in `IMPLEMENTATION_PLAN_BLOCKERS.md`, APEX-2026-023 and APEX-2026-024, and FS-OWN-10, FS-OWN-12, FS-OWN-14, FS-OWN-15, and FS-MONEY-01 in the full-spread PRD.

Short answer: Weir does not resolve the APEX-2026-023 maintenance-placement loss. Its liquidity-denominated deposit issuance puts a new depositor's placement shortfall on that depositor, but permissionless compounding of already-owned idle at the live price leaves the loss with existing holders. A later compound can likewise place at a price moved by Weir's own withdrawal swap. Weir does resolve the narrow APEX-2026-024 whole-balance-dump shape because its one-token withdrawal swaps only the withdrawn unwanted-token amount, not the vault's whole opposing balance.

## Evidence

### Source observations

1. **Permission and ordering.** `compound` is external and documented as callable by anyone (`contracts/protocols/strategy/weir/WeirVaults.sol:207-211`). `unlockCallback` calls `_compound` before `_deposit` and before `_withdraw` (`:229-236`). Thus a deposit can first place existing vault assets at the current price; a withdrawal compounds before, not after, its own swap.

2. **Live-price placement.** `_deposit` optionally calls `_balance`, then reads `poolManager.getSlot0` and passes that live `sqrtP` to `getLiquidityForAmounts` (`:252-262`). `_compound` independently reads live `getSlot0` to size the reinvestment of harvested fees plus idle (`:355-368`), then adds the resulting liquidity without minting shares (`:370-376`). `createVault` uses `TickMath.minUsableTick` and `maxUsableTick` (`:153-154`).

3. **No price-reference bound in the swap.** `_swap` is exact-input and sets `sqrtPriceLimitX96` to `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1` (`:413-425`). There is no comparison with the pre-operation price, a TWAP, or any other reference in this function or its callers. `_balance` reads the live price only to calculate the half-excess input (`:391-405`); it is not a price check.

4. **Withdrawal swap size.** `_withdraw` computes liquidity and idle pro rata to the withdrawn shares (`:289-311`). For `zapTo == 1`, it swaps `uint256(net1)`; for `zapTo == 2`, it swaps `uint256(net0)` (`:313-320`). Those nets are the withdrawn position delta plus the withdrawn pro-rata idle. The source does not sell a shortfall or the vault's whole opposing balance.

5. **What `_balance` swaps.** `_deposit` passes the depositor's declared `p.amount0` and `p.amount1` into `_balance` (`:248-252`). `_balance` sells half the value excess of those inputs at the live pre-swap price (`:391-405`). It does not read or spend vault idle. `_deposit` then rereads the post-swap live price for placement (`:255-262`).

6. **Share denominator.** For existing supply, `frame.shares = frame.liq * v.totalShares / v.liquidity` (`:269`). Idle is absent from that denominator. Compound adds liquidity without changing supply, whereas a deposit mints shares for its added liquidity.

7. **Amount formulas.** In range, `LiquidityAmounts.getLiquidityForAmounts` takes the smaller of token0-derived and token1-derived liquidity (`contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol:26-40`). `getAmountsForLiquidity` performs the reverse conversion (`:53-66`). Consequently, strictly one-sided in-range input with zero of the other token produces zero liquidity.

8. **Audit record.** APEX-2026-023 identifies live-`slot0` maintenance placement, including an external push and a trailing placement after the vault's own redemption swap, and says honest LPs bear the loss pro rata (`IndexedEx_DiffReview_aca16198-2ba07631.md:1528-1555`, `:1582-1587`). APEX-2026-024 separately identifies selling the whole opposing balance rather than only the required amount, with staying holders losing (`:1605-1634`, `:1665-1674`).

### What the PRD already copies

Selecting Weir is not itself a new accounting rule:

- FS-MONEY-01 already copies the absolute entry-swap limit: “Its price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`,” with no tighter cap (`UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:265`).
- FS-MONEY-01 already copies the liquidity-only issuance denominator and explicitly excludes idle (`:267`), and already copies compound-before-deposit and compound-before-withdraw (`:268`).
- FS-MONEY-01 already copies harvesting and reinvesting the remainder plus idle (`:269`). FS-OWN-14 separately says “`compound()` deploys booked idle” and “Any address may call it” (`:76`), while adding the PRD's own no-fee return sentence.
- FS-MONEY-01 already copies pro-rata liquidity and idle withdrawal, but expressly does not install Weir's `zapTo` (`:270`). FS-OWN-15 says redemption “takes deployed liquidity first and may swap through the pool” (`:78`). Those sentences do not expressly copy Weir's exact unwanted-net swap quantity, although they also do not specify a whole-balance dump.
- FS-OWN-12 requires local-balance movement after every deposit, withdrawal, and compound (`:72`); it states no price reference. FS-OWN-10 says no replacement zap view, cap, tick bound, or hidden constant is added (`:64`).

### Accounting identities

The simulations use the infinite-range, in-range limit of the library, with `s = sqrt(P)` and `P0 = 1`:

```text
dL(P, a0, a1) = min(a0 * s, a1 / s)
placed(P, dL) = (dL / s, dL * s)
recovered(P0, dL) = (dL, dL)
shortfall = placed0 + placed1 - recovered0 - recovered1
          = dL * (s + 1/s - 2)
          = dL * (s - 1)^2 / s
```

The last line is exactly the APEX-2026-023 expression `dL * (sqrtP' - sqrtP0)^2 / sqrtP'` when `P0=1`. It matches the direct amount formulas in this infinite-range limit. This identity does not depend on a constant-product swap approximation. It measures the placed liquidity only; unplaced input remains an asset.

For a new deposit into existing liquidity `L` and supply `S`, Weir mints `dS = dL * S / L`. At `P0=1`, full-range value in token1 units is `2L`. After the price returns, existing holders own `L/(L+dL)` of `2(L+dL) = 2L`, so their value is unchanged in this fixture. The depositor owns the new `2dL` position value plus unplaced input and bears the placement shortfall. By contrast, compound mints no shares, so the same shortfall on already-owned idle remains with all current holders.

For redemption, the swap-size identity is also independent of the pool approximation: Weir sells only the withdrawn `net1` or `net0`. In the stylized whole-dump comparison, if the exiter receives fraction `f` of actual post-dump assets, staying value after return to `P0=1` is `(1-f)(B0 + wholeSwapOut)`, versus `(1-f)(B0+B1)` when the staying opposing balance is not sold. The difference is `(1-f)(B1-wholeSwapOut)`.

### Executed Python simulation

Script: `docs/research/se-weir-b02-accounting-20261101/members/kimi/sim/accounting_sim.py`

Command: `python3 docs/research/se-weir-b02-accounting-20261101/members/kimi/sim/accounting_sim.py`

Exit status: `0`

Numeric output:

```text
FIXTURE: P0=1; infinite-range LiquidityAmounts limit; L=S=1000; no fees or rounding
CASE 1A: external push; caller deposit of 100 token0 + 100 token1
P'=2 existing_L=1000 existing_supply=1000
  placement dL=70.710678 placed0=50.000000 placed1=100.000000 recovered0=70.710678 recovered1=70.710678 shortfall_token1_at_P0=8.578644 audit_IL=8.578644
  minted_shares=70.710678 left0_refund=50.000000 left1_refund=0.000000 existing_loss=0.000000 caller_loss=8.578644 existing_share_of_loss=0% caller_share_of_loss=100%
P'=4 existing_L=1000 existing_supply=1000
  placement dL=50.000000 placed0=25.000000 placed1=100.000000 recovered0=50.000000 recovered1=50.000000 shortfall_token1_at_P0=25.000000 audit_IL=25.000000
  minted_shares=50.000000 left0_refund=75.000000 left1_refund=0.000000 existing_loss=0.000000 caller_loss=25.000000 existing_share_of_loss=0% caller_share_of_loss=100%
CASE 1B: same pushed placement of already-owned idle; compound mints no shares
P'=2 idle dL=70.710678 placed0=50.000000 placed1=100.000000 recovered0=70.710678 recovered1=70.710678 shortfall_token1_at_P0=8.578644 audit_IL=8.578644
  idle_left0=50.000000 idle_left1=0.000000 existing_holders_loss=8.578644 compound_caller_loss=0.000000 existing_holder_share_of_loss=100%
P'=4 idle dL=50.000000 placed0=25.000000 placed1=100.000000 recovered0=50.000000 recovered1=50.000000 shortfall_token1_at_P0=25.000000 audit_IL=25.000000
  idle_left0=75.000000 idle_left1=0.000000 existing_holders_loss=25.000000 compound_caller_loss=0.000000 existing_holder_share_of_loss=100%
CASE 1C: strictly one-sided idle has zero other-side amount
P'=2 token0_only dL=0.000000 placed0=0.000000 placed1=0.000000 recovered0=0.000000 recovered1=0.000000 shortfall_token1_at_P0=0.000000 audit_IL=0.000000
P'=2 token1_only dL=0.000000 placed0=0.000000 placed1=0.000000 recovered0=0.000000 recovered1=0.000000 shortfall_token1_at_P0=0.000000 audit_IL=0.000000
P'=4 token0_only dL=0.000000 placed0=0.000000 placed1=0.000000 recovered0=0.000000 recovered1=0.000000 shortfall_token1_at_P0=0.000000 audit_IL=0.000000
P'=4 token1_only dL=0.000000 placed0=0.000000 placed1=0.000000 recovered0=0.000000 recovered1=0.000000 shortfall_token1_at_P0=0.000000 audit_IL=0.000000
CASE 2: withdraw zap moves P0 to P'; following compound places 100+100 at P'
  CP approximation: zero fees; pool depth chosen so the withdrawn-net swap reaches P'
P'=2 pool_reserve_each_at_P0=1609.475708 withdrawn_token1_swapped=666.666667 token0_out=471.404521 whole_vault_token1=1000.000000
  trailing_idle dL=70.710678 placed0=50.000000 placed1=100.000000 recovered0=70.710678 recovered1=70.710678 shortfall_token1_at_P0=8.578644 audit_IL=8.578644
  swap_is_withdrawn_slice_only=yes; remaining_holder_trailing_loss=8.578644; redeemer_already_exited=yes
P'=4 pool_reserve_each_at_P0=666.666667 withdrawn_token1_swapped=666.666667 token0_out=333.333333 whole_vault_token1=1000.000000
  trailing_idle dL=50.000000 placed0=25.000000 placed1=100.000000 recovered0=50.000000 recovered1=50.000000 shortfall_token1_at_P0=25.000000 audit_IL=25.000000
  swap_is_withdrawn_slice_only=yes; remaining_holder_trailing_loss=25.000000; redeemer_already_exited=yes
CASE 3: Weir withdrawn-net swap versus stylized 024 whole-opposing-balance dump
  Same exit fraction 2/3 and same non-binding MIN/MAX limit; CP approximation, zero fees
  Whole-dump shape pays the exiter 2/3 of actual post-dump assets; stayer owns the rest
P'_Weir=2 Weir_swap_in=666.666667 Weir_swap_out=471.404521 whole_swap_in=1000.000000 whole_swap_out=616.781257 whole_post_price=2.628680
  stayer_value_after_return_P0_Weir=666.666667 stayer_value_after_return_P0_whole=538.927086 whole_dump_stayer_loss=127.739581
P'_Weir=4 Weir_swap_in=666.666667 Weir_swap_out=333.333333 whole_swap_in=1000.000000 whole_swap_out=400.000000 whole_post_price=6.250000
  stayer_value_after_return_P0_Weir=666.666667 stayer_value_after_return_P0_whole=466.666667 whole_dump_stayer_loss=200.000000
CASE 4: _balance half-excess on caller input 100+100 at displaced live price
  CP approximation: zero fees, k=100000000; placement uses post-swap live price
P'_before_balance=2 caller_token0_swapped=25.000000 caller_token1_out=49.823846 post_swap_price=1.985933 n0=75.000000 n1=149.823846
  post_balance_placement dL=105.692338 placed0=75.000000 placed1=148.944938 recovered0=105.692338 recovered1=105.692338 shortfall_token1_at_P0=12.560262 audit_IL=12.560262
  minted_shares=105.692338 vault_idle_used_by_balance=0 price_reference_check=none existing_holder_loss_from_issuance=0.000000
P'_before_balance=4 caller_token0_swapped=37.500000 caller_token1_out=148.883375 post_swap_price=3.940668 n0=62.500000 n1=248.883375
  post_balance_placement dL=124.069479 placed0=62.500000 placed1=246.291770 recovered0=124.069479 recovered1=124.069479 shortfall_token1_at_P0=60.652812 audit_IL=60.652812
  minted_shares=124.069479 vault_idle_used_by_balance=0 price_reference_check=none existing_holder_loss_from_issuance=0.000000
IDENTITY: placement shortfall = placed0 + placed1 - recovered0 - recovered1 at P0=1
IDENTITY: audit IL equals direct placed-amount shortfall in this infinite-range limit
IDENTITY: Weir withdraw swaps only net1 (zapTo=1) or net0 (zapTo=2) from the withdrawn slice
```

## Assumptions

- The placement fixture uses the stated infinite-range limit of `LiquidityAmounts`, not numerical evaluation at `minUsableTick` and `maxUsableTick`. It does not mix the two. `P0=1`, `P'=2` and `P'=4`, existing liquidity is `1000`, existing supply is `1000`, and the placed input is `100 token0 + 100 token1` balanced at `P0`.
- There are no fees, rounding, hook effects, or genesis-floor effects in the fixture. Weir's source default `perfFeeBps = 500` applies to harvested fees (`WeirVaults.sol:80`, `:351-356`); no performance fee is applied to principal in the simulation.
- No fee cap, TWAP check, tick bound, or exit fee is added. The only price is the underlying pool price. No independent pricing source is assumed.
- Swap legs use a labeled zero-fee constant-product approximation. Placement, share issuance, the audit-IL comparison, and the swapped-amount identities do not rely on that approximation. In the self-moved cases, initial pool depth is chosen so selling the withdrawn `666.666667` token1 moves the price exactly to `P'=2` or `P'=4`.
- The self-moved trailing case posits a `100+100` fee/idle bundle available to the following compound. This is necessary because Weir's pre-withdraw compound would already have attempted to place preexisting idle before the withdrawal swap. The case models fees accrued by the later call or an equivalent post-withdraw bundle; with no fees and no placeable idle, there is no trailing mint.
- In that case the redeemer has exited fully, so the remaining holders own all remaining shares and bear the later compound loss. A redeemer retaining shares would also bear its pro-rata share.
- The whole-dump case is a stylized APEX-2026-024 shape, not a reconstruction of deleted Wings source. It uses the same two-thirds exit and non-binding absolute limit, sells all `1000` opposing tokens, and pays the exiter two-thirds of actual post-dump assets. This payment convention is stated so the staying-holder comparison is reproducible.
- “One-sided idle” means the other token amount is exactly zero. Imbalanced two-sided idle instead places the smaller liquidity side and leaves the excess idle; its placed-liquidity shortfall follows the same identity.

## Coverage

1. **External push, then placement.** For a new caller deposit, `P'=2` places `50+100`, recovers `70.710678+70.710678`, and loses `8.578644` token1 at `P0`; `P'=4` places `25+100`, recovers `50+50`, and loses `25`. The share formula assigns `0%` of those direct-deposit losses to existing holders and `100%` to the caller. The same placement of already-owned idle mints no shares, so existing holders bear all `8.578644` or `25`. This distinction does not make a deposit safe for existing holders when its preceding `_compound` has placeable vault assets. Strictly one-sided idle places zero liquidity and has zero placement loss.

2. **Self-moved trailing placement.** The withdraw zap sells only `666.666667` token1 from the withdrawn slice, not the vault's `1000` token1. Under the CP approximation it returns `471.404521` token0 at `P'=2` or `333.333333` at `P'=4`. A following compound nevertheless sizes the `100+100` bundle at that moved live price. After return to `P0`, remaining holders bear `8.578644` or `25`, respectively. The narrow withdrawal-slice rule therefore does not prevent the trailing placement loss.

3. **Whole-balance dump versus Weir withdraw.** Weir leaves staying value at `666.666667` after return to `P0` in both cases because it did not sell the staying opposing inventory. The stylized whole dump leaves `538.927086` (`P'=2` Weir case) or `466.666667` (`P'=4` Weir case), a staying-holder loss of `127.739581` or `200`. The CP approximation determines swap outputs only; the loss follows from whole-balance versus withdrawn-slice ownership.

4. **Half-excess `_balance`.** At pre-swap `P'=2`, `_balance` sells `25` of the caller's token0; the CP approximation returns `49.823846` token1 and placement occurs at post-swap `1.985933`. At `P'=4`, it sells `37.5`, returns `148.883375`, and places at `3.940668`. The respective placed-liquidity shortfalls are `12.560262` and `60.652812`. `_balance` uses no vault idle and performs no reference-price check. On new issuance, existing holders are protected by the liquidity-denominated share formula, not by `_balance`; compound does not call `_balance` at all.

## Conclusions

### Source observations

- Weir has the APEX-2026-023 precondition: permissionless compound and live-`slot0` sizing of fees plus idle (`WeirVaults.sol:207-211`, `:355-368`). Deposits and withdrawals also invoke compound before their money operations (`:229-236`).
- Weir's `_swap` retains the absolute MIN/MAX limit without a pre-operation or TWAP comparison (`:413-425`).
- Weir does not have the APEX-2026-024 whole-opposing-balance sale in `_withdraw`; its zap sells only withdrawn `net1` or `net0` (`:289-320`).
- The PRD already copies the live-compound mechanism, liquidity-only issuance, compound ordering, and absolute entry-swap limit. It does not add a maintenance price guard in the named locks.

### Inferences from the executed math

- **External-push loss: not resolved for maintenance.** A caller can move the pool price and invoke compound, or invoke a deposit whose callback compounds first. Lines `360-368` place vault-owned value at that price and lines `370-376` add the liquidity without new shares. After return to `P0`, existing holders bear the resulting placement loss pro rata: `8.578644` at `P'=2` and `25` at `P'=4` in the fixture. A new depositor's own placement loss is instead borne by that depositor through line `269`; that narrower issuance result does not remove the maintenance loss.
- **Self-moved trailing placement: not resolved.** `_withdraw` itself compounds before, rather than after, its swap, but any address can call compound afterward. The withdrawn-net swap at lines `313-320` can move the only available pool price, and the later live-price read at lines `360-368` uses it. The following placement loss remains with the remaining holders. Limiting the swap to the withdrawn slice does not close this path.
- **Whole-balance redemption dump: resolved in the narrow size sense.** Lines `313-320` sell only the exiting holder's withdrawn unwanted-token amount. They never pass the vault's whole opposing balance to `_swap`, so the staying holders' opposing inventory is not dumped. The absolute price limit at line `422` still permits slippage on the withdrawn slice; that execution loss is the exiting holder's, and the unbounded limit does not cure the separate live-price maintenance issue.
- **Overall B-02 verdict: partial, not a resolution.** Weir's accounting changes who bears a new deposit's placement loss and avoids the whole-balance redemption dump, but caller-moved live pricing still leaves APEX-2026-023 maintenance losses with other holders.

## Limits

This is source and mathematical research, not an implementation or safety clearance. I did not run Forge, project tests, a V4 tick-level swap, a deployment, or any network query. The simulations exclude fees, integer rounding, finite usable-tick truncation, attacker push cost, and profitability; they prove accounting allocation, not attack economics. The CP outputs are approximations, while the placement, audit-IL, issuance, and swap-size identities are exact within the stated infinite-range fixture. No TWAP or independent price is assumed or recommended. This response proposes no PRD edit, locks no B-02 decision, and grants no implementation authority.
