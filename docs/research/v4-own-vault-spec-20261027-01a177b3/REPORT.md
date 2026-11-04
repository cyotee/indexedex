# Research report

## Question

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Question: Write an implementable requirements specification for IndexedEx's own Crane diamond vault that earns trading fees on one homogeneous Uniswap V4 position, mints shares from a price-free liquidity-unit claim, and can be valued and exited in one target token. Settle the receipt shape. Do not reconstruct any third-party implementation.
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council request in this thread
- Authorizing task or role: invoking session 01a177b3-f4ed-7770-9633-b5735573eb05
- Admitted read scope: the V2 conversion, the three prior research reports named in the brief, Crane architecture as members reported it, and PoolManager.unlock / modifyLiquidity as re-read for the final
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

The user asked for a specification of StonkBrokers Pair Token source so a later agent could reimplement it. That question was not admitted. Reading that BUSL source and writing a build specification is not a clean room and does not create a production-use grant. This report does not translate or reconstruct that source. A later agent implements this file. It must not open that source to fill a gap.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking-agent, not a vote | invoking session | not exposed | none | continued | synthesis written | PI_SESSION_ID |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | chatgpt-subscription/gpt-6-astra:high, reasoning high | st_01a17cf6 | fresh, then continued for feedback | initial and feedback settled | task host |
| grok | council-member | xai/grok-4.7:xhigh | xai/grok-4.7:xhigh, reasoning xhigh | st_01a17cf7 | fresh, then continued for feedback | initial settled; feedback file written; task then reported no assistant output | task host |
| minimax | council-member | minimax/MiniMax-M3 | minimax/MiniMax-M3 | st_01a17cf8 | fresh, then continued for feedback | initial settled; feedback file written; task then reported no assistant output | task host |
| kimi | council-member | kimi-coding/k3:high | kimi-coding/k3:high, reasoning high | st_01a17cf9 | fresh, then continued for feedback | initial and feedback settled | task host |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none. The Grok and MiniMax transport errors are not missing files.

## Conclusions

This is the specification a later agent implements. Wording that differs from `coordinator/draft.md` is a coordinator revision. Members did not review this text. It is not implementation authorization. It does not change the existing Wings vault. It does not redefine `getRate` as NAV. It does not assume an independent price. No project test was run.

### Product

One new Crane diamond. One Uniswap V4 pool. One tick range. One salt. The diamond proxy owns that position and is the address PoolManager calls back. The only transferable claim is the diamond ERC-20. Liquidity units are an internal ledger, not a second token.

Deposited capital funds that position. Trading fees accrue in the two pool currencies and sit in a fee escrow. They are not part of the share's redeemable property. Exit of shares pays one configured target currency by removing that share's liquidity slice and selling only that slice's opposing principal. Fee escrow is claimed separately, in kind.

### Terms

| Symbol | Meaning |
| --- | --- |
| `U` | Booked liquidity of the one position. Not a sum across ranges. Not a token balance. Not a fee balance. |
| `S` | Share supply. Fee recognition does not mint shares. |
| `d` | Stored conversion offset. Value 9. Used in both directions. Not derived from a price. |
| `uReceived` | Liquidity units the position gained in this call, from the principal delta. Not a pre-trade quote. |
| `Q` | Fee-index scale. Value `2^128`. Not a price. |
| `feePerShare_i` | Cumulative index for currency `i`. |
| `debt_i(account)` | `floor(balance * feePerShare_i / Q)` last settled for that account. |
| `unclaimed_i(account)` | Crystallized fee escrow owed to that account. Not part of the share. |
| `collected_i` | Fee tokens of currency `i` held in escrow. |
| `liability_i` | Sum over accounts of `unclaimed_i` plus unsettled `floor(balance * feePerShare_i / Q) - debt_i`. |
| `remainder_i` | `collected_i - liability_i`. Must be at least zero. Not a holder claim until a settle creates one. |

