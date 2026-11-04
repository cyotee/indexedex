# MiniMax response — se-fullspread-prd-weir-align-20261031-01a18660

## Identity

MiniMax, independent council member, route `minimax/MiniMax-M3`, profile: research. I wrote only this file. I did not edit the publication target PRD, `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, the brief, or any peer file, did not read peer responses, did not delegate, and did not run Forge, Git, installs, or deployments. My recommendations are my own; the coordinator is not a fifth vote, and nothing below is owner approval.

## Question and targets

**Question.** What exact PRD replacements remove unauthorized PairToken inheritance and state the Weir-adapted money rules, without reopening a locked owner decision (FS-OWN-01 through FS-OWN-10) and without inventing a zap guard?

**Targets read** (all read in full before any money rule is stated):

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
- `docs/research/se-weir-adaptation-fidelity-20261031-01a18660/REPORT.md`
- `contracts/protocols/strategy/weir/WeirVaults.sol` and `contracts/protocols/strategy/weir/base/WeirBase.sol`

One additional read was needed and is disclosed: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, the document the PRD inherits from by ID. I read it only to identify **which inherited clauses assert a rule the owner rejected**, so that the removals reach the inheritance mechanism and not just the Goal sentence. I did not use it as an economics authority for this family.

**Sections covered by the replacements below.** §1 Goal and §1.1; §1.2 delta FS-X04; §1.3 lock FS-OWN-10 (its final sentence only); §2 authority table, precedence paragraph, named-override bullet for FS-X04, inherit list, §2.1 dispositions table; §3 FS-FACET-01 (quoteFacet row, new-error list); §4 FS-PKG-01 (`PkgArgs`), FS-PKG-02 (validation bullet, initialization paragraph); §5 FS-MONEY-01; §6 rate/quote/issuance table; §8 FS-TEST-02 inherited-row exceptions and FS-TEST-03 rows FS-A03, FS-A05, FS-A06, FS-A07, FS-A11, FS-A33.

**Other PairToken-economics sentences found, by section** (named as the brief requires): §2 inherit list — S1-ACC-07, S1-ACC-02's genesis sentence, S1-D03, S1-P01, S1-P05, S1-P07, S1-X15, S1-X17, S1-OP-02's size/tick/residual clauses, S1-OP-05's ratio-swap/quarter-cap branches, S1-EXIT-01 (whole clause); §8 FS-TEST-02 — inherited rows S1-A10, S1-A13, S1-A15, S1-A19, S1-A46, S1-A62, S1-A64, S1-A70; §8 FS-TEST-03 FS-A25's `S1-ACC-06` fee-attribution reference and its stale `token == rateAsset` clause; §4 FS-PKG-01's "`PkgArgs` is the PairToken set"; §3 FS-FACET-01's "Twelve-field `PkgInit` shape" row (package shape, not economics — left alone).

## Evidence

All Weir citations are `contracts/protocols/strategy/weir/WeirVaults.sol` as read on 2026-10-31; line numbers are from that read, so cite the function name as the durable anchor.

**E1. Unused declared input goes back to the payer.** `deposit` (L160-185) pulls the declared `p.amount0` and `p.amount1` (L172-173), receives `(shares, used0, used1)` back from the unlock (L177-178), and then sends `p.amount0 - used0` and `p.amount1 - used1` to `msg.sender` (L182-183). `used0`/`used1` are the amounts the manager actually took: `frame.net0 < 0 ? uint256(-frame.net0) : 0` (L282).

**E2. A swap settles from the deltas actually returned; there is no consumption-equality check.** `_deposit` (L248-286) takes `frame.net0`/`frame.net1` from `_balance`'s swap `BalanceDelta` (L252; `_balance` L387-409) plus the `modifyLiquidity` delta `d` (L273-280), then settles each currency from that net (L283-284, `WeirBase._settle`). Nothing compares consumed amount to declared amount anywhere in the file. `_balance` swaps only half of the imbalance (`x = (a0 - …) / 2`, L396-397; `(a1 - a0in1) / 2`, L401), and `_swap` (L413-424) sends `amountSpecified = -int256(amountIn)` with `sqrtPriceLimitX96` at `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`, so the fill can be partial and the result is whatever the manager returns.

**E3. Issuance is against added liquidity; idle is not in the denominator; a genesis case exists.** `_deposit` (L264-271):

```
if (v.totalShares == 0) {
    if (frame.liq <= MIN_SHARES) revert ZeroShares();
    frame.shares = frame.liq - MIN_SHARES;
    v.totalShares = MIN_SHARES; // never redeemable: blocks share-price inflation
} else {
    frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity;
}
```

`MIN_SHARES = 1_000` (L37, comment: "locked forever on the first deposit"). The denominator in the non-genesis branch is deployed liquidity `v.liquidity`; `idle0`/`idle1` (L45-46) appear only at redemption (`_withdraw` L290-293) and in `previewRedeem` (L126-127), never in issuance. WeirVaults states no `J_i`, no `G_i`, no zap-credit view, and no `previewZapCredit`.

**E4. `compound` harvests and reinvests, and it runs before deposit and before withdrawal.** `_compound` (L341-384) collects the position's fees with a zero-liquidity-delta `modifyLiquidity` (L344-347), computes `cut0/cut1 = f * perfFeeBps / BPS` and takes them to the treasury (L350-353), adds the idle dust (L355-356), adds liquidity back with a positive `modifyLiquidity` (L370-374), and never writes `v.totalShares`. There is no ratio swap and no size cap. `unlockCallback` (L222-237) calls `_compound` **before** `_deposit` (L231) and **before** `_withdraw` (L235); the public `compound()` (L207-211) reaches `_compound` through `Action.COMPOUND` (L226). The treasury cut is `perfFeeBps`, default `500` (L80), hard cap `MAX_PERF_FEE_BPS = 1_000` (L36), documented at L28.

**E5. Weir does not book a direct transfer as a donation.** WeirVaults.sol declares no `donate` function. `idle0`/`idle1` are written only in `_compound` (L378-379) and `_withdraw` (L293-296), and `sharesOf` only in `deposit`, `withdraw`, and `transferShares` (L213-217). A direct ERC-20 transfer to the contract is therefore credited to no share and no idle balance.

**E6. Weir has no entry bound, no tick guard, and no collection-only withdrawal mode.** There is no size or tick parameter anywhere in the file; `_swap` is bounded only by the range-boundary price limit. There is no `CollectOnly` branch: `_withdraw` always runs after `_compound`.

**What Weir does not provide, and I therefore did not invent:** an entry size cap, an entry tick or price guard, a zap-credit view, a residual (`J_i`) booking rule, a collection-only withdrawal fallback, a genesis rule without the `MIN_SHARES` floor, and a no-fee statement. WeirVaults *does* take a treasury cut of harvested fees; the PRD's existing "no vault-level performance fee" sentence is the divergence, and I keep it because the owner authorized no fee.

**The removal has to reach the inheritance mechanism.** The Goal sentence is not where the PairToken economics live. §2's authority row ("Inherited economics, package law, and inherited acceptance"), the precedence paragraph ("the stage-one PRD controls"), and the inherit list ("Inherit … S1-ACC-01 through S1-ACC-07 … S1-EXIT-01 … S1-P01 through S1-P07 … S1-X01 through S1-X19 … S1-OP-01 through S1-OP-05 …") carry them in. The stage-one clauses that assert a rejected rule are: S1-ACC-07 (`G_i`, `J_i`, `qCredit`, `C_i`); S1-ACC-02's genesis sentence ("no 1,000-share subtraction, virtual shares, virtual assets, or hidden minimum liquidity sink"); S1-D03 ("do not inherit PairToken's permanent dead shares, 10-basis-point redemption retention, or protocol-fee routing"); S1-OP-02 steps 3, 6 and 9 (`maxZapBps` size bound, `maxZapTickMove` bound, book `J_i`); S1-OP-05 (ratio swap, quarter cap `maxZapBps / 10000 / 4`, `DUST = 1000`, "Retain the full collection; no protocol split"); S1-P01 (ratio-swap compounding), S1-P05 and S1-P07 (conditional collection-only fallback), S1-EXIT-01 (the `FullCompound`/`CollectOnly` fallback and its `previewWithdrawalMode` disclosure, the latter already dropped by FS-OWN-10); S1-X15 and S1-X17; and inherited acceptance rows S1-A10, S1-A13, S1-A15, S1-A19, S1-A46, S1-A62, S1-A64, S1-A70. The fidelity report reached the same conclusion from the other side: deleting the sibling sentence without replacing the inherited economics would leave the same design under a new name.

## Proposed PRD replacements

Exact Markdown, labeled by PRD section, ready to apply. R-numbers are for coordination only. FS-OWN-01 through FS-OWN-10 keep their substance; the only locked text touched is FS-OWN-10's final sentence, which the brief states is superseded.

**R1 — §1 Goal** (replaces the two paragraphs "This is not WeirVaults. …" and "It is a sibling of PairToken stage one, …")

```markdown
This is not the WeirVaults contract. WeirVaults is one manager of many virtual vaults. This family is one token, one pool, one position.

