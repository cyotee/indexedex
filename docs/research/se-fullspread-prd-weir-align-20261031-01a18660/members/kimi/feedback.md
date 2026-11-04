# Identity

Kimi, independent council member, research profile.

# Draft reviewed

- Draft ID: `se-fullspread-prd-weir-align-20261031-01a18660-r1`
- Path: `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/coordinator/draft.md`
- SHA-256 verified: `c7afa4cd5c82ff0338ebe3cc09ab5aa216280fa17a2c584127b349e73cd10527`

# Disposition

The draft states the core of my original accurately: Weir is the money-rule source; PairToken economics are not inherited; unused input is refunded; actual deltas settle entry; issuance is liquidity-based with the cited genesis floor and excludes idle from the later-deposit denominator; `compound` is harvest-and-reinvest before deposit and withdrawal; `donate` is a locked non-Weir exception; and no zap guard or performance fee is added.

It is nevertheless incomplete as a coordinator-ready replacement set. Several existing PRD sentences that my original expressly replaced would remain and contradict the draft if its edits were applied literally. The corrections below are fidelity and completeness corrections, not votes on the preserved disagreements.

# Corrections by draft section

## Authority

The economic-authority statement is accurate, but the replacement must also cover the current PairToken `PkgInit`-shape authority row, the named-override paragraphs, and the blanket S1-inheritance paragraph. Otherwise the PRD still inherits package inputs and acceptance economics by ID even after the narrative says it does not. Preserve only the expressly retained non-economic hook, registry, compiler, and testing authorities.

## FS-MONEY-01

Add the withdrawal rule from my original: `WeirVaults._withdraw` removes proportional position liquidity and proportional idle amounts; the accepted paired exit pays both currency faces in `vaultTokens()` order without selling one leg to pay the other. Also state that the PairToken withdrawal-only collect-or-compound fallback is removed. Compound-before-withdrawal alone does not expressly remove that old fallback.

Clarify the genesis wording so `totalShares` is not read as finally containing only `MIN_SHARES`: `_deposit` subsequently adds the minted shares to `totalShares`, leaving the `1_000` floor included in the total. This does not choose the floor's ERC-20 representation, which remains open in the draft.

## Proposed text — add the missing package-input replacements

The draft needs a distinct FS-FACET-01 / FS-PKG-01 / FS-PKG-02 correction. Deleting the two zap fields under FS-OWN-09 and FS-OWN-10 is insufficient because the current PRD would still say that `PkgInit` follows PairToken facet order and that `PkgArgs` is the PairToken set.

State that the package fields are self-contained, remove `previewZapCredit` from the `quoteFacet` row, reduce `PkgArgs` to `poolKey`, `name`, and `symbol`, and delete the `InvalidZapLimits` validation bullet. These are removals of unauthorized inheritance, not proposals for replacement guards.

## Proposed text — add the missing §2.1 and §6 replacements

Replace the §2.1 **Entry remainder** disposition, which currently retains inherited `J_i` booking and full selected-swap consumption. Replace the §6 issuance row, which currently names S1-ACC-02/S1-ACC-07 and `previewZapCredit`, with the cited Weir issuance rule and the absence of `previewZapCredit`. Without those edits, two sections directly contradict FS-X04 and FS-MONEY-01.

## FS-PKG-02 and the genesis disagreement

The proposed edits must expressly remove or replace the existing initialization sentence banning a permanent dead-share mint and FS-A05's corresponding `No dead-share mint` assertion. The draft's statement that it “does not restore the old dead-share ban” records intent but does not identify those conflicting texts.

This correction does not resolve whether a new owner lock is needed or choose an ERC-20 holder/representation. It only makes the draft's stated source formula and its preservation of that open question internally consistent.

## Tests and acceptance

The generic instruction to replace rows is not enough to cover every removed rule. Name the local replacements for:

- FS-TEST-02's blanket inheritance of S1-A01 through S1-A70, so no inherited row can restore removed economics.
- FS-A03: remove zap-limit validation.
- FS-A05: replace the dead-share ban with the cited genesis behavior while leaving ERC-20 representation open.
- FS-A06: use FS-MONEY-01 issuance and proportional paired redemption, not S1-ACC-02/S1-ACC-03.
- FS-A07: assert actual-delta settlement and payer refunds, with no entry `IncompleteConversion` or booked `J_i`.
- FS-A11: assert compound before deposit and withdrawal and no withdrawal-only fallback.
- FS-A25: use FS-MONEY-01 issuance and fee compounding, not S1-ACC-06 attribution.
- FS-A33: remove the inherited fallback comparison while retaining equivalent locked and borrowed compound behavior.

FS-A08 should remain unchanged: the accepted one-token exit pays only the selected token or reverts, and a revert does not burn shares.

## Preserved disagreements

Do not resolve either preserved split in this revision. The genesis correction above addresses only conflicting existing text; it does not select a representation or owner lock. The one-token credit correction requires no new return field or encoding and should leave that disagreement exactly as recorded.

# Limits

This is advisory only. It does not implement code, edit the draft or PRD, or authorize a new guard, fee, or owner decision. No peer responses were read.