Share decimals are 18. One whole share is `10^18`. One whole target token is `10^dT`. The coordinator re-read decimals 18 and offset 9 in `UniswapV2StandardExchangeDFPkg.initAccount`. They are stored constants so this conversion matches that converter. They are not an ERC-4626 reserve pointer at a priced token.

### 1. Receipt and mint

Chosen rule. One homogeneous liquidity-unit receipt for one `(pool, range, salt)`.

```text
shares = floor(uReceived * (S + 10^d) / (U_before + 1))
```

`U_before` and `S` exclude this call's new liquidity and new shares. Received units are the numerator. They are not in the denominator.

The coordinator re-read `BetterMath._convertToShares`. Floor rounding is `assets.mulDiv(totalShares + 10**decimalOffset, reserve + 1, Floor)`. The exact-in LP branch in `UniswapV2StandardExchangeInTarget` converts `amountIn` against `reserveBefore`, not against `reserveBefore + amountIn`. An OutTarget comment that puts received units in the denominator is not the executed mint.

The V2 fee-share mint that runs before that conversion is not adopted. `S` here is not increased by a reserve-dependent fee-share mint.

Rejected, and named accurately. Astra's componentwise fee funding is a separate admission rule on top of this same mint equation, not a different mint. It is not adopted. Kimi's compounding of fee tokens into extra liquidity before the mint is not adopted, because it changes `U` at the current tick. The basket and the compound path remain dissent.

Evidence class. The equation is a source observation. The receipt choice is a proposal.

### 2. One share, one range

Initialization binds pool key, tickLower, tickUpper, salt, and target currency. No later call adds a range, changes the salt, or folds another position into `U`. A second range is a different vault. Rebalancing is out of scope.

The share owns this liquidity receipt only. It does not own fee escrow, another range, a donation, or a right to be minted against a liquidation quote.

Summing liquidity across ranges is rejected. That rejection is a source observation of the wrap report.

### 3. Fees

Fees increase holder value in native token units, outside `U` and outside `S`. They are not marked at a square-root price, a TWAP, or a target quote.

Collection. Inside the armed callback, before `S` or `U` changes, call `PoolManager.modifyLiquidity` on this position with a zero liquidity delta. The coordinator re-read `PoolManager.modifyLiquidity`: it passes `owner: msg.sender` and returns `feesAccrued` separately from the principal delta. `feesAccrued` is `delta_i`. Principal is not `delta_i`. Both deltas are settled before the callback returns. `unlock` reverts with `CurrencyNotSettled` if a nonzero delta remains. Do not price the fee. Do not fill this call from excluded source.

Attribution, when `S > 0`:

```text
feePerShare_i += floor(delta_i * Q / S)
```

There is no per-collection dust ledger. After every sync and settle:

```text
liability_i = sum of unclaimed and unsettled claims
remainder_i = collected_i - liability_i
```

`remainder_i` must be at least zero. A later settle that increases liability takes that increase from remainder. Remainder is not paid to a depositor, not swap input, and not labeled a holder claim before that settle. Astra's two-collection counterexample must end with liability plus remainder equal to collected. The later one-unit claim comes out of remainder.

If `S = 0`, collected tokens are remainder. They are not a mint bonus.

Before a balance change, crystallize that account:

```text
unsettled_i = floor(balance * feePerShare_i / Q) - debt_i
unclaimed_i += unsettled_i
debt_i = floor(balance * feePerShare_i / Q)
```

Then change the balance and set `debt_i` from the new balance. A mint adds shares and does not increase `unclaimed`. New shares therefore have no claim on fees already attributed.

Transfer syncs first. Pending earnings crystallize to the sender. `unclaimed` stays with the sender. It does not travel with the shares. The recipient does not receive it.

`claimFees(account)` pays that account's `unclaimed` in kind from escrow. It does not require a share balance. It does not remove liquidity. It does not sell. If escrow cannot pay, that claim reverts and share state is unchanged.

Share exit does not pay `unclaimed`. Removal principal does not fund a fee claim. Fee escrow is not sold on share exit. A fee collected on an earlier sync is paid only from escrow.

