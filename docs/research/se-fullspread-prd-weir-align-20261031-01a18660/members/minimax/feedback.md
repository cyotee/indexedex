# MiniMax feedback — se-fullspread-prd-weir-align-20261031-01a18660-r1

## Identity

MiniMax, independent council member, route `minimax/MiniMax-M3`. I reviewed only the frozen coordinator draft `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/coordinator/draft.md` (draft ID `se-fullspread-prd-weir-align-20261031-01a18660-r1`) and the sources I had already read for my own response: the current `contracts/protocols/strategy/weir/WeirVaults.sol`, `contracts/protocols/strategy/weir/base/WeirBase.sol`, the publication-target PRD, `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, and the fidelity report. I did not read peer responses, did not edit `members/minimax/response.md`, the draft, the PRD, or the review file, and did not implement anything.

## Draft under review

- Path: `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/coordinator/draft.md`
- Draft ID: `se-fullspread-prd-weir-align-20261031-01a18660-r1`
- SHA-256: `c7afa4cd5c82ff0338ebe3cc09ab5aa216280fa17a2c584127b349e73cd10527`
- Verification: computed with `shasum -a 256 draft.md`; the output matches the supplied digest exactly. The file is readable (92 lines, 7,066 bytes). I reviewed the draft as read.

## Disposition

**REQUEST CHANGES.**

The draft's Weir money rules, its `compound` and `donate` treatment, its refusal to add a zap cap, tick guard, or performance fee, and its preservation of the accepted one-token exit all state my original accurately. None of that needs revision.

The changes below are localized. Three of them matter because the owner directive is "PairToken economics are not inherited": the draft replaces the inheritance *rule* but not the enumerated inheritance *list*, so S1-ACC-07, S1-ACC-02's genesis sentence, S1-D03, S1-OP-02's caps, S1-OP-05's ratio swap and quarter cap, S1-P05/S1-P07, S1-EXIT-01 and S1-X15/S1-X17 survive as inherited text (C1). Two more matter because the draft leaves a PRD contradiction where the money rule and the acceptance rows disagree (C5, C7). The rest are coverage of named leftover sentences (C2, C3, C4, C8) and framing accuracy (C6, C9, C10).

I do not resolve the two preserved splits by voting, and I take no position on how the draft characterizes the other members' originals.

## Concerns

Each concern names its draft section and the exact correction.

**C1 — "Authority": the removal does not reach the §2 enumerated inherit list. (highest severity)**

The draft replaces the general rule ("An FS delta no longer means 'every other clause of that inherited requirement stays.'") but does not amend the PRD sentence that enumerates what is inherited: "Inherit S1-D01 through S1-D05, S1-P01 through S1-P07, S1-X01 through S1-X19 except where FS-X04 narrows S1-OP-02, S1-ARCH-01 through S1-ARCH-05 except family name and directory, S1-ACC-01 through S1-ACC-07, S1-OP-01 through S1-OP-05 except the named sentences above, S1-EXIT-01, S1-NATIVE-01, …". That enumeration still pulls in the clauses the owner rejected: S1-ACC-07 (`G_i`, `J_i`, `qCredit`), S1-ACC-02's genesis sentence ("no 1,000-share subtraction, virtual shares, virtual assets, or hidden minimum liquidity sink"), S1-D03 ("do not inherit PairToken's permanent dead shares … or protocol-fee routing"), S1-OP-02's `maxZapBps` size bound and `maxZapTickMove` bound, S1-OP-05's ratio swap and quarter cap, S1-P05 and S1-P07 (conditional collection-only fallback), S1-EXIT-01 (the `FullCompound`/`CollectOnly` fallback), S1-X15 and S1-X17. It also leaves the precedence sentence "If this PRD and the stage-one PRD disagree on an inherited ID that no FS delta names, the stage-one PRD controls" intact for exactly those IDs.

Exact correction — replace the inherit paragraph with:

```markdown
Inherit S1-D01 through S1-D05 except S1-D03's dead-share sentence, S1-P01 through S1-P07 except S1-P01's ratio-swap and retained-fee sentence, S1-P05, and S1-P07's collection-only-fallback sentences, S1-X01 through S1-X19 except S1-X15 and S1-X17, S1-ARCH-01 through S1-ARCH-05 except family name and directory, S1-ACC-01 through S1-ACC-07 except S1-ACC-02's genesis sentence and all of S1-ACC-07, S1-OP-01 through S1-OP-05 except S1-OP-02's size, tick-movement, and residual clauses, except S1-OP-05's ratio-swap, quarter-cap, and dust branches, and except the named sentences above, S1-NATIVE-01, S1-API-01 through S1-API-05 except the provider sentence, S1-QUOTE-01, S1-GAS-01, S1-PKG-01, S1-SEC-01 except the named sentence, S1-SEC-02, S1-OBS-01, and S1-TEST-01's fixture discipline. S1-EXIT-01 is not inherited: WeirVaults has no collection-only withdrawal mode.
```

and append to the precedence paragraph: "An inherited ID whose economics this PRD replaces does not control that rule: the issuance, entry credit, zap-accounting, and compound rules come from FS-MONEY-01, and the stage-one text does not control them."

The S1-D03 carve-out depends on the genesis split (C5). If the owner does not lock the Weir floor, delete "except S1-D03's dead-share sentence" from the paragraph above.

**C2 — "Authority": the §2.1 dispositions table still states a removed rule.**

The §2.1 row "| Entry remainder | Inherited `J_i` booking plus FS-X04 full selected-swap consumption. | Every input wei becomes liquidity. |" asserts the removed rule in the table the PRD calls "Dispositions retained from advisory". The draft does not mention it. Exact correction:

```markdown
| Entry remainder | Weir refund of the unused declared input to the payer. FS-MONEY-01. | `J_i` booked to shared backing without extra shares. A consumption-equality check. |
```

**C3 — "FS-OWN-09 and FS-OWN-10": "are absent" must be applied to the two manifest rows, not only stated.**

The draft says "`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent." Two PRD rows still install or name them. Exact corrections:

