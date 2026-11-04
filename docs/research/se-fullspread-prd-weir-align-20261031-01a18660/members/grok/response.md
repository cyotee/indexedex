# Grok response

## Identity

Grok, independent council member. Profile: research. Run `se-fullspread-prd-weir-align-20261031-01a18660`.

This is a research response for the coordinator to apply to `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. It does not authorize implementation. It does not reopen FS-OWN-01 through FS-OWN-10. It does not edit the PRD, the review file, the brief, or a peer file.

## Question and targets

Question: what exact PRD replacements remove unauthorized PairToken inheritance and state the Weir-adapted money rules, without reopening a locked owner decision and without inventing a zap guard?

Targets read:

- `docs/research/se-fullspread-prd-weir-align-20261031-01a18660/brief.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`
- `docs/research/se-weir-adaptation-fidelity-20261031-01a18660/REPORT.md`
- `contracts/protocols/strategy/weir/WeirVaults.sol`, including `deposit`, `withdraw`, `compound`, `unlockCallback`, `_deposit`, `_withdraw`, `_compound`, `_balance`, and `_swap`

Narrow callee read, not a new formula source: `contracts/protocols/strategy/weir/base/WeirBase.sol` `_pull`, `_send`, `_settle`, `_take`, `_pay`, and `receive`, because `deposit` and `_deposit` call them.

Narrow ID read, not adopted: the stage-one sections the current PRD incorporates by ID (`S1-ACC-02`, `S1-ACC-03`, `S1-ACC-04`, `S1-ACC-06`, `S1-ACC-07`, `S1-OP-02`, `S1-OP-04`, `S1-OP-05`, `S1-EXIT-01`, `S1-ARCH-03`, and the `S1-A` rows named below). Those formulas are identified so they can be removed. They are not restated as this family's rules.

Peer responses were not read.

## Evidence

### Weir money rules, cited

Unused declared input is returned to the payer. `deposit` pulls `p.amount0` and `p.amount1` from `msg.sender`, then:

```solidity
_send(p.key.currency0, msg.sender, p.amount0 - used0);
_send(p.key.currency1, msg.sender, p.amount1 - used1);
```

The payer is `msg.sender`. The share recipient may be `p.recipient`. `used0` and `used1` come from `_deposit`:

```solidity
(uint256 used0, uint256 used1) = (frame.net0 < 0 ? uint256(-frame.net0) : 0, frame.net1 < 0 ? uint256(-frame.net1) : 0);
_settle(v.key.currency0, frame.net0, depositor);
_settle(v.key.currency1, frame.net1, depositor);
```

`depositor` is the `msg.sender` passed into the unlock. `WeirBase._settle` pays a negative net and takes a positive net to `to`. `WeirBase._pull` does not pull a native leg; native value is checked by `_checkNative`, and `deposit` still sends the unused native amount back through `_send`. `_deposit` does not write `idle0` or `idle1`. Entry remainder is not stored as idle and is not booked as a no-share contribution.

A swap is settled from the deltas actually returned. `_swap` returns the `BalanceDelta` from `poolManager.swap` and does not compare that delta to `amountIn`. `_balance` then does:

```solidity
net0 = s.amount0();
net1 = s.amount1();
n0 = uint256(int256(a0) + net0);
n1 = uint256(int256(a1) + net1);
```

`_withdraw`, when `zapTo` is 1 or 2, adds `s.amount0()` and `s.amount1()` to the nets and settles those nets. There is no consumption-equality check in `deposit`, `_deposit`, `_balance`, `_swap`, or `_withdraw`. `WeirVaults.sol` does not declare `IncompleteConversion`.

`_swap` passes `sqrtPriceLimitX96` of `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1` by direction. That is the source's call. It is not `maxZapTickMove`. This response does not turn it into a new tick guard.

`_balance` states its own swap size. Its NatSpec says it swaps part of the larger side so the two amounts match the pool price by value. This response does not replace that computation with a paraphrased equation, a cap, or `S1-OP-02`'s `floor(received / 2)`.

Share issuance is `_deposit`. The source states:

```solidity
frame.liq = LiquidityAmounts.getLiquidityForAmounts(
    sqrtP,
    TickMath.getSqrtPriceAtTick(v.tickLower),
    TickMath.getSqrtPriceAtTick(v.tickUpper),
    frame.a0 > 2 ? frame.a0 - 2 : 0,
    frame.a1 > 2 ? frame.a1 - 2 : 0
);
if (v.totalShares == 0) {
    if (frame.liq <= MIN_SHARES) revert ZeroShares();
    frame.shares = frame.liq - MIN_SHARES;
    v.totalShares = MIN_SHARES; // never redeemable: blocks share-price inflation
} else {
    frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity;
}
```

`MIN_SHARES` is `1_000`. A genesis case exists: `v.totalShares == 0`. Recipient shares are `frame.liq - MIN_SHARES`. `deposit` credits that `frame.shares` amount to `p.recipient`. The `MIN_SHARES` amount is not credited to the recipient. After the branch, `_deposit` adds `frame.shares` to `totalShares`.

Idle is not in that denominator. `_deposit` does not read `v.idle0` or `v.idle1`. The non-genesis denominator is `v.liquidity`. The source does not state an issuance formula with idle in the denominator. Do not add one. The source also does not state `floor(sqrt(a0 * a1))`, `G_i`, `J_i`, `C_i`, or `qCredit`. Do not add those.

`previewRedeem` adds `(v.idle0 * shares) / v.totalShares` and the same for `idle1` to the redeem amounts. That is not the issuance denominator. This response does not install `previewRedeem`.

`_withdraw` with `zapTo == 0` removes `liquidity * shares / totalShares` and the same proportion of each idle balance, then settles both currencies and does not swap. That is consistent with the locked proportional redeem. It is not a reason to put idle into issuance, and it is not `S1-ACC-03`. `zapTo` 1 and 2 are not the family's one-token exit.

`compound` is harvest-and-reinvest. `unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`. Public `compound` unlocks with `Action.COMPOUND`, and that callback calls `_compound` only. `_compound` collects with `modifyLiquidity` at liquidity delta 0, reinvests through `getLiquidityForAmounts` and a positive `modifyLiquidity`, does not call `_balance` or `_swap`, and does not write `totalShares`. If `v.liquidity == 0`, it returns without collecting. There is no collection-only withdrawal branch in these functions.

The source also takes a performance-fee cut inside `_compound` before reinvestment:

```solidity
frame.cut0 = (frame.f0 * perfFeeBps) / BPS;
frame.cut1 = (frame.f1 * perfFeeBps) / BPS;
_take(v.key.currency0, treasury, frame.cut0);
_take(v.key.currency1, treasury, frame.cut1);
```

`BPS` is `10_000`. `perfFeeBps` defaults to `500`. `MAX_PERF_FEE_BPS` is `1_000`. The contract NatSpec says that cut of harvested fees goes to the treasury and that nothing is charged on deposits or withdrawals. The owner has not authorized adding that fee. It is not proposed PRD text. PairToken's no-fee rule is also not adopted. See Requires owner authorization.

`donate` is not Weir. `WeirVaults.sol` has no `donate`. `deposit`, `withdraw`, and `_compound` do not book a direct transfer as a donation. `WeirBase.receive` accepts ETH and does not credit shares. Fee leftover updated into `idle0` and `idle1` by `_compound` is not an entrant donation. FS-OWN-09 keeps `donate` anyway. That is an explicit exception. It is not deleted.

These rules adapt cited behavior onto the accepted routes. They do not install Weir's `deposit`, `withdraw`, `compound(PoolKey, bytes)`, `zap`, or `zapTo` selectors. The family's `compound()` stays the locked selector. Public `compound` on the borrowed path still reverts `ManagerAlreadyUnlocked`. FS-A22 stays. The pre-entry and pre-exit harvest is inside the vault's own locked-path action.

The accepted one-token exit remains. FS-A08 already says it pays only the selected token or reverts, and shares are not burned if it reverts. That is a route constraint. It is not `IncompleteConversion`. It is not Weir's `zapTo` path, which settles both returned deltas and can pay both currencies.

The fidelity report's recommendation table matches these removals. It is not the formula source. No cap number is stated there, and none is chosen here.

### PairToken-economics sentences, by section

| Section | Sentence | Disposition |
| --- | --- | --- |
| §1 Goal | Sibling of PairToken; inherit that economics by ID. | Replace. |
| §1 Goal | Public shares are proportional claims on that basket. | Replace. It conflicts with the quoted issuance branch. |
| §1.1 | Not a Weir source copy, and not add ERC-20 to WeirVaults. | Keep. It is the manager-copy limit, not PairToken economics. |
| §1.2 FS-X04 | `IncompleteConversion`, unchanged `S1-ACC-07`, booked `J_i`. | Replace. |
| §1.2 FS-OWN-09 | Keep `donate` and `compound`, with no Weir exception. | Clarify. Do not delete the lock. |
| §1.3 FS-OWN-09 | Same lock, no exception and no compound behavior. | Clarify. Preserve the mapped routes, proportional redeem, paired events, and undecided raw ETH. |
| §1.3 FS-OWN-10 | `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` stay open. | Replace. Close as absent. Not a new design. |
| §2 authority table | Stage one is inherited economics, package law, and inherited acceptance. | Replace the economics role. Package shape already written in FS-FACET-01 is not economics. |
| §2 | An FS delta overrides only the named clause; otherwise stage one controls. | Replace for economics. |
| §2 | Inherit `S1-ACC-01` through `S1-ACC-07`, `S1-OP-02`, `S1-OP-05`, `S1-EXIT-01`, and the rest of that sentence. | Delete that sentence. Do not replace it with a shorter inherit list. |
| §2 named override | FS-X04 turns `S1-A13` and `S1-A15` into rejection cases; their other accounting checks stay. | Delete. Those other checks are the removed credit rule. |
| §2.1 | Inherited `J_i` booking plus FS-X04 full selected-swap consumption. | Replace. |
| §2.1 | Supply below `1e18` reverts `InsufficientRateSupply`. | Mark withdrawn by FS-OWN-03. Not a new rate policy. |
| §3 FS-FACET-01 | `quoteFacet` includes `previewZapCredit`. | Remove the selector. |
| §3 FS-FACET-01 | Declare `IncompleteConversion`. | Remove the error. |
| §3 FS-FACET-01 | `SettlementMismatch` where the inherited execution already uses it. | Keep. It is unlock plumbing in FS-UNLOCK-02, not the entry consumption check. |
| §3 FS-FACET-01 | `PkgInit` follows the current PairToken facet order. | Keep as package shape. It is not economics authority. |
| §4 FS-PKG-01 | `PkgArgs` is the PairToken set, including `maxZapBps` and `maxZapTickMove`. | Replace. Do not add a field. |
| §4 FS-PKG-02 | Zap limits revert `InvalidZapLimits`. | Delete the bullet. Do not add a validation. |
| §4 FS-PKG-02 | Pool key outside the inherited domain. | Delete that phrase. It is the path back to the stage-one zap domain. Keep the initialized and nonzero-hook checks. |
| §4 FS-PKG-02 | No permanent dead-share mint and no vault-level performance fee. | Replace the dead-share sentence with the quoted genesis branch. Do not adopt a fee, and do not adopt a no-fee rule. |
| §5 FS-MONEY-01 | PairToken surface, `S1-ACC-02`, `S1-ACC-07`, `G_i`, `J_i`, `IncompleteConversion`, inherited settlement failure, `S1-EXIT-01`. | Replace those sentences. Keep the native paragraph and the gas ceilings. |
| §6 issuance table | Issuance and `previewZapCredit` are `S1-ACC-02` and `S1-ACC-07`. | Replace. |
| §6 issuance table | `previewExchangeIn` includes maintenance and full unwanted-leg consumption. | Replace the maintenance import. Keep the exit constraint, unnamed as `IncompleteConversion`. |
| §8 FS-TEST-02 | `S1-A01` through `S1-A70` apply, and partial-entry success becomes `IncompleteConversion`. | Replace. The FS-A rows are the acceptance surface. |
| §8 FS-A03 | Invalid zap limits revert. | Remove that assertion. |
| §8 FS-A05 | No dead-share mint. No performance fee. | Replace. |
| §8 FS-A06 | Paired deposit and redeem match `S1-ACC-02` and `S1-ACC-03`. | Replace. |
| §8 FS-A07 | `IncompleteConversion` and booked `J_i`. | Replace. |
| §8 FS-A08 | Single-token exit pays only the selected token or reverts. | Keep the assertion. Say it is not `IncompleteConversion` and not Weir `zapTo`. |
| §8 FS-A11 | Withdrawal fallback follows `S1-EXIT-01`. | Replace. |
| §8 FS-A25 | Fee attribution follows `S1-ACC-06`. | Replace that clause. Keep the hook assertions. |
| §8 FS-A33 | Same compound, fallback, and fee attribution. | Replace the fallback and fee-attribution clause. |
| §8 FS-TEST-01 | Follow the current PairToken setup; bootstrap through public paired entry. | Keep. Harness and the locked bundle route, not a removed economics rule. |
| §7 FS-HOOK and §8 compiler sentences | Hook bindings, `viaIR=false`, gas ceilings already restated. | Do not rewrite. |
| §9 | This PRD does not authorize a Weir copy. | Keep. It is the manager-copy limit. |

Stage-one acceptance rows incorporated by the FS-TEST-02 blanket that assert a removed rule, and therefore do not apply: `S1-A08` (geometric-mean genesis, zero dead shares), `S1-A10` (`S1-ACC-07` credit cap), `S1-A13`, `S1-A14` (size cap and tick boundary), `S1-A15`, `S1-A19`'s collection-only success, `S1-A22` (retain all LP fees), `S1-A23` (quarter-cap), `S1-A46`'s `S1-ACC-07` clause, `S1-A61`, `S1-A62`, `S1-A63`, `S1-A64`, `S1-A66`'s dead-share clause, and `S1-A69`'s zap-parameter clause. The partial-exit revert half of `S1-A19` is already FS-A08. It does not need the stage-one row.

`S1-OP-05` is the ratio swap, the quarter-cap (`maxZapBps / 10000 / 4`), and the no-fee rule ("Retain the full collection"). `S1-EXIT-01` is the collection-only fallback. `S1-ARCH-03` items 4 and 5 are the zap fields. None of those are inherited.

FS-OWN-01 through FS-OWN-08 are preserved. FS-OWN-09 and FS-OWN-10 are preserved and clarified. No hook section, compiler sentence, or unlock section is rewritten.

## Proposed PRD replacements

These blocks are the new Markdown. They are not a full PRD. A new guard is not in any block.

### §1 Goal

Replace the paragraphs under `## 1. Goal` after `Build UniswapV4FullSpreadStandardExchangeVault.`

