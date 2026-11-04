# Identity

Kimi, independent council member, research profile. Disposition: **request owner clarification before implementation**. The PRD closes many prior economic choices, but the gaps below still permit divergent money, storage, selector, or route behavior.

# Question and targets

Question: which sentences in the updated full-spread PRD still require an implementor to choose product behavior, and what owner decision or source-backed replacement removes each choice?

Targets read in full:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, revision `fullspread-se-prd-weir-align-r1`.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`.
- `contracts/protocols/strategy/weir/WeirVaults.sol`, for the cited `deposit`, `_deposit`, `_withdraw`, `_compound`, and `_swap` behavior.

# Evidence

The owner locks override conflicting PRD text, but they do not settle sentences that expressly remain undecided. The function-review file repeats those locks and, importantly, says that dropping the paired selectors removed the only named raw-ETH entry and exit.

The cited Weir source establishes the following limits on what can be closed without a new owner decision:

- `_deposit` initializes `v.totalShares` to `MIN_SHARES`, then adds `frame.shares`; `deposit` credits only `frame.shares` to `sharesOf[id][p.recipient]`. Weir therefore has an internal supply floor with no corresponding recipient credit, but it does not specify how a tokenized ERC-20 should represent that floor.
- `_deposit` calls `_settle` for each currency and its comment says credits go to the depositor. The source does not define how the accepted `(amountOut, amountRefunded)` ABI reports a credit denominated in a currency other than the selected input.
- `_withdraw` calculates both pro-rata idle amounts, pays them into the withdrawal calculation, swaps a positive unwanted-leg net amount for `zapTo == 1` or `zapTo == 2`, and then settles. This is an existing source rule for the accepted one-token exit even though the external `zapTo` parameter is not retained.
- `_compound` reinvests harvested fees plus idle and leaves only the remainder idle. It has no target-percentage sleeve refill or shortfall policy, so it cannot close FS-OWN-04.

Minimum-inventory disposition:

| Brief item | Disposition |
| --- | --- |
| Genesis floor representation | Confirmed as G-01. |
| Positive credit in the unselected currency | Confirmed as G-02. |
| Sleeve refill, shortfall, and locked-caller spending | Confirmed and split into G-03 and G-04. |
| `poolManager` package field and aware-repo write | Confirmed as G-05. |
| `wrappedNative` binding storage | Confirmed as G-06. |
| Raw ETH entry and exit | Confirmed as G-07; the PRD also contains conflicting affirmative native language. |
| `queryFacet` under function review | Confirmed as G-08. |
| Other FS-OWN-07 reserve semantics | Confirmed and narrowed by FS-A32 into G-09 and G-10. |
| Later rate policy | Rejected as a current implementation gap; see G-11. |
| Pro-rata idle on the one-token exit | Confirmed as G-12, but closable from `_withdraw` and existing acceptance locks. |

# Gaps

## G-01 — Genesis floor has no ERC-20 representation

**PRD section:** FS-MONEY-01; also FS-A05.

**Deferring sentences:** “The floor is supply that is not credited to that recipient. This update does not add a second share ledger, pick a holder address, or rescale the constant.”

**Why implementors diverge:** One implementor can include `MIN_SHARES` in ERC-20 `totalSupply` and assign a balance so supply and holder accounting reconcile; another can reproduce Weir literally with supply included in the redemption denominator but no holder balance. Those choices produce different `totalSupply`, balance, transfer, and final-redemption behavior. Weir's internal `totalShares`/`sharesOf` split does not choose the ERC-20 representation, and the PRD expressly leaves the holder unpicked.

**Closure:** Owner question Q-01.

## G-02 — `amountRefunded` is undefined for an unselected-currency credit

**PRD section:** FS-X04, FS-OWN-08, and FS-MONEY-01.

**Deferring sentences:** “A positive credit is returned to the depositor and is not booked without shares.” FS-OWN-08 separately locks the return to “`(uint256 amountOut, uint256 amountRefunded)`” and says “Do not add a return field” in FS-MONEY-01.

**Why implementors diverge:** On a one-token deposit, a positive PoolManager credit can be denominated in the currency that was not selected as `tokenIn`. One implementor can pay that credit separately and report only unused `tokenIn` in `amountRefunded`; another can reject the route because its credit cannot be represented; an implementation that adds unlike currency units would be a third, invalid interpretation. The ABI forbids a new field but does not state the reporting rule, while `_deposit` only says to settle the credit to the depositor.

**Closure:** Owner question Q-02.

## G-03 — Sleeve target, refill timing, and shortfall are unsettled

**PRD section:** FS-OWN-04 and FS-MONEY-01.

**Deferring sentence:** “Refill, shortfall, and whether a locked caller may spend the sleeve are not specified.”

**Why implementors diverge:** The target is a percentage of each token's owned amount, while owned amount itself includes the local sleeve. An implementor must choose when to rebalance, whether the target is exact or only an upper/lower objective, and whether an unreachable target leaves a partial sleeve or reverts. The `1e18` case makes the choice observable: local equals 100% of local-plus-deployed only when the deployed term is zero. Weir `_compound` instead reinvests all usable idle and cannot supply this policy.

**Closure:** Owner question Q-03.

## G-04 — Borrowed-unlock spending of the sleeve is unsettled

**PRD section:** FS-OWN-04 and FS-UNLOCK-02.

**Deferring sentence:** “Refill, shortfall, and whether a locked caller may spend the sleeve are not specified.”

**Why implementors diverge:** A borrowed `exchangeIn` cannot call `unlock`, so one implementor can fund manager debts partly from local balances while another leaves the sleeve untouched and funds only from the payer and operation proceeds. These versions have different success sets, reserve balances, and settlement behavior even with identical inputs. Neither FS-UNLOCK-02's settlement steps nor Weir's always-unlocked `_deposit` chooses between them.

**Closure:** Owner question Q-04.

## G-05 — The `poolManager` binding and aware-repo initialization are undecided

**PRD section:** FS-OWN-01 and FS-PKG-01.

**Deferring sentences:** “A `poolManager` address may still be a package binding. How that address is written into the aware repo is not decided here.” FS-PKG-01 repeats: “FS-OWN-01 does not yet say whether that field stays or the aware facet becomes a package input.”

**Why implementors diverge:** One implementation can retain the immutable `PkgInit.poolManager` field and write it to the aware repo during initialization; another can require an aware component as a package input and read a preinitialized repo. These choices change `PkgInit`, `bindingHash`, deployment order, initialization authority, and the storage read used by every PoolManager route.

**Closure:** Owner question Q-05.

## G-06 — The `wrappedNative` binding has no storage location or writer

**PRD section:** FS-OWN-10 and FS-PKG-01.

**Deferring sentence:** “This lock does not remove a package address binding, does not decide where that binding is stored, and does not publish an internal compound-or-collect branch.”

**Why implementors diverge:** The package still has a `wrappedNative` binding and validation depends on it, but an implementor can keep it only as an immutable package binding, copy it into family storage, or copy it into another repo. Those are different storage and initialization designs, and the routes will read different state. The prohibition on a family getter does not choose the storage location.

**Closure:** Owner question Q-06.

## G-07 — Raw ETH support is both asserted and left undecided

**PRD section:** FS-OWN-09 and FS-MONEY-01; compare FS-UNLOCK-02 and FS-A10.

**Deferring/conflicting sentences:** FS-OWN-09 says, “Raw ETH is not decided and no extension is added.” FS-MONEY-01 instead says, “Native ETH stays, including native-currency pools and actual ETH payout. A wrapped-native boundary does not remove native operation.”

**Why implementors diverge:** One implementor can restrict public routes to the wrapped ERC-20 faces in `vaultTokens()` while still accounting for a native pool key; another can make locked entry payable and pay raw ETH on exit. The function-review file confirms that the dropped paired selectors removed the only named raw-ETH routes. These implementations differ in payability, currency selection, settlement, and recipient behavior. The borrowed path's nonpayable rule does not settle the locked path.

**Closure:** Owner question Q-07.

## G-08 — `queryFacet` has exclusions but no affirmative selector set

**PRD section:** FS-FACET-01, `queryFacet` row.

**Deferring sentence:** “Still under function review.”

**Why implementors diverge:** The lock names selectors that must not be installed, but does not say which of `poolKey`, `tickLower`, `tickUpper`, `positionLiquidity`, `localReserves`, or other reviewed queries are exposed by this facet or elsewhere. Two packages can satisfy every exclusion and still ship different proxy selectors and facet cuts. Recounting selectors only after the review does not provide the manifest.

**Closure:** Owner question Q-08.

## G-09 — The reserves snapshot has no refresh rule

**PRD section:** FS-OWN-07 and FS-A32.

**Deferring/conflicting sentences:** FS-OWN-07 says, “Its other semantics are not specified.” FS-A32 says, “Busy-vault economic views revert. An idle vault answers while the manager is unlocked. Basic reserves return the last committed snapshot.”

**Why implementors diverge:** FS-OWN-07 defines deployed reserves from current liquidity, price, ticks, and owed fees, whereas FS-A32 requires a last committed snapshot without defining when that snapshot is committed. One implementation can compute live values while idle and use stored values only while busy; another can always return stored values refreshed at different operations. Deposit, withdrawal, compound, donate, and fee accrual can therefore produce different reserve reads. FS-A32 narrows the busy behavior but does not fix snapshot timing.

**Closure:** Owner question Q-09.

## G-10 — `reserveOfToken` has no non-vault-token behavior

**PRD section:** FS-OWN-07.

**Deferring sentences:** “`reserveOfToken(address)` returns that same sum for one token.” The same lock says, “Its other semantics are not specified.”

**Why implementors diverge:** For an address absent from `vaultTokens()`, one implementation can revert and another can return zero. Both can claim to return the local-plus-deployed sum for actual vault tokens while exposing different query behavior to integrators. No cited Weir function defines this tokenized Basic Vault query.

**Closure:** Owner question Q-10.

## G-11 — Rejected minimum item: a later rate policy is not a current implementation gap

**PRD section:** FS-OWN-03 and FS-RATE-01.

**Sentence assessed:** “A later decision may name a rate policy. This lock does not name one.”

**Disposition:** Reject this as a current gap. The implementor is not asked to choose a rate: `rateAsset()` and `getRate()` are expressly absent, no substitute denomination is allowed, and a hook that requires a provider remains an FS-HOOK-04 integration record. Shipping without those selectors is fully specified. A future rate policy would be a new decision, not behavior the current implementor must invent.

## G-12 — Pro-rata idle needs an explicit one-token conversion sentence, but Weir closes the choice

**PRD section:** FS-MONEY-01; also the Section 6 quote table, FS-A08, and FS-A11.

**Deferring sentences:** “`_withdraw` removes liquidity in proportion to shares and pays pro-rata idle. This family does not install `zapTo`. The accepted one-token exit still pays only the selected token or reverts.”

**Why implementors diverge:** Removing the external `zapTo` parameter does not say whether the internal one-token route swaps the unwanted leg including pro-rata idle, leaves idle behind, or reverts whenever withdrawal produces both currencies. Those choices change payout and remaining reserves. However, cited `_withdraw` already pays idle into the withdrawal deltas and swaps the positive unwanted leg, while FS-A08/FS-A11 and the preview requirement for “full unwanted-leg consumption” select that behavior. An exact replacement can therefore close this without inventing a rule.

**Closure:** Recommendation R-01.

## G-13 — Additional gap: `donate` has no custody or reserve disposition

**PRD section:** FS-OWN-09 and FS-FACET-01.

**Deferring sentence:** “Keep `donate` and `compound`.” The function-review lock adds only that `donate(token, amount)` “adds tokens to the vault's book and mints no shares.”

**Why implementors diverge:** One implementor can transfer the donation into the diamond's local idle balance, making it visible in `localReserves()` and available to the next compound; another can add value directly to the position or hold a PoolManager credit. These choices change local reserves, deployed reserves, sleeve accounting, and subsequent share issuance without changing share supply at donation time. Weir has no `donate`, and PairToken behavior is not inherited authority.

**Closure:** Owner question Q-13.

## G-14 — Additional gap: the required Universal Router component has no binding source

**PRD section:** FS-OWN-01 and FS-PKG-01.

**Deferring sentence:** “This standard keeps the protocol's components in one pair, including the PoolManager, the Universal Router, and any other V4 component an integrator needs.”

**Why implementors diverge:** FS-PKG-01 fixes the infrastructure bindings and names no Universal Router input. One implementor can leave the aware repo's Universal Router unset because this vault's routes do not use it; another must introduce an initialization source to satisfy the requirement that the pair store and expose it. Those packages have different stored component state and aware-facet results. The open-ended phrase for other integrator components does not identify an existing binding for this required component.

**Closure:** Owner question Q-14.

# Questions for the owner

- **Q-01 (G-01):** Which ERC-20 balance, if any, should own the `MIN_SHARES` floor, or should ERC-20 `totalSupply` exclude it while the internal issuance/redemption denominator includes it?
- **Q-02 (G-02):** When a one-token deposit produces a positive credit in the currency other than `tokenIn`, must `exchangeIn` pay that credit to the payer but exclude it from `amountRefunded`, with `amountRefunded` reporting only unused `tokenIn`, or must the operation revert?
- **Q-03 (G-03):** After which operations must each token's sleeve be rebalanced toward `mulDiv(liquidReservePercentageOfVault(address(this)), reserveOfToken(token), 1e18)`, and when that target cannot be reached, including at `1e18`, should the operation retain the attainable partial sleeve or revert?
- **Q-04 (G-04):** May borrowed-unlock `exchangeIn` spend the local sleeve to fund its manager action and settlement, or must it leave the sleeve untouched and use only the payer's funds plus operation proceeds?
- **Q-05 (G-05):** Should `PkgInit.poolManager` remain and be written into the Protocol Aware Repo during vault initialization, or should the aware facet/repo instead be supplied as an already initialized package input?
- **Q-06 (G-06):** Which named repo must store the `wrappedNative` package binding, and which initialization step is authorized to write it?
- **Q-07 (G-07):** Does “Native ETH stays” require payable raw-ETH entry and actual raw-ETH exit on the accepted routes, or does it require only native-pool support through the wrapped ERC-20 faces already on `vaultTokens()`?
- **Q-08 (G-08):** What is the complete affirmative `queryFacet` selector list, including the facet placement of `poolKey`, `tickLower`, `tickUpper`, `positionLiquidity`, and `localReserves`, after the locked exclusions are applied?
- **Q-09 (G-09):** At which operations is the FS-A32 “last committed snapshot” of local-plus-deployed reserves refreshed, and are live current-price/current-fee computations returned while the vault is idle?
- **Q-10 (G-10):** Must `reserveOfToken(address)` revert for an address absent from `vaultTokens()`, or return zero?
- **Q-13 (G-13):** Must `donate(token, amount)` pull the token into the diamond as local idle included in `localReserves()` and the next compound, or should the donation be placed directly into the deployed position or another custody location?
- **Q-14 (G-14):** Which existing package binding or initialization input must supply the Universal Router address that FS-OWN-01 requires the Protocol Aware pair to store and expose?

# Recommendations that close a gap

## R-01 — Close G-12 from `_withdraw` and the existing acceptance locks

Replace this FS-MONEY-01 sentence:

> This family does not install `zapTo`. The accepted one-token exit still pays only the selected token or reverts.

With exactly:

> The accepted one-token exit uses the `_withdraw` conversion path without exposing a `zapTo` parameter: add pro-rata idle to the withdrawal deltas, swap the entire positive unselected-currency delta into the selected currency, and settle only the selected currency; if that conversion cannot close with only the selected currency payable, revert without burning shares.

**Authorizing source and locks:** `WeirVaults.sol::_withdraw` computes `i0` and `i1` as pro-rata idle, calls `_pay` for both, adds them to `net0` and `net1`, and for `zapTo == 1` or `zapTo == 2` calls `_swap` on the full positive unwanted-currency net before settlement. FS-A08 requires selected-token-only payout or revert without burning shares; FS-A11 requires pro-rata idle and no collection-only fallback; the Section 6 quote table requires “full unwanted-leg consumption.” This recommendation adds no selector, return field, cap, fee, or holder.

# Limits

This is a requirements audit, not an implementation plan or safety clearance. I did not treat a future rate policy, unresolved hook integration records, file naming, selector recount mechanics, or unperformed test evidence as permission for an implementor to choose current product behavior. I made no code or target-document edits and ran no builds, tests, Forge, Git, installations, or deployments.
