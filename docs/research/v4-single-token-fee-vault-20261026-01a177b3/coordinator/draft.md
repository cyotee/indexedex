# Coordinator draft

## Draft identity

- Draft ID: draft-v4-single-token-fee-vault-20261026-01a177b3-r1
- Path: docs/research/v4-single-token-fee-vault-20261026-01a177b3/coordinator/draft.md
- Run ID: v4-single-token-fee-vault-20261026-01a177b3
- Status: pending advisory review. This file is not the final.
- Fingerprint: not stored in this file. RUN.md records the sha256 of these bytes before advisory review.
- Sources: the four initial responses and the coordinator-fetched pages in coordinator/public-sources.md. The coordinator is not a fifth vote.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

What existing public design, or new design, can IndexedEx adapt so a vault earns the underlying pool's trading fees, can be valued as one token, and can be exited in that one token, when that token may have liquidity only in the underlying pool and that pool's TWAP is the only reference?

## Proposed text

No opened design meets every constraint. The closest design to adapt is a settled-target claim. It is new. It is not an implementation.

The holder deposits the target token, receives shares of a settled target balance, and exits in that token or the exit reverts. The share does not hold the pool position. A separate position, funded by capital that is not this share, can earn the pool's swap fees. Only fees actually collected in the target token are credited to the settled balance. Fees collected in the other token are not marked, not sold, and not added to the share.

That is the design. Two constraints break, and they are named here rather than renamed:

- Fee exposure is incomplete. Holders do not earn the other token's LP fees, because putting those fees into the target token requires a sale or a price. This design uses neither.
- `getRate` previews the exit this design actually performs. That exit does not sell. `getRate` is therefore not a withdrawal-and-sale preview. It is also not a NAV mark of unsold inventory. Do not redefine it to satisfy the sentence.

If "use this liquidity" means the deposited target is itself the pool principal, and the resulting share is still valued and exited as one token, this design does not do that. Astra names the same break as same-capital reuse. No settled response established a design that does that stronger thing under the same-pool premise.

### Mint

The mint uses no price, no quote, no TWAP, and no `getRate`.

`sharesMinted = floor((S + s0) * D / (A + a0))`

`S` is share supply. `A` is settled target. `D` is target actually received by the deposit call. `s0` and `a0` are nonzero genesis constants, one-for-one. A bare transfer does not increase `A`. Issuance is this equation. It is not a mark of the pool book.

### Exit

Burn the shares and pay `floor(shares * A / S)` in target from idle settled target. If idle target is short, revert. Do not read the pool, remove liquidity, swap, or pay the other token. A later credit is allowed only when the credit is target tokens already held, such as collected target fees.

### What another hook can hold

Under the locked valuation law, another hook can hold this share and value it as raw balance, or as balance times a rate provider. The provider must return settled target per share and fail closed on revert, a short return, or zero. It must not read the pool. A hook must not derive a rate from the Standard Exchange it holds.

### What was not adopted

ICHI's published vault prices the book from token amounts and the pool ratio, and compares spot with a TWAP. That is a priced mint. The prior report is the reason not to adapt it. The coordinator fetched that page. The formulas on it are images, so the exact equation was not extracted as text.

The Arrakis page the coordinator fetched is an issuer-owned NFT with an optional external price. It is not a public single-token depositor share.

Bunni's pool-creation docs did not load. The fetched incident writeup is a rounding drain of a two-token book, not a design to copy. Grok reports the Bunni repository says the code was exploited and should not be used as-is. That repository text was not re-fetched by the coordinator.

MiniMax keeps the liquidity in the share and mints against `max(spot, old TWAP)` of the whole book, then sells the redeemer's other-token slice. That uses a same-pool price on inventory the deposit did not trade. The prior report did not treat that class of mint as a repair. The frozen observation MiniMax requires is not the TWAP implementation read in the prior run.

Kimi keeps the liquidity in the share and mints with a price-free per-component join, with an unpriced zap outside issuance. The prior report adopted that acceptance identity and did not adopt post-sale immunity. Kimi's `getRate` is a live one-share sale through the pool, so one transaction can move the number another hook would read. That share is not the usable reserve this question asked for.

Grok reports that the archived THORChain Savers page describes units over an asset-quantity balance, with yield paid in kind, and an exit that still swaps. The coordinator has not re-fetched that page. The settled-target claim borrows the asset-quantity balance only. It does not borrow the exit swap.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Who holds the pool principal | Astra and Grok: not the share. MiniMax and Kimi: the vault, funded by depositors. | The draft adopts the first, because the second cannot be valued through a rate another hook can trust without a same-pool price or a live sale. |
| Whether `getRate` on a no-sale exit satisfies the withdrawal-and-sale sentence | Grok: no. Astra: the one-share preview is linearly consumable because backing is target. | The draft follows Grok's label. It does not call the preview a sale. |
| Whether a priced conservative mint is enough | MiniMax: `max(spot, old TWAP)` stops the depositor capturing an inflated book, and pool-price exposure remains. | Not adopted. Not treated as a refutation of MiniMax's arithmetic. The coordinator did not re-execute that equation. |
| Whether the price-free join plus a slice sale is the design | Kimi: yes, with the single-token deposit broken at the accounting boundary. | Not adopted for this question. The acceptance identity from the prior report is not withdrawn. |

## Evidence gaps

- The coordinator has not re-fetched the THORChain Savers page, the Bancor pages, the Bunni repository, or the Bunni post-mortem. Those citations stay Grok's observations.
- Bunni's docs site failed TLS on the coordinator fetch. No content is claimed from it.
- No product PRD for this vault was supplied. None was invented.
- No response was executed as a Forge trace or a production Wings lifecycle.
- MiniMax's mint equation was not re-executed.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| One recommended design | examined | Grok's settled-target claim, with Astra's same split | Kimi and MiniMax recommend keeping the LP in the share. Not averaged. |
| Earn pool swap fees, not an exit fee | partial | All four reject an exit fee. Astra and Grok limit the credit to target-denominated fees actually collected. | Complete two-token fee exposure is the named break. |
| Value and exit as one token | examined | Astra and Grok | The exit pays settled target or reverts. |
| No independent price | examined | The adopted design uses no price | MiniMax's design uses the pool price. Not adopted. |
| `getRate` not redefined as NAV | examined | Grok's label | The adopted preview is not a sale and not a mixed-book NAV. |
| Usable by another hook under the locked law | examined | The adopted share, as raw balance or as settled-target rate | A live sale preview is not adopted as that rate. |
| Public design to adapt | examined | ICHI, Arrakis Pro, and the Bunni incident were fetched by the coordinator. None is the recommendation. | Savers and Bancor remain member-fetched. |

## Limits

- Static, extracted, supplied-runtime, and unverified claims stay distinguished.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- Agreement that no complete design was found is not a proof that none exists.