```markdown
One registry-deployed Crane diamond owns one Uniswap V4 pool key, one full-range position, and one ERC-20 share supply. The diamond is the position owner.

This vault adapts WeirVaults to the tokenized Standard Exchange standard. It is one ERC-20 share, one pool, and one full-range position. It is not a copy of Weir's multi-vault manager, and it is not a sibling of PairToken. PairToken economics are not inherited. A PairToken aspect stays only where an owner lock already keeps it. Do not inherit issuance, zap credit, or package zap fields from `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`.
```

### §1.2 FS-X04

Replace the FS-X04 row.

```markdown
| FS-X04 | Single-token entry does not require the selected swap to consume its entire specified input. There is no `IncompleteConversion` check. Unused declared input is returned to the payer. A swap is settled from the deltas actually returned. Share credit is not S1-ACC-07. Addition remainder `J_i` is not booked to shared backing. The accepted one-token exit is not this row. |
```

### §1.2 FS-OWN-09

Replace the FS-OWN-09 row. The lock stays.

```markdown
| FS-OWN-09 | Do not keep `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map them to the accepted bundle routes. Keep `donate` and `compound`. `donate` is an explicit exception and is not Weir. `compound` is Weir harvest-and-reinvest, not a PairToken ratio swap. |
```

### §1.2 FS-OWN-10

Replace the FS-OWN-10 row. The locked drops stay. The zap names are closed as absent.

```markdown
| FS-OWN-10 | Do not implement `previewWithdrawalMode` or a family `wrappedNative()` getter. `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, or tick bound is added. |
```

