# Identity

Kimi, independent council member, research profile. Run: `se-fullspread-prd-weir-align-20261031-01a18660`.

# Question and targets

What exact PRD replacements remove unauthorized PairToken inheritance and state the Weir-adapted money rules without reopening FS-OWN-01 through FS-OWN-10 or inventing a zap guard?

This response covers the Goal, Authority and precedence, FS-X04, FS-OWN-10's open-zap sentence, package inputs and `PkgArgs`, FS-MONEY-01, the issuance table, and every acceptance or blanket test-inheritance row that asserts a removed rule. It also covers the other PairToken-economics sentences in §2.1, §3, §4, and §8 identified below. It does not rewrite hook bindings, compiler law, or locked facet wiring.

# Evidence

- `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`, **Locked basis**, says this vault adapts WeirVaults and that PairToken package inputs and economics are not authorized by inheritance. Its locked paired-money decision keeps `donate` and `compound`; `donate(token, amount)` is an explicit Standard Exchange exception, not a Weir behavior.
- `docs/research/se-weir-adaptation-fidelity-20261031-01a18660/REPORT.md` identifies the current PRD as PairToken stage-one economics and requires Weir-based money rules. It rejects the copied zap fields, `previewZapCredit`, entrant-remainder booking, and entry `IncompleteConversion`; it does not select a replacement cap or tick guard.
- **Unused input and actual swap deltas:** `WeirVaults.deposit` pulls the declared `amount0` and `amount1`, then returns `p.amount0 - used0` and `p.amount1 - used1` to `msg.sender`, the payer. `WeirVaults._deposit` obtains entry-swap results through `_balance`; `_balance` applies the returned `BalanceDelta` to the amounts and does not require a specified input amount to be consumed equally by a resulting delta. There is no entry consumption-equality check and no `IncompleteConversion` in these functions.
- **Issuance:** `WeirVaults._deposit` states the share formula directly:

  ```solidity
  if (v.totalShares == 0) {
      if (frame.liq <= MIN_SHARES) revert ZeroShares();
      frame.shares = frame.liq - MIN_SHARES;
      v.totalShares = MIN_SHARES; // never redeemable: blocks share-price inflation
  } else {
      frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity;
  }
  ```

  Thus a genesis case exists: `MIN_SHARES` is `1_000`, genesis requires `frame.liq > 1_000`, and the locked floor remains in `totalShares`. `WeirVaults.deposit` credits the minted `frame.liq - 1_000` shares to `sharesOf[id][p.recipient]`, so the share recipient need not be the payer. On later deposits, shares are added liquidity multiplied by pre-deposit `totalShares`, divided by pre-deposit `v.liquidity`. Neither `idle0` nor `idle1` occurs in that denominator. The source does not state a different NAV, attributable-growth, or `J_i` issuance formula, so none should be added.
- **Withdrawal:** `WeirVaults._withdraw` removes proportional position liquidity and proportional `idle0`/`idle1`. Its optional one-token branches swap the other currency and apply the actual returned `BalanceDelta`. The full-spread PRD's accepted one-token exit remains a route constraint: pay the selected token or revert. That constraint is not a Weir two-currency zap rule and is not entry `IncompleteConversion`.
- **Compound:** `WeirVaults.compound` dispatches `Action.COMPOUND`. `WeirVaults.unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`. `WeirVaults._compound` harvests fees with a zero-liquidity `modifyLiquidity`, reinvests the remaining fees plus existing idle amounts, increases position liquidity when possible, and does not increase `totalShares`. It performs no PairToken ratio swap. Weir's treasury performance fee is visible in `_compound`, but this update does not import that fee or any PairToken no-fee rule.
- **Donation exception:** Weir's `deposit`, `_deposit`, and `_compound` do not book a direct token transfer as a donation. `donate` survives only because FS-OWN-09 explicitly locks it; it is not evidence of Weir behavior and does not restore PairToken issuance or remainder accounting.

# Proposed PRD replacements

## §1 Goal — replace the final paragraph

