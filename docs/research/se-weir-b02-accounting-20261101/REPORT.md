# Research report

## Question

- Run ID: se-weir-b02-accounting-20261101
- Question: Does WeirVaults' own internal accounting resolve the B-02 losses, or does a caller-moved pool price still leave that loss with the other holders?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the owner asked this session for a council analysis of how Weir Vaults handle this internal accounting, including Python simulations. "This" is B-02.
- Admitted read scope: `contracts/protocols/strategy/weir/WeirVaults.sol`, `contracts/protocols/strategy/weir/libraries/LiquidityAmounts.sol`, B-02 in the full-spread blockers file, APEX-2026-023 and APEX-2026-024 in the second-audit report, and FS-OWN-10, FS-OWN-12, FS-OWN-14, FS-OWN-15, FS-OWN-33, and FS-MONEY-01 in the full-spread PRD.
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git. It does not lock B-02. It does not edit the PRD or the blockers file.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking agent | invoking session model | xai/grok-4.7, xhigh | not exposed | continued | completed synthesis | `PI_PROVIDER`, `PI_MODEL`, `PI_REASONING_LEVEL` |
| Astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | chatgpt-subscription/gpt-6-astra, high | st_01a198bf | fresh, then continued for feedback | initial and feedback completed | completion notices |
| Grok | council-member | `xai/grok-4.7:xhigh` | xai/grok-4.7, xhigh | st_01a198c0 | fresh, then continued for feedback | initial and feedback completed | completion notices |
| MiniMax | council-member | `minimax/MiniMax-M3`, adaptive thinking | minimax/MiniMax-M3, adaptive thinking admitted in the live models file | st_01a198c1 | fresh, then continued for a clarification and for feedback | initial and feedback completed | completion notices |
| Kimi | council-member | `kimi-coding/k3.1-pro:high`, global route | kimi-coding/k3.1-pro, high | st_01a198c2 | fresh, then continued for feedback | initial and feedback completed | completion notices |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

The coordinator is not a vote. The Grok member is a separate conversation.

## Conclusions

Weir does not resolve B-02. It removes APEX-2026-024's whole-opposing-balance quantity shape. It leaves APEX-2026-023's live-price placement exposure, and the absolute swap limit, in place.

Selecting the Weir model is not a new rule, and it is not a lock sentence. FS-MONEY-01 expressly copies the absolute entry-swap limit and the cited compound-before-money order. The named locks do not contain the words `slot0`, `getSlot0`, `live-price`, `TWAP`, or `pre-operation`. Live-price sizing is what the cited Weir operations do, and what those locks do not forbid. The withdrawn-net swap amount is explicit in Weir and is not an explicit sentence in FS-OWN-15. That absence is a specification gap. It is not authorization to sell the staying holders' inventory, and it is not a request for a new economic cap.

No member found a read of a pre-operation price, a TWAP, or any other reference. The only price used to size liquidity is the pool's live price. This result does not assume an independent pricing source.

### External push

Not resolved for vault-owned idle or harvested fees, when the position already has liquidity.

`compound` is external. The notice says anyone can call it. `_compound` returns immediately when `v.liquidity == 0` (`WeirVaults.sol:343`), so that empty path does not place idle. When liquidity is positive, it sizes remainder plus idle at the live `slot0` and, if liquidity can be added, adds it without increasing `totalShares` (`:355-376`). After the price returns to `P0`, that shortfall sits in a position the existing holders own. The caller of `compound` does not receive new shares for it.

Astra, Kimi, and MiniMax ran the comparable 100/100 budget that was balanced at `P0 = 1`. At twice the price the placement shortfall is about 8.578644 token1. At four times the price it is 25. Those direct amounts match the audit approximation `IL(dL) = dL * (sqrtP' - sqrtP0)^2 / sqrtP'`. Grok printed the same identity at a 1e17-scale budget. The coordinator re-ran all four scripts. Each exited 0.

A caller-funded deposit is a different case. With no pre-existing residual idle, that fixture leaves the pre-existing holders' value at `P0` unchanged. The new shares, and that placement shortfall, go to `p.recipient` (`:181`). Unused input is refunded to `msg.sender` (`:182-183`). More generally, the share formula preserves the old deployed-liquidity claim. It does not necessarily preserve the old holders' whole claim. Idle is excluded from the entry denominator and included in proportional withdrawal, so residual idle can be diluted by a new deposit. Astra's executed examples reported that idle transfer. The coordinator did not recompute those two figures. MiniMax called the external-push result partly resolved because of the deposit case. The other three called the maintenance path unresolved and stated the deposit case separately. Both descriptions remain. They are one split, not two mechanisms.