This family adapts the money rules of `contracts/protocols/strategy/weir/WeirVaults.sol` to the tokenized Standard Exchange standard, as stated in FS-MONEY-01 and cited there to the source function. It is not a sibling of PairToken stage one, not a rename, and not an amendment of `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`. PairToken stage one is not this family's economics authority: it is inherited only for the non-economic clauses listed in §2, and it never supplies issuance, entry credit, zap credit, or package zap fields. Specify only the deltas below.
```

**R2 — §1.1 first bullet** (replaces `- Not a Weir source copy, and not "add ERC-20 to WeirVaults."`)

```markdown
- Not a Weir source copy, and not "add ERC-20 to WeirVaults." The Weir rules are adopted as behavior, not as code. Weir's multi-vault manager, its per-pool vault registry, its `zapTo` exit selector, and its `transferShares` are not part of this family.
```

**R3 — §1.2 delta FS-X04** (keeps the ID, replaces the row)

```markdown
| FS-X04 | Single-token entry follows WeirVaults. The entry swap settles from the deltas the manager actually returns, a partial fill is accepted, and the unused part of the declared input is returned to the payer. `WeirVaults.sol:deposit` returns `p.amount0 - used0` and `p.amount1 - used1` to `msg.sender`, where `used0` and `used1` are the amounts the manager actually took. There is no consumption-equality check, no `IncompleteConversion`, no preflight rejection of a predicted partial swap, no entry size cap, and no tick-movement bound. `J_i` is not booked to shared backing, and no extra shares are minted for uncredited input. This replaces S1-OP-02's size, tick-movement, and residual clauses. |
```

**R4 — §2 authority table, first row**

```markdown
| PairToken stage-one PRD | Inherited package, deployment, security, gas, and acceptance clauses only, as listed in the inherit paragraph below. It is not this family's economics authority and never supplies issuance, entry credit, zap credit, or package zap fields. |
```

**R5 — §2 precedence paragraph**

```markdown
An enumerated FS delta overrides only the named clause of an inherited requirement. Every other clause of that requirement stays. If this PRD and the stage-one PRD disagree on an inherited ID that no FS delta names, the stage-one PRD controls. An inherited ID whose economics this PRD replaces does not control that rule: the issuance, entry credit, zap-accounting, and compound rules come from FS-MONEY-01, and the stage-one text does not control them.
```

**R6 — §2 named-override bullet for FS-X04** (replaces the FS-X04 bullet)

```markdown
- FS-X04 replaces the successful partial-entry-fill cases in S1-A13 and S1-A15 with the Weir entry rule: a partial fill is accepted and the unused input is returned to the payer. Their other accounting checks stay unless they assert the stage-one `G_i` and `J_i` credit equation, which FS-MONEY-01 replaces.
```

**R7 — §2 inherit list** (replaces the "Inherit S1-D01 through …" paragraph)

```markdown
Inherit S1-D01 through S1-D05 except S1-D03's dead-share sentence, S1-P01 through S1-P07 except S1-P01's ratio-swap and retained-fee sentence, S1-P05, and S1-P07's collection-only-fallback sentences, S1-X01 through S1-X19 except S1-X15 and S1-X17, S1-ARCH-01 through S1-ARCH-05 except family name and directory, S1-ACC-01 through S1-ACC-07 except S1-ACC-02's genesis sentence and all of S1-ACC-07, S1-OP-01 through S1-OP-05 except S1-OP-02's size, tick-movement, and residual clauses, except S1-OP-05's ratio-swap, quarter-cap, and dust branches, and except the named sentences above, S1-NATIVE-01, S1-API-01 through S1-API-05 except the provider sentence, S1-QUOTE-01, S1-GAS-01, S1-PKG-01, S1-SEC-01 except the named sentence, S1-SEC-02, S1-OBS-01, and S1-TEST-01's fixture discipline. S1-EXIT-01 is not inherited: WeirVaults has no collection-only withdrawal mode.
```

The two carve-outs that depend on the genesis authorization are flagged under "Requires owner authorization" item 4: if the owner does not lock the Weir genesis floor, delete "except S1-D03's dead-share sentence" from this paragraph and drop R11's genesis sentences, R14's genesis sentence, and R18's FS-A05 genesis sentence.

**R8 — §2.1 dispositions table, "Entry remainder" row**

```markdown
| Entry remainder | Weir refund of the unused declared input to the payer. FS-MONEY-01. | `J_i` booked to shared backing without extra shares. A consumption-equality check. |
```

**R9 — §1.3 FS-OWN-10, final sentence** (replaces "`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` stay open." and the sentence before it is kept)

```markdown
This lock does not remove a package address binding, does not decide where that binding is stored, and does not publish an internal compound-or-collect branch. `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are closed as absent from this family: they are not installed as views, not carried as package inputs, and not replaced by another name, another view, or another cap. WeirVaults has no such view and no such input.
```

