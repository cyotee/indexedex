# Identity

- Member label: `minimax`
- Profile: `research`
- Phase: initial independent response
- Owned path: `members/minimax/response.md`
- Requested role: `council-member`
- Requested model: `minimax/MiniMax-M3` with admitted adaptive thinking, not a selectable depth
- Actual Native identity beyond the assignment: not exposed
- Peers read before submission: no
- Context: fresh

# Question and targets

Does WeirVaults' own accounting resolve the B-02 losses, or can a caller move the pool price and leave a placement or redemption loss with the other holders?

I examined only the admitted targets:

- `contracts/protocols/strategy/weir/WeirVaults.sol`
- `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol`
- B-02 in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`
- APEX-2026-023 and APEX-2026-024 in `docs/security/audit/second_review/IndexedEx_DiffReview_aca16198-2ba07631.md`
- FS-OWN-10, FS-OWN-12, FS-OWN-14, FS-OWN-15, and FS-MONEY-01 in `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`

No peer response, coordinator draft, or final report was read.

# Evidence

## Source observations: WeirVaults

1. **Who can compound, and operation order.** `compound` is external and has no owner or other authority restriction; its comment says, “Anyone can call it” (`WeirVaults.sol:207-210`). In `unlockCallback`, a deposit calls `_compound` and then `_deposit`, while a withdrawal calls `_compound` and then `_withdraw` (`WeirVaults.sol:222-237`). Thus a deposit or withdrawal also causes the preceding compound.

2. **The price used to size new liquidity.** `_deposit` optionally calls `_balance` first, then reads the current pool `slot0` and calls `getLiquidityForAmounts` (`WeirVaults.sol:248-263`). `_compound` likewise reads the current `slot0` and sizes the remainder plus idle with `getLiquidityForAmounts` (`WeirVaults.sol:341-367`). There is no pre-operation price or TWAP comparison in either sizing path.

3. **`_balance` uses the live spot.** `_balance` reads the current `slot0`, values token0 at that price, swaps half of the larger side's excess, and returns the resulting amounts (`WeirVaults.sol:387-410`). If a zap is requested, `_deposit` then sizes at the post-swap live price read again at `WeirVaults.sol:254-263`.

4. **The swap limit.** `_swap` is exact-input and uses `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1` (`WeirVaults.sol:413-425`). It does not compare the pool price with the pre-operation price, a TWAP, an oracle, or another reference.

5. **What a one-token withdrawal swaps.** `_withdraw` removes the exiting fraction's liquidity and pays its pro-rata idle (`WeirVaults.sol:288-311`). For a token0 exit it swaps `net1`; for a token1 exit it swaps `net0` (`WeirVaults.sol:313-319`). The amount is therefore the withdrawn unwanted-token amount, not a shortfall against a target and not the vault's whole opposing balance.

6. **What `_balance` swaps.** It acts on the deposit's own `amount0` and `amount1`, not on the vault's other holders' inventory. It swaps half of the larger side's live-price excess (`WeirVaults.sol:387-410`). A non-zapped two-sided deposit does not call `_balance`.

7. **The issuance denominator.** For an existing vault, `_deposit` computes `frame.shares = frame.liq * v.totalShares / v.liquidity` (`WeirVaults.sol:266-273`). Idle is not in that denominator. The first deposit instead uses the separate `MIN_SHARES` rule (`WeirVaults.sol:264-272`).

8. **The library formulas.** `LiquidityAmounts.getLiquidityForAmounts` takes the smaller liquidity implied by the two supplied amounts when the current price is inside the range (`LiquidityAmounts.sol:26-43`). `getAmountsForLiquidity` reverses that calculation (`LiquidityAmounts.sol:53-65`). `createVault` selects the full-range `minUsableTick`/`maxUsableTick` bounds (`WeirVaults.sol:145-154`).

## Source observations: audit record and PRD

- APEX-2026-023 describes the old FullSpread maintenance path: it sized from live `slot0`, “Nothing checks that price against a TWAP, an oracle or the pre-operation price,” and the new liquidity's loss remained with honest LPs (`IndexedEx_DiffReview_aca16198-2ba07631.md:1528-1554`). Its stated approximation is `IL(dL) = dL * (sqrtP' - sqrtP0)^2 / sqrtP'`.
- APEX-2026-024 describes the different Wings shape: the redemption “sells the vault's whole opposing-token balance exact-in” at the extreme limit, and “the staying holders' share of that inventory is sold at a heavily slipped price” (`IndexedEx_DiffReview_aca16198-2ba07631.md:1605-1629,1667`).
- B-02 distinguishes exactly these two live-price/unbounded-swap behaviors (`IMPLEMENTATION_PLAN_BLOCKERS.md:64-78`).

The PRD already copies substantial parts of Weir:

- FS-OWN-10: “`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, tick bound, or hidden constant is added.” (`UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md:64`)
- FS-OWN-12: “After every deposit, withdrawal, and compound, attempt to move each token's local balance toward `liquidReservePercentageOfVault(address(this))` of that token's owned amount.” (`...VAULT_PRD.md:72`)
- FS-OWN-14: “`compound()` deploys booked idle. ... Any address may call it.” (`...VAULT_PRD.md:76`)
- FS-OWN-15: “A redemption takes deployed liquidity first and may swap through the pool. The purpose is pool volume.” (`...VAULT_PRD.md:78`)
- FS-MONEY-01 already copies the unbounded entry-swap limit, the liquidity-only issuance denominator, `_compound` before deposit/withdraw, fee-plus-idle reinvestment, and proportional liquidity-plus-idle withdrawal (`...VAULT_PRD.md:258-270`).

FS-OWN-12 is not itself Weir's `_balance`: it is a post-operation local-balance target rule. FS-OWN-15 permits a redemption swap but does not specify Weir's withdrawn-net swap amount. FS-MONEY-01 says this family does not install Weir's `zapTo` selector (`...VAULT_PRD.md:270`). Thus selecting Weir does not introduce every observed behavior as a new rule: the live-price and unbounded-swap core is already substantially present. It also adds no authorized price guard.

## Inference from the source

- A caller-funded placement and a vault-idle placement are different. The share formula isolates a caller-funded non-zap deposit's placement loss from existing holders in the comparable fixture. `_compound`, by contrast, deploys vault-owned idle without minting shares, so placement loss from idle remains with the existing holders.
- Because `compound` is permissionless and both deposit and withdrawal call `_compound` first, a caller can move spot and then cause a compound at that displaced spot. No source rule prevents that.
- Weir does not have APEX-2026-024's whole-opposing-balance redemption swap. It swaps only the exiting fraction's unwanted-token net. The unbounded limit remains, however, so a withdrawal can still move spot and a later live-price idle placement remains exposed.

## Python simulation

Script: `docs/research/se-weir-b02-accounting-20261101/members/minimax/sim/weir_b02_accounting.py`

Command:

```text
python3 docs/research/se-weir-b02-accounting-20261101/members/minimax/sim/weir_b02_accounting.py
```

Exit status: `0`

The script uses Python's standard library only. It encodes the infinite-range limit of `LiquidityAmounts` directly:

- `L = min(amount0 * sqrt(P), amount1 / sqrt(P))`
- `amounts(P, L) = (L / sqrt(P), L * sqrt(P))`

The fixture uses `P0 = 1`, `P' = 2` and `4`, existing liquidity `L0 = 100`, and existing supply `S = 100`. The direct amount calculation and the audit approximation agree in this fixture within `1e-48`.

Case results:

- **External push, then placement.** At `P'=2`, balanced `100/100` adds `70.710678118655` liquidity, places `50/100`, recovers `70.710678118655/70.710678118655` at `P0`, and loses `8.578643762690` token1. At `P'=4`, it adds `50`, places `25/100`, recovers `50/50`, and loses `25`. If this is vault idle, existing holders bear the loss. If the same placement is funded by a non-zap caller deposit, the caller receives proportional shares, existing-holder value is unchanged in the fixture, and the caller bears the same loss. A strictly one-sided idle computes to zero liquidity at the live price and remains idle.
- **Self-moved trailing placement.** A one-third exit swaps only `33.333333333333`, the withdrawn unwanted-token net. A later compound with `10/10` idle at the moved price loses `0.857864376269` at `P'=2` or `2.5` at `P'=4`, borne by the remaining holders. The source order means this later compound is not part of the same withdrawal callback; `_compound` precedes `_withdraw`.
- **Whole-balance dump versus withdrawn-net swap.** The fixture swaps `66.666666666667` under Weir versus `100` under the 024 shape. Under the script's explicit allocation—exit receives the Weir-path proceeds and staker receives the dump residual—the staker's `P0` value is `33.333333333333` versus `28.409090909091`, a `4.924242424242` difference. This numeric comparison uses the labeled constant-product approximation; the source identity is independent of it.
- **Half-excess `_balance`.** A one-sided token1 deposit of `100` swaps `50` at the live price and sizes liquidity at the resulting live price. Caller loss is `2.494331065760` without a push, `31.522710181780` at `P'=2`, and `51.814058956916` at `P'=4`. Existing-holder value is unchanged in these caller-funded fixtures. `_balance` therefore ratio-matches the caller's input; it is not a price guard.

Numeric output from the successful run:

```text
CASE 1: external push, then placement
  fixture: P0=1; balanced amount pair=100/100; existing liquidity L0=100; supply S=100
  share formula: added_liquidity * S / L0; idle is absent from the denominator
  Weir calls _compound before deposit/withdraw money operations

  [vault idle placed at P'=2]
    offered token0/token1       = 100.000000000000/100.000000000000
    liquidity added             = 70.710678118655
    token0/token1 placed        = 50.000000000000/100.000000000000
    leftover token0/token1      = 50.000000000000/0.000000000000
    token0/token1 recovered P0  = 70.710678118655/70.710678118655
    initial value at P0         = 200.000000000000
    final value at P0           = 191.421356237310
    direct shortfall token1     = 8.578643762690
    audit IL approximation      = 8.578643762690
    absolute audit difference   = 0.000000000000000000000000000000
    audit matches direct        = True

    all idle-placement loss is borne by existing holders
    one-sided idle at this price adds liquidity=0 and remains idle

  [same placement funded by a caller deposit at P'=2]
    new shares                  = 70.710678118655
    existing-holder value change= 0.000000000000
    caller final wealth at P0   = 191.421356237310
    caller placement loss       = 8.578643762690
    caller loss is isolated from existing holders by proportional issuance

  [vault idle placed at P'=4]
    offered token0/token1       = 100.000000000000/100.000000000000
    liquidity added             = 50.000000000000
    token0/token1 placed        = 25.000000000000/100.000000000000
    leftover token0/token1      = 75.000000000000/0.000000000000
    token0/token1 recovered P0  = 50.000000000000/50.000000000000
    initial value at P0         = 200.000000000000
    final value at P0           = 175.000000000000
    direct shortfall token1     = 25.000000000000
    audit IL approximation      = 25.000000000000
    absolute audit difference   = 0.000000000000000000000000000000
    audit matches direct        = True

    all idle-placement loss is borne by existing holders
    one-sided idle at this price adds liquidity=0 and remains idle

  [same placement funded by a caller deposit at P'=4]
    new shares                  = 50.000000000000
    existing-holder value change= 0.000000000000
    caller final wealth at P0   = 175.000000000000
    caller placement loss       = 25.000000000000
    caller loss is isolated from existing holders by proportional issuance

CASE 2: self-moved trailing placement after a withdraw zap
  fixture: L0=100; S=100; exit fraction=1/3; later-compound idle=10/10
  zero-fee constant-product approximation supplies the post-swap live price
  source order is _compound then _withdraw, so the withdrawal cannot compound in the same call

  [target post-swap price P'=2]
    withdrawn net0/net1         = 33.333333333333/33.333333333333
    _swap amount identity       = 33.333333333333
    token0 out (CP approximation)= 23.570226039552
    post-swap live price        = 2.000000000000
    sold slice is the withdrawn net, not the whole vault balance
  [later compound of booked idle at the moved live price]
    offered token0/token1       = 10.000000000000/10.000000000000
    liquidity added             = 7.071067811865
    token0/token1 placed        = 5.000000000000/10.000000000000
    leftover token0/token1      = 5.000000000000/0.000000000000
    token0/token1 recovered P0  = 7.071067811865/7.071067811865
    initial value at P0         = 20.000000000000
    final value at P0           = 19.142135623731
    direct shortfall token1     = 0.857864376269
    audit IL approximation      = 0.857864376269
    absolute audit difference   = 0.000000000000000000000000000000
    audit matches direct        = True

    remaining holders           = 66.666666666667 shares
    loss borne by remaining holders = 0.857864376269
    loss per remaining share       = 0.012867965644036

  [target post-swap price P'=4]
    withdrawn net0/net1         = 33.333333333333/33.333333333333
    _swap amount identity       = 33.333333333333
    token0 out (CP approximation)= 16.666666666667
    post-swap live price        = 4.000000000000
    sold slice is the withdrawn net, not the whole vault balance
  [later compound of booked idle at the moved live price]
    offered token0/token1       = 10.000000000000/10.000000000000
    liquidity added             = 5.000000000000
    token0/token1 placed        = 2.500000000000/10.000000000000
    leftover token0/token1      = 7.500000000000/0.000000000000
    token0/token1 recovered P0  = 5.000000000000/5.000000000000
    initial value at P0         = 20.000000000000
    final value at P0           = 17.500000000000
    direct shortfall token1     = 2.500000000000
    audit IL approximation      = 2.500000000000
    absolute audit difference   = 0.000000000000000000000000000000
    audit matches direct        = True

    remaining holders           = 66.666666666667 shares
    loss borne by remaining holders = 2.500000000000
    loss per remaining share       = 0.037500000000000

CASE 3: whole-balance dump versus Weir withdrawn-net swap
  fixture: opposing inventory B=100; exit fraction=2/3; pool reserves=1000/1000
  both swaps use the same source limit; the zero-fee CP model only prices their paths
  exit holder receives its fixed P0 token0 entitlement; residual value belongs to staker

  Weir withdrawn-net amount       = 66.666666666667
  024 whole-balance amount        = 100.000000000000
  extra staker inventory sold     = 33.333333333333
  Weir post-swap price             = 1.137777777778
  dump post-swap price             = 1.210000000000
  Weir token0 out / price slippage= 62.500000000000/4.166666666667
  dump token0 out / price slippage= 90.909090909091/9.090909090909
  return-to-P0 Weir input/output   = 62.500000000000/66.666666666667
  return-to-P0 dump input/output   = 90.909090909091/100.000000000000
  exit proceeds at P0-equivalent  = 62.500000000000 token0
  Weir swap proceeds              = 62.500000000000 token0
  dump swap proceeds              = 90.909090909091 token0
  staker value at P0, Weir         = 33.333333333333
  staker residual token0, dump    = 28.409090909091
  stayer value loss, dump vs Weir  = 4.924242424242
  model allocation: exit receives the Weir-path proceeds; staker receives the dump residual
  Weir has no whole-opposing-balance redemption swap

CASE 4: half-excess _balance at the live price
  fixture: one-sided token1 deposit=100; existing L0=100; supply S=100
  _balance uses the pre-swap live price; _deposit sizes at the post-swap live price

  [no push, P=1]
    live price before _balance    = 1.000000000000
    half-excess swap input         = 50.000000000000
    token0 out / post-swap price   = 47.619047619048/1.102500000000
    balanced n0/n1                = 47.619047619048/50.000000000000
    liquidity sized at live price = 47.619047619048
    token0/token1 placed          = 45.351473922902/50.000000000000
    token0 credit to caller       = 2.267573696145
    token0/token1 recovered P0    = 47.619047619048/47.619047619048
    caller loss at P0              = 2.494331065760
    existing-holder value change  = 0.000000000000

  [external push, P=2]
    live price before _balance    = 2.000000000000
    half-excess swap input         = 50.000000000000
    token0 out / post-swap price   = 23.809523809524/2.205000000000
    balanced n0/n1                = 23.809523809524/50.000000000000
    liquidity sized at live price = 33.671751485074
    token0/token1 placed          = 22.675736961451/50.000000000000
    token0 credit to caller       = 1.133786848073
    token0/token1 recovered P0    = 33.671751485074/33.671751485074
    caller loss at P0              = 31.522710181780
    existing-holder value change  = 0.000000000000

  [external push, P=4]
    live price before _balance    = 4.000000000000
    half-excess swap input         = 50.000000000000
    token0 out / post-swap price   = 11.904761904762/4.410000000000
    balanced n0/n1                = 11.904761904762/50.000000000000
    liquidity sized at live price = 23.809523809524
    token0/token1 placed          = 11.337868480726/50.000000000000
    token0 credit to caller       = 0.566893424036
    token0/token1 recovered P0    = 23.809523809524/23.809523809524
    caller loss at P0              = 51.814058956916
    existing-holder value change  = 0.000000000000

All direct-versus-audit and one-sided-liquidity assertions passed.

EXIT_STATUS=0
```

# Assumptions

- `P` means token1 per token0, consistent with `sqrtP` and the library's amount formulas.
- The simulation uses the infinite-range limit of `LiquidityAmounts` rather than evaluating the finite `minUsableTick`/`maxUsableTick` prices. This deviation is intentional and stated; the source itself selects the full-range ticks.
- Solidity's two-unit dust subtraction and integer truncation are omitted from the continuous fixture.
- Where a concrete swap path is needed, a zero-fee constant-product pool is an explicitly labeled approximation. The source-derived accounting identities do not depend on it: the amount swapped is the withdrawn net in Weir, the whole opposing balance in the 024 shape, and the liquidity-sizing price is the current live `slot0`.
- The case-3 allocation is stated in the output: the exiting holder receives the Weir-path proceeds and the staying holder receives the residual from the dump path. Its numeric difference is illustrative of that allocation, not a general Wings redemption model.
- No TWAP or independent price is assumed. The only referenced price is the pool's live price.
- No fee cap, TWAP check, tick bound, or exit fee is added. `perfFeeBps` is irrelevant to these fixtures because they contain no harvested fees.

# Coverage

- Required source functions: covered — `deposit`, `withdraw`, `compound`, `unlockCallback`, `_deposit`, `_withdraw`, `_compound`, `_balance`, and `_swap`.
- Required liquidity directions: covered — amounts to liquidity and liquidity to amounts.
- Required audit findings: covered — APEX-2026-023 and APEX-2026-024.
- Required PRD locks: covered — FS-OWN-10, FS-OWN-12, FS-OWN-14, FS-OWN-15, and FS-MONEY-01.
- Required fixture prices: covered — `P0=1`, `P'=2`, `P'=4`.
- Required cases: covered — external push and placement, self-moved trailing placement, whole-balance dump versus withdrawn-net swap, and half-excess `_balance`.
- Direct formulas versus audit approximation: covered and matched in the fixture.
- Public search: not used.

# Conclusions

1. **External-push loss: only partly resolved by Weir's share accounting.** A caller-funded non-zap deposit's placement loss is borne by that caller in the comparable fixture: `8.578643762690` at `P'=2` and `25` at `P'=4`, with no existing-holder value change. Weir does **not** protect existing holders from live-price deployment of vault-owned idle. `_compound` includes idle in the live-price placement and adds liquidity without shares (`WeirVaults.sol:355-378`), so the remaining loss stays with the existing holders. Because compound is permissionless, an external price mover can trigger that placement.

2. **Self-moved trailing placement: the same-call shape is absent, but the live-price loss is not resolved.** `_compound` runs before `_withdraw`, so Weir's withdrawal callback does not compound after its own redemption swap. A **following** compound, however, deploys remaining idle at the moved live price. In the fixture, the remaining holders bear `0.857864376269` at `P'=2` or `2.5` at `P'=4`. The relevant source lines remain the live-price sizing in `_compound` (`WeirVaults.sol:355-367`) and the unbounded swap in `_swap` (`WeirVaults.sol:413-425`).

3. **Whole-balance redemption dump: Weir does resolve the APEX-2026-024 shape.** `_withdraw` swaps only `net1` or `net0`, the exiting fraction's unwanted-token net (`WeirVaults.sol:313-319`); it never sells the vault's whole opposing balance. The unbounded limit still permits the redemption to move spot, and a later idle placement can still lose value, but the specific whole-balance dump is absent.

4. **`_balance` is not a displaced-spot defense.** It only ratio-matches the caller's own deposit input using the live price and half of the excess (`WeirVaults.sol:387-410`). It neither compares the live price with a reference nor places at a protected price. Proportional issuance keeps the caller-funded fixture loss with the caller; that isolation comes from the share formula, not from `_balance`.

5. **The PRD already contains much of the relevant mechanism.** FS-MONEY-01 and the named locks already copy the unbounded entry limit, liquidity-only issuance, permissionless idle-deploying compound, and proportional redemption accounting. They do not currently add a live-price or TWAP guard. Choosing Weir does not, by itself, create a new replacement rule, and this response proposes no PRD edit or implementation authorization.

# Limits

- This is source analysis plus a standard-library mathematical simulation. It does not execute the Solidity contract, a Uniswap V4 pool, hooks, or project tests; those were outside the assignment.
- The constant-product pool is only a labeled price-path approximation. It does not model V4 fees, hooks, integer rounding, or exact tick bounds.
- The audit approximation matches the direct amount formulas in the stated infinite-range fixture; that does not establish equality for every finite range or every pool state.
- The case-3 numeric stayer comparison depends on the explicitly stated proceeds allocation. The source-level conclusion—that Weir swaps the withdrawn net rather than the whole balance—does not.
- A Python language server was not installed, and the assignment prohibited installation. The specified script itself compiled and ran with exit status `0`.
