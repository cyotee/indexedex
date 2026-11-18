# Member feedback

## Identity

- Run ID: v3-fullspread-v4-accounting-plan-20261116
- Member label: grok
- Profile: research
- Phase: advisory review
- Owned path: docs/research/v3-fullspread-v4-accounting-plan-20261116/members/grok/feedback.md
- Requested role: council-member
- Requested model: xai/grok-4.7:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Initial response path: docs/research/v3-fullspread-v4-accounting-plan-20261116/members/grok/response.md
- Initial response preserved: yes

This is a new advisory-review conversation. It is not the initial-response conversation. No runtime identity was given.

## Draft under review

- Draft ID: draft-v3-fullspread-v4-accounting-plan-20261116-r1
- Path: docs/research/v3-fullspread-v4-accounting-plan-20261116/coordinator/draft.md
- Fingerprint supplied by the coordinator: f8265634984958df9eb1e22716527ae6be06c7b5505ab571ddbe1fa0d2026314
- Fingerprint independently computed: not computed
- Draft bytes opened: yes

The opened file's own identity line is draft-v3-fullspread-v4-accounting-plan-20261116-r1. The supplied fingerprint was not recomputed.

## Disposition

- Disposition: requested-changes
- This file replaces a missing initial response: no

The carried disagreements match my initial response. The corrections below are execution splits in the draft's own steps. They are not a request to reopen those disagreements.

## Concerns

| ID | Draft location | Concern | Requested change |
| --- | --- | --- | --- |
| G1 | Step 4; Step 7 | Step 4 says `setOperator` and `setOperatorFor` are not in the V3-ACC-16 exception list, so a disabled vault reverts `VaultDisabled` on them. Step 7 groups those two selectors with `donate` and `compound` under Maintenance and says maintenance remains available while the vault is disabled. An author cannot satisfy both sentences. One will revert operator appointment while disabled. The other will allow it. | In Step 7, limit the disable exception to `donate` and `compound`. State that `setOperator` and `setOperatorFor` revert `VaultDisabled` while the vault is disabled. Do not describe operator appointment as maintenance that remains available. |
| G2 | Step 8; Requirement check | V3-ACC-15 and V3-ACC-16 are mapped to steps 4, 5, and 7 only. Step 8 does not state either gate. Import must `pool.mint`, so a locked pool is an execution route V3-ACC-15 covers. Import is not a withdrawal, `donate`, or `compound`, so a disabled import reverts `VaultDisabled`. Step 8 says to preserve deadline, but not that a missed deadline reverts before disable. An author who treats the requirement check as the coverage list, and Step 8's bullets as that step's work, will leave import callable while disabled or while the pool is locked. | Map V3-ACC-15 and V3-ACC-16 to Step 8. In Step 8, state the order: a missed deadline reverts before `VaultDisabled`; a disabled import reverts `VaultDisabled`; a locked-pool import execution reverts `UniswapV3Exchange_BoundPoolInteractionBlocked`; the preview does not revert merely because the pool is locked. |
| G3 | Step 5; Step 7 | Step 4 says a missed deadline reverts before disable on a route that takes deadline, and that a disabled vault reverts `VaultDisabled` on every execution route except a withdrawal, `donate`, and `compound`. Step 5 states the disabled `exchangeOut` error and does not state that deadline order. `exchangeOut` takes deadline and does not touch the pool, so the fail-closed errors stay; only the order is missing. Step 7 states the disable exception and the locked-pool bar only for maintenance. It does not state that a bundle deposit reverts `VaultDisabled`, that a bundle exit is a withdrawal and remains available, that both bundle routes take deadline, or that bundle execution reverts `UniswapV3Exchange_BoundPoolInteractionBlocked` while the bundle previews do not. An author implementing Step 5 and Step 7 from their own bullets can keep disable-before-deadline on `exchangeOut` and can ship bundle routes without those gates. | In Step 5, state that a missed deadline reverts before `VaultDisabled`. Do not replace `ExchangeOutNotAvailable` with the pool-lock error. In Step 7, state the bundle gates separately from maintenance: deadline before disable; a disabled bundle deposit reverts `VaultDisabled`; a bundle exit remains available while disabled; locked-pool bundle execution reverts `UniswapV3Exchange_BoundPoolInteractionBlocked`; bundle previews do not revert merely because the pool is locked. |
| G4 | Step 8 | Step 8 lists nonzero source liquidity with owner or approval, matching pool, deadline, and non-reentrancy as checks to preserve under V3-OWN-01. The tests then keep the zero-liquidity negative. V3-OWN-01 does not name that reject. It requires collection of every token amount the NFT yields, including fees. A position can have zero liquidity and nonzero tokens owed. An author who follows the preserve list will reject that NFT and skip collection. An author who follows the collect sentence will collect those fees and then apply genesis or the positive-supply no-mint rule. | Remove nonzero source liquidity from the preserved-check list. Do not present the zero-liquidity reject as a V3-OWN-01 requirement. If the NFT yields tokens, collect them and then apply `MinLiquidityNotMet` on a failed genesis or the positive-supply no-mint rule. Do not add a new error. Keep the wrong-pool, unauthorized, and deadline negatives. Do not keep a zero-liquidity negative that skips collection. |

## What was not adopted from others

- Peer responses read: not read
- Peer feedback read: not read
- Unread members treated as support: no

The draft's attributions of Astra, Kimi, and MiniMax were not checked against their files. Unread text is not agreement.

## Limits

- Advisory only. The coordinator decides acceptance, rejection, or deferral.
- This file grants no implementation authority.
- This file does not replace the draft.
- Inherited parent permissions are not evidence of confinement.
- The supplied fingerprint was not recomputed. No test, build, Git, or install was run.
- Carried disagreements on import execution return width, unnamed transition-quote removal, `deployedReserve`, the usage-fee key, the storage file, and the floor write match my initial response. I do not ask to reopen them.
- Step 8 is right that widening `previewImportPosition`'s return does not change the selector, and that a selector or ERC-165 check does not prove the ABI change. I do not ask to restore the contrary sentence in my initial response.
- The empty-NFT burn, post-supply import, recipient refunds, and new-vaults fence match the locks. Those matches are not approval of the four rows above.
