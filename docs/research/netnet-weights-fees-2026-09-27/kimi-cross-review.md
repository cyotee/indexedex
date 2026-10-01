# Kimi K3 — NN-05 weights/fees CROSS-REVIEW (Astra / Grok / MiniMax M3)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original; moderator corrections treated as authority. |

## 1. Four-way agreement (verified formulas)

All four traced the same code and agree on the substance of `previewSynthetic` (`ExitQueryTarget.sol:89–140`): self-leg excluded (:122); numeraire leg full value; other non-self legs marked into NET via the weight-ratio marginal identity (:129); owned-LP fraction over post-protocol-fee supply (:132–134); caller-side 9→WAD (`detfTotalSupply * 1e9`, `UniswapV4DetfCommon.sol:184–186`, applied once, pending-expansion handled once); creation-rate division (:139). The "simple NET-balance ÷ supply" formula is unanimously rejected. Fee mechanics unanimous: hook fee = growth-share protocol-LP mint (`Target.sol:387–452`, `Math.sol:165–179`, `FEE_DENOMINATOR=100_000`), not a flat join haircut; DETF seigniorage = issuance-time split (`DETFMintSplitLib.sol:19–53`); two independent floors live / three bond; no double charge. Oracle: three-tier vault→type→global, stored 0 = unset (`IVaultFeeOracleQuery.sol:16–24`; Astra adds the facet citation `VaultFeeOracleQueryFacet.sol:105–116,224–233`, peer-reported, plausible).

## 2. The one real disagreement — creation normalization (resolved by moderator ruling)

- **Grok (:57) sets `creationOfPair[NET] = 1000e18`**, making `synthetic = 1e18` correspond to **1,000 NET per DETF** — i.e., normalizing the peg to the opening price. Under the selected absolute peg (1 NET/DETF gates swap vs burn), this silently redefines the threshold to the launch price.
- **Me and Astra** set `creation = 1e18` (1 NET/DETF), `opening = 1000e18`, preserving the source's :139 creation division untouched — the opening/creation split already exists (`_openingBondQuote` :259–264 uses opening, creation fallback; `_quoteCtx` uses creation only).
- **Ruling (moderator, adopted): peg is absolute 1 NET; reject creation=1000; preserve the source creation division with 1e18 creation / 1000e18 opening.** Grok's mapping is corrected accordingly. His own note ("pin NET as the synthetic numeraire") survives and is adopted.

## 3. Corrections adopted from the moderator/peers (sharpening all four drafts)

1. **Oracle stored-0 ≠ silent-zero result.** MiniMax's heading "Oracle fallback (silent zeros, not reverts)" conflates two distinct semantics: the *oracle's* stored-0 triggers vault→type→global **fallback** (a resolved value, possibly nonzero), while the *math helpers'* zero returns (`protocolLpShares` :173–175, `_maybeMintProtocolFee` :432–434, `previewSynthetic` :94–97) are fail-closed outputs. Keep them separate; `_seigniorageIncentiveWad`'s oracle-address-0 → 0 (`DetfCommon.sol:114`) is a third, distinct "unconfigured" case.
2. **Rate failure ≠ missing TWAP.** `_getRateFailClosed` (`Target.sol:330–332`) failing is a genuine dependency failure, never the absent-TWAP above-1 policy branch.
3. **A not-live/zero synthetic return is not a measured below-peg price.** `previewSynthetic` returning 0 must map to TWAP-series *unavailability* (absent→above-1 policy), never be recorded as a measured 0 (<1 → burn). This closes a capture-rule hazard none of the four drafts stated explicitly; it follows directly from A44's no-fabricated-measurement rule.
4. **K is the Weighted invariant V / interim k, not a square root** despite the `rootK` name (Astra :45; `Target.sol:334–346,400–412`, measured from normalized native inventory, not the rated vector).
5. **Fee separation vs swap/imbalance (Astra :47, peer-cited JoinCore :191–215,552–611):** pending protocol HLP is minted *before* user join-share calculation; previews include the dilution; unbalanced joins separately use `dexSwapFeeOfVault` in the imbalance math — no duplicated usage fee. Ordering obligation for the custom hook. (Citation peer-reported, not independently read by me.)
6. **No Universal imports:** `_highestSyntheticPrice` (`DetfCommon.sol:322–340`) is Universal's expansion helper — NetNet expansion is hook-TWAP-gated and must not import it (Grok :59); the reference live-mint seigniorage path is not restored for custom liquid purchases (Astra :63); expansion takes no `p` — fee/creator internal shares only (Grok :88).
7. **2.5× mark only conditionally:** with all three external coordinates positive and selected weights, the mark ≈ 2.5×R_NET (Astra :28) — conditional on positivity/domain checks and exact per-stage floors; never a constant coefficient in the spec.
8. **`DETFDecimalScaleLib` comment claiming DETF "stays 18" contradicts 9-decimal law and Common's ×1e9** (Grok :90) — code-comment discrepancy worth recording; Common controls. (Peer-reported, not independently verified by me.)
9. **Pin NET as numeraire explicitly:** `_syntheticPrice` reads `pairs_[0]` (`DetfCommon.sol:207–211`) — array order is not a numeraire guarantee (Grok :59, Astra :15).

## 4. Dissent record

Only Grok's creation=1000 mapping — resolved against it by the moderator's absolute-peg ruling. MiniMax's zero-semantics conflation — corrected, not a product disagreement. No remaining dissent; nobody reopened the user's fee choices, weights, or the reused formulas.

## 5. Final amendment content (merged, for the consolidator)

Record as selected: weights `[50,20,10,20]e16` bound by **leg identity** (not array order); synthetic = reference `previewSynthetic` with **NET pinned as numeraire**, `creationOfPair[NET] = 1e18`, `openingOfPair[NET] = 1000e18`; self-leg excluded, other positive non-self legs weight-marked into NET; owned-HLP over post-protocol-fee supply; native-9→WAD once; pending supply once. Fees: hook usage fee realized as growth-share protocol HLP mint under the hook key; DETF seigniorage as issuance split under the DETF key; swap/imbalance fees separate; no flat join haircut, no double charge, no new defaults, no live values claimed. Capture rules: rate failure and zero/not-live returns map to unavailability, never to a measured price. Remaining engineering (not owner numbers): custom SY/PLP-YT custody→native/rated book mapping (NN-08/NN-10), preview/settlement parity, first-bond G/U under these weights (A35).

## 6. Limits

Peer-only citations flagged (JoinCore ranges, VaultFeeOracleQueryFacet, DETFDecimalScaleLib comment); everything else re-verified against my own direct reads this session. No execution, no live-config claims, originals unchanged.