```markdown
This family adapts the cited WeirVaults deposit, withdrawal, issuance, and compound money rules to the tokenized Standard Exchange standard. It does not inherit PairToken economics or package zap fields. WeirVaults remains one manager of many virtual vaults; this family is one ERC-20 share, one pool, and one full-range position. A PairToken aspect survives only where an owner lock expressly keeps it.
```

## §1.2 FS-X04 — replace the table row

```markdown
| FS-X04 | On entry, unused declared input is returned to the payer. An entry swap is settled from the `BalanceDelta` values actually returned by PoolManager, following `WeirVaults.deposit`, `_deposit`, and `_balance`; there is no consumption-equality check and no `IncompleteConversion`. No addition remainder `J_i` is booked to shared backing without shares, and issuance follows FS-MONEY-01 rather than S1-ACC-07. This does not change FS-OWN-08's accepted one-token exit, which pays the selected token or reverts. |
```

## §1.3 FS-OWN-10 — replace only the final sentence

```markdown
`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. This closes their previously open status; it does not authorize a replacement view, cap, or tick guard.
```

The rest of FS-OWN-10, including the drops of `previewWithdrawalMode` and the family `wrappedNative()` getter, stays unchanged.

## §2 Authority and precedence — replace the first two source rows

```markdown
| `contracts/protocols/strategy/weir/WeirVaults.sol` | Source of the deposit, withdrawal, issuance, and compound money rules expressly stated in this PRD. Its multi-vault manager, administration surface, and treasury performance fee are not inherited. |
| FS-FACET-01 and FS-PKG-01 below | The self-contained family package inputs and arguments. No PairToken package field or economic rule is inherited. |
```

## §2 Authority and precedence — replace the inheritance paragraphs and named-override list through the blanket S1-inheritance paragraph

```markdown
FS-OWN-01 through FS-OWN-10 remain locked and override every conflicting sentence in this file. PairToken stage one is not an economics authority: no issuance, zap-credit, addition-remainder, or package zap rule is inherited from it. WeirVaults supplies only the money rules expressly cited in this PRD; it does not change the accepted Standard Exchange routes or any owner lock.

Named clarifications:

- FS-X01 permits the already-unlocked path only for canonical `exchangeIn`. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`. `depositPair` and `redeemPair` are not installed under FS-OWN-09, and there are no SY mutators under FS-OWN-05.
- FS-OWN-05 removes `syMoneyFacet`, `syQueryFacet`, and every `IStandardizedYield` selector, including `exchangeRate`.
- FS-OWN-03 withdraws FS-X02. Do not install `IRateProvider`, `IERC4626`, a transition quote, an external-state quote, or a silent `IStandardExchangeRateQuote` unless a later owner decision expressly authorizes it.
- FS-X04 replaces partial-entry consumption and remainder accounting with Weir's actual-delta settlement and payer refund. It does not impose a consumption-equality rule on the accepted one-token exit.

No PairToken S1 requirement or acceptance row is inherited by ID as this family's economics or acceptance law. The local requirements below define the family. The named hook, registry, token, compiler, and production-first testing sources retain their non-economic roles.
```

## §2.1 Dispositions retained from advisory — replace the Entry remainder row

```markdown
| Entry input and swap settlement | `WeirVaults.deposit`, `_deposit`, and `_balance`: settle from actual returned deltas and refund unused declared input to the payer. | Entry consumption equality, `IncompleteConversion`, and booking an addition remainder `J_i` without shares. |
```

## §3 FS-FACET-01 Package inputs — replace the opening paragraph

```markdown
`PkgInit` uses the shared and family facet fields listed below, in the binding order specified by FS-PKG-01. FS-OWN-05 removes `syMoneyFacet` and `syQueryFacet`. It is not an open `IFacet[]`. Do not pass a PairToken facet address into this package. Family facets are this family's implementations. `basicVaultFacet` is the custom implementation in FS-OWN-07, not the shared facet. Package validation must not require `getRate`; FS-OWN-03 forbids installing it.
```

## §3 FS-FACET-01 Package inputs — replace the quoteFacet row

```markdown
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. Do not install `previewZapCredit`, `previewWithdrawalMode` (FS-OWN-10), or the paired previews. |
```

## §3 FS-FACET-01 Package inputs — replace the new-errors block

