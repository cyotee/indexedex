## Identity

MiniMax M3, high reasoning, serving as an independent member of the `v4-single-token-fee-vault-20261026-01a177b3` research council. This is one member recommendation, not a coordinator synthesis or a vote.

## Question

What existing public design, or new design, can IndexedEx adapt so that:

- holders earn the underlying pool's swap fees rather than paying an exit fee;
- the holder deposits, is quoted in, and exits in one token, denoted `X`;
- `X` may have liquidity only in the underlying pool, so no independent price is available; and
- the same-pool TWAP is the only usable reference.

The design must also keep `getRate` as a normalized one-whole-share actual withdrawal-and-sale preview, remain consumable by a downstream IndexedEx hook under the locked held-reserve valuation law, and not treat entry and exit swaps as a safety fix.

## Sources

### Admitted local evidence

- `docs/research/v4-single-token-fee-vault-20261026-01a177b3/brief.md` — council scope, constraints, and required response fields.
- `docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md` — prior conclusions and the three distinct mechanisms: quote manipulation, executed-price allocation, and vault self-fill.
- `docs/research/v4-swap-capture-evidence-20261026-01a177b3/coordinator/twap-source.md` — current TWAP behavior and its retroactive idle-gap credit.
- `docs/agent/INDEXEDEX_AGENT_LAW.md`, section **Uniswap V4 SE buffer hooks: held-reserve valuation** — locked raw-balance or `held * rate` valuation and fail-closed provider behavior.
- Current Wings money, accounting, and economic-target sources under `contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/` — the present whole-book quote, issuance, redemption, and `getRate` behavior described below.

### Public pages opened