No usage-fee share is in this specification. A later authorization could take a fraction of `delta_i` in kind before the index update. It must not mint shares from a price. This specification does not add that take.

### 4. Entry

No vault-initiated swap.

Entry pulls both pool currencies, adds liquidity, refunds amounts that do not become liquidity, and mints with section 1. Either amount may be zero when the current tick leaves that side unused. If `uReceived` is zero, or minted shares are zero, or minted shares are below the caller's `minShares`, the call reverts. Refunded tokens are not fees, not `U`, and not a claim on existing liquidity.

The current tick may change `uReceived`. It does not enter the denominator.

An external contract may swap and then call this two-currency entry. That swap is not this vault. The vault must not add a swap to accommodate it. A later specification may add a vault zap only as a separate route that does not change section 1 and must not claim that a deposit swap plus the exit sale closes the swap-capture result. This file does not add that route.

Kimi and MiniMax include that zap and say it is not the protection. That inclusion is dissent.

### 5. Share exit

After the fee sync, and before the burn:

```text
uOut = floor(shares * (U + 1) / (S + 10^d))
```

The coordinator re-read `BetterMath._convertToAssets`. Floor rounding is `shares.mulDiv(reserve + 1, totalShares + 10**decimalOffset, Floor)`. This is that function. It is not `floor(shares * quote / S)`. It is not `shares * getRate / 10^18`. It is not a whole-book liquidation.

If `uOut` is zero, revert. Remove exactly `uOut`. Sell only the opposing principal from that removal. Pay target from that removal's target principal plus the sale proceeds. Do not include fee escrow, other holders' tokens, remainder, donations, or the vault's remaining opposing inventory. Do not remove extra liquidity to improve the fill.

The caller supplies `minTargetOut`. If the sale cannot complete, or target paid is below `minTargetOut`, the whole call reverts. Unfilled opposing is not paid as target. There is no in-kind fallback.

Set `U` to `U_before - uOut`. If position liquidity is not that value, revert. Do not assign `U` from whatever liquidity the position happens to hold.

A last burn may leave `U > 0` because of floor. That residual stays in the position. It is not swept to the last redeemer. The exit equation is not changed to force `U` to zero. A later deposit uses that residual as `U_before`, so the residual is in the denominator. It is not a free mint. While `S = 0`, fees on the residual are remainder.

Evidence class. The `uOut` equation is a source observation. The no-sweep lifecycle is a coordinator revision accepted from Astra's static counterexample. It was not executed.

### 6. Diamond boundary

The diamond external-calls `PoolManager.unlock`. The coordinator re-read `unlock`: it calls `IUnlockCallback(msg.sender).unlockCallback(data)` and then reverts with `CurrencyNotSettled` if a nonzero delta remains. `modifyLiquidity` is `onlyWhenUnlocked` and `noDelegateCall`, and it records `owner: msg.sender`. The diamond must external-call PoolManager. It must not delegatecall PoolManager. The callback selector lives on a facet, so the callback runs by delegatecall and `address(this)` is the diamond. The position owner is the diamond.

No other address may be the unlock caller, the callback target, or the position owner. An external clone, a helper that calls `unlock`, and a position-manager NFT are rejected.

Per-vault state lives in a diamond repo slot: position key, `U`, `S`, fee index, debts, unclaimed, collected, remainder, target. A facet may hold immutables that are identical for every vault using that facet, such as the pool manager address. `PkgInit` and `PkgArgs` live on the package interface. `unlockCallback` is in `facetFuncs`. Direct calls to the facet implementation cannot own a position.

The callback reverts unless `msg.sender` is the configured pool manager and an entry point armed a single-use flag that binds caller, receiver, pool, range, salt, operation, and amount budgets. Neither check alone is enough.

Deployment follows existing Crane rules: CREATE3 facets, one DFPkg, IndexedEx manager vault registry, reuse of `DiamondPackageCallBackFactory`. This report does not authorize that deployment.

Evidence class. The PoolManager sentences are a source observation of `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol` lines 55-61 and 94-118. No transaction trace was run. Crane package rules are member observations of the architecture skill. The coordinator did not re-open that skill on the final pass.