One-sided idle that cannot form liquidity is not placed. The scripts report zero added liquidity for that input in the infinite-range fixture.

This is an accounting identity. It is not a re-run of the audit's profitable attack. The push and the return were not funded. Grok inferred that a same-pool round trip extracts the shortfall with or without outside liquidity. That inference is not adopted as attacker profit. The audit's profit depended on the vault's share of pool depth. Those proofs were not re-executed.

### Self-moved trailing placement

The old same-call trailing mint is absent in raw Weir. The price risk is not closed, and selecting Weir does not remove the PRD's post-withdrawal sleeve move.

`unlockCallback` compounds, then withdraws, then returns. It does not compound again after the zap. That removes the automatic trailing placement the audit found on the old FullSpread redeem path.

A later `compound` is still permissionless. If the withdraw zap moved the only available pool price, and a usable pair remains, that later call sizes it at the moved price and does not increase `totalShares`. The exiting shares are already burned, so that placement shortfall belongs to the remaining holders. All four initials reached that allocation. Grok is not silent on it. Their trailing amounts differ because the fixtures differ. No single trailing figure is the council number.

The fee-bearing examples measure that shortfall against retaining the same net fees and idle until the pool returns to `P0`. They do not show that the staying holders finish below their pre-fee wealth. In Astra's source-ordered fixture, the pre-withdraw compound leaves one-sided idle, and fees from the withdrawal swap supply the missing currency for the later compound. Agreement on the allocation does not prove that every stated two-sided idle budget survives Weir's preceding compound.

A later compound of only one-sided idle and no fees does not add liquidity. That limit does not make the usable-pair case safe.

This absence is raw Weir only. FS-OWN-12 separately requires a best-effort move of each local balance toward its sleeve target after every withdrawal. Selecting Weir does not remove that lock. If that adjustment places a usable pair after the redemption swap, the same live-price identity applies. This run did not implement or execute that adaptation, and it does not assert that every sleeve move adds liquidity.

### Whole-balance redemption dump

Removed in Weir as a quantity shape. Not removed by the price limit.

`_withdraw` swaps `uint256(net1)` or `uint256(net0)`, the exiting slice's unwanted net (`:314` and `:318`). It does not pass the vault's remaining opposing balance to `_swap`. All four responses reached that conclusion. Grok's initial citations of lines 316 and 320 were the delta additions, not the swap calls. Grok accepted the correction. The originals were not rewritten.

The absolute limit remains. It can slip the exiting slice. That slippage belongs to the exiting path, not to a sale of the stayers' inventory. The amount is the distinction. The shared limit is not.

FS-OWN-15 says a redemption may swap through the pool for volume. It does not state the swap amount. FS-OWN-30 pays the caller's fraction. It does not state the swap amount either. Weir's source makes the withdrawn-net quantity explicit. The quoted locks already require proportional withdrawal accounting. The missing sentence is a clarity gap. It is not a finding that the adaptation may sell staying holders' inventory, and it is not an instruction to add a new cap.

### Half-excess balance

`_balance` swaps half of the caller's excess, calculated at the pre-swap live price (`:387-410`). That targets the pool ratio. It does not guarantee an exact ratio after the swap moves the price. `_deposit` then sizes liquidity at the post-swap live price and refunds unplaced input. It is not a price guard.

In the caller-funded fixture, the placement loss is borne by `p.recipient` because the share formula assigns the added liquidity there, not because `_balance` checked a reference. A preceding compound of vault-owned idle remains a separate path on which the existing holders bear the loss. FS-OWN-33 already says a one-sided share mint swaps about half of the excess so the deposit matches the pool ratio. That is the same shape. It is not a displaced-spot defense.

### What selecting Weir does not change

FS-MONEY-01 already copies the absolute entry-swap limit, the liquidity-only share denominator, compound before deposit and before withdraw, reinvestment of remainder plus idle, and pro-rata removal. It does not expressly say that placement is sized from live `slot0`. That sizing is the cited Weir operation, read against a PRD that adds no price check.

