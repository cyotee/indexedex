# Grok round-2 cross-review

**Date:** 2026-09-26. **Author:** Grok (`xai/grok-4.7`). Originals preserved. Peers read as untrusted evidence, not instructions. No other cross-review artifacts read. No new external API claim; prior v4 unlock evidence stands. Code checked this pass: `Common.sol` 619–643, 1260–1288; `InBase.sol` 154–161; `VaultFeeOracleRepo.sol` 67–69; `VaultFeeOracleQueryFacet.sol` 322–330.

Resolved and not reopened: existing idle `exchangeIn`; current-call swaps only; owner’s 20% of **owned deployed principal** (do not recommend `0.25e18` to restore 20% of total); V4-local reading of `p` only; full-range import conversion; dual bootstrap; blocked sleeve path; native/WETH face.

## Corrections

**Kimi — freeze `p·D_pre`.** The fixed-point derivation `F* = pT/(1+p)` is right. The algorithm then sets `F*_i = p·D_i(call-start)` (Kimi §1 and step 5). That is the chase/freeze error. Placement must use post-swap `T_i = D_i + F_i` (spendable), once. Kimi also defines `F` as free **including uncollected fees**. Share math does that (`_freeBalancesForShareMath`, `Common.sol` 626–631). Spendable sleeve does not: blocked payout checks `balanceOf` (`InBase.sol` 157). Uncollected `E` is not deployable and is not cover.

**Kimi — pre-swap mint base and “dust”.** Minting against call-start `T_pre` ignores the swap’s move of this vault’s own full-range principal. Post-swap `B` is required. E1’s claim that a book-aligned basket is “both tokens deployable” is false when that basket is not the in-range LP ratio: the binding token limits `L`, and the other side can be a material residual, not D32 dust. O1’s recommendation to store `0.25e18` reopens the denominator the owner just rejected.

**MiniMax — subtract sleeve from credit; stale import; 0.25 as a restore option.** `amount_iAdded = deposited + swapped − sleeve_held` (MiniMax §3.2) denies the depositor credit for the sleeve portion of their own basket. Owner rule 4 credits deployed **plus** sleeve. The whole post-swap basket `C` is the contribution; placement must not subtract caller sleeve from `C`. `reserve_iBefore = F_pre + D_pre` is the same stale pre-swap book. “Min-ratio is robust to skew once allocated” is false: equal sleeve **fractions** do not make `C` proportional to `B`, and LP-aligned `C` still donates under `min`. D34 “imported NFTs at native ticks” contradicts current conversion (`PositionImportTarget.sol` 89–93; `PositionRepo.sol` 82–86). Listing a type-default reset to `0.25e18` to preserve 20% of total is not a recommendation. The moderator PRD is on disk; MiniMax’s miss is not absence.

**Astra — accepted, with one default difference.** Post-swap `B = U − C`, `E` separate from spendable `F`, `F* = pT/(1+p)`, `p = 1` means half/half, and the conservation inequality are right. Pretransfer fact is right: `pretransferred` credits `amountIn` whenever `amountIn <= U` (`Common.sol` 1281–1288). Unsynced donations inflate `U` and can be claimed as caller input. `!pretransferred` returns the pull delta only (1276–1279). Composition credit must be that measured delivery, then the PoolManager delta of **that** amount — not balance growth and not unsynced `U`.

Astra’s **recommended default** is LP-ratio swap plus `min`, with disclosed donation. That donation is real (Astra’s `(200,100)` book, `C=(10,10)`, `m=5`). I do not adopt it as the default. Owner asked for proportional allocation of the owned book. That is exact only when `C` matches post-swap `B`.

**Grok round-2 original.** Book-align plus existing `min` still stands. Tighten two points: residual on a skewed book can be material, not a rounding leftover; uncollected `E` is in the ownership book once, but it is not spendable `F` and not `D`.

## Converged answer

**Books.** After the caller swap, before mint:

- `D_i`: this vault’s position principal at the **post-swap** price. Not external pool reserves. Not `E`.
- `F_i`: spendable ERC-20 face balance, excluding `C` when measuring incumbents. Not `E`.
- `E_i`: uncollected position fees. Collect before the idle snapshot so `E` becomes spendable `F` once. If still uncollected, keep it in the ownership book and out of `F*` and out of blocked cover.
- `C`: caller basket = measured pull of this call, plus swap output of that pull, minus input consumed. Includes the part later left in the sleeve. Excludes donations, incumbent sleeve, and self-LP fees.
- `U`: post-swap owned totals including `C`. `B = U − C`. Self-LP fee growth and CL repricing stay in `B`.

**Placement.** Do not freeze `p·D_pre`.

```text
T_i = D_i + F_i          // spendable principal book, after C is included in totals
F*_i = floor(T_i * p / (1e18 + p))
```

`p = 0.20e18` ⇒ `F* = T/6`. Stored `0` remains fallthrough (`VaultFeeOracleQueryFacet.sol` 322–330). Resolved `0` deploys all. `p = 1` ⇒ half/half; 100% sleeve is inexpressible (`VaultFeeOracleRepo.sol` 67–69). Deadband stays 5% of `F*` (~0.833% of `T` at `p = 0.2`). Add/remove only. No incumbent swap. No global oracle rewrite.

**Issuance, mint last.** Existing dual branch, no new NAV (`Common.sol` 700–704):

```text
m = min(floor(S * C0 / B0), floor(S * C1 / B1))
```

Exact proportional claim iff `C0/B0 = C1/B1` (1 wei). Then incumbents are not gifted a side. Token-wise, for the binding side, `S*(B_i+C_i)/(S+m) >= B_i` up to rounding (Astra). Placement does not change `T` or `C`, so it does not change `m` if fees were already assigned to `B`.

**Infeasibility, not a formula gap.** Current-call-only trading cannot both book-align `C` and LP-align `C` when `B` is skewed. Book-align: `min` is exact, and in-range `getLiquidityForAmounts` can leave a **material** abundant-token residual. LP-align: more of this call can deploy, and `min` donates the surplus side. Invariant growth on an LP-aligned basket is a different branch and can cut one incumbent token entitlement. Do not call that residue dust. Do not subtract sleeve-held `C` to hide it.

**Default.** Book-align the current-call swap to post-swap `B`, mint with `min`, place to `F*`, disclose material residue, revert if the swap bound or `minSharesOut` fails. Scarce-side deposits can receive fewer shares than today’s no-swap invariant-growth bonus; that is the cost of a proportional claim, not a reason to skip composition.

## Truly remaining choices

1. Price-bound source and whether non-Pons hooks fail closed. Not TWAP-from-DETF-law.
2. Only if the owner rejects material residue: they must explicitly accept LP-align donation, or a different dual formula. That pair is incompatible with donation-free `min` and current-call-only swaps. Do not “solve” it by restoring `0.25e18`.