### §1.3 FS-OWN-09

Replace the FS-OWN-09 lock paragraph. Do not delete the lock.

```markdown
**FS-OWN-09.** The owner accepted the council recommendation in `docs/research/se-paired-money-necessity-20261030-01a18660/REPORT.md`. Do not install `depositPair`, `previewDepositPair`, `redeemPair`, or `previewRedeemPair`. Map deposit to `exchangeBundleInForSingleOut` and `previewExchangeBundleInForSingleOut`, with `tokenOut` as the share. Map redeem to `exchangeBundleOut` and `previewExchangeBundleOut`, with `tokenIn` as the share and `tokensOut` as the two ERC-20 faces. Keep `donate` and `compound`. `donate` is an explicit exception. `WeirVaults.sol` has no `donate`. `deposit`, `withdraw`, and `_compound` do not book a direct transfer as a donation. Do not delete this lock, and do not treat `donate` as Weir issuance or as a path back to PairToken share credit. `compound` stays. Its behavior is Weir harvest-and-reinvest, specified in FS-MONEY-01. It is not PairToken's ratio swap, quarter-cap, or no-fee rule. The mapped redeem removes both currencies proportionally. It does not sell one leg to pay the other. Paired events survive the selector drop. Raw ETH is not decided and no extension is added.
```

