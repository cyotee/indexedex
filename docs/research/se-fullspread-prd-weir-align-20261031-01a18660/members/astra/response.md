# Identity

Astra, independent council member, research profile. Run: `se-fullspread-prd-weir-align-20261031-01a18660`. Requested route: `chatgpt-subscription/gpt-6-astra:high`; provider internals are not independently attested here. This is an initial authoring contribution, not a peer review, a coordinator decision, or implementation authorization.

# Question and targets

Replace unauthorized PairToken economics with source-grounded Weir behavior under the already locked one-share, one-pool, one-full-range-position Standard Exchange design. Preserve FS-OWN-01 through FS-OWN-10, including the accepted routes, refund return, liquidity sleeve, custom reserve views, and explicit `donate` exception. Remove the named zap fields and view without substituting a new guard.

I read the complete brief and all four required targets:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, revision `fullspread-se-prd-final-r2` with subsequent owner locks.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`.
- `docs/research/se-weir-adaptation-fidelity-20261031-01a18660/REPORT.md`, revision `se-weir-adaptation-fidelity-20261031-01a18660-final`.
- `contracts/protocols/strategy/weir/WeirVaults.sol`, including public `deposit`, `withdraw`, and `compound`, their callback dispatch, and all internal money functions.

I also read `contracts/protocols/strategy/weir/base/WeirBase.sol` to verify settlement and refund helpers. References below use repository paths and function names. These are live-file observations, not an atomic repository snapshot.

# Evidence

## Source observations: deposits and settlement

`WeirVaults.deposit` pulls the declared amounts, receives `(shares, used0, used1)` from the callback, checks the share minimum, credits the recipient, and refunds the payer:

```solidity
sharesOf[id][p.recipient] += shares;
_send(p.key.currency0, msg.sender, p.amount0 - used0);
_send(p.key.currency1, msg.sender, p.amount1 - used1);
```

The share recipient and refund payer are distinct roles. `WeirVaults._deposit` computes `used0` and `used1` from the negative parts of the accumulated net deltas. It calls `_settle` with `depositor` as the credit recipient. Therefore the refund account is not simply the amounts remaining after `_balance`: the swap and liquidity deltas are accumulated first; positive manager credits and unused declared funds are returned through their respective paths.

`WeirVaults._balance` uses the delta actually returned by `_swap`:

```solidity
net0 = s.amount0();
net1 = s.amount1();
n0 = uint256(int256(a0) + net0);
n1 = uint256(int256(a1) + net1);
```

`WeirVaults._swap` returns `poolManager.swap(...)` directly. It sets an exact-input amount and the directional extreme sqrt-price limit. Neither `_swap` nor `_balance` checks consumed input for equality with the specified input. `WeirBase._settle` pays a negative net through `_pay` and takes a positive net through `_take`. A partial swap is not itself the `IncompleteConversion` failure described by the current full-spread PRD. This does not mean every partial swap must succeed: later liquidity, share, minimum, arithmetic, or settlement conditions still apply.

## Source observations: issuance and genesis

In `WeirVaults._deposit`, added liquidity is calculated from post-balance amounts using `LiquidityAmounts.getLiquidityForAmounts`, the current price, the stored ticks, and the exact per-currency adjustment `amount > 2 ? amount - 2 : 0`. The share branch is:

```solidity
if (v.totalShares == 0) {
    if (frame.liq <= MIN_SHARES) revert ZeroShares();
    frame.shares = frame.liq - MIN_SHARES;
    v.totalShares = MIN_SHARES; // never redeemable: blocks share-price inflation
} else {
    frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity;
}
if (frame.shares == 0) revert ZeroShares();
```

`MIN_SHARES` is `1_000`. `_deposit` subsequently adds `frame.liq` to `v.liquidity` and `frame.shares` to `v.totalShares`.

The non-genesis denominator is deployed liquidity, not idle, not token-valued NAV, and not attributable removable-principal growth `G_i`. The source supplies no alternative issuance denominator incorporating `idle0`, `idle1`, an oracle-targeted local sleeve, or a direct donation. `_compound` can convert existing idle into liquidity before this branch; any resulting liquidity is then already in `v.liquidity`. That does not make idle itself a denominator term.

The source has a genesis case and a permanent unredeemable minimum in its internal share ledger. It does not show how to represent that internal floor in this new ERC-20 diamond. A chosen burn address, decimals conversion, or alternate genesis formula would be an adaptation decision, not a source quotation.

## Source observations: withdrawals and compound

`WeirVaults.unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`. The standalone `compound` route dispatches to that same `_compound`.

`WeirVaults._compound` harvests by `modifyLiquidity` with zero liquidity delta, applies its source performance-fee calculation, combines the remaining fees with tracked idle, attempts to add liquidity, updates idle from the resulting net, and settles both currencies to `address(this)`. It does not call `_balance` or `_swap` and does not change `v.totalShares`. It can leave idle when no additional liquidity fits. It has no PairToken ratio swap, quarter-cap, or withdrawal-only collection fallback.

The source does charge a treasury performance fee: `perfFeeBps` starts at `500`, is bounded by `MAX_PERF_FEE_BPS = 1_000`, and `_compound` uses it on harvested fees. Those are observations about Weir, not authorization to add that fee, treasury, administrator, or configuration to the new family. Likewise, deleting that source fee from a description cannot justify importing PairToken's no-fee policy.

`WeirVaults._withdraw` allocates deployed liquidity and each tracked idle balance proportionally to the requested shares, removes liquidity, pays the allocated idle into the manager, optionally swaps one leg, and settles both resulting currency deltas. It returns both positive outputs. There is no full-consumption check on the withdrawal swap either. Consequently the accepted full-spread single-token exit is an explicit route constraint: the chosen token only, or atomic revert. It is not a claim that Weir's two-output settlement already enforces that constraint.

## Source observations: donation and authority

`WeirVaults` has no `donate` function. `_deposit` uses declared amounts and returned deltas; `_compound` uses harvested fees and tracked idle; `_withdraw` uses recorded liquidity and idle. None of those functions reconciles an arbitrary token transfer into a recorded donation. FS-OWN-09 nevertheless keeps `donate(token, amount)` as an explicit exception that books the declared donation and mints no shares. That lock is not authority to retain involuntary entry-remainder donations or PairToken issuance.

The function-review document locks the Weir-adaptation basis. Its older zap entries still say "Open," but the present brief expressly supersedes them. The fidelity report identifies the same economic substitutions, including the easily missed withdrawal fallback. This contribution does not treat that report's possible guard proposals as owner decisions.

# Proposed PRD replacements

Each fenced Markdown block below is replacement text, labeled by its destination. Apply only to the specified paragraph, row, or span. All unmentioned FS-OWN provisions, hook bindings, compiler requirements, and locked facet wiring remain intact. These replacements are not a duplicate PRD.

## PRD section 1, Goal: replace the two paragraphs beginning "This is not WeirVaults" and "It is a sibling"

```markdown
This family adapts the money operations of `contracts/protocols/strategy/weir/WeirVaults.sol` to the tokenized Standard Exchange standard. It has one ERC-20 share, one pool, and one full-range position. It does not copy Weir's manager of multiple virtual vaults or its separate per-pool share ledger.