**R10 — §3 FS-FACET-01, `quoteFacet` row**

```markdown
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. Do not install `previewWithdrawalMode` (FS-OWN-10), `previewZapCredit` (FS-OWN-10), or the paired previews. |
```

**R11 — §3 FS-FACET-01, new-error list** (replaces the list and the sentence that follows it)

```markdown
- `InvalidUnlockedContext()`
- `SettlementMismatch()` where the inherited execution already uses it

`IncompleteConversion(uint256 expectedInput, uint256 consumedInput)` is withdrawn with FS-X04 and is not declared for this family. The one-token exit of FS-A08 reverts with the inherited settlement failure; no new exit error is declared.

`InsufficientRateSupply`, `RateNormalizationOverflow`, and `RateUnavailable` are withdrawn with `getRate`. Do not declare them for this family.
```

**R12 — §4 FS-PKG-01, `PkgArgs`** (replaces the lead sentence and the field list)

```markdown
`PkgArgs` carries the initialization inputs this family needs. It is not the PairToken set: the PairToken zap fields are not carried, and this PRD adds no zap field of its own. No zap field and no hook allowlist:

- `PoolKey poolKey`, stored through the Position Repo in FS-OWN-02, not as proof that `poolKey()` is a family-only selector
- `string name`
- `string symbol`
```