### §1.3 FS-OWN-10

Replace only the last sentence of the FS-OWN-10 lock paragraph. The preceding sentences stay, including the sentence that this lock does not publish an internal compound-or-collect branch.

```markdown
`previewZapCredit`, `maxZapBps`, and `maxZapTickMove` are absent. No replacement view, cap, or tick bound is added. This close is not a new zap design.
```

### §2 Authority table

Replace the PairToken stage-one row.

```markdown
| PairToken stage-one PRD | Not the economics authority. Not the source of issuance, zap credit, package zap fields, compound economics, or an entry consumption-equality check. |
```

Replace the current PairToken package-interface row.

```markdown
| Current PairToken `IUniswapV4PairTokenStandardExchangeVaultDFPkg` | Package facet shape already written in FS-FACET-01. Not issuance, not zap credit, and not package zap fields. Re-read before coding. |
```

### §2 Control paragraph and inherit sentence

Delete the paragraph that begins `An enumerated FS delta overrides only the named clause` and the sentence that begins `Inherit S1-D01 through S1-D05`. Do not replace that sentence with a shorter inherit list. Insert:

```markdown
PairToken stage one is not the economics authority. It is not the source of issuance, zap credit, package zap fields, compound economics, or an entry consumption-equality check. If this PRD and the stage-one PRD disagree on those subjects, this PRD controls. The stage-one clause is not inherited.

Do not inherit S1-ACC-01 through S1-ACC-07, S1-OP-02, S1-OP-05, S1-EXIT-01, S1-ARCH-03's `maxZapBps` and `maxZapTickMove` items, or the S1-API getters `maxZapBps()` and `maxZapTickMove()`. Do not apply a stage-one acceptance row that asserts one of those rules.

Non-economic constraints already written in this PRD stay as written. That includes FS-X01, the FS-UNLOCK sections, the FS-HOOK sections, the FS-TEST-01 compiler and harness sentences, and the facet wiring in FS-FACET-01 except the removed zap selector and the removed `IncompleteConversion` error. Do not re-import a stage-one clause to fill a removed rule.
```