It is not a sibling of PairToken and does not inherit PairToken economics by requirement ID. The owner locks in FS-OWN-01 through FS-OWN-10 govern the tokenized adaptation. Weir source behavior and explicit adaptation differences are stated below; a PairToken economic or package choice requires its own owner authorization.
```

## PRD section 1.1: replace its first bullet only

```markdown
- Not a source copy of Weir's multi-vault manager or a mechanical ERC-20 wrapper around its internal share ledger. The adapted money-operation source is `WeirVaults`; the one-share architecture and owner locks govern the differences.
```

## PRD section 1.2: replace FS-X04

```markdown
| FS-X04 | Entry settles the swap and liquidity deltas actually returned, as in `contracts/protocols/strategy/weir/WeirVaults.sol::_balance`, `_swap`, and `_deposit`. There is no selected-swap consumption-equality check and no entry `IncompleteConversion` requirement. `deposit` refunds unused declared input to the payer; `_deposit` also settles positive net credits to that payer. Do not book addition remainder as shared backing without extra shares. Issuance follows the source rule described in FS-MONEY-01, not S1-ACC-07. This entry rule does not weaken the accepted single-token exit: that route pays only the selected token or reverts. |
```

## PRD section 1.3: replace only FS-OWN-10's final open-zap sentence

```markdown
`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent from this family's public surface; `maxZapBps` and `maxZapTickMove` are also absent from `PkgArgs`. No replacement cap, tick guard, hidden constant, or replacement zap-credit view is specified by this decision.
```

