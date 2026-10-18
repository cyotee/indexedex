# Kimi K3 — REQ-05 outside-trade: is an owner question left? (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. Controlling text: `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` REQ-05 (`:255-270`, read in full). The four families' tests were verified against current source in my preceding pass (`kimi-req05.md`): V3 FullSpread (`release/v3/…_FeeCompound.t.sol:50-75`), V4 hookless (`…/hookless/AttributionAndBooking.t.sol:34-49`), V4 Pons (`…/ponsFamilyV2Hook/AttributionAndBooking.t.sol:37-52`), Wings (`…/upperLowerWings/…Money.t.sol:26-40`). Nothing was edited. I did not run Forge.
- **Date:** 2026-10-17.

## Answer: No blocking question.

Every acceptance criterion in the section is already satisfied by current source, verified per family in my prior pass: each family has an outside-trade test whose pool trade never touches the vault (direct `pool.swap` / `poolManager.swap` / actor swap), whose `reserveOfToken` and supply assertions prove the book is not refreshed, and whose follow-on deposit is credited exactly at the funded input's preview; the reserve-reconcile supplement is labeled as not-the-proof in current law docs (`STAGE1_EVIDENCE.md:22`); the old-bug evidence is historical and the deleted legacy tree needs no compilation. No product, economic, or scope decision remains for the owner.

## The one closed PRD scope, in one sentence

"REQ-05 is a completion record, not new work: the PRD names the four existing outside-trade tests — V3 FullSpread `release/v3/UniswapV3FullSpreadStandardExchangeVault_FeeCompound.t.sol:50-75`, V4 hookless `fullSpread/hookless/AttributionAndBooking.t.sol:34-49`, V4 Pons `fullSpread/ponsFamilyV2Hook/AttributionAndBooking.t.sol:37-52`, and Wings `upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.t.sol:26-40` — as the per-family proof that an outside pool trade does not refresh the vault book and that the next credit uses only vault-held tokens, records that the reserve-reconcile supplement is not that proof, and closes the item with no production change and no new test."

## One execution-evidence note (not a question)

My verification is source-presence; no reviewer ran the four tests this round. If the closing PRD wants runtime evidence, it can name one recorded command for the four files — that is an execution-record detail for the plan, not an owner question, and it invents no production work.

I did not run Forge.