**R13 — §4 FS-PKG-02, validation list** (delete the bullet, add the sentence after the list)

Delete:

```markdown
- Zap limits that are not a positive in-range fee bound and a nonnegative tick bound. `InvalidZapLimits`.
```

Add after the bullet list:

```markdown
`InvalidZapLimits` is not declared for this family. There are no zap limits, so there is no zap-limit validation and no zap-limit error.
```

**R14 — §4 FS-PKG-02, initialization paragraph** (replaces the final two sentences)

```markdown
Initialization installs the inherited metadata, the pool key, and the full-range ticks. It does not store a designated rate token. The PoolManager binding comes from the Protocol Aware pair in FS-OWN-01, not from a family `poolManager()` selector. The first depositor creates the position. Genesis follows WeirVaults `_deposit`: the first deposit requires the added liquidity to exceed `MIN_SHARES`, mints the added liquidity minus `MIN_SHARES`, and leaves `MIN_SHARES` permanently locked in total supply as a floor no holder can redeem. There is no vault-level performance fee: this family takes no cut of the harvested fees.
```

**R15 — §5 FS-MONEY-01, whole section** (replaces the section from its heading to the end of the section)

```markdown
### FS-MONEY-01 — Weir-adapted money surface

The public surface is the Standard Exchange surface named in FS-OWN-08 and FS-OWN-09, without `getRate` and without `rateAsset`. The money rules are WeirVaults' rules, cited to the source function.

**Entry.** A single-token entry balances the position with a swap in the same pool and settles from the deltas the manager actually returns. WeirVaults `_deposit` calls `_balance`, which swaps half of the imbalance between the two declared amounts, and `_deposit` settles each currency from `frame.net0` and `frame.net1`, the net deltas returned by the manager. The unused part of the declared input is returned to the payer: `deposit` sends `p.amount0 - used0` and `p.amount1 - used1` back to `msg.sender`, where `used0` and `used1` are the amounts the manager actually took. There is no consumption-equality check, no `IncompleteConversion`, and no preflight rejection of a predicted partial swap. The entry swap has no size cap and no tick-movement bound; WeirVaults `_swap` uses `sqrtPriceLimitX96` of `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`.

**Issuance.** Shares are minted against the liquidity added to the position, and idle balances are not in the denominator. WeirVaults `_deposit`: when `v.totalShares == 0` the genesis case applies, which requires the added liquidity to exceed `MIN_SHARES`, mints the added liquidity minus `MIN_SHARES`, and sets total supply to `MIN_SHARES` (1,000), an amount no holder can redeem; otherwise the minted amount is the added liquidity times total supply divided by the vault's deployed liquidity. The denominator is deployed liquidity, not idle: `idle0` and `idle1` are allocated to holders at redemption and never enter the issuance equation. WeirVaults has no `J_i`, no `G_i`, and no zap-credit view, and this family does not add one.

**Compound.** `compound` harvests the position's accrued fees and reinvests them into the same full-range position. WeirVaults `_compound` collects the fees, adds the idle dust, computes the liquidity for the harvested amounts, and adds it back to the same position; it never mints or burns shares. It performs no ratio swap and has no size cap. The same harvest-and-reinvest step runs before every deposit and before every withdrawal: WeirVaults `unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`. There is no collection-only withdrawal mode in this family, and `previewWithdrawalMode` is absent. This family takes no cut of the harvested fees.

**Donation.** `donate` stays because FS-OWN-09 locked it. It is an explicit exception: WeirVaults has no `donate` function and does not book a direct transfer as a donation, so `donate` is not a Weir behavior and is not a route back to PairToken-style issuance.

**Exit.** The one-token exit stays as locked in FS-OWN-08 and FS-A08: it pays the selected token or reverts. It is a route constraint, not a two-currency Weir zap and not `IncompleteConversion`.

Native ETH stays, including native-currency pools and actual ETH payout. A wrapped-native boundary does not remove native operation.

The 12,000,000 gas transaction ceiling and the 5,000,000 preview ceiling stay. A hook-composed transaction must fit the 12,000,000 ceiling or be recorded as an unresolved narrowed route. It is not a passing measurement and not a waiver.
```