## PRD section 1.3: append after the FS-OWN-10 paragraph

```markdown
**Weir-alignment clarification of FS-OWN-09.** `donate` remains the explicitly locked exception: it books the declared donation and mints no shares. It is not a Weir function; `contracts/protocols/strategy/weir/WeirVaults.sol` does not book a direct transfer as a donation. Keeping `donate` does not authorize booking unused entry funds as a donation. `compound` remains harvest-and-reinvest, following `WeirVaults._compound`, not a PairToken ratio swap or quarter-cap operation. The Weir source's treasury performance fee is not imported by this clarification, and a PairToken no-fee rule is not inherited.
```

This clarifies the existing lock rather than replacing its accepted route mappings, events, or raw-ETH limitation.

## PRD section 2, Authority and precedence: replace the table and inheritance paragraphs through the blanket S1 inheritance list

Stop this replacement before the paragraph beginning "Do not install `IStandardExchangeTransitionQuote`".

```markdown
| Source | Role |
| --- | --- |
| FS-OWN-01 through FS-OWN-10 and the owner-locked Weir-adaptation basis | Controlling authority for this family's shape, routes, returns, reserves, selectors, and explicitly retained exceptions. |
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Money-operation source: actual-delta entry settlement and payer refunds (`deposit`, `_deposit`, `_balance`, `_swap`); liquidity-based issuance and genesis (`_deposit`); pre-deposit and pre-withdrawal harvest-and-reinvest (`unlockCallback`, `_compound`); proportional liquidity and idle withdrawal (`_withdraw`). Source behavior is not blanket adoption of Weir's manager, administration, native API, or performance fee. |
| This PRD's explicit family requirements | Tokenized Standard Exchange adaptation, including the accepted single-token exit and borrowed `exchangeIn` path. An unresolved adaptation is not filled by importing PairToken behavior. |
| `contracts/hooks/uniswap/v4/standardExchange/` | Current hook bindings. Do not redesign them here. |
| `CLAUDE.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `.github/ASSISTANT_CODING.md`, `.github/ASSISTANT_TESTS.md` | Registry, token, compiler, and test law. |
| Crane architecture, IndexedEx testing, and Uniswap V4 hook-package skills | Packaging and production-first tests. |

PairToken stage one is not an economics authority for this family. There is no blanket inheritance of its S1 requirements or acceptance rows. References to current PairToken files for an implementation pattern, fixture, or selector comparison do not authorize its issuance, remainder booking, zap fields, fee attribution, maintenance fallback, or package arguments.

FS-OWN-01 through FS-OWN-10 override conflicting text throughout this PRD. FS-X01 and FS-UNLOCK-01 through FS-UNLOCK-03 specify this family's manager-context behavior directly: canonical `exchangeIn` supports the borrowed path; `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` reject that path with `ManagerAlreadyUnlocked`. Paired-named selectors and SY mutators remain absent.

No ERC-4626, transition quote, external-state quote, or silent `IStandardExchangeRateQuote` is authorized. ERC-5115 and its facets are absent under FS-OWN-05. `getRate` and `rateAsset` are absent under FS-OWN-03; this update supplies no replacement denomination or rate policy.
```

## PRD section 2.1: replace the two obsolete disposition rows

```markdown
| Supply below `1e18` | The former rate-supply requirement is withdrawn with `getRate`. Issuance genesis is described separately in FS-MONEY-01. | Retaining `InsufficientRateSupply` or using a withdrawn rate threshold as an issuance rule. |
| Entry remainder | Settle actual returned deltas and return unused declared input and positive net credits to the payer, following `WeirVaults.deposit` and `_deposit`. | Shared-backing booking of `J_i`, S1-ACC-07 credit, or selected-swap consumption equality. |
```

## PRD section 3, FS-FACET-01: replace its opening paragraph

```markdown
The facet inputs are the explicit family roles listed below, subject to the owner-locked wiring and the unresolved package-binding questions already recorded in FS-PKG-01. PairToken's facet count or order is not an independent authority for this package. `PkgInit` is not an open `IFacet[]`. Do not pass a PairToken family facet address into this package. Preserve FS-OWN-07: `vaultTokens` is supplied by `MultiAssetBasicVaultFacet`, while the family custom facet supplies only `reserveOfToken` and `reserves`. FS-OWN-05 removes `syMoneyFacet` and `syQueryFacet`. Package validation must not require or install `getRate`. FS-OWN-03 forbids it.
```

Replace the `quoteFacet` row only:

```markdown
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. Do not install `previewZapCredit`, `previewWithdrawalMode`, or the paired-named previews. |
```

Replace the sentence "Cite the current package `_expectedSelectors` and S1-ARCH-04 when implementing" with:

```markdown
Derive and verify the selector manifest from this family's accepted interfaces, explicit package requirements, and owner-locked facet wiring. A comparison with another package's `_expectedSelectors` is not authority to import its selectors or economics.
```

Replace the "New errors" introduction and list, stopping before the paragraph about withdrawn rate errors:

```markdown
Family-context errors include:

- `InvalidUnlockedContext()`
- `SettlementMismatch()` for the expressly specified settlement failures

Do not declare `IncompleteConversion` for entry consumption equality. Its removal is not permission to weaken the selected-token-only exit constraint. No replacement exit error signature is selected by this update.
```

## PRD section 4, FS-ARCH-01: replace only the sentence introducing the production-file list

```markdown
The production-file list below describes this family's code organization, not inheritance of PairToken economics, storage accounting, or package inputs.
```

In that list, replace only the final facet/target bullet:

```markdown
- one facet and one target file for money, quote, out, query, and callback. The target filename is `UniswapV4FullSpreadStandardExchangeVaultMoneyTarget.sol` and the same pattern for the others. Do not use a shortened literal `MoneyTarget.sol`. SY money and SY query are absent under FS-OWN-05.
```

This is a correction to a stale contradiction of an existing lock, not new facet wiring.

## PRD section 4, FS-PKG-01: replace the `PkgArgs` introduction and its five bullets

```markdown
`PkgArgs` contains the following family inputs:

- `PoolKey poolKey`, stored through the Position Repo in FS-OWN-02, not as proof that `poolKey()` is a family-only selector
- `string name`
- `string symbol`

There is no `rateAsset`, `maxZapBps`, or `maxZapTickMove` argument. Their absence does not install a default cap, hidden cap, tick guard, or hook allowlist. PairToken's argument set is not inherited.
```

Keep the already stated `PkgInit` infrastructure and linked-library bindings as the current explicit proposal, not as a newly authorized lock. The `poolManager`/aware-facet question already recorded there stays unresolved. Do not silently replace the six-library list or redesign its wiring during this money-rule update.

## PRD section 4, FS-PKG-02: replace the pool-key validation bullet and remove the zap-limits bullet

Replacement pool-key bullet:

```markdown
- A pool key that is not initialized on the bound manager, has a nonzero hook, or violates the explicit family or repository token-domain requirements. `InvalidPoolKey`. PairToken's domain is not imported by reference.
```

Delete the complete bullet beginning "Zap limits that are not a positive in-range fee bound". It has no replacement. `InvalidZapLimits` is not a family requirement.

Replace the final initialization paragraph:

```markdown
Initialization installs the family's explicit metadata, pool key, and full-range ticks. It does not store a designated rate token or either removed zap field. The PoolManager binding comes from the Protocol Aware pair in FS-OWN-01, not from a family `poolManager()` selector. The first deposit creates the position. `WeirVaults._deposit` has a genesis minimum-share floor; the previous blanket assertion of no permanent share floor is removed. FS-MONEY-01 records the exact source branch and the unresolved ERC-20 representation. This update does not import Weir's treasury performance fee or establish an inherited PairToken no-fee policy.
```

## PRD section 5: replace all of FS-MONEY-01, stopping before FS-UNLOCK-01

```markdown
### FS-MONEY-01 — Weir-adapted money operations

The public routes and returns are those accepted in FS-OWN-08 and FS-OWN-09. `previewExchangeIn` and `exchangeIn` keep their current parameters and return `(amountOut, amountRefunded)`; there is no `WithRefund` sibling. The paired deposit and proportional paired redemption use the accepted bundle routes. Do not install the paired-named methods, their previews, ERC-5115, `getRate`, or `rateAsset`.

