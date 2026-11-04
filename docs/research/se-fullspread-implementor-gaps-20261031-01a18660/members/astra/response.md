# Identity

Astra, independent council member, research profile, for `se-fullspread-implementor-gaps-20261031-01a18660`. Date: 2026-10-31.

The runtime exposes `PI_MODEL=gpt-6-astra` and `PI_PROVIDER=chatgpt-subscription`. The requested route is `chatgpt-subscription/gpt-6-astra:high`; the reasoning setting was not independently exposed by the metadata examined.

# Question and targets

Which sentences in the updated full-spread PRD still require an implementor to choose product behavior, and which exact owner question or already-authorized replacement removes that choice?

I examined the complete brief, the complete PRD revision `fullspread-se-prd-weir-align-r1`, and the complete `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`. I checked the relevant Weir money functions and the two accepted route reports cited by FS-OWN-08 and FS-OWN-09. I did not read peer responses.

The ten-item minimum inventory is dispositioned below as M1-M10. Additional behavior gaps are A1-A13. An unresolved owner question is not a recommendation to implement either possible answer. A correction supported by an existing lock is not a request to reopen that lock.

# Evidence

Local source references:

- **PRD:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, read completely. Section and requirement IDs below identify the operative text.
- **Function decisions:** `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, read completely. In particular, Paired money, Zap accounting, Pool and position identity, Liquidity sleeve, Custom Basic Vault reserves, and Rate.
- **Accepted interface report:** `docs/research/se-interface-refund-bundle-20261030-01a18660/REPORT.md`, read completely. Its Owner lock overrides the preserved recommendation against changing the existing return ABI. Refund rule defines an input-denominated refund, nonpayable ERC-20 faces, and pretransfer custody separation. The accepted bundle interfaces define caller-ordered output arrays and no surprise bundle output.
- **Accepted paired-route report:** `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`, read completely. Answer locks the route mapping, donation without minting, compounding without supply change, and stable `vaultTokens()` order. Raw ETH explicitly leaves raw user entry/exit undecided.
- **Weir source:** `contracts/protocols/strategy/weir/WeirVaults.sol`, examined around the cited money functions, not as a whole-contract audit:
  - `deposit`, lines 160-184: declared pulls, shares to the recipient, unused declared amounts back to the payer.
  - `unlockCallback`, lines 222-236: compound before deposit or withdrawal.
  - `_deposit`, lines 248-286: optional `_balance`, liquidity sizing, the `1_000` floor, liquidity-based issuance, and per-currency credit settlement to the depositor.
  - `_withdraw`, lines 288-325: separately rounded proportional liquidity and idle; idle joins the manager credit before optional conversion; settlement of both final currency deltas.
  - `_compound`, lines 341-381: zero-liquidity fee collection, fees plus idle reinvestment, retained idle, and an early return when liquidity is zero. The PRD expressly excludes the source treasury cut.
  - `_balance`, lines 385-411, and `_swap`, lines 413-427: the balancing calculation and range-boundary swap limits. They do not establish a sleeve policy, an ERC-20 floor holder, or a Standard Exchange preview ABI.

Observed facts are the quoted requirements and source behavior. Divergence examples below are deductions from their missing or conflicting contracts. No execution, gas, fork, deployment, or compiler result is claimed.

# Gaps

## Minimum inventory

### M1. Genesis floor representation: confirmed, narrowly

**PRD location:** FS-MONEY-01, genesis bullet; FS-A05.

> "This update does not add a second share ledger, pick a holder address, or rescale the constant."

The arithmetic is already settled: first added liquidity must exceed `1_000`; the recipient gets added liquidity minus `1_000`; the floor remains in total supply. Weir `_deposit` lines 264-278 and `deposit` line 181 establish that. They do not establish how the uncredited portion is represented by this product's single ERC-20 ledger. An implementor could create a permanent non-redeemable supply offset; another could allocate a balance and prevent its redemption. Those choices differ in balances, transfer behavior, and ERC-20 mint events. Neither the holder nor the representation may be selected by the implementor.

**Disposition:** Q1. Do not ask again whether the floor exists or what its size is.

### M2. Positive credit in an unselected entry currency: correct the inventory; settlement is already chosen

**PRD location:** FS-X04; FS-MONEY-01, settlement and withdrawal bullets.

> "A positive credit goes back to the depositor."

> "Unused input and a positive credit are returned to the payer. They are not booked without shares. Do not add a return field."

If the second sentence were treated as an unspecified refund convention, implementations could retain the other currency, convert it, or overload `amountRefunded` with its units. The first sentence and Weir `_deposit` lines 281-285 already exclude those choices: settlement sends each positive credit to the depositor in that currency. The accepted interface report makes `amountRefunded` a quantity of declared `tokenIn`, not an arbitrary currency credit. Its declared-input conservation equation cannot include newly generated other-token credit.

**Disposition:** no new owner choice about entry settlement or a return field. R2 makes the two distinct transfers explicit. It does not extend this entry rule to one-token withdrawal. A scalar preview does not gain a second-currency quote.

### M3. Sleeve refill, shortfall, and spending: confirmed

**PRD location:** FS-OWN-04.

> "Refill, shortfall, and whether a locked caller may spend the sleeve are not specified."

The target source, WAD unit, per-token application, and actual-balance getter are settled. Operation policy is not. Maintaining a hard minimum, pursuing a soft target, or reinvesting the sleeve as ordinary Weir idle produces different deployable liquidity and successful withdrawals. Weir `_compound` consumes available idle but has no percentage sleeve to preserve. It cannot choose the adaptation.

**Disposition:** Q3a-Q3c. These are separate decisions; computing a percentage does not answer any of them.

### M4. PoolManager package binding and aware-repo initialization: confirmed

**PRD location:** FS-OWN-01; FS-PKG-01.

> "A `poolManager` address may still be a package binding. How that address is written into the aware repo is not decided here."

> "FS-OWN-01 does not yet say whether that field stays or the aware facet becomes a package input."

A facet implementation address and a protocol component address are not interchangeable inputs. Implementors can otherwise derive the manager from different authorities, commit different bindings into `bindingHash`, and initialize the same-looking pool key against different managers. The aware-repo requirement is settled; its authoritative binding and initialization contract are not.

**Disposition:** Q4. The question does not reopen the prohibition on a family-only getter.

### M5. Wrapped-native binding storage: confirmed

**PRD location:** FS-OWN-10; FS-PKG-01.

> "This lock does not remove a package address binding, does not decide where that binding is stored, and does not publish an internal compound-or-collect branch."

FS-PKG-01 includes `wrappedNative`; absence of a getter does not identify the runtime storage authority. Reading an immutable package binding versus a per-vault repository value can yield different initialization and wrapper-validation behavior. This is a binding contract, not a request to select a filename.

**Disposition:** Q5. No public wrapper getter or replacement selector is proposed.

### M6. Raw ETH user entry and exit: confirmed, with internal settlement separated

**PRD location:** FS-OWN-09; FS-MONEY-01 native paragraph; FS-A10.

> "Raw ETH is not decided and no extension is added."

> "Native ETH stays, including native-currency pools and actual ETH payout."

> "Native pool entry and payout move ETH, except the inherited wrapper boundary."

Native settlement between this vault and PoolManager is compatible with nonpayable wrapped-face user routes. Raw ETH paid by or to a user is a separate capability. The accepted reports explicitly say the mapped bundle routes do not take or pay raw ETH, while the PRD still contains an unqualified actual-ETH-payout requirement. One implementation could provide only wrapper-facing public routes; another could interpret the money paragraph as requiring an additional public native route. The second has no authorized selector.

**Disposition:** Q6 for the product scope; R6 states the boundary already locked for accepted routes. Do not use the unresolved sentence to invent an extension or resurrect a paired selector.

### M7. Query facet under review: reject as an outstanding function-inclusion decision

**PRD location:** FS-FACET-01, `queryFacet` row.

> "Still under function review."

Read alone, this permits different query manifests. Read with FS-OWN-01 through FS-OWN-10 and the function-review file, the named inclusion decisions are already closed: retained local balances, ticks, liquidity, and reusable pool identity; relocated protocol identity; rejected rate, basket, wrapper, withdrawal-mode, and zap views. The review file's introductory "Unmarked functions are still open" does not authorize a replacement rate; its final Rate section expressly says otherwise.

**Disposition:** R7 replaces the stale open-review statement. The aware-component scope and package wiring still need M4, A3, and A4; that is not a reason to reopen each function.

### M8. FS-OWN-07 summary says other reserve semantics are unspecified: correct as stale

**PRD location:** section 1.2, FS-OWN-07 table row.

> "Its other semantics are not specified."

That summary no longer describes the detailed lock. FS-OWN-07 specifies local plus deployed amounts, token ordering, the current-price principal and unpaid-fee terms, and the three selector-to-facet assignments. Implementors must not choose sleeve-only balances or a different deployed valuation.

**Disposition:** R8. This closes the stale blanket deferral, not the separate custody, busy-view, and unsupported-token questions in A1, A2, and A13.

### M9. A later rate policy: reject as a present implementation gap

**PRD location:** FS-OWN-03; FS-RATE-01.

> "A later decision may name a rate policy. This lock does not name one."

There is one current behavior: no `rateAsset`, no `getRate`, no substitute denomination or provider installed as this family's rate. A required hook bind that needs a provider remains an unresolved FS-HOOK-04 record. Choosing a rate now would violate the lock, not implement an alternative permitted by it.

**Disposition:** R9 can sharpen the scope sentence. No owner rate-policy question is needed to implement the current exclusion. A later hook-record procedure is not a product gap by itself.

### M10. Pro-rata idle in the one-token exit without installing `zapTo`: correct; the money rule closes it

**PRD location:** FS-MONEY-01 withdrawal bullet; section 6 preview table; FS-A08 and FS-A11.

> "`_withdraw` removes liquidity in proportion to shares and pays pro-rata idle. This family does not install `zapTo`. The accepted one-token exit still pays only the selected token or reverts."

Weir `_withdraw` first calculates each idle entitlement, pays it into the manager, and includes it in the currency totals before conversion. The PRD also requires full unwanted-leg consumption for the executable exit preview. Omitting idle from conversion, paying the unwanted idle as a second token, or retaining the withdrawer's idle would conflict with those requirements.

The source's `zapTo` is a withdrawal parameter, not a separately callable source function. Refusing to install a Weir selector does not prohibit the internal selected-currency conversion required by `exchangeIn`. The source itself settles both residual deltas, so its permissive residual payout must not be copied over the stricter selected-token-only rule.

**Disposition:** R10 closes the misleading wording with the source ordering and the already-locked full-conversion-or-revert condition. Sleeve treatment must still be settled under M3; this recommendation does not equate every sleeve balance with distributable idle.

## Additional behavior gaps

### A1. Actual local balances versus booked backing and pretransfer credit

**PRD location:** FS-OWN-04; FS-OWN-07; section 8 comparison instruction.

> "`localReserves()` returns the actual local balances of the underlying tokens."

> "`reserves()` returns the local-plus-deployed amount of each vault token, in `vaultTokens()` order."

> "Compare supply, holder balances, both positions, booked and reserved custody, wrapper balances, and per-address deltas."

The accepted interface report distinguishes booked holder backing from unbooked pretransfer input and surplus above a declaration. Raw balances can include all three. It is not settled whether every raw balance belongs in local reserves and the sleeve target, or whether only accounted backing does. That choice changes reported claims, target funding, donation capture, and whether another caller's pretransfer is made available to compound or withdrawal. The report settles that booked backing cannot fund pretransfer and surplus is not consumed merely because it exists; it does not choose the reserve getter's custody model.

**Disposition:** Q11. This also covers native/wrapper custody classification without allowing double-counting, already forbidden by FS-A35.

### A2. Current reserves, last committed snapshot, and busy-view coverage

**PRD location:** FS-OWN-07; FS-A32.

> "The deployed term is locked."

> "For each underlying token it is the amount implied by this position's liquidity, the current pool price, and the stored ticks, plus fees owed to this position in that token and not yet collected."

> "Busy-vault economic views revert. An idle vault answers while the manager is unlocked. Basic reserves return the last committed snapshot."

A snapshot of token amounts made at the vault's last operation can be stale after another account swaps or fees accrue. Returning that instead of current-price amounts contradicts the higher-priority lock. R12 closes that conflict for idle reads.

The same acceptance row also leaves unclear whether Basic reserves are an exception to busy economic-view rejection and whether position liquidity/local balances are covered. Implementors could expose intermediate backing on some callbacks or revert all such queries. FS-OWN-07 defines values, not this exception list.

**Disposition:** R12 plus Q12 for the exact busy-view surface. Merely saying "snapshot" is not a sufficient storage or temporal contract.

### A3. Protocol Aware component set beyond PoolManager

**PRD location:** FS-OWN-01.

> "This standard keeps the protocol's components in one pair, including the PoolManager, the Universal Router, and any other V4 component an integrator needs."

The Universal Router is explicitly named, but FS-PKG-01 supplies no corresponding binding. "Any other ... an integrator needs" lets implementors publish different protocol-component state and getters or select different component addresses. A reusable repository's extensibility does not decide which components this deployment binds and exposes.

**Disposition:** Q13. This is distinct from how the already-required manager binding is initialized.

### A4. One Basic Vault package field names two facet addresses

**PRD location:** FS-FACET-01; FS-PKG-01.

> "`basicVaultFacet` is the custom implementation in FS-OWN-07, not the shared facet."

> "Not one shared facet. `vaultTokens` is `MultiAssetBasicVaultFacet`. `reserveOfToken` and `reserves` are the family custom facet."

> "`bindingHash` covers every `PkgInit` field."

The selector routing is settled, but the fixed package-input list describes only one Basic Vault field while requiring two implementations. An implementor could introduce a second bound address; another could obtain the shared facet from an external authority or embed it in another component. That changes binding and initialization behavior, not just source organization.

**Disposition:** Q14. Do not solve this by reimplementing `vaultTokens` or installing the shared reserve functions.

### A5. The validation domain is still inherited from an unnamed source

**PRD location:** FS-PKG-02.

> "A pool key that is not initialized on the bound manager, has a nonzero hook, or is outside the inherited domain. `InvalidPoolKey`."

Initialization and nonzero-hook rejection are clear. The remaining domain is not enumerated, while section 2 denies automatic PairToken package/economic inheritance and inherits Weir rules only when expressly stated. Implementors could disagree about which otherwise initialized hookless keys are admissible. Token policy from the router is not a complete pool-key domain specification.

**Disposition:** Q15. No new allowlist, cap, or pool restriction is proposed.

### A6. Transaction-fee policy is not established by excluding the Weir treasury fee

**PRD location:** FS-MONEY-01 compound bullet; FS-FACET-01 shared standard-vault row; FS-PKG-01.

> "That cut is not added here. This is not PairToken's no-fee rule. It is the absence of an unauthorized fee."

The package also binds `oracle` and retains `vaultFeeTypeIds`. The sleeve's oracle lookup is specified; other fee use is not. An implementor could treat all money routes as having no deductions, while another could import an existing SE fee policy because the standard-vault surface remains. Removing Weir's performance fee does not identify any authorized entry, exit, swap, donation, or compound deduction.

**Disposition:** Q16. Neither a new fee nor an assertion that the owner chose a universal no-fee policy is authorized by this sentence.

### A7. Donation booking does not determine admission or use

**PRD location:** FS-OWN-09.

> "Keep `donate` and `compound`. `donate` is an explicit exception."

The accepted paired report and function decisions additionally settle that `donate(token, amount)` books tokens and mints no shares. They do not specify whether a donation only becomes idle, immediately deploys liquidity, or refills a protected sleeve. Before genesis, Weir `_compound` returns when liquidity is zero; no Weir donation function supplies a bootstrap rule. Accepting and retaining such a donation versus rejecting it changes first-depositor economics.

**Disposition:** Q17a-Q17b. The selector and no-mint rule are not open. This is not permission to copy PairToken's entire donation implementation.

### A8. Source deposit has an optional balancing branch; mapped bundle deposit does not choose it

**PRD location:** FS-MONEY-01.

> "The entry swap, when one is needed, uses `_swap`."

Weir `_deposit` line 252 executes `_balance` only if `p.zap` is true. The accepted bundle input has no such flag. One implementation could balance an imbalanced two-token declaration with `_balance`; another could add only the available ratio and refund the surplus without a swap. Both can satisfy proportional liquidity issuance and declared-input refunds, but they execute different trades and mint different quantities.

**Disposition:** Q18 for the bundle branch. Weir's `_balance` supplies a concrete calculation if that branch is selected; it does not select the flag for this ABI. The one-token entry's need to produce the other leg does not settle imbalanced two-token entry.

### A9. Family support for underlying-to-underlying scalar exchanges is not stated

**PRD location:** FS-MONEY-01 opening; FS-UNLOCK-01.

> "The public selectors stay the accepted Standard Exchange routes, plus locked `donate` and `compound`."

> "After ordinary route, deadline, amount, and authority checks, `exchangeIn` reads `TransientStateLibrary.isUnlocked` on the bound manager:"

The accepted interface report describes swaps, deposits, and withdrawals, and expressly permits a vault to reject a route. The family specifies share entry and exit but does not say whether underlying-to-underlying exchange is supported. An implementor could provide it through the pool, or reject it as outside this vault's money surface. The borrowed-unlock paragraph then applies to different route sets.

**Disposition:** Q19. No new selector is needed to make this an actual route-behavior choice.

### A10. The preview table describes only exit although the same selector must quote entry

**PRD location:** section 6, `previewExchangeIn` row.

> "Amount-specific executable exit, including maintenance and full unwanted-leg consumption."

The scalar interface and `quoteFacet` also cover deposit. Implementors reading this row alone could omit entry previews or wrongly impose exit's full unwanted-leg consumption on entry. FS-X04 and the accepted interface settle the distinction.

**Disposition:** R20. This is a wording closure, not permission to add another preview or change the return fields. Preview/execution differences allowed by the accepted interface remain allowed.

### A11. Disabled issuance has no identified controlling contract

**PRD location:** FS-A38; section 2 authority table.

> "Disabled inbound issuance still allows a supported exit through a buffered hook route."

> "Its multi-vault manager, administration surface, and treasury performance fee are not inherited."

FS-A38 assumes an issuance-disable state. The PRD does not identify its source, authorized writer, or which entry routes it disables. Weir's administrative pause is not automatically inherited. A local pause bit, a shared oracle/registry flag, and no disable support produce different behavior.

**Disposition:** Q21. Do not add a setter or copy Weir administration to satisfy an acceptance row.

### A12. ERC-20 share decimal metadata is not selected

**PRD location:** FS-FACET-01 ERC-20 row; FS-PKG-02 initialization paragraph.

> "The nine canonical ERC-20 and metadata selectors."

> "Initialization installs the name, symbol, pool key, and full-range ticks."

The share uses liquidity-unit issuance and an unscaled `1_000` floor, but neither sentence selects the value returned by `decimals()`. Keeping a shared facet fixes its implementation, not necessarily its initialized metadata. Weir has an internal share ledger rather than this ERC-20 metadata contract. Different decimals change the externally represented share unit even with identical raw mint arithmetic.

**Disposition:** Q22. Do not infer a decimal count from the withdrawn one-whole-share rate or rescale `MIN_SHARES`.

### A13. Unsupported token behavior in the custom Basic Vault query

**PRD location:** FS-OWN-07.

> "`reserveOfToken(address)` returns that same sum for one token."

The two underlying-token sums are specified, but the result for an address outside `vaultTokens()` is not. Returning zero and reverting are observably different public query behavior. The shared reserve implementation is explicitly not installed, so its implementation cannot silently become the authority for the custom function. Weir has no matching public query to settle this.

**Disposition:** Q23. This asks for behavior of an existing selector, not another selector.

# Questions for the owner

These are the unresolved decisions, each attached to the gap above. Answering them should produce explicit requirements rather than permission for the implementor to select an option.

1. **Q1 / M1:** What ERC-20 balance and mint-event representation must implement the permanently unredeemable `1_000` units already required in total supply?
2. **Q3a / M3:** At which operation boundaries must each token's sleeve target be recomputed and refilled, including its integer-rounding rule?
3. **Q3b / M3:** If an operation cannot leave a token's sleeve at its target, must it revert or may it finish below target?
4. **Q3c / M3:** May an ordinary `exchangeIn` call received while PoolManager is locked spend sleeve backing without opening an unlock?
5. **Q4 / M4:** Must `PkgInit.poolManager` remain the authoritative manager binding copied into the diamond's Protocol Aware Repo during initialization, or what existing authority must supply that value instead?
6. **Q5 / M5:** Which repository or immutable binding must be the authoritative runtime source for `PkgInit.wrappedNative`?
7. **Q6 / M6:** Is raw-ETH user entry or payout required in this revision beyond native PoolManager settlement, despite the accepted public routes being nonpayable and wrapper-facing?
8. **Q11 / A1:** Do local reserves and the sleeve-owned-amount calculation include unbooked transfers, pretransfer surplus, and in-flight reserved input, or only accounted vault backing?
9. **Q12 / A2:** Which of `reserves`, `reserveOfToken`, `localReserves`, `positionLiquidity`, and the accepted previews must reject while the vault's operation guard is held?
10. **Q13 / A3:** Which protocol components besides PoolManager must this package initialize and expose through the Protocol Aware standard, and what is the authoritative binding for each?
11. **Q14 / A4:** How must the fixed package input contract bind both the shared `MultiAssetBasicVaultFacet` address and the custom reserve-facet address?
12. **Q15 / A5:** What exact additional pool-key conditions does "outside the inherited domain" mean after the stated initialized-manager and hookless checks?
13. **Q16 / A6:** Which existing fee policy, if any, is authorized to deduct value on this family's supported money routes?
14. **Q17a / A7:** Must `donate` only book local backing, or must the call also deploy or rebalance that backing?
15. **Q17b / A7:** Must `donate` accept funds before the first successful share deposit?
16. **Q18 / A8:** Must an imbalanced bundle deposit run Weir's balancing swap, or add liquidity without that swap and return the unused declarations?
17. **Q19 / A9:** Does this family's canonical `exchangeIn` support underlying-to-underlying swaps, or only underlying-to-share entry and share-to-underlying exit?
18. **Q21 / A11:** What existing authoritative state and writer govern the "disabled inbound issuance" condition in FS-A38?
19. **Q22 / A12:** What value must the share's existing `decimals()` selector return?
20. **Q23 / A13:** Must `reserveOfToken` return zero or revert for an address not in `vaultTokens()`?

Q3a-Q3c must be reconciled with Weir compounding before finalizing the adaptation: an answer that protects a sleeve cannot silently feed that protected balance into the source's unrestricted idle reinvestment. Q11 must also determine which balance is eligible to enter that idle accounting. These are consequences of the questions, not additional proposed policies.

# Recommendations that close a gap

The following is exact replacement prose. None selects a new cap, fee, holder, return field, or selector.

## R2. Separate entry refunds from generated currency credit

**Replace the entry remainder wording in FS-MONEY-01, and remove its misleading repetition inside the withdrawal bullet, with:**

> On entry, return unused declared input to the payer in its declared currency. Set each accepted refund return only to unused declared input in that return's input currency. Separately settle every positive net currency credit to the payer in the currency that produced that credit, as in Weir `_deposit`; a credit in the other underlying is not converted, retained as backing, or encoded in `amountRefunded`. Share output goes to `recipient`. The two scalar return values do not report an other-currency credit, and no return field or replacement view is added. This entry-credit rule does not permit an unselected-token payout on withdrawal.

**Authority:** FS-X04; FS-MONEY-01 settlement rule; section 2.1 Entry remainder; FS-OWN-08 and the accepted report's Refund rule; Weir `_deposit` lines 281-285 and `deposit` lines 181-183.

This does not claim that the generic Standard Exchange standard automatically defines every possible side credit. It makes this family's expressly retained Weir settlement rule explicit without changing the accepted ABI or treating another token as input-denominated refund.

## R6. State the already-decided native boundary

**Replace FS-A10's "inherited wrapper boundary" wording with:**

> Native-currency pools remain supported. The accepted Standard Exchange entry, exit, and bundle routes are nonpayable, use the ERC-20 faces in `vaultTokens()`, and reject `address(0)` as a route token. Native ETH movement needed for PoolManager settlement remains internal to those routes. These routes do not establish a raw-ETH user entry or payout surface.

**Authority:** FS-OWN-09 and FS-OWN-10; accepted interface report Refund rule; accepted paired report Raw ETH; FS-A35.

This closes the route-boundary wording only. Q6 must determine whether the contradictory raw-user capability sentence is a future decision or a current requirement needing separate authorization.

## R7. Close the named query-function review without inventing package inputs

**Replace "Still under function review" in FS-FACET-01 with:**

> The named function-inclusion decisions are closed by FS-OWN-01 through FS-OWN-10: retain `localReserves()`, `tickLower()`, `tickUpper()`, and `positionLiquidity()` with their locked meanings; expose `poolManager()` through the Protocol Aware standard and pool-key information through the reusable Position Repo surface, not through family-only replacements. Do not install `rateAsset`, `getRate`, `basket`, `wrappedNative`, `previewWithdrawalMode`, `previewZapCredit`, `maxZapBps`, or `maxZapTickMove`. Package binding and initialization must separately satisfy the Protocol Aware and Position Repo requirements.

**Authority:** FS-OWN-01 through FS-OWN-10 and the complete function-review file.

**Replace the unqualified `poolManager()`-absence phrase in FS-A01 with:**

> No family-only `poolManager()` or family-only `poolKey()` implementation is installed; the Protocol Aware and reusable position surfaces required by FS-OWN-01 and FS-OWN-02 are not prohibited by this assertion.

The current acceptance row says `poolManager()` is absent, whereas the lock relocates it. The lock closes that conflict. This correction does not choose unapproved getters for other protocol components.

## R8. Replace the obsolete reserve-summary deferral

**Replace "Its other semantics are not specified" in the section 1.2 FS-OWN-07 row with:**

> `reserves()` and `reserveOfToken(address)` return local backing plus this position's current token amounts and uncollected fees, as specified in FS-OWN-07; `reserves()` follows `vaultTokens()` order. Reuse `vaultTokens()` from `MultiAssetBasicVaultFacet`, and map only the two reserve selectors to the custom facet.

**Authority:** detailed FS-OWN-07 and Function decisions, Custom Basic Vault reserves.

This is not a claim that A1, A2, or A13 has been answered.

## R9. Make rate exclusion current, not an implementor choice

**Replace the final two sentences of FS-OWN-03 with:**

> This revision has no rate policy to implement: `rateAsset`, `getRate`, and substitute rate denominations are absent. A hook dependency that requires such a policy remains an unresolved FS-HOOK-04 integration record unless a later owner decision changes this requirement.

**Authority:** FS-OWN-03, FS-OWN-05, FS-RATE-01, and FS-A29.

## R10. Make one-token idle conversion explicit

**Replace the first three sentences of the FS-MONEY-01 withdrawal bullet with:**

> After the required preceding compound, calculate the withdrawn liquidity and each idle entitlement using the separate pro-rata integer divisions in Weir `_withdraw`. Include both idle entitlements in the currency totals before any exit conversion. For a one-token `exchangeIn` exit, convert the entire unwanted-currency entitlement, including its idle portion, into the selected output currency; if any unwanted-currency entitlement remains, revert the whole call without burning shares or paying either currency. For the mapped paired `exchangeBundleOut` exit, pay the two proportional currency entitlements without selling one leg into the other. The selected output of the accepted Standard Exchange route determines this behavior; do not add a public `zapTo` parameter or install a Weir withdrawal selector.

**Authority:** Weir `_withdraw` lines 289-320; FS-MONEY-01; section 6 executable-exit row; FS-OWN-09; FS-A08 and FS-A11.

The source's residual two-currency settlement is deliberately subordinate to the already-locked selected-output-only requirement. The definition of sleeve backing eligible for the idle calculation remains Q3/Q11.

## R12. Remove stale idle-reserve snapshots

**Replace "An idle vault answers while the manager is unlocked. Basic reserves return the last committed snapshot" in FS-A32 with:**

> An idle vault answers the specified economic views while the manager is unlocked. Its Basic Vault reserve views use the local-plus-deployed amounts defined in FS-OWN-07, including the current pool price and uncollected fees; a token-amount snapshot from an earlier vault operation is not a substitute.

**Authority:** owner-lock precedence and FS-OWN-07's current-price and unpaid-fee terms.

This leaves the preceding busy-view sentence subject to Q12 rather than inventing an exception list or snapshot-update procedure.

## R20. Cover both scalar-preview directions

**Replace the section 6 `previewExchangeIn` Meaning cell with:**

> Amount-specific entry or exit for the supported route, returning `(amountOut, amountRefunded)` under FS-OWN-08. Entry follows FS-MONEY-01 issuance and unused-input refunds without a full-input-consumption requirement. One-token exit includes the required maintenance, pro-rata idle, and full unwanted-leg conversion or reversion; it does not return an unselected output token.

**Authority:** FS-OWN-08; FS-X04; FS-MONEY-01; FS-A07, FS-A08, and FS-A11; accepted interface report.

## Related already-closed text, not additional owner questions

- **FS-ARCH-01 still lists "SY money, SY query".** Those are stale file-list entries, not permission to install SY. Exact replacement for that list item: "Create facet and target files for the retained money, quote, out, query, and callback surfaces; do not create or install SY money or SY query surfaces for this family." Authority: FS-OWN-05 and FS-FACET-01. No new product choice exists.
- **FS-OWN-02 says "`PkgArgs` may still carry the pool key used at initialization."** FS-PKG-01 already explicitly lists `PoolKey poolKey`. Exact replacement: "`PkgArgs.poolKey` supplies the initialization pool key, which is stored through the reusable Position Repo." Authority: FS-PKG-01 and FS-OWN-02. No owner question is needed about whether this listed argument exists.
- **Compound before money operations is not optional.** Exact clarifying sentence for FS-MONEY-01: "Execute the Weir-adapted compound before the deposit or withdrawal calculation on both locked and borrowed execution paths; the absence of `previewWithdrawalMode` does not authorize a collection-only fallback." Authority: Weir `unlockCallback` lines 229-235; FS-A11 and FS-A33. This does not choose the unsettled sleeve policy.
- **Hook failures and gas ceilings are not blanket waivers.** FS-HOOK-04 expressly says a cited reject does not close FS-HOOK-02; FS-A31 treats an oversized route as unresolved. There is no implementor option to report either as a canonical passing proof.
- **File naming, renamed paired events, later selector recounting, and a later hook-record procedure are not independent gaps merely because work remains.** They become behavior questions only if their resulting ABI or binding conflicts with a lock. The specific conflicting manager-absence assertion and incomplete package bindings are identified above.

# Limits

This is an independent research contribution, not a code-review defect report, PRD amendment, implementation plan approval, or authorization to implement. Existing owner locks take precedence over the alternatives used to explain ambiguity.

The PRD and function-review file were read completely; the two accepted interface/mapping reports were also read completely. Weir inspection was restricted to the relevant money-function region and adjacent context needed to understand those functions. I did not audit the remaining source, the shared Basic Vault implementation, the fee oracle implementation, hook packages, or prospective new repositories. In particular, I do not assert a particular shared-facet decimal default, unsupported-token error, fee policy, or component-binding mechanism.

The files were live local reads, not an atomic repository snapshot. No peer response was read. No delegation, Forge, Git, install, deployment, wallet action, project test, or production-file edit was performed. The only authored file is this assigned `members/astra/response.md`.

All ten minimum-inventory items are addressed. Additional gaps found in the complete PRD are included, with existing locks used to close stale or misleading text rather than handing those choices back to the owner. The unresolved questions remain unresolved; this response does not answer them on the owner's behalf.