**R16 — §6 rate, quote, and issuance table** (replaces the "Issuance and `previewZapCredit`" row with two rows)

```markdown
| Issuance | FS-MONEY-01. WeirVaults `_deposit`: shares are minted against the liquidity added to the position, idle balances are not in the denominator, and the genesis case locks `MIN_SHARES`. | Not `exchangeRate`. Not `getRate`. Not the stage-one `S1-ACC-07` credit equation. |
| `previewZapCredit` | Not installed. FS-OWN-10. | Not a renamed view. Not a replacement cap. Not a re-disclosed remainder. |
```

**R17 — §8 FS-TEST-02, inherited-row exceptions** (replaces the bullet list)

```markdown
- S1-A40 is superseded for `exchangeIn` by FS-A19 through FS-A23. It still applies to the methods in FS-A22.
- S1-A06, S1-A56, and S1-A68 use this family's selector manifest after the function review. `getRate` is not required.
- S1-A13 and S1-A15's partial-entry success becomes the Weir entry rule of FS-A07: a partial fill is accepted and the unused input is returned to the payer.
- S1-A10, S1-A46, and S1-A64 are replaced by FS-A07 and FS-A33: they assert the stage-one `G_i` and `J_i` credit equation and the `J_i` donation split, which WeirVaults does not have.
- S1-A19, S1-A62, and S1-A70's collection-only paired-exit wording is replaced by the Weir maintenance rule of FS-A11. Their atomicity and gas bounds stay.
- S1-A70 still bounds the vault call. Composed transactions are FS-A31.
```

**R18 — §8 FS-TEST-03, acceptance rows** (replaces the six rows)

```markdown
| FS-A03 | Invalid component, pool key, wrapper, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no rate-asset argument to reject and no zap-limit argument to reject. |
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Genesis follows WeirVaults `_deposit`: the first deposit requires added liquidity above `MIN_SHARES`, mints the added liquidity minus `MIN_SHARES`, and leaves `MIN_SHARES` permanently locked in total supply. No performance fee: this family takes no cut of the harvested fees. |
| FS-A06 | Paired deposit and redeem follow FS-MONEY-01. The paired deposit adds the declared amounts to the position and mints the Weir liquidity-proportional amount. The paired redeem removes liquidity and each idle balance pro rata (`WeirVaults.sol:_withdraw`). S1-ACC-03's proportional-removal clauses stay; S1-ACC-02's `qQuote` table and all of S1-ACC-07 do not apply. |
| FS-A07 | A single-token entry may partially consume the declared input. After the manager action the payer receives the declared amount minus the amount the manager actually took (`WeirVaults.sol:deposit`). No `IncompleteConversion` is raised, no preflight partial-swap rejection occurs, no `J_i` remainder is booked to shared backing, and no extra shares are minted for uncredited input. |
| FS-A11 | Withdrawal runs the same harvest-and-reinvest step as deposit. `WeirVaults.sol:unlockCallback` calls `_compound` before `_withdraw` and before `_deposit`. There is no collection-only withdrawal mode, `previewWithdrawalMode` is absent, and the standalone `compound()` entry point remains. |
| FS-A33 | Borrowed execution uses the same harvest-and-reinvest step, the same issuance rule, and the same fee attribution as the locked path from the same economic state. |
```