### §2 Named override

Delete this bullet:

```markdown
- FS-X04 turns the successful partial-entry-fill cases in S1-A13 and S1-A15 into rejection cases. Their other accounting checks stay.
```

Do not replace it. FS-X01, FS-OWN-05, and FS-OWN-03 bullets stay.

### §2.1 Dispositions

Replace the Entry remainder row.

```markdown
| Entry remainder | Unused declared input is returned to the payer. It is not booked as `J_i` and it does not mint shares. There is no consumption-equality check. | Every input wei becomes liquidity. Booked no-share remainder. `IncompleteConversion` on entry. |
```

Replace the Supply below `1e18` row. This applies FS-OWN-03. It does not name a rate policy.

```markdown
| Supply below `1e18` | Withdrawn by FS-OWN-03. `getRate` is not installed. | A live `InsufficientRateSupply` requirement. |
```

### §3 FS-FACET-01 quote facet

Replace the `quoteFacet` selector cell.

```markdown
| `quoteFacet` | `previewExchangeIn`, `previewExchangeBundleInForSingleOut`, `previewExchangeBundleOut`. Do not install `previewZapCredit`, `previewWithdrawalMode` (FS-OWN-10), or the paired previews. |
```

### §3 FS-FACET-01 query facet

Add this sentence to the `queryFacet` cell, after the existing do-not-install sentence:

