# Grok original — shared-SY NET/sNET output (owner override of PRD v0.21)

| Field | Value |
| --- | --- |
| Researcher | Independent Grok first pass |
| Observed model metadata | Prompt names `grok-4.6`; ID `xai/grok-4.6`. Routing, not attestation. |
| Date | 2026-09-26 |
| PRD | `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` **v0.21** (1067 lines) |
| Authorization | Research only. Moderator owns PRD edits. No implementation. |
| Peer artifacts | None read. |

**Verdict:** Accept the owner’s **nonstandard** split: NET is **priced** from the PLP/YT zap-out virtual, but **ordinary NET output is funded from the same held SY book as sNET**, not by liquidating PLP/YT. Do not reject or redesign it. C09 and C10 are **answered**. v0.21 still says the opposite on NET **funding** (R49, §6.1, A27). Full rewrite of those rows is required. §7.1.2 stays **valuation + HLP allocated position-exit**, not ordinary swap funding.

Do **not** reopen: 3600s arithmetic TWAPs; absent-as-above-1; `floor(S0*n/200)`; pre-expansion participation; fee/creator internal shares; interest-token/`feeTo` with non-blocking retries; atomic rollover; family approval; four HLP legs; SE-share HLP (no unwrap); Keep-YT **ingress**; USDG swap deposit/redeem; raw DETF swap from held balance; `minAmountOut` / atomic revert / **no principal fallback**.

## Settled owner routes (this round)

| Surface | Selection |
| --- | --- |
| HLP legs | Unchanged: raw DETF; raw custom V2 SE shares (no underlying on HLP exit); held + net-claimable SY with direct SY join/payout; internal proportional PLP/YT sub-reserve |
| HLP unbalanced | **Existing Balancer V3 Weighted unbalanced liquidity** (invariant-ratio + taxable excess), **not** `h/H` of each selected leg and **not** omitted-claim retention of a full basket. **C10 closed.** |
| DETF swap | Raw DETF in from held / out from held |
| USDG swap | Rate-valued SE inventory; USDG in deposits SE, out redeems SE |
| NET **and** sNET **in** | Both enter Pendle via **Keep-YT**. **C09 closed.** |
| NET **price** | §7.1.2 joint zap-out of PLP/YT (unchanged method) |
| Ordinary NET **and** sNET **out** | **Same eligible SY reserve.** Held SY first; if short, claim pending interest/rewards, **retain SY**, forward other tokens to current `feeTo()` (retry policy unchanged), then `redeem` needed SY to the requested token |
| Purpose | Sell earned interest to grow Pendle principal. Shared ingress/egress, **different pricing coordinates**. |

HLP PLP/YT **allocated** exits still realize that position to SY via §7.1.2. That is **not** ordinary NET swap funding.

## BasicVaultRepo — observed API (do not invent)

`contracts/vaults/basic/BasicVaultRepo.sol` (pragma `^0.8.0`):

- Slot `keccak256(abi.encode("indexedex.vaults.basic"))` (`:20`).
- `Storage`: `AddressSet vaultTokens`; `mapping(address => uint256) reserveOfToken` (`:23–28`).
- Helpers: `_initialize` / `_vaultTokens` / `_addVaultToken(s)` / `_reserveOfToken` / `_updateReserve` / `_reserves` (`:51–134`).
- **NatSpec fact (`:25–26,91–96`):** `reserveOfToken` is **only locally held ERC-20 balances**, for pretransfer / pass-through checks. It is **not** external DEX share accounting (not PLP inside Pendle, not unclaimed YT interest).

**Inference:** “Update held SY using BasicVaultRepo” means: after every SY mint/claim/redeem/donation/forward, `_updateReserve(SY, IERC20(SY).balanceOf(hook))` (or equivalent newReserve) so accounted **held** SY matches local cash. **Unclaimed** interest cannot live in this mapping until claimed. Accounted SY book = `reserveOfToken[SY]` + **separately** computed net-claimable (InterestManagerYT:43–79: `accrued` minus factory interest fee; index catch-up before transfer). Force-claims that pay the hook must reconcile `balanceOf` vs stored reserve **once** (A05/pretransfer). No extra BasicVaultRepo methods exist.

## Balancer V3 unbalanced (C10)

**Fact.** Local `UniswapV4StandardExchangeWeightedBufferHookMath.sol:303–353` `_unbalancedJoinShares` “Mirror BasePoolMath.computeAddLiquidityUnbalanced”: new balances, `computeInvariantUp`/`Down`, `invariantRatio`, fee on **taxable** excess vs proportional token, BPT from invariant growth. Caps: `MAX_INVARIANT_RATIO` 300% (`WeightedMath.sol:36–39`). Context7 `/llmstxt/balancer_fi_llms-full_txt` 2026-09-26: unbalanced add/remove = proportional liquidity **plus a swap**; `addLiquidityUnbalanced(exactAmountsIn → bptOut)`.

