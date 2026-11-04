# Identity

Astra, independent council member. This is the single advisory pass on the coordinator's frozen draft, not a new original contribution or an implementation decision.

# Draft under review

- ID: `se-fullspread-prd-weir-align-20261031-01a18660-r1`
- Path: `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/coordinator/draft.md`
- Expected SHA-256: `c7afa4cd5c82ff0338ebe3cc09ab5aa216280fa17a2c584127b349e73cd10527`
- Raw-file SHA-256 computed in this advisory: `c7afa4cd5c82ff0338ebe3cc09ab5aa216280fa17a2c584127b349e73cd10527`
- Result: matched. The complete draft was readable and read.

# Disposition

Request corrections before publication. The draft accurately states my central position: remove PairToken economic inheritance and the named zap fields; use actual returned deltas and payer refunds; preserve the selected-token-only exit; retain `donate` as an explicit non-Weir exception; and use Weir harvest-and-reinvest rather than a compound ratio swap.

It also accurately attributes my positions in the two preserved splits. I said that the source genesis floor is known while its ERC-20 representation is unspecified, and that source credits must not be forced into a guessed refund encoding or another return field. I do not resolve either split by voting.

The draft does not fully carry my original contribution. Its proposed money text omits important source precision and the sleeve interaction, while its generic edit instructions leave several contradictory PRD requirements and acceptance rows without exact replacements. Those omissions matter because the assignment is to provide ready-to-apply replacements, not merely describe their direction.

# Concerns and corrections by draft section

## Proposed text / FS-MONEY-01: complete the issuance sequence

The genesis bullet says `totalShares` is set to `MIN_SHARES` but does not state that `_deposit` subsequently adds the recipient's issued shares. Read as a complete money rule, it can leave the mistaken impression that final total supply remains `1_000`. The existing-supply bullet also uses the unqualified name `liquidity` for added liquidity while using `v.liquidity` for the denominator. That distinction must be explicit.

Replace those two bullets with:

```markdown
- In `WeirVaults._deposit`, `frame.liq` is the deposit's added liquidity. When `v.totalShares == 0`, the source rejects `frame.liq <= MIN_SHARES`, assigns `frame.shares = frame.liq - MIN_SHARES`, and sets `v.totalShares = MIN_SHARES`. `MIN_SHARES` is `1_000`; the source marks that minimum as never redeemable. After the liquidity modification, the function adds `frame.liq` to `v.liquidity` and `frame.shares` to `v.totalShares`. Setting the minimum is an intermediate step, not the final total share count.
- For an existing supply, the exact assignment in `_deposit` is `frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity`. The existing liquidity and share count are those after the preceding compound and before this deposit is added. Idle balances are not a term in the denominator. The function rejects zero issued shares.
```

Also state how `frame.liq` is obtained, rather than leaving a generic liquidity term to be supplied by PairToken accounting:

```markdown
`WeirVaults._deposit` computes added liquidity with `LiquidityAmounts.getLiquidityForAmounts`, using the current pool price, the stored ticks, and the post-balance currency amounts adjusted exactly as `amount > 2 ? amount - 2 : 0`. This is a source rule, not permission to substitute an unstated share-credit or valuation formula.
```

This is source precision, not a vote on the preserved genesis split or a choice of ERC-20 representation.

## Proposed text / FS-MONEY-01: preserve the unresolved sleeve interaction

My original explicitly distinguished Weir's tracked idle from this family's locked oracle-targeted local sleeve and explicit donation route. The draft states idle exclusion but omits that distinction. It should not imply that the source provides a complete issuance formula for those additional locked behaviors.

Add:

```markdown
The source contains no alternate issuance denominator for this family's oracle-targeted local sleeve or explicit donation route. FS-OWN-04, FS-OWN-07, and FS-OWN-09 remain locked. Their unresolved interaction with deployment timing and source liquidity-based issuance must be specified explicitly. Do not fill that gap with PairToken accounting, NAV, or an invented idle-inclusive denominator.
```

This preserves the existing locks. It neither reopens the sleeve nor proposes a new formula.

## Proposed text / FS-MONEY-01: state withdrawal behavior, not just its route restriction

The Authority section promises a source-grounded withdrawal rule, but FS-MONEY-01 currently gives only pre-withdrawal compound and the accepted single-token constraint. My original also stated what `_withdraw` allocates.

Add:

```markdown
`WeirVaults._withdraw` allocates deployed liquidity and each tracked idle balance proportionally to the withdrawn shares, removes the allocated liquidity, pays the allocated idle into the manager, optionally swaps one leg, and settles both resulting currency deltas. The accepted bundle exit remains proportional and two-currency. The accepted one-token exit instead pays only the selected token or reverts atomically; Weir's two-output settlement does not itself establish that route constraint.
```

This does not weaken the one-token exit or resolve the preserved entry-credit split.

## Proposed text / FS-MONEY-01: remove the fallback explicitly and clarify compound

The draft correctly says `_compound` runs before deposit and withdrawal. It should also explicitly remove the current PRD's S1-EXIT-01 withdrawal-only collect-or-compound fallback. Otherwise FS-A11 and FS-A33 can continue to demand the discarded operation through tests.

Add:

```markdown
`WeirVaults._compound` does not call `_balance` or `_swap` and does not change share supply. It can leave tracked idle when additional liquidity cannot be added. Do not inherit S1-EXIT-01's withdrawal-only collection fallback, PairToken compound swaps, or S1-ACC-06 fee attribution. Any fee-policy-dependent expectation requires an explicit family policy; this update neither adds Weir's treasury fee nor imports PairToken's no-fee rule.
```