FS-FACET-01 `quoteFacet` row:

```markdown
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. Do not install `previewWithdrawalMode` (FS-OWN-10), `previewZapCredit` (FS-OWN-10), or the paired previews. |
```

§6 rate, quote, and issuance table:

```markdown
| Issuance | FS-MONEY-01. WeirVaults `_deposit`: shares are minted against the liquidity added to the position, idle balances are not in the denominator, and the genesis case locks `MIN_SHARES`. | Not `exchangeRate`. Not `getRate`. Not the stage-one `S1-ACC-07` credit equation. |
| `previewZapCredit` | Not installed. FS-OWN-10. | Not a renamed view. Not a replacement cap. Not a re-disclosed remainder. |
```

**C4 — "FS-OWN-09 and FS-OWN-10" and "Tests and acceptance": two zap-limit leftovers must be deleted, or the PRD still validates and tests arguments that no longer exist.**

FS-PKG-02 validation bullet:

```markdown
- Zap limits that are not a positive in-range fee bound and a nonnegative tick bound. `InvalidZapLimits`.
```

This bullet must be deleted, and after the bullet list: "`InvalidZapLimits` is not declared for this family. There are no zap limits, so there is no zap-limit validation and no zap-limit error." The draft's "Tests and acceptance" list does not reach this, because it names `maxZapBps` and `maxZapTickMove` but not "zap limits". The same gap hits FS-A03, whose assertion reads "Invalid component, pool key, zap limits, wrapper, double initialization, …". Exact replacement:

```markdown
| FS-A03 | Invalid component, pool key, wrapper, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no rate-asset argument to reject and no zap-limit argument to reject. |
```

**C5 — "FS-MONEY-01" and "Tests and acceptance": the draft states the Weir genesis floor as this family's rule while its own "Preserved disagreements" table says the split is unresolved, and FS-A05 still says "No dead-share mint."**

The draft's FS-MONEY-01 states: "If `totalShares` is zero and liquidity is above `MIN_SHARES`, minted shares are `liquidity - MIN_SHARES`, and `totalShares` is set to `MIN_SHARES`." Its "Preserved disagreements" row says the floor is "Not resolved in this draft" and that the draft "does not restore the old dead-share ban". The PRD's FS-A05 currently asserts "First deposit creates one full-range salt-zero position owned by the diamond. No dead-share mint. No performance fee." A coordinator applying the draft literally would have FS-MONEY-01 contradict FS-A05, and would have silently resolved a split the draft says it preserves.

Exact correction — the draft must pick one of two states and say which it is:

(a) If the Weir floor is adopted for this family, FS-A05 becomes:

```markdown
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Genesis follows WeirVaults `_deposit`: the first deposit requires added liquidity above `MIN_SHARES`, mints the added liquidity minus `MIN_SHARES`, and leaves `MIN_SHARES` permanently locked in total supply. No performance fee: this family takes no cut of the harvested fees. |
```

and FS-PKG-02's closing sentence becomes: "… The first depositor creates the position. Genesis follows WeirVaults `_deposit`: the first deposit requires the added liquidity to exceed `MIN_SHARES`, mints the added liquidity minus `MIN_SHARES`, and leaves `MIN_SHARES` permanently locked in total supply as a floor no holder can redeem. There is no vault-level performance fee: this family takes no cut of the harvested fees."

(b) If the floor is not adopted, the draft must say the floor is a cited source behavior that this family does not yet take, keep FS-A05 as it is, and state that the PRD then needs an owner-supplied genesis rule, because WeirVaults states none.

Either way the "Preserved disagreements" row must not simultaneously report the split as open and the ban as gone.

**C6 — "FS-MONEY-01": "the ERC-20 representation of the unredeemable `MIN_SHARES` floor is not chosen" and "pick a holder address" overstate what the source leaves open.**

The source states the representation. `WeirVaults.sol:_deposit` sets `v.totalShares = MIN_SHARES` and `deposit` credits only the minted shares to the holder — `sharesOf[id][p.recipient] += shares;` — so the floor is total supply credited to no holder, by construction, with no address to pick and no second ledger to keep. The open ERC-20 question is narrower: how this diamond expresses total supply that includes an amount no balance holds. Exact correction: replace the draft's sentence with a statement that the source fixes the economic representation (supply with no holder) and that only the ERC-20 encoding of an unheld supply remainder is left open, without implying that a holder address is a free choice.

**C7 — "Tests and acceptance" and "FS-MONEY-01": FS-A07's "without a second-token payout" clause is not a Weir property and must be deleted with the FS-MONEY-01 sentence that carries it.**

The PRD's FS-MONEY-01 says "The call does not pay a second token, strand an exiter's unsold allocation, or burn shares if it reverts", and FS-A07 repeats "without a second-token payout". Weir does not have that property: `_deposit` settles each currency from its net delta and `WeirBase._settle` pays any positive net to the depositor in that currency (`net > 0` → `_take(c, to, uint256(net))`), so a positive execution credit in the second currency goes to the payer. The draft's own FS-MONEY-01 text says exactly that ("A positive credit goes back to the depositor"), so the surviving acceptance clause would contradict the rule the draft states. The locked one-token exit row FS-A08 is unaffected.

Exact replacement for FS-A07:

```markdown
| FS-A07 | A single-token entry may partially consume the declared input. After the manager action the payer receives the declared amount minus the amount the manager actually took (`WeirVaults.sol:deposit`). No `IncompleteConversion` is raised, no preflight partial-swap rejection occurs, no `J_i` remainder is booked to shared backing, and no extra shares are minted for uncredited input. A positive execution credit in either currency is returned to the payer. |
```

**C8 — "Tests and acceptance": the specific rows that assert the removed rules are not named, so the coordinator cannot apply the instruction mechanically.**

The draft's instruction is "Replace rows and bullets that require `IncompleteConversion`, booked `J_i`, `previewZapCredit`, `maxZapBps`, `maxZapTickMove`, or S1-ACC-07 share credit." The following still assert a removed rule and are not covered by that list. Exact corrections:

FS-TEST-02 inherited-row exceptions, replacing the bullet "S1-A13 and S1-A15's partial-entry success becomes `IncompleteConversion`." with:

```markdown
- S1-A13 and S1-A15's partial-entry success becomes the Weir entry rule of FS-A07: a partial fill is accepted and the unused input is returned to the payer.
- S1-A10, S1-A46, and S1-A64 are replaced by FS-A07 and FS-A33: they assert the stage-one `G_i` and `J_i` credit equation and the `J_i` donation split, which WeirVaults does not have.
- S1-A19, S1-A62, and S1-A70's collection-only paired-exit wording is replaced by the Weir maintenance rule of FS-A11. Their atomicity and gas bounds stay.
```

FS-A11 and FS-A33:

```markdown
| FS-A11 | Withdrawal runs the same harvest-and-reinvest step as deposit. `WeirVaults.sol:unlockCallback` calls `_compound` before `_withdraw` and before `_deposit`. There is no collection-only withdrawal mode, `previewWithdrawalMode` is absent, and the standalone `compound()` entry point remains. |
| FS-A33 | Borrowed execution uses the same harvest-and-reinvest step, the same issuance rule, and the same fee attribution as the locked path from the same economic state. |
```