```markdown
Do not install `maxZapBps()` or `maxZapTickMove()`.
```

### §3 FS-FACET-01 errors

Delete this bullet:

```markdown
- `IncompleteConversion(uint256 expectedInput, uint256 consumedInput)`
```

Do not declare a replacement error. Keep `InvalidUnlockedContext` and `SettlementMismatch`.

### §4 FS-PKG-01

Replace the `PkgArgs` introduction and field list.

```markdown
`PkgArgs` is not the PairToken set. It does not carry `maxZapBps`, `maxZapTickMove`, `previewZapCredit`, `rateAsset`, or a replacement cap or tick bound. No hook allowlist:

- `PoolKey poolKey`, stored through the Position Repo in FS-OWN-02, not as proof that `poolKey()` is a family-only selector
- `string name`
- `string symbol`
```

### §4 FS-PKG-02

Delete this bullet:

```markdown
- Zap limits that are not a positive in-range fee bound and a nonnegative tick bound. `InvalidZapLimits`.
```

Replace the pool-key bullet with:

```markdown
- A pool key that is not initialized on the bound manager, or has a nonzero hook. `InvalidPoolKey`.
```

Replace the sentence `The first depositor creates the position. There is no permanent dead-share mint and no vault-level performance fee.` with:

```markdown
The first depositor creates the position. On that first deposit, share issuance follows the genesis branch in FS-MONEY-01. This section does not set a performance fee, and it does not adopt a no-fee rule.
```

In that same initialization paragraph, replace `installs the inherited metadata` with `installs the share name and symbol`.

### §5 FS-MONEY-01

Replace the body of `### FS-MONEY-01 — Inherited surface`. Rename the heading as part of the replacement.

~~~~markdown
### FS-MONEY-01 — Weir-adapted money rules

The public surface is the accepted Standard Exchange routes, plus `donate` and `compound` as FS-OWN-09 keeps them. It is not the PairToken surface. `getRate` and `rateAsset` are not installed. `previewZapCredit` is absent. These rules do not install Weir's `deposit`, `withdraw`, `compound(PoolKey, bytes)`, `zap`, or `zapTo` selectors.

Issuance is the `_deposit` branch in `contracts/protocols/strategy/weir/WeirVaults.sol`. It is not S1-ACC-02 and not S1-ACC-07. Shares are not credited against `G_i`. `J_i` is not booked without extra shares. The source states:

```solidity
frame.liq = LiquidityAmounts.getLiquidityForAmounts(
    sqrtP,
    TickMath.getSqrtPriceAtTick(v.tickLower),
    TickMath.getSqrtPriceAtTick(v.tickUpper),
    frame.a0 > 2 ? frame.a0 - 2 : 0,
    frame.a1 > 2 ? frame.a1 - 2 : 0
);
if (v.totalShares == 0) {
    if (frame.liq <= MIN_SHARES) revert ZeroShares();
    frame.shares = frame.liq - MIN_SHARES;
    v.totalShares = MIN_SHARES; // never redeemable: blocks share-price inflation
} else {
    frame.shares = (uint256(frame.liq) * v.totalShares) / v.liquidity;
}
```

`MIN_SHARES` is `1_000`. A genesis case exists when total shares are 0. Recipient shares are `frame.liq - MIN_SHARES`. The `MIN_SHARES` amount is not credited to the recipient. The non-genesis denominator is `v.liquidity`. Idle is not in that denominator. `_deposit` does not read `idle0` or `idle1`. The source does not state an issuance formula with idle in the denominator, and it does not state `floor(sqrt(a0 * a1))`, `G_i`, or `qCredit`. Do not add one.

Unused declared input is returned to the payer. `deposit` sends `amount0 - used0` and `amount1 - used1` to `msg.sender`. `used0` and `used1` are the absolute values of the negative nets after the optional balance swap and `modifyLiquidity`. Positive nets are settled to that same payer. The share recipient may be a different address. This remainder is not booked to shared backing and does not mint shares. The accepted return stays `(uint256 amountOut, uint256 amountRefunded)`.