**Entry and payer refunds.** Follow `contracts/protocols/strategy/weir/WeirVaults.sol::deposit`, `_deposit`, `_balance`, and `_swap`: account for the swap deltas actually returned, add the liquidity-operation deltas, derive used declared input from negative net deltas, settle positive net credits to the payer, and return unused declared input to the payer. The share recipient is not necessarily that payer. There is no entry requirement that the selected swap consume its entire specified input. Remove `IncompleteConversion` preflight and execution equality checks. A partial swap remains subject to the actual share, minimum, arithmetic, and settlement conditions; it is not guaranteed to succeed. Do not book the entrant's unused addition amounts as shared backing without extra shares.

**Issuance.** The source rule is `WeirVaults._deposit`, not S1-ACC-02 or S1-ACC-07. The function computes added liquidity from the current price, stored ticks, and post-balance amounts using `LiquidityAmounts.getLiquidityForAmounts`; each amount supplied to that calculation is adjusted exactly as `amount > 2 ? amount - 2 : 0`. For an existing share supply, the source assignment is:

    frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity;

Here `frame.liq` is the deposit's added liquidity, and the denominator and existing share count are taken after the preceding compound and before this deposit's liquidity and shares are added. Idle balances are not a term in that denominator. Do not substitute whole-book value, a price-weighted sleeve, `G_i`, `J_i`, or another unstated formula.

The source also has a genesis case. `MIN_SHARES` is `1_000`. With `v.totalShares == 0`, `_deposit` rejects `frame.liq <= MIN_SHARES`, assigns `frame.shares = frame.liq - MIN_SHARES`, and sets `v.totalShares = MIN_SHARES` before adding the recipient's shares. That initial minimum is never redeemable. It rejects zero issued shares. The source uses an internal ledger, not this family's ERC-20 supply: this PRD does not invent the tokenized representation of the permanent floor, a different seed constant, or a decimal-conversion rule.

The source contains no alternate issuance formula for this family's oracle-targeted local sleeve or explicit donation route. FS-OWN-04, FS-OWN-07, and FS-OWN-09 remain locked. Their unresolved interactions with source issuance must be specified explicitly; neither PairToken accounting nor an invented idle-inclusive denominator closes them.

**Maintenance and compound.** `WeirVaults.unlockCallback` invokes `_compound` before both `_deposit` and `_withdraw`; standalone `compound` dispatches to `_compound` as well. Use that harvest-and-reinvest sequence. `_compound` harvests through a zero-liquidity modification, attempts to reinvest harvested fees and tracked idle in the same position, and retains the amount that cannot be added as tracked idle. It neither performs a ratio swap nor changes share supply. Do not inherit PairToken's quarter-cap, compound swap, or withdrawal-only collect-or-compound fallback.

Weir's `_compound` also contains a treasury performance fee. That fact is source attribution, not authorization to add its fee module here. This update does not add a performance fee, select a fee rate, or adopt PairToken's no-fee policy.

**Withdrawals.** `WeirVaults._withdraw` proportionally allocates deployed liquidity and tracked idle, removes the allocated liquidity, and settles the resulting currencies. The accepted bundle redemption retains its proportional two-currency route under FS-OWN-09. The accepted single-token exit instead pays only the selected token or reverts atomically; no unwanted allocation is retained for remaining holders. This route constraint is not `IncompleteConversion` and is not a claim that Weir's optional two-output zap already enforces a one-token result.

**Donation exception.** Keep the explicitly authorized `donate(token, amount)`: book the declared donation and mint no shares. It is not a Weir operation. A direct transfer is not booked as a donation by `WeirVaults.deposit`, `_deposit`, `_compound`, or `_withdraw`. This exception does not authorize treating entry refunds as donations.

**Native boundary.** Preserve the ERC-20 faces and stable `vaultTokens()` ordering in FS-OWN-09 and FS-OWN-10. A native pool currency remains distinct from its ERC-20 face. Raw-ETH public entry and payout are not decided by those locks; do not import PairToken's raw-ETH routes or add an extension here.