```markdown
New errors, declared on the family interface, with selectors computed later:

- `InvalidUnlockedContext()`
- `SettlementMismatch()` where execution already uses it

`IncompleteConversion` is not declared. `InsufficientRateSupply`, `RateNormalizationOverflow`, and `RateUnavailable` are withdrawn with `getRate`. Do not declare them for this family.
```

## §4 FS-PKG-01 PkgInit and PkgArgs — replace the PkgArgs introduction and bullets

```markdown
`PkgArgs` contains only the following fields. There is no silent zap default, copied zap limit, or hook allowlist:

- `PoolKey poolKey`, stored through the Position Repo in FS-OWN-02, not as proof that `poolKey()` is a family-only selector
- `string name`
- `string symbol`
```

## §4 FS-PKG-02 Validation — remove the zap-limit rejection and replace the genesis sentence

Delete this bullet without replacement:

```markdown
- Zap limits that are not a positive in-range fee bound and a nonnegative tick bound. `InvalidZapLimits`.
```

Replace the final two sentences of the initialization paragraph with:

```markdown
The first depositor creates the position and uses the Weir genesis case in FS-MONEY-01: liquidity must exceed the locked `1_000`-share floor, the deposit recipient receives added liquidity minus that floor, and the floor is not redeemable. No vault-level performance fee is added by this PRD.
```

## §5 FS-MONEY-01 — replace the complete subsection

```markdown
### FS-MONEY-01 — Weir-adapted money rules

The public money surface is `exchangeIn`, `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound`, with the accepted previews. There is no `getRate`, `rateAsset`, or `previewZapCredit`.

Entry follows `WeirVaults.deposit`, `_deposit`, and `_balance`. Declared input is pulled from the payer; an entry swap is settled from the `BalanceDelta` values actually returned; and unused declared input is returned to the payer. There is no selected-swap consumption-equality check, no `IncompleteConversion`, and no addition remainder `J_i` booked to shared backing without shares. Weir idle amounts arise in compound accounting; they are not an entrant donation.

Share issuance follows `WeirVaults._deposit`. Let `liq` be the added liquidity computed there from the post-swap amounts. If pre-deposit `totalShares` is zero, revert when `liq <= MIN_SHARES`; otherwise issue `liq - MIN_SHARES` to the deposit recipient and retain `MIN_SHARES = 1_000` as a locked, non-redeemable floor in `totalShares`. If shares already exist, issue `(liq * preDepositTotalShares) / preDepositLiquidity`. Idle0 and idle1 are not in the issuance denominator. No S1-ACC-02, S1-ACC-07, attributable-growth, or uncredited-remainder rule is inherited.

Withdrawal follows `WeirVaults._withdraw`: burning shares removes proportional position liquidity and proportional idle amounts. The accepted paired exit pays both currency faces in `vaultTokens()` order without selling one leg to pay the other. Under FS-OWN-08, the accepted one-token exit pays the selected token or reverts. Its conversion uses actual returned deltas and is a route constraint, not a Weir two-currency zap and not `IncompleteConversion`.

`compound` follows `WeirVaults.compound`, `unlockCallback`, and `_compound`: harvest fees and reinvest them together with existing idle amounts into the same full-range position, without changing share supply. `unlockCallback` compounds before deposit and before withdrawal. There is no PairToken ratio swap, quarter-cap, no-fee rule, or withdrawal-only collect-or-compound fallback. Weir's treasury performance fee is not imported, and this PRD adds no replacement fee.

`donate` remains only as the explicit FS-OWN-09 exception: it adds the donated token to the vault's book and mints no shares. Weir does not book a direct transfer as a donation. This exception does not authorize PairToken issuance or remainder accounting.

Native ETH stays, including native-currency pools and actual ETH payout. A wrapped-native boundary does not remove native operation. The 12,000,000 gas transaction ceiling and the 5,000,000 preview ceiling stay. A hook-composed transaction must fit the 12,000,000 ceiling or be recorded as an unresolved narrowed route. It is not a passing measurement and not a waiver.
```

## §6 Rate, quote, and issuance — replace the table