### 7. getRate

`getRate` is the normalized preview of `redeemTarget` for one whole share. It writes nothing. It is not an issuance input. It is not `liquidateAll(book) / S`. It is not a NAV mark. It does not include personal `unclaimed`, and it does not include `floor(oneShare * F_i / S)`. That average would assign one holder's historical fees to an anonymous share. This council does not redefine `getRate`.

Preview order, Floor throughout:

```text
uOut = floor(10^18 * (U + 1) / (S + 10^d))
```

Simulate removal of that `uOut` first. The opposing sale input is the opposing principal from that removal only. Then quote an exact-in sale of that full input against the post-removal pool state, at the pool's current fee, with the same limits execution will use.

```text
q = targetFromRemoval + saleProceeds
getRate = floor(q * 10^18 / 10^dT)
```

Revert when `S < 10^18`, when `uOut` is zero, when `uOut > U`, when removal cannot be previewed, when the sale cannot be quoted, when opposing input is nonzero and sale output is zero, when the fill would be incomplete, when `q` is zero, or when the normalized rate is zero. Do not return a constant substitute.

Domain. The pool key's hook is the zero address, or a hook that does not change removal amounts or swap outputs relative to the pool's own math. Otherwise `getRate` reverts. If a dynamic fee can change inside the swap outside the quote, revert rather than guess. Do not look in excluded source for the missing hook behavior.

A same-pool tick can change `q`. That is the preview. It is not permission to put the tick into section 1.

A hook that holds this share values it as raw balance, or as balance times a configured rate provider that fails closed on revert, short return, or zero. It does not derive a rate from this vault's issuance preview. This rate is not a claim of manipulation resistance.

### 8. Sequences

Deposit, one armed callback:

1. Collect `feesAccrued` and attribute them to pre-mint `S`.
2. Crystallize the recipient if that account already has shares.
3. Pull both currencies. No vault swap.
4. Add liquidity. `uReceived` is the principal liquidity increase.
5. Revert if `uReceived` is zero, if minted shares are zero, or if minted shares are below `minShares`.
6. Mint with section 1.
7. Set the recipient's debt from the post-mint balance.
8. Set `U` to `U_before + uReceived`. Revert if position liquidity differs.
9. Settle every delta before return.

If fees or liquidity change between the checkpoint and the mint inside that callback, attribute the new fees to pre-mint `S` or revert. Do not let the new shares take them.

Share exit, one armed callback:

1. Collect and attribute fees to pre-burn `S`.
2. Crystallize the holder. Do not pay `unclaimed` on this path.
3. Compute `uOut`. Revert if zero.
4. Burn the shares. Update debt from the new balance.
5. Remove exactly `uOut`.
6. Sell only that slice's opposing principal.
7. Pay target. Revert the whole call if below `minTargetOut`.
8. Set `U` to `U_before - uOut`. Revert on mismatch.
9. Settle every delta before return.

### 9. Invariants a later agent must test

This run does not authorize writing or running them.