FS-OWN-14 already makes `compound` permissionless and says it deploys booked idle. Its no-fee return sentence is not what Weir does when liquidity is positive and idle can form a position. Weir still places that idle when the fee harvest is zero. That conflict is B-03. This report does not pick a winner. The zero-liquidity return at line 343 is a different path and does not close B-03.

FS-OWN-10 forbids replacement zap views, caps, tick bounds, and hidden constants. It does not install a maintenance price check. FS-OWN-12 is not a Weir rule. The plan must not treat raw Weir's call order as deleting it.

No PRD edit is proposed. B-02 stays open. This report does not authorize a TWAP, a tick bound, a fee cap, or an implementation.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Four initial responses | members/*/response.md | source observation | the split between maintenance loss, deposit isolation, and the withdrawn-net quantity |
| Four advisory files | members/*/feedback.md | source observation | the wording corrections in the resolution |
| Weir compound, deposit credit, withdraw swap, and zero-liquidity return | `WeirVaults.sol:181-183`, `:207-211`, `:229-236`, `:290-324`, `:343`, `:355-376`, `:387-425` | source observation | coordinator-checked locators |
| PRD has no `slot0`, `getSlot0`, `live-price`, `TWAP`, or `pre-operation` | full-spread PRD text search | source observation | G-1 and MiniMax concern 1 |
| FS-OWN-33 half-excess sentence | full-spread PRD | source observation | the balance-swap comparison |
| Four Python scripts re-run by the coordinator | members/*/sim/*.py, each exit 0 | supplied runtime | the placement identity and the audit-formula match |
| Audit IL approximation | APEX-2026-023 text | source observation | the formula the scripts checked |
| Attacker profit at a stated vault share of depth | not re-executed | unverified for this run | not adopted |

Public search was not used. Private excerpts were not sent to a search service.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| WeirVaults money functions | required | examined | All four read them. The coordinator re-read the cited lines. |
| LiquidityAmounts | required | examined | Comparable totals use the infinite-range limit. Finite ticks were a side case, not the fixture. |
| APEX-2026-023 and APEX-2026-024 | required | examined | Finding text. Proofs of concept were not re-run. |
| B-02 and the named FS-OWN and FS-MONEY locks | required | examined | Compared with Weir. Not edited. |
| Deleted FullSpread and Wings sources | optional | absent | Not reconstructed. |

## Disagreement and missing responses

- Disagreement: MiniMax's "partly resolved" emphasis against the others' "maintenance unresolved" emphasis. Grok's unadopted profitability inference. Fixture-specific trailing amounts.
- Dissent carried into this report: those three. None reverses the holder allocation.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-se-weir-b02-accounting-20261101-r1
- Draft path: docs/research/se-weir-b02-accounting-20261101/coordinator/draft.md
- Resolution path: docs/research/se-weir-b02-accounting-20261101/coordinator/resolution.md
- Feedback dispositions: Astra requested changes. Grok and MiniMax supported with reservations. Kimi supported.
- Post-review wording changes: the qualifications in Conclusions. They are listed in the resolution.
- Those changes are member-approved: no

## Recommendations

- Do not treat "we selected Weir" as an answer to B-02. The live-price placement of vault-owned inventory is still an owner decision.
- If a replacement is wanted, it has to be an explicit sentence. Raw Weir does not supply a price check, and the current locks do not already state one.
- The withdrawn-net quantity can be written as a clarity sentence. It should not be written as a new cap, and its absence should not be read as permission to sell the staying holders' inventory.
- FS-OWN-12 remains a separate lock. A plan that copies raw Weir's call order still has to say what the post-withdrawal sleeve move does.
- B-03 remains open. Weir's zero-fee idle placement and FS-OWN-14's no-fee return are not the same sentence.

These are cautions for the next owner decision. They are not a lock and not an implementation plan.

## Limitations

- The swap legs that move a price use a labeled constant-product approximation. The placement identity does not depend on it.
- Integer rounding and finite usable ticks were not the comparable fixture.
- Astra's residual-idle transfer figures were not recomputed by the coordinator.
- Live files can change. This report is not an atomic repository snapshot.
- No Forge run, project test, deployment, wallet, or network call was used.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/se-weir-b02-accounting-20261101/REPORT.md
- Cooperative update: none. The PRD and the blockers file were not edited.
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