A swap is settled from the `BalanceDelta` actually returned. `_swap` returns `poolManager.swap`. `_balance` sets its nets from `s.amount0()` and `s.amount1()`, then sets the new amounts from the prior amounts plus those nets. There is no check that the consumed amount equals the specified input. Do not add that check. Do not declare `IncompleteConversion`. Do not inherit S1-OP-02's `floor(received / 2)`, `maxZapBps` size test, or `maxZapTickMove` check. When an accepted entry swaps to balance the deposit, the amount is the amount `_balance` computes. This PRD does not replace that computation with a cap or a tick bound. `_swap` passes `sqrtPriceLimitX96` of `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1` by direction. That is the source's call. It is not `maxZapTickMove` and not a new guard. A two-token bundle entry is not given a new swap by this section.

The accepted one-token exit remains a route constraint. It pays the selected token or reverts. That revert is not `IncompleteConversion`. It is not Weir's `zapTo` settlement, which can return both currencies from the deltas actually returned. Shares are not burned if the exit reverts. The proportional redeem remains FS-OWN-09. It removes both currencies proportionally and does not sell one leg to pay the other.

`compound` harvests fees and reinvests them. `unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`. Public `compound` calls `_compound` through the same callback. `_compound` collects with a zero-liquidity `modifyLiquidity`, reinvests liquidity, does not call `_balance` or `_swap`, and does not write `totalShares`. It is not PairToken's ratio swap, quarter-cap, or no-fee rule. The source takes `perfFeeBps` of harvested fees to `treasury` before reinvestment. That cut is not a requirement of this PRD. The owner has not authorized it. Do not write a rule that the cut is zero. This harvest runs inside the vault's own locked-path action. It does not unlock public `compound` on the borrowed path. FS-A22 stays. There is no collection-only fallback. Do not inherit S1-EXIT-01.

Native ETH stays, including native-currency pools and actual ETH payout. A wrapped-native boundary does not remove native operation.

The 12,000,000 gas transaction ceiling and the 5,000,000 preview ceiling stay. A hook-composed transaction must fit the 12,000,000 ceiling or be recorded as an unresolved narrowed route. It is not a passing measurement and not a waiver.
~~~~

### §6 Issuance table

Replace the issuance row.

```markdown
| Issuance | The `_deposit` share branch quoted in FS-MONEY-01. Idle is not in that denominator. | S1-ACC-02. S1-ACC-07. `previewZapCredit`. `exchangeRate`. `getRate`. |
```

Replace the `previewExchangeIn` row.

```markdown
| `previewExchangeIn` | Amount-specific executable quote of the accepted route. A one-token exit pays the selected token or reverts. That revert is not `IncompleteConversion`. | Whole-book value divided by supply. A Weir two-currency zap. S1-EXIT-01 maintenance. |
```

Leave the SY `exchangeRate` row and the `getRate` row as they are.

### §8 FS-TEST-02

Replace the paragraph that begins `Inherited rows S1-A01 through S1-A70 apply except` and its four bullets.

```markdown
Stage-one acceptance rows are not this family's economics authority. Do not apply S1-A01 through S1-A70 as inherited obligations. The FS-A rows in FS-TEST-03, as amended in this update, are the acceptance surface. Unlock behavior stays FS-A19 through FS-A23 and FS-A22. The selector manifest stays FS-A01. The gas ceiling stays FS-A31. Do not turn a partial entry fill into `IncompleteConversion`.
```

### §8 FS-A01

In the FS-A01 assertion, add `previewZapCredit`, `maxZapBps()`, and `maxZapTickMove()` to the absent-selector list.

### §8 FS-A03

Replace the FS-A03 row.

```markdown
| FS-A03 | Invalid component, pool key, wrapper, double initialization, wrong `processArgs` caller, and right registry in the wrong account all revert and leave no usable vault. There is no rate-asset argument to reject. There is no zap-limit argument to reject. |
```

### §8 FS-A05

Replace the FS-A05 row.

```markdown
| FS-A05 | First deposit creates one full-range salt-zero position owned by the diamond. Genesis issuance follows the FS-MONEY-01 branch: recipient shares are liquidity minus `MIN_SHARES` (`1_000`), and that `MIN_SHARES` amount is not credited to the recipient. This row does not assert a performance fee and does not assert a no-fee rule. |
```

### §8 FS-A06

Replace the FS-A06 row.