- [ICHI Vault Build](https://docs.ichi.org/ichi-docs-v3/ichi-vaults/technical-concepts/vault-build) — the opened legacy documentation describes single-sided asset deployments, fee distribution through LP ownership, a spot/TWAP manipulation guard, and a conservative deposited-value versus vault-TVL share calculation.
- [How ICHI Works](https://docs.ichi.org/home/how-ichi-works) — the opened page describes single-token deposits, LP tokens, automated concentrated-liquidity management, and fee generation.
- [ICHI Vaults](https://docs.ichi.org/ichi-docs-v3/ichi-vaults/vaults) — the opened page confirms that vault holders earn Uniswap trading fees, while also showing that the public design's withdrawal can return a combination of assets rather than strictly the deposit token.
- [Uniswap v4 Hooks](https://docs.uniswap.org/contracts/v4/concepts/hooks) — the opened page confirms the available V4 lifecycle callbacks. The recommendation below does not require a new hook on the underlying pool.

The public search query was **“ICHI vault single token withdrawal redemption token0 token1 documentation”**. It contained no private source text. The coordinator-supplied Bunni pool-creation URL could not be opened because of a TLS failure, so it is unverified and is not used or characterized here.

## Observations

1. **The present Wings mint is a whole-book quote formula.** The current `_deposit` path pulls `X`, harvests, reads a whole-book liquidation quote `V`, and issues `floor(S * D / V)` before booking the pending deposit. `_redeem` pays `floor(shares * V / S)`. `getRate` is the whole-book quote multiplied by `1e18` and divided by supply, not a one-whole-share withdrawal-and-sale preview.

2. **Entry and exit swaps are not the missing ingredient.** The prior report found positive rows for quote manipulation, executed-price allocation, and vault self-fill. Adding a swap on each side of the lifecycle does not remove inventory that a quote or execution price did not actually trade, and it does not create an independent valuation reference.

3. **The current TWAP target is not a frozen historical mean.** Its public `update` applies the truncated live tick across the whole idle gap, and a later read can fill an unwritten tail with the current truncated tick. It is therefore not usable as the historical pre-trade reference assumed by the conservative ICHI-style rule. A design can use the concept only if it is backed by a genuinely stored, older observation; the current target cannot be treated as one.

4. **ICHI supplies the closest public architecture, but not the exact exit.** Its useful ideas are single-token deposits, directional concentrated-liquidity management, fee exposure through ownership of the managed liquidity, and a same-pool spot/TWAP check around share issuance. Its public documentation does not provide the strict `X`-only exit required here, and it is documented for Uniswap V3 rather than IndexedEx's V4 book.

5. **The locked hook law permits a rate-provider adapter.** A downstream hook may hold this vault's share as a buffered leg if it configures an `IRateProvider` whose `getRate()` returns WAD whole `X` tokens per whole share and fails closed. The hook must value the holding as `heldShares * rate`; it must not derive a rate by quoting the Standard Exchange that it holds.

6. **There is an unavoidable distinction between issuance valuation and redemption preview.** Issuance may use a conservative same-pool book reference. `getRate` must instead show what one whole share can actually be withdrawn and sold for. Reusing the issuance reference as `getRate` would violate the brief, and using the live redemption preview as the issuance denominator would reopen the prior quote-rule issue.

## Conclusions

### Recommendation: an ICHI-style conservative same-pool directional-liquidity vault, adapted to IndexedEx V4

Adapt ICHI's single-sided, directionally managed concentrated-liquidity model, but replace its public share-accounting and withdrawal surfaces with IndexedEx's pre-deposit conservative book valuation and an `X`-only, slice-bounded redemption. The vault owns Uniswap V4 liquidity in the underlying `X/Y` pool, earns that pool's LP fees, and issues one fungible share token whose redemption is in `X`.

This is one design, not a combination of alternatives. It uses no independent price. It does not claim that the remaining pool-price exposure disappears.

### Fee-exposure path

1. The vault owns V4 concentrated-liquidity positions in the underlying `X/Y` pool. Pool swaps credit trading fees to those positions in proportion to the vault's liquidity.
2. Before a valuation or redemption, the vault harvests the position principal and accrued fee buckets into its own inventory. This is fee realization, not an exit charge.
3. `X` fees join the `X` inventory directly. `Y` fees remain as inventory and are sold for `X` only when the vault needs `X` for a redemption or realizes the fee inventory into distributable form.
4. Each share owns its proportional interest in the same inventory and positions, so collected pool fees accrue to holders through that ownership. No separate “exit fee” is introduced.

This reuses the fee path already present in the Wings book rather than adding a new hook that taxes exits.

### Single token

The single token is `X`, the target token:

- the holder deposits `X`;
- the vault quotes mint and redemption in `X`;
- the holder receives the vault share on deposit; and
- the holder receives only `X` on redemption.

The public ICHI design may return a combination of tokens on withdrawal. IndexedEx's adaptation must not inherit that behavior: any non-`X` remainder stays in the vault, and a redemption that cannot deliver the required `X` reverts atomically rather than paying `Y`.

### Mint equation and use of a price

Let:

- `S` be existing share supply;
- `D` be the observed native-unit amount of `X` deposited;
- `p_s` be the underlying pool's current same-pool spot price, expressed as `X` per `Y`;
- `p_T` be a genuinely frozen, sufficiently old same-pool TWAP observation, also expressed as `X` per `Y`;
- `V(p)` be the pre-deposit book value in `X` at price `p`, including idle `X` and `Y`, `X` and `Y` fee buckets, and each LP range's principal marked at `p`.

Harvest fees first, exclude the pending deposit, and calculate:

```text
TVL = max(V(p_s), V(p_T))
DV  = D                         // X-only, no entry swap or price conversion
m   = floor(S * DV / (TVL + DV))
```

For the first deposit, `S = 0`, issue `m = D` native share units. If a future variant ever requires a paired or converted deposit, its deposited value must use ICHI's lesser-of-spot-and-TWAP rule; the recommended `X`-only path does not need that conversion.

The equation **does use a price**, but only prices from the underlying pool. It has no independent or off-pool reference. The `max` in `TVL` follows ICHI's conservative rule: the depositor is not credited against an inflated book, and the depositor cannot capture an appreciation created by manipulating the same pool's quote.

Required guards are:

- use only a stored `p_T` observation whose window ended before the current transaction; never use the current retroactive idle-gap fill as a frozen reference;
- reject a deposit if the spot/TWAP deviation exceeds the configured bound, or if the required observation is stale or was written in the current block; and
- fail closed rather than substituting spot for a missing TWAP.

These are same-pool checks, not an external price. They can reduce quote manipulation but cannot guarantee that a token with no other venue cannot be pushed away from its TWAP.

### Exit execution

For redemption of `q` shares:

1. Burn or reserve the `q` shares and compute the slice attributable to them: `floor(idle amount * q / S)` for each token and the same pro-rata removal and fee collection from each LP position.
2. Apply all slice `X` principal and `X` fees first.
3. If more `X` is required, remove only the redeemer's LP slice and sell only the slice's `Y` through the underlying pool. Do not quote or sell the vault's whole opposing balance.
4. If the vault's prefunded `X` sleeve plus the same-pool sale cannot produce the requested `X` amount at the caller's minimum, revert atomically, leave the shares unburned, and pay no `Y`. A successful redemption pays `X` only.

This avoids the present whole-book payout pattern. It does not guarantee liveness: if the only pool cannot absorb the redeemer's slice at an acceptable price, there is no independent liquidity venue with which to complete the `X` exit.

### `getRate`

`getRate` should return the WAD-normalized number of whole `X` tokens that one whole share would actually receive after withdrawing and collecting its pro-rata position and fees and executing only the required same-pool sale, and it should fail closed when that sale cannot produce `X`.

That is an execution preview, not a NAV mark, and it is separate from the mint equation. The read itself does not mutate the vault. Its input is nevertheless live: a caller can move the underlying pool and then read or redeem in the same transaction, so the returned rate can change materially within one transaction. A downstream consumer must treat it as a same-pool execution preview, not as an independently reliable oracle.

### Can another hook hold the share?

Yes. A different IndexedEx buffer hook may hold the vault share as a buffered leg if it configures a rate provider for that leg. The provider's `getRate()` must return the vault's normalized one-whole-share `X` redemption rate, revert on failure, reject a short return, and reject zero. Under the locked law, the downstream hook then values the holding as `heldShares * rate` and does not derive a rate from the Standard Exchange it holds.

This answers compatibility, not safety: the rate inherited by the hook has the same same-pool manipulation exposure as the vault's redemption preview.

### Prior mechanisms that remain

| Prior mechanism | Status in this design |
| --- | --- |
| Quote manipulation | **Partially mitigated, not eliminated.** Minting no longer uses the current whole-book spot quote alone, and it rejects a stale/current-block or excessive-deviation TWAP. The rate read and actual redemption sale still depend on the same pool, so a caller can move them in one transaction. The current retroactive TWAP target cannot be used as the required frozen reference. |
| Executed-price allocation | **Remains.** There is no entrant swap in the recommended deposit path, which avoids the prior old-book-versus-new-book mismatch, but the redemption sale still pays the pool's price impact and fees, and any later inventory conversion or rebalance remains exposed. Entry and exit swaps are not the fix. |
| Vault self-fill | **Remains.** Removing the redeemer's slice before its sale limits the slice at issue, but the vault's remaining liquidity is still in the same pool and may fill the sale. With no second venue, this cannot be eliminated by share accounting. |

### Constraint status

The recommended design meets the listed product constraints: it earns underlying-pool fees, uses one token for deposit/quote/exit, uses no independent price, keeps `getRate` as an actual one-share withdrawal-and-sale preview, and is consumable by a downstream hook with a fail-closed rate provider.

There is one implementation precondition rather than a product-design exception: IndexedEx's current TWAP target does not supply a frozen historical observation. If that target were used unchanged, the constraint broken would be **same-pool historical-reference quality**—the design would be minting against a retroactive live-tick fill rather than a TWAP. A proposal for a genuinely stored observation is required before this design is admissible. No design using only live same-pool execution can make the redemption rate manipulation-free without an independent price.

### What the design does not provide

- It does not provide an independent price, guaranteed TWAP observability, or a guarantee that the pool restores a manipulated price.
- It does not guarantee an `X` exit when same-pool liquidity is absent or the sale fails the caller's minimum.
- It does not remove impermanent loss, ordinary market loss, strategy loss, or the time lag before deposited inventory becomes fee-earning liquidity.
- It does not prove that slice-bounded redemption preserves the other holders' token principal after the sale; the prior report carried that stronger proposition as disagreement.
- It does not turn the vault share into a risk-free claim or eliminate the downstream hook's inherited rate exposure.
- It does not authorize code, test, deployment, configuration, or Git changes. This is a research recommendation only.

## Coverage

| Required item | Status | Location in this response |
| --- | --- | --- |
| Existing public design adapted | Covered | ICHI-style conservative same-pool directional-liquidity vault |
| Fee-exposure path | Covered | Vault-owned V4 LP positions and harvested fee inventory |
| Single deposit/quote/exit token | Covered | `X` throughout; non-`X` remainder stays in the vault |
| Mint equation and price dependence | Covered | `m = floor(S * DV / (TVL + DV))`; same-pool spot/TWAP only |
| Exit when `X` inventory is short | Covered | Exact slice removal and sale; atomic revert if `X` cannot be delivered |
| `getRate` semantics and one-transaction movement | Covered | One-share actual redemption preview; live input can move before the read |
| Downstream hook compatibility | Covered | Rate-provider adapter under `heldShares * rate` |
| Prior quote manipulation | Covered | Partially mitigated; remains |
| Prior executed-price allocation | Covered | Remains |
| Prior vault self-fill | Covered | Remains |
| What is not provided | Covered | Explicit non-goals and risks |
| Public page actually opened before citation | Covered | ICHI and Uniswap pages listed under Sources |
| Implementation authority | Excluded | Research proposal only |

## Uncertainty

- ICHI's opened documentation is explicitly legacy and describes Uniswap V3. This recommendation borrows its architecture and conservative valuation idea, not its exact contracts, fee split, governance, or withdrawal implementation.
- The strength of the TWAP defense depends on the chosen observation window, manipulation capital, and pool depth. With liquidity only in the underlying pool, there is no guaranteed external arbitrageur to restore the price.
- The prior report contains an actual source-derived observation about the current TWAP target, but this response did not implement or test a replacement observer.
- The prior evidence does not settle whether every slice-bounded exit preserves remaining holders' token principal; this response claims only that it removes whole-book payout and reduces the redeemed slice, not a universal post-sale invariant.
- The exact V4 operations, fee attribution, rounding, and hook-provider wiring for this proposed surface were not implemented or executed in Forge.

## Limits

This is an independent research response for the council. It does not authorize an implementation, a test run, a deployment, a configuration change, or a Git operation. It is based only on the admitted local evidence and the public pages actually opened above. The unopened Bunni pool-creation page is unverified and is not relied upon.