```markdown
| Surface | Meaning | Forbidden substitute |
| --- | --- | --- |
| Issuance | `WeirVaults._deposit`: liquidity-based issuance, the `1_000`-share genesis floor, and pre-deposit liquidity as the later-deposit denominator. Idle is not in that denominator. | Not S1-ACC-02 or S1-ACC-07. Not attributable-growth credit. No `J_i` booking. |
| `previewZapCredit` | Not installed. | No replacement zap-credit view is authorized. |
| SY `exchangeRate()` | Not installed. FS-OWN-05. | A replacement denomination. NAV. |
| `previewExchangeIn` | Amount-specific executable exit under the accepted routes. A one-token exit pays the selected token or reverts. | Not whole-book value divided by supply. Not an entry consumption-equality rule. |
| `getRate()` | Not installed. FS-OWN-03. | The withdrawn one-share formula. NAV. The external full-book provider. |
```

## §8 FS-TEST-01 Harness — replace the bootstrap sentence

```markdown
Bootstrap shares only through the accepted public entry routes and verify issuance against FS-MONEY-01.
```

## §8 FS-TEST-02 Files — replace the blanket inherited-acceptance paragraph and its exceptions

```markdown
PairToken S1 acceptance rows are not inherited by ID. FS-A01 through FS-A38 below are the local acceptance set, together with the hook, native, callback, unlocked, and gas requirements expressly stated in this PRD. No test asserts S1-ACC-07 issuance, addition-remainder `J_i` booking, entry `IncompleteConversion`, `previewZapCredit`, `maxZapBps`, `maxZapTickMove`, or a withdrawal-only collect-or-compound fallback. Selector-manifest checks use this family's reviewed manifest, and the gas limits remain FS-MONEY-01 and FS-A31.
```

## §8 FS-TEST-03 Acceptance rows — replace these rows

```markdown
| FS-A03 | Invalid component, pool key, wrapper, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no rate-asset argument or zap-limit argument to reject. |
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Issuance follows the Weir genesis case: added liquidity must exceed `1_000`, the deposit recipient receives added liquidity minus `1_000`, and the `1_000`-share floor remains locked and non-redeemable. No performance fee is added. |
| FS-A06 | Paired entry issues shares under FS-MONEY-01. Paired redeem burns shares and removes proportional position liquidity and proportional idle amounts, paying both currency faces in `vaultTokens()` order without selling one leg to pay the other. |
| FS-A07 | Entry settles from actual returned swap deltas and returns each unused declared input amount to the payer. No entry case reverts `IncompleteConversion` for partial selected-swap consumption, and no case books an addition remainder `J_i` without shares. Share credit follows FS-MONEY-01. |
| FS-A11 | `compound` harvests and reinvests without changing share supply. It runs before deposit and before withdrawal, and standalone compound follows the same Weir operation. There is no withdrawal-only collect-or-compound fallback. |
| FS-A25 | Buffered configuration mints and burns through `exchangeIn` while unlocked. Recipient may be the hook or the hook's unwrap recipient. Position owner, ticks, and salt hold. Issuance and fee compounding follow FS-MONEY-01. Do not require `token == rateAsset`. A package that rejects the bind for lack of a provider is FS-HOOK-04, not a pass. |
| FS-A33 | Borrowed execution uses the same compound and fee accounting as the locked path from the same economic state. No withdrawal-only fallback is introduced on either path. |
```

FS-A08 remains unchanged and is the accepted exit assertion: the one-token exit pays only the selected token or reverts, and a revert does not burn shares.

# Requires owner authorization

No replacement entry-size cap, tick-move cap, price guard, or other zap guard is proposed. If the owner wants one, its purpose, inputs, bounds, and behavior require a separate explicit owner decision; that case is not PRD text here. Likewise, importing Weir's treasury performance fee would require separate authorization. This response requests no change to FS-OWN-01 through FS-OWN-10.

# Limits

This is a research and PRD-clarification contribution only. It does not implement contracts, edit the PRD, authorize deployment, or claim test, audit, or security results. No Forge, Git, installation, deployment, or peer-response review was performed. The money rules above are limited to the cited WeirVaults functions and the express owner locks; no formula absent from that source has been added.