**Inference:** omitted tokens are **not** paid and **not** kept as a second claim on the burner; remaining LPs keep the residual book. That closes C10’s “omitted-claim retention” vs `h/H` selected-leg. Still must map four **rated** legs (DETF, SE shares, SY, **subshares**) into this math; nested PLP/YT floors stay inside the subshare leg.

## Shared-SY conservation (do not redesign)

**Intended books (inference from owner, not a new product):**

1. **SY cash book** (BasicVaultRepo + claimable): funds **both** ordinary NET-out and sNET-out.
2. **PLP/YT sub-reserve:** grows on Keep-YT **in**; shrinks only on **HLP allocated position-exit** (and rollover/expiry realization), **not** on ordinary NET swaps.
3. **Virtual NET price** = §7.1.2 zap-out of remaining PLP/YT (may **exceed** SY cash).
4. **Virtual sNET price** = SY provider × eligible SY.

**Finite liquidity vs virtual price (real blocker / proof obligation):** a Weighted quote using zap-out NET can demand more NET than `previewRedeem` of eligible SY can deliver. Selected policy: **revert** (`minAmountOut` / R22). **No** silent PLP/YT liquidation. Specify exact-out inversion against **SY cash**, while the **price** still comes from the zap-out coordinate — those two numbers can diverge; that is accepted, not a license to merge books.

**Cross-leg effects (proof):** NET-out and sNET-out **both debit the same SY cash**. After a NET-out, sNET virtual falls; PLP/YT (hence NET virtual) **unchanged**, so NET/sNET relative price **moves without touching Pendle LP**. Keep-YT in **does not** credit the SY cash book (principal in sub-reserve). HLP SY exit debits SY cash + HLP; must not also look like a swap. Position-exit SY must **not** be credited into the interest/SY cash book (`PRD.md:287` already; keep). Fee-owned tokens never enter SY cash (`:796`). Claim: receivable → `_updateReserve` held SY, **once**.

**Claim-to-cash sequence (selected):** held eligible SY first; if insufficient, claim pending interest/rewards; **retain SY**; forward non-SY rewards to `feeTo()` with **non-blocking** retries (`:796`); then redeem needed SY to NET or sNET. Failed user redeem/minOut still **reverts the swap** — forwarding isolation does not waive payout.

## Stale v0.21 text to replace (operative)

| Location | Retired | Replacement |
| --- | --- | --- |
| R03 `:146`; R37 `:180`; §5 `:310`; C09 `:837`; O06 `:811` | sNET in unfinished / not Keep-YT | **sNET in = Keep-YT**, same as NET |
| R28 `:171`; R32 `:175`; C10 `:838`; §4.4 `:291`; §7.1 `:393` | C10 open; fear of `h/H` or omitted-claim | Unbalanced = **existing Weighted/BasePoolMath unbalanced**; omitted legs stay in the pool |
| R49 `:192`; `:51,91,103`; §6.1 `:349`; `:353`; `:367`; A27 `:874` | Ordinary **NET out realizes PLP/YT** | NET **priced** by §7.1.2; **funded** from shared SY cash; no principal fallback |
| §7.1.2 `:403` “NET pricing/**output**” | Mixes valuation with swap funding | Valuation + **HLP position-exit** only for ordinary NET **output** |

Keep §7.1.2 steps 1–7 and post-expiry rules as written for quotes and HLP `exitPreExpToSy` / `exitPostExpToSy`.

## Proof obligations (not extra owner questions)

1. Conservation: one SY debit schedule for NET-out, sNET-out, HLP SY-out, claims, force-claims, donations; no double credit of position-exit SY.
2. Preview/execution: Weighted NET amount vs `previewRedeem`/`redeem` of **eligible** SY (Pendle previews unofficial on-chain — `PRD.md:301`).
3. Exact-out: invert against SY cash + claimable, not against zap-out inventory.
4. BasicVaultRepo vs `balanceOf` vs Pendle `userInterest` under callbacks.
5. Weights/virtual balances after SY-cash changes that **do not** change PLP/YT.
6. FoT NET / rebasing sNET on the final SY redeem (family-approved; still delivery-check).

**Not owner questions:** C09/C10; whether to liquidate PLP/YT on NET-out (**no**); TWAP/expansion; feeTo set.

## Confidence / limits

**High:** C09/C10 closed; NET price vs SY funding split; BasicVaultRepo local-only semantics; unbalanced = invariant-ratio math; v0.21 R49/A27 stale. **Medium:** exact claim/redeem ordering vs minOut. **None:** solvency if zap-out ≫ SY cash (policy is revert). No tests. Context7 Balancer 2026-09-26. No consensus.