The phrase "reinvests the remainder plus idle" should say that, in the source, the remainder is harvested fees after the source performance-fee cut. That is source attribution only. The draft's existing statement that the cut is not adopted must remain. This correction selects no fee.

Also replace "Do not install Weir's `deposit`, `withdraw`, `zap`, or `zapTo` selectors" with:

```markdown
Do not install Weir's `deposit` or `withdraw` selectors. Its `zap` and `zapTo` parameter fields are not additional public methods or authority to alter the accepted Standard Exchange routes.
```

`zap` and `zapTo` are fields in the source parameter structs, not standalone selectors.

## Proposed text / Authority: supply the full replacement span

The draft says to replace PairToken as the economics authority but does not expressly replace the blanket S1 inheritance list, the named override bullets, or the S1 acceptance inheritance. Those clauses are how the rejected design persists independently of the authority-table sentence.

Name the exact replacement span in PRD section 2: the authority table and all following inheritance/override paragraphs through the blanket S1 list, stopping before the transition-quote-interface paragraph. Include explicit text that there is no blanket inheritance of S1 requirements or acceptance rows. Retain direct family requirements and owner locks rather than preserving them through S1 precedence.

The original also supplied a section 2.1 entry-remainder replacement and removed its obsolete `InsufficientRateSupply` disposition. Those exact local changes should be included. The latter preserves FS-OWN-03 rather than reopening rate policy.

## Proposed text / FS-OWN-09 and FS-OWN-10: identify the exact superseded sentence

The proposed clarification is substantively accurate. Specify that the final sentence of FS-OWN-10 saying the three zap views/fields "stay open" is replaced, not merely followed by another paragraph. Otherwise the contradictory open status remains in the PRD.

Keep the rest of both owner locks intact, including accepted bundle mappings, paired events, wrapper-face use, and the fact that raw ETH is undecided. Keep `compound()` as the family's locked selector, as the draft already correctly does.

## Proposed text: missing package, facet, and issuance-table replacements

Add exact replacements, labeled by these PRD destinations:

- **FS-FACET-01:** remove `previewZapCredit` from the quote-facet row, remove the entry `IncompleteConversion` error, and remove authority derived from PairToken's facet order/count without redesigning locked facet wiring.
- **FS-PKG-01:** replace the `PkgArgs` paragraph and field list with `PoolKey poolKey`, `string name`, and `string symbol`; remove both zap fields and the "PairToken set" authority. Do not add a hidden default.
- **FS-PKG-02:** remove the zap-limits validation bullet and `InvalidZapLimits`; replace the final initialization paragraph's no-floor and no-performance-fee assertions with accurate source attribution and the expressly unresolved adaptation decisions. Do not leave those assertions contradicting FS-MONEY-01.
- **Section 6 issuance table:** replace the row that couples issuance to `previewZapCredit`, S1-ACC-02, and S1-ACC-07. The accepted entry previews remain; the dedicated zap-credit view does not.

The draft currently instructs the coordinator to delete fields, but does not provide all of this ready-to-apply text. My original contains the local replacements. No new package design or new guard is needed to close this omission.

## Proposed text / Tests and acceptance: replace named rows, not only a category of rows

The generic paragraph is not sufficient to remove contradictory assertions. Carry exact replacement rows from the original, or equally precise coordinator replacements, for:

- **FS-TEST-02:** remove blanket S1-A01 through S1-A70 inheritance and the partial-entry-rejection override.
- **FS-A01 and FS-A03:** absent zap selectors/fields and removal of zap-limit validation.
- **FS-A05:** source genesis floor versus the old no-dead-share/no-performance-fee assertions, without choosing its ERC-20 representation.
- **FS-A06 and FS-A07:** source liquidity issuance, actual deltas, payer refunds, and no `J_i` booking or consumption-equality rejection.
- **FS-A11, FS-A25, and FS-A33:** remove the withdrawal fallback and S1-ACC-06 fee attribution.

Keep FS-A08's accepted one-token exit.

The original additionally identified **FS-A10** as conflicting with the owner locks' undecided raw-ETH route, **FS-A32** as importing the economic-read guard/snapshot reserve policy, and **FS-A38** as importing disabled-inbound policy. These points are absent from the draft. Carry their limited disposition or explicitly state that they were not adopted and why. Do not silently treat them as resolved or retain them through blanket inheritance. This advisory does not request a new guard.

## Preserved disagreements

Both entries accurately describe my original position. Preserve them as unresolved. The issuance-sequence correction above does not decide how to tokenize the floor, and the withdrawal clarification does not choose a new entry refund encoding.

Do not describe another member's omission of the encoding concern as assent to a particular encoding. The draft currently avoids that mistake.

# What was not adopted from my original

The draft does not yet carry the exact destination-specific edits for package validation, the issuance table, the detailed acceptance rows, the explicit sleeve/issuance gap, or the other copied-policy dispositions identified above. It also omits the original's narrow correction of stale SY file-list entries and the public-bundle bootstrap wording. Those last two enforce existing locks and can be carried as local consistency changes without redesigning architecture.

I do not require adopting my row numbering or the additional FS-A39/FS-A40 labels. The substantive donation-exception coverage and unresolved-adaptation accounting can be recorded elsewhere. I do require that omitted proposals receive an explicit disposition rather than the final report implying that my original was fully incorporated.

# Limits

Only the pinned draft was read anew for this advisory, plus its raw bytes for SHA-256 verification. Comparison with my original and source observations uses the existing session context. No peers, source files, PRD, review file, or other research were reopened. No Forge, Git, installs, deployments, delegation, or implementation occurred.

Only `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/members/astra/feedback.md` is written. This advisory neither replaces the original contribution nor changes the frozen draft. It authorizes no implementation, resolves no preserved split by voting, and requests no additional advisory round.