FS-A08 (one-token exit), FS-A11's locked sibling rows, FS-A16, FS-A22, FS-A25, FS-A29 and FS-A31 are otherwise unchanged. FS-A25's stale `token == rateAsset` clause conflicts with FS-OWN-03 and should be deleted in the same pass; it is not a Weir-alignment change and I list it only as found.

## Requires owner authorization

These are cases, not proposed PRD text. None of them is authorized by this advisory, and I propose no replacement for any removed knob.

1. **Entry size bound.** WeirVaults has none. The copied `maxZapBps` field is removed and nothing replaces it. If the owner wants an entry bound, it needs a stated case and a lock; the PRD must then name the bound, the unit, and where it is enforced. I do not propose a number and I do not propose a field name.
2. **Entry tick or price bound.** WeirVaults has none; `_swap` uses the range-boundary price limit, so a Weir entry swap can move the price across the whole range. The copied `maxZapTickMove` field is removed and nothing replaces it. A guard, if wanted, must be authorized separately; a Weir-shaped price limit would be the candidate, but it is not proposed here.
3. **Treasury performance fee.** WeirVaults takes `perfFeeBps` (default 5%, hard cap 10%) of harvested fees to the treasury. The PRD keeps "no vault-level performance fee" because the owner authorized no fee, and I did not add one. If the owner wants Weir's cut, that is a separate lock with its own cap.
4. **Genesis floor.** Adopting Weir's `MIN_SHARES` floor (1,000 liquidity units, permanently locked, unredeemable) supersedes the inherited S1-D03 sentence ("do not inherit PairToken's permanent dead shares"), the inherited S1-ACC-02 genesis sentence ("no 1,000-share subtraction, virtual shares, virtual assets, or hidden minimum liquidity sink"), and FS-A05's "No dead-share mint". The replacements above assume the owner locks the Weir floor. If the owner declines it, delete the "except S1-D03's dead-share sentence" carve-out in R7 and the genesis sentences in R11, R14 and R18's FS-A05, and then the PRD must state a genesis issuance rule of its own — WeirVaults states none, so that rule would be a new design the owner would have to authorize, not a Weir adaptation.
5. **`donate`.** Already locked by FS-OWN-09 and kept as an explicit exception. Weir does not book direct transfers as donations, so this is a named divergence, not a Weir behavior. It needs no new authorization; it does need the PRD to say so, which R15 does. It must not be read as permission to reintroduce PairToken issuance from a donation.
6. **Remaining inherited economics not named in the brief.** S1-ACC-06's custody and fee-ownership ledger, the rest of S1-D01 through S1-D05, and the remaining S1-X and S1-QUOTE clauses stay inherited. I found no other clause that asserts a removed rule, but a full clause-by-clause sweep of the remaining inherited IDs is a separate pass and I do not claim I performed one.

## Limits

- No implementation, no Forge build or test, no deployment, no Git operation, no install. Nothing here was executed against a chain.
- I did not read peer responses, edit the PRD, the review file, the brief, or any peer file, and I did not delegate.
- The advisory neither replaces the PRD nor authorizes implementation. It does not carry owner approval for items 1 through 6 above.
- FS-OWN-01 through FS-OWN-10 keep their substance. The only locked text I propose to change is FS-OWN-10's final sentence, which the brief states is superseded by this update.
- The one-token exit rule is not re-derived from Weir. Weir's exit swap does not require full consumption of the unwanted leg; the PRD's locked FS-OWN-08 / FS-A08 rule is preserved as an owner decision and is not weakened or strengthened here.
- Every number in this response is quoted from `WeirVaults.sol` or from the stage-one PRD. Where WeirVaults states no rule (entry cap, tick guard, zap-credit view, residual booking, collection-only fallback, genesis without the floor, no-fee statement), I said so and added nothing.
- Line numbers are from the read of `WeirVaults.sol` on 2026-10-31 and can drift; the function names are the durable anchors.
- I read the stage-one PRD to identify which inherited clauses assert a rejected rule. It remains the reference for the inherited non-economic clauses only, and my recommendations do not treat it as an economics authority for this family.