1. Minted shares equal `floor(uReceived * (S_before + 10^d) / (U_before + 1))`. No fee-share mint sits between the terms.
2. The denominator is not `U_before + uReceived + 1`, a square-root price, a TWAP, a liquidation quote, an idle balance, or a fee balance.
3. Given the same `uReceived`, `S_before`, and `U_before`, a spot move does not change shares minted. It may change `uReceived` for a token amount, and it may change `getRate`.
4. Pool key, ticks, salt, and target do not change after initialization.
5. `U` changes only by `uReceived` or `uOut`. A mismatch with position liquidity reverts. A bare transfer does not change `U`, `S`, or `feePerShare`.
6. A deposit after a fee sync leaves the new holder's `unclaimed` unchanged by that sync. Remainder is not paid to the new holder.
7. The exit swap input equals the opposing principal from removing `uOut`. Fee escrow, remainder, donations, and remaining inventory are not inputs.
8. A failed sale leaves state unchanged.
9. `getRate` equals the shares-only preview above. It reverts on every section 7 case. It does not include `unclaimed`.
10. `unlockCallback` runs only for the pool manager during an armed flag. The position owner is the diamond. The callback leaves no nonzero delta. A direct facet-implementation call cannot move the position.
11. Transfer crystallizes to the sender. The recipient's `unclaimed` does not increase by the sender's claim.
12. `claimFees` pays escrow in kind and does not change `U` or `S`. Share exit does not decrease `unclaimed`.
13. With no intervening state change, fee accrual, or swap, `redeemLiquidity(mintShares(u)) <= u`. That is not a profitless target round trip, and it is not post-sale immunity.
14. After a deposit, an incumbent's liquidity claim is not increased. Rounding may reduce it by less than one liquidity unit. This is a test bound, not a proved identity.
15. Collected equals liability plus remainder after every sync and settle. Remainder is never negative.
16. Burning the last shares may leave `U > 0`. That residual is not paid out. The next mint uses it in the denominator.

### What this does not deliver

It does not make `getRate` independent of the pool. It does not close execution-price exposure on the exit sale. It does not let this vault swap on entry. It does not hold more than one range. It does not replace Wings. It does not grant a right to copy excluded source. It does not promise that the last burn returns every liquidity unit.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Share mint | lib/crane/contracts/utils/math/BetterMath.sol, `_convertToShares`, lines 726-739 | source observation | Section 1 equation |
| Share redeem | same file, `_convertToAssets`, lines 786-800 | source observation | Section 5 equation |
| Exact-in LP call | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol, exact-in LP branch | source observation | Received units stay out of the denominator |
| Decimals and offset | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol, `initAccount` | source observation | 18 and 9 |
| Callback and owner | lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol, lines 55-61 and 94-118 | source observation | Section 6 and fee collection |
| Wrap, fee-vault, and swap-capture reports | the three paths in the brief | source observation of those reports | Constraints and rejected paths. Not re-executed |
| Member responses and feedback | this run's member files | source observation of those files | Dissent and accepted concerns |
| Excluded third-party source | not read | not examined | Required exclusion |

Public queries sent no private source excerpt. No excluded pair-token source was fetched.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| V2 conversion | required | examined | Coordinator re-read |
| Three prior reports | required | examined by members | Used as their observations. Coordinator used the wrap and fee-vault conclusions already in this thread |
| Crane architecture skill | optional | examined by members | Not re-opened on the final pass |
| Held-reserve law | optional | examined by members | Rate-provider fail-closed rule carried forward |
| PoolManager callback | required for the final's owner sentence | examined | Re-read for this final |
| Excluded third-party source | excluded | not examined | Required |

## Disagreement and missing responses

- Disagreement: Astra prefers in-kind fee funding attached to the share. Kimi prefers compounding fees into liquidity. Kimi and MiniMax prefer a vault zap. Grok prefers an aggregate fee claim inside `getRate`. None of those four positions is adopted. Each is named above.
- Dissent carried into this report: yes, in sections 1, 3, 4, and 7.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-v4-own-vault-spec-20261027-01a177b3-r1
- Draft path: coordinator/draft.md
- Resolution path: coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok requested-changes; minimax support-with-reservations; kimi support-with-reservations
- Post-review wording changes: the specification in Conclusions
- Those changes are member-approved: no

## Recommendations

- Do not implement from this report until a later explicit authorization.
- The first implementation test to write, when authorized, is section 9 items 1, 2, 6, 7, 12, and 15. Those are the holes the review actually found in the draft.
- Do not add a vault zap in that implementation.

## Limitations

- Grok and MiniMax feedback tasks reported a transport error after the files existed. The files were used. They were not retried.
- Astra's residual-liquidity and dust counterexamples are static arithmetic. They were not executed.
- No PoolManager transaction trace was run.
- The coordinator did not re-open the Crane architecture skill on the final pass.
- Live source can change after this report.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md
- Cooperative update: none
- Unrelated edits preserved: not applicable
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