```markdown
| FS-A06 | Paired entry issues shares by the FS-MONEY-01 `_deposit` branch. It does not match S1-ACC-02. Paired redeem removes both currencies proportionally and does not sell one leg to pay the other. That is FS-OWN-09. It is not S1-ACC-03 and not a collection-only fallback. |
```

### §8 FS-A07

Replace the FS-A07 row.

```markdown
| FS-A07 | Unused declared input is returned to the payer. A partial selected entry swap does not revert `IncompleteConversion`. No `J_i` is booked without extra shares. No second-token payout is required to make that true. |
```

### §8 FS-A08

Replace the FS-A08 row. The exit assertion stays.

```markdown
| FS-A08 | Single-token exit pays only the selected token or reverts. Shares are not burned if it reverts. This is a route constraint. It is not `IncompleteConversion`. It is not Weir `zapTo`, which can pay both currencies. |
```

### §8 FS-A11

Replace the FS-A11 row.

```markdown
| FS-A11 | `_compound` runs before entry and before exit, as `unlockCallback` does. There is no S1-EXIT-01 collection-only fallback. Deposit and `compound` do not take a fallback that is not specified. |
```

### §8 FS-A25

Replace the FS-A25 row. The hook assertions stay. The S1-ACC-06 clause does not.

```markdown
| FS-A25 | Buffered configuration mints and burns through `exchangeIn` while unlocked. Recipient may be the hook or the hook's unwrap recipient. Position owner, ticks, and salt hold. Fee harvest follows the FS-MONEY-01 compound rule. It does not follow S1-ACC-06. Do not require `token == rateAsset`. A package that rejects the bind for lack of a provider is FS-HOOK-04, not a pass. |
```

### §8 FS-A33

Replace the FS-A33 row.

```markdown
| FS-A33 | Borrowed execution uses the same compound harvest-and-reinvest as the locked path from the same economic state. There is no collection-only fallback and no S1-ACC-06 fee attribution. |
```

## Requires owner authorization

This section is not proposed PRD text. No new guard is proposed.

Weir's `_compound` takes `perfFeeBps` of harvested fees to `treasury` before reinvestment. The default is `500`. The hard cap is `1_000`. `BPS` is `10_000`. The cut is `(fees * perfFeeBps) / BPS`, paid through `_take`. The owner has not authorized adding that fee. This response does not put the cut, the constants, or a zero-fee substitute into the PRD as a requirement. PairToken's "retain the full collection" rule is not the substitute. A fee decision remains an owner decision.

`maxZapBps`, `maxZapTickMove`, and `previewZapCredit` are closed as absent. No replacement cap, tick guard, view, or number is proposed. Prior fidelity-report cases for an entry-size bound or a local tick bound are not renewed here.

`donate` does not need a new authorization. FS-OWN-09 already keeps it. The genesis `MIN_SHARES` branch is proposed PRD text because the source states it and the brief requires that quote. It is not a new guard.

## Limits

This response does not authorize implementation, deployment, or a PRD edit by this member. The coordinator applies the replacements or rejects them.

FS-OWN-01 through FS-OWN-10 are preserved. FS-OWN-09 and FS-OWN-10 are clarified, not reopened. Hook sections, compiler sentences, and unlock sections are not rewritten. FS-A22 still rejects borrowed-path `compound`.

No formula was added that `WeirVaults.sol` does not state. The 2-wei liquidity input and `MIN_SHARES = 1_000` are quoted from `_deposit`. They were not rescaled. Idle was not added to the issuance denominator. `previewRedeem`'s idle term was not installed as a family view.

No cap number was chosen. No tick guard was designed. No exit error was invented. `amountRefunded` was not redefined beyond this: unused declared input is returned to the payer and is not booked as `J_i`. The refund-bundle report was not read. The accepted return ABI stays.

FS-OWN-04's local sleeve was not equated with Weir `idle0` and `idle1`. Sleeve refill and spend stay unspecified, as that lock says.

`WeirBase` was read only to see how the cited `deposit` return and settlement calls move funds. Stage-one text was read only to identify incorporated IDs that assert removed rules. Those stage-one formulas are not adopted.

The function-review file still marks `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` Open. This response does not edit that file. FS-ARCH-01 still names SY facet files. That sentence was left in place. FS-OWN-05 already drops those facets. No revision identifier is proposed.

Peer responses were not read. Forge, Git, installs, and deployments were not run.