FS-A06 still reads "Paired deposit and redeem match S1-ACC-02 and S1-ACC-03", which names S1-ACC-02's `qQuote` table as this family's issuance rule. Exact replacement:

```markdown
| FS-A06 | Paired deposit and redeem follow FS-MONEY-01. The paired deposit adds the declared amounts to the position and mints the Weir liquidity-proportional amount. The paired redeem removes liquidity and each idle balance pro rata (`WeirVaults.sol:_withdraw`). S1-ACC-03's proportional-removal clauses stay; S1-ACC-02's `qQuote` table and all of S1-ACC-07 do not apply. |
```

**C9 — "FS-MONEY-01": two Weir facts that state what the removed knobs leave behind are missing. (minor)**

The draft says no replacement cap or tick bound is added, which is the required negative, but it never states the positive Weir fact that answers "then what bounds the entry". `WeirVaults.sol:_swap` sends `amountSpecified = -int256(amountIn)` with `sqrtPriceLimitX96` of `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`, i.e. the entry swap is bounded only by the pool's range boundary. The draft also does not say that idle is allocated to holders pro rata at redemption (`_withdraw`: `liq = floor(liquidity * shares / totalShares)`, `i0 = floor(idle0 * shares / totalShares)`), which is what makes idle non-dilutive under Weir. Both are source-quoted statements, not new rules. Exact correction: add one sentence to each of the FS-MONEY-01 entry and issuance rules.

**C10 — "FS-OWN-09 and FS-OWN-10": the no-fee outcome and its basis should be stated once, unambiguously. (minor)**

The draft says "Weir's treasury performance fee is source attribution only. This update does not add that fee, and it does not adopt PairToken's no-fee rule." That is right, but the PRD keeps "no vault-level performance fee" (FS-PKG-02) and FS-A05's "No performance fee", so the PRD still shows a no-fee outcome while the draft disclaims inheriting PairToken's no-fee rule. The basis should be explicit so the PRD does not read as inheritance. Exact correction: keep the outcome, and state the basis once in FS-MONEY-01's compound rule: "This family takes no cut of the harvested fees. That is the owner's no-fee posture for this family, not an inherited PairToken rule; WeirVaults does take `perfFeeBps` to the treasury."

**Mechanical catches.** In the "FS-X04" paragraph, "`deosit` returns unused declared input to the payer" is a misspelling of `deposit`. In the "FS-X04" paragraph, "`_deposit` settles from the deltas actually returned and sends a positive credit back to the depositor" is accurate, but note that the credit goes to `depositor`, which is `msg.sender`, while the minted shares go to `p.recipient`; the draft states that split correctly in FS-MONEY-01, and the FS-X04 row would be stronger naming the same two payees.

**Not a correction, recorded for accuracy.** The draft's "Preserved disagreements" row 1 characterizes my position as "MiniMax treats adopting `MIN_SHARES` as needing a separate owner lock because the old PRD forbade dead shares." That matches my response. My response additionally stated that if the owner declines the floor, the PRD must state a genesis issuance rule of its own, because WeirVaults states none. C5 is written to make that consequence explicit rather than to decide the split; the split stays open for the coordinator and the owner.

## Limits

- I reviewed one file: the frozen draft, verified by SHA-256 as `c7afa4cd5c82ff0338ebe3cc09ab5aa216280fa17a2c584127b349e73cd10527`, which matches the digest supplied. I read no peer response and make no claim about any peer's original beyond the draft's own characterization of them.
- I did not edit the draft, my response, the PRD, the review file, the brief, or any peer file. I ran no Forge build or test, no deployment, no Git operation, and no install; nothing was executed against a chain.
- Line and function citations are to `contracts/protocols/strategy/weir/WeirVaults.sol` and `contracts/protocols/strategy/weir/base/WeirBase.sol` as read on 2026-10-31; the function names are the durable anchors.
- Every replacement quoted above is derived from a Weir source statement or from the stage-one text the PRD inherits by ID. Where Weir states no rule, I said so and added nothing.
- This advisory neither replaces the draft nor authorizes implementation, and it carries no owner approval for the genesis floor, an entry bound, a tick or price guard, or a treasury performance fee.