The 12,000,000 gas transaction ceiling and the 5,000,000 preview ceiling remain explicit family requirements. A hook-composed transaction must fit the transaction ceiling or be recorded as an unresolved narrowed route. It is not a passing measurement or a waiver.
```

## PRD section 5, FS-UNLOCK-02 and FS-UNLOCK-03: remove authority-by-inheritance wording only

In FS-UNLOCK-02 item 2, replace its final sentence:

```markdown
Otherwise, a failed funding or route check uses the error defined by the accepted family route, and a borrowed-path context miss uses `InvalidUnlockedContext`.
```

In FS-UNLOCK-03, replace only the first sentence:

```markdown
Ordinary entry uses the per-action dispatcher specified here.
```

The rest of these sections is outside the economic rewrite. In particular, this contribution does not add a guard, change callback commitments, or rewrite native borrowed settlement.

## PRD section 6: replace the issuance table's first and third rows

```markdown
| Issuance and accepted entry previews | FS-MONEY-01's Weir-source liquidity issuance, including the source genesis case and payer refunds. `previewZapCredit` is absent. | S1-ACC-07, uncredited shared-backing remainder, an idle-inclusive formula not stated by the source, `exchangeRate`, or `getRate`. |
| `previewExchangeIn` | Quote the selected accepted entry or exit route, its maintenance, and its `(amountOut, amountRefunded)` return. For a single-token exit, quote an executable selected-token-only result or the route's rejection. | Whole-book value divided by supply, Weir's pre-fee `previewRedeem` as a complete executable quote, or an entry consumption-equality rule. |
```

The distinction from `WeirVaults.previewRedeem` is source-observed: that function expressly previews before pending fees and returns two currency amounts. No new preview function or formula is proposed.

## PRD section 8, FS-TEST-01: replace the bootstrap paragraph's first sentence

```markdown
Bootstrap shares only through the accepted public bundle entry, `exchangeBundleInForSingleOut`, with the share as `tokenOut`; do not use the dropped `depositPair` selector.
```

Retain the production-first funding and no-SUT-mock requirements.

## PRD section 8, FS-TEST-02: replace the entire inherited-row paragraph and its four bullets

```markdown
There is no blanket inheritance of S1-A01 through S1-A70. This family's acceptance rows and owner locks are the test authority. A reused test pattern must name the explicit family requirement it proves; it must not carry forward PairToken issuance, fee attribution, remainder booking, zap limits, entry consumption equality, or withdrawal fallback. The current family selector manifest is authoritative, and `getRate` is absent. FS-A19 through FS-A23 cover borrowed entry and the methods that still reject an already-unlocked manager. FS-A31 preserves the explicit transaction and preview gas ceilings.
```

## PRD section 8, FS-TEST-03: replace the following individual acceptance rows

```markdown
| FS-A01 | Package inputs follow FS-FACET-01. ERC-165, ERC-8109, loupe, and the cited temporary-hook facet are absent from cuts and still callable on the factory-built proxy where the factory installs them. The reviewed selector manifest succeeds through the proxy. Family `poolManager()`, family-only `poolKey()`, `rateAsset()`, `getRate()`, `basket()`, `previewWithdrawalMode`, `wrappedNative()`, `previewZapCredit`, `maxZapBps`, `maxZapTickMove`, paired-named money/previews, and every Standardized Yield selector are absent. Preserve the owner-locked aware, Position Repo, and Basic Vault wiring. Factory selectors stay disjoint. |
| FS-A03 | Invalid component, explicit family pool domain, wrapper, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no `rateAsset`, `maxZapBps`, or `maxZapTickMove` argument and no `InvalidZapLimits` acceptance case. |
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Verify FS-MONEY-01 against `WeirVaults._deposit`: liquidity at or below the source `MIN_SHARES` is rejected; the source genesis branch reserves the permanent minimum and credits only the remainder. The ERC-20 representation of that floor requires an explicit specification before its implementation test can pass. Do not assert no share floor or an inherited no-performance-fee policy. |
| FS-A06 | Accepted bundle entry uses FS-MONEY-01 liquidity-based issuance and refunds unused declared amounts to the payer, including when payer and share recipient differ. Existing-supply issuance uses the source `_deposit` denominator, not idle or S1-ACC-07. Bundle redemption follows the accepted proportional two-currency route and `WeirVaults._withdraw` liquidity/idle allocation. No paired-named selector is installed. |
| FS-A07 | Entry uses returned swap and liquidity deltas. Cover partial selected-input consumption without an equality-based reject, successful issuance where the remaining conditions permit it, and atomic rejection when those conditions fail. Verify actual used amounts, positive net credits, payer refunds, and no shared-backing booking of unused addition funds. No `IncompleteConversion` or `previewZapCredit` assertion survives. |
| FS-A10 | Accepted routes use the ERC-20 faces in stable `vaultTokens()` order, including a wrapper face for a native pool leg. No family `wrappedNative()` getter is installed. Raw-ETH public entry or payout is not a passing requirement without a separate accepted route. Preserve FS-A35's native manager-settlement coverage. |
| FS-A11 | Maintenance follows `WeirVaults.unlockCallback` and `_compound`: harvest-and-reinvest precedes deposit and withdrawal, and standalone compound uses the same operation without changing share supply. Verify retained idle when amounts cannot be reinvested. Do not assert a PairToken ratio swap, quarter-cap, or withdrawal-only fallback. Any fee-policy-dependent expectation requires an explicit family policy rather than copied PairToken or Weir assumptions. |
| FS-A25 | Buffered configuration mints and burns through `exchangeIn` while unlocked. Recipient may be the hook or the hook's unwrap recipient. Position owner, ticks, and salt hold. Assert the actual deltas, payer refunds, and source maintenance order in FS-MONEY-01; S1-ACC-06 is not a fee-attribution authority. Do not require `token == rateAsset`. A package that rejects the bind for lack of a provider is FS-HOOK-04, not a pass. |
| FS-A32 | FS-OWN-07 governs `reserves()` and `reserveOfToken`: local plus the specified deployed amounts and unpaid fees, using the locked facet wiring. This update does not authorize PairToken's blanket economic-read guard or a last-committed-snapshot substitute for that view. Any busy-state policy not settled by the owner locks remains an explicit unresolved adaptation, not an inherited passing assertion. |
| FS-A33 | Borrowed execution uses the same source-grounded harvest-and-reinvest, issuance, refund, and withdrawal rules as locked execution from the same economic state. Neither path imports PairToken's withdrawal fallback or S1-ACC-06 fee attribution. Check each route's accepted return values and per-address settlement constraints. |
| FS-A38 | PairToken's disabled-inbound-issuance policy is not inherited. No disabled-inbound acceptance claim is made until an explicit family policy is authorized. This does not weaken supported exits under the currently accepted routes. |
```

Keep FS-A08 as written: it already correctly separates the selected-token-only exit from entry swap behavior. Keep the other acceptance rows except where another owner lock already supersedes them.

Append these two rows, without renumbering existing IDs:

```markdown
| FS-A39 | The retained `donate(token, amount)` books the explicit donation and mints no shares under FS-OWN-09. Distinguish it from `WeirVaults`, which has no such operation, and from an entry's refundable unused amounts. Do not derive a new issuance denominator from this exception. |
| FS-A40 | Track unresolved source-to-tokenized adaptations explicitly: permanent genesis-floor representation, fee policy, and issuance interaction with the locked local sleeve and donation route. Do not mark a guessed formula, cap, tick guard, or copied PairToken policy as a passing implementation of FS-MONEY-01. |
```

FS-A40 is a specification-completeness gate, not a runtime guard.

## Other PairToken-economics sentences located, by section

The exact replacements above cover more than the named Goal sentence:

- Section 1.3, FS-OWN-04: "overrides the inherited refusal of a local sleeve" is historical framing. Its substantive sleeve lock stays. Replace that sentence alone with `This local-sleeve holding requirement is an explicit owner decision.`
- Section 2: the clause-by-clause S1 precedence rule, S1-ACC inheritance, S1-EXIT inheritance, and partial-fill overrides must all disappear, not merely the authority-table row.
- Section 2.1: the entry-remainder row retained both unauthorized rules; its stale rate-supply row also contradicted FS-OWN-03.
- Section 3: `previewZapCredit`, `IncompleteConversion`, and the inherited settlement-error qualification carried the discarded entry design.
- Section 4, FS-PKG-02: inherited domain/metadata, zap validation, and the paired assertions of no dead-share mint and no performance fee cannot remain as authority for source adaptation.
- Section 5, FS-MONEY-01: `G_i` credit, `J_i` booking, consumption-equality preflight, inherited native public payout, and S1-EXIT-01 fallback each need their own disposition. The explicit gas ceilings need not be removed with those economic rules.
- Section 6: the issuance row imports S1-ACC-02/07 even if the dedicated zap view is deleted.
- Section 8: blanket S1-A inheritance, FS-A05/06/07/11/25/33, and the reserve-snapshot/read-guard and disabled-inbound assertions in FS-A32/38 otherwise preserve unauthorized economics or related policy through tests.

Structural references to PairToken in section 4's filename organization, section 7's actual other-vault integration limitations, and section 8's production fixture example are not themselves economic inheritance. Do not erase those references indiscriminately or rewrite hook bindings. Their use supplies no authorization for package fields or money rules.

# Requires owner authorization

These are unresolved choices or cases, not additional replacement PRD text and not new requirements.

1. **Tokenized representation of the genesis floor.** The source's `MIN_SHARES = 1_000` and liquidity issuance branch are known. It is not known whether the new ERC-20's permanent floor is represented by inaccessible ERC-20 balances or another explicitly reconciled supply mechanism. Do not silently introduce a second share ledger, choose an address, rescale the constant, or restore "no dead-share mint" as if Weir had no floor. The owner should authorize the tokenized representation while preserving the source behavior or explicitly authorize a divergence.

2. **Locked sleeve and donation interaction with issuance.** The local sleeve, its oracle target, the local-plus-deployed reserve views, and `donate` are already locked; they do not need to be reopened. What remains unspecified is how deployment/refill timing and explicitly donated local balances interact with issuance based on deployed liquidity. Weir's ordinary idle exclusion does not state a formula for this separately targeted sleeve. The owner must authorize any proposed deviation from source issuance; this contribution supplies no idle-inclusive, NAV, minimum-ratio, or PairToken formula.

3. **Fees and swap-generated fee attribution.** Weir charges a source treasury performance fee; the brief does not authorize adding it. Nor does it authorize S1-ACC-06 or a PairToken no-fee rule. The family needs an explicit fee decision, including any intended departure from the actual source operation order. Do not hide a fee decision inside `compound`, a test expecting no fee, or a retained authority reference.

4. **Entry bounds, if wanted.** No replacement for `maxZapBps` or `maxZapTickMove` has been authorized. I would require a separate owner decision before adding any size bound or local price/tick bound, whether as a parameter, constant, or check. The source `_swap` extreme price limit is not evidence of a tighter economic safety guard. This is not a proposal to add a guard to this PRD revision; no cap number is selected.

5. **Refund and preview adaptation detail.** The source can return unused declared funds and positive net credits in both currencies to the payer. The accepted `(amountOut, amountRefunded)` ABI stays. Do not force all source settlement effects into a guessed single refund metric, redirect a payer's credit to the share recipient, silently retain a second-currency remainder, or add another return field. The implementation specification must reconcile those actual flows with the already accepted route definitions. A changed ABI or changed entitlement would require owner authorization, not a local inference.

6. **Other copied policy is not automatically retained.** A busy-vault economic-read rejection, snapshot reserve view, inbound-disable mode, raw-ETH public route, or further PairToken package dependency needs an explicit case if it is proposed as new family policy. Existing operation/callback protections and hook settlement requirements are not rewritten here. The source-alignment assignment is not authority to choose a new guard or redesign facets.

The single-token exit, `donate`, and harvest-and-reinvest `compound` do not belong on a fresh vote: they are already required by this assignment and the owner locks. Their source attribution and remaining implementation questions must be stated accurately without reopening them.

# Limits

This contribution supplies exact local replacements, not a full PRD and not an implementation plan. It preserves all ten owner locks and separates source observations, proposed text, and decisions still requiring authorization.

The required PRD, review file, fidelity report, and complete `WeirVaults.sol` were read. `WeirBase.sol` was read narrowly for the settlement/refund functions. No peer response was read. No delegation, Forge, Git, install, deployment, wallet, or external-message operation was performed. No source correctness, compiled behavior, runtime safety, or hook compatibility is claimed from these static reads. PairToken's source and stage-one PRD were not independently audited; the current full-spread PRD's explicit inheritance references are sufficient to identify what this contribution removes.

Only `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/members/astra/response.md` is written. The PRD, function-review file, brief, and peer files are unchanged by this contribution. The coordinator must reconcile these scoped replacements with the current publication base. This research contribution does not authorize implementation.
