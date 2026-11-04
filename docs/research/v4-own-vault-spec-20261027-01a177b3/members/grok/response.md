# Member response

## Identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

The member label is the caller's assignment, not a model identity inferred from prose. This assignment text did not expose a task ID or a session ID. The brief names an invoking session for the coordinator; that is not this member's identity. This self-description is not proof of the runtime model.

## Question and targets

- Question: Write an implementable requirements specification for IndexedEx's own Crane diamond vault that earns trading fees on one homogeneous Uniswap V4 position, mints shares from a price-free liquidity-unit claim, and can be valued and exited in one target token. Settle the receipt shape. Do not reconstruct any third-party implementation.
- Required targets: contracts/protocols/dexes/uniswap/v2 share-mint and exit conversion; docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md; docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md; docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md conclusions only
- Optional context: .agents/skills/crane-architecture/SKILL.md; docs/agent/INDEXEDEX_AGENT_LAW.md held-reserve rule. Both were present.
- Admitted read scope: the required targets, the optional context, and the brief. Callees of the V2 conversion and exit that I opened are listed in Evidence. No third-party pair-token source. No peer response, draft, or final.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Executed share conversion | lib/crane/contracts/utils/math/BetterMath.sol, `_convertToShares` (called by `_convertToSharesDown` with `Math.Rounding.Floor`) | source observation | `shares = assets.mulDiv(totalShares + 10**decimalOffset, reserve + 1, Floor)`. Received units are the numerator. They are not added into the denominator. |
| Executed liquidity assignment | same file, `_convertToAssets` (called by `_convertToAssetsDown` with Floor) | source observation | `assets = shares.mulDiv(reserve + 1, totalShares + 10**decimalOffset, Floor)`. |
| Exact-in LP mint | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol, branch `tokenIn == pool` and `tokenOut == address(this)`, preview and execute | source observation | Preview converts `amountIn` against live `pool.balanceOf(address(this))` after `_calcVaultFee` has added `feeShares` to the in-memory supply. Execute calls `_calcAndMintVaultFee`, sets `reserveBefore` to the live balance minus a pretransferred inbound, pulls, then `_convertToSharesDown(amountIn, reserveBefore, vault.vaultTotalShares, decimalOffset)`. The comment on that path says not to credit a `lastTotalAssets` exact gap. |
| Zap-in mint | same file, reserve-asset in and vault-share out, preview and execute | source observation | Both convert the LP quantity against booked `vault.vaultLpReserve`, not against `reserve + lpReceived`. Execute reverts if `pool.balanceOf(address(this)) != vault.vaultLpReserve` before the zap, then converts the LP actually minted. A zero preview reverts `MinAmountNotMet(1, 0)` before the swap. |
| Comment that is not the mint | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol, `_exchangeOut_zapInVaultDeposit` | source observation | The comment says Route 6 computes `floor(lpReceived * (S + 10^d) / (R_before + lpReceived + 1))`. The same function then calls `_convertToAssetsUp` and, after the zap, `_convertToSharesDown(lpReceived, vault.vaultLpReserve, ...)`. The executed converter does not match that comment. |
| Decimal offset and share decimals | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol, `initAccount` | source observation | `ERC20Repo._initialize` sets share decimals to 18. `ERC4626Repo._initialize` sets `decimalOffset` to 9. The offset is stored, not recomputed from a price. |
| Offset read | lib/crane/contracts/tokens/ERC4626/ERC4626Repo.sol, `_decimalOffset` | source observation | The conversion reads the stored slot. It does not derive `d` from reserves or from a quote. |
| Fee-share mint before depositor conversion | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol, `_calcVaultFee` and `_calcAndMintVaultFee` | source observation | `_calcVaultFee` calls `ConstProdUtils._calculateFeePortionForPosition` and `_quoteDepositWithFee`, takes `usageFeeOfVault`, converts that LP-equivalent with `_convertToSharesDown`, and adds `feeShares` to `vaultTotalShares`. `_calcAndMintVaultFee` mints those shares to `feeTo` before the depositor conversion. I did not re-read `ConstProdUtils` in this pass. |
| Exact-in exit | same file, `_redeemLpSharesFrom`; lib/crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol, `_withdrawSwapDirect` | source observation | Burns `shares_`, assigns LP with `_convertToAssetsDown`, and if a pool token is requested calls `_withdrawSwapDirect` for that LP amount only. `_withdrawSwapDirect` withdraws that amount and swaps only the other token from that withdrawal (`_swapWithdrawnTokens`). It does not take the vault's remaining opposing balance as the swap input. `MinAmountNotMet` reverts if `amount_ < minimum_`. I did not read a residual-in-kind branch. |
| Wrap report | docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md | source observation of that report | V2 mint matches the floor form above. Spot does not enter that equation. A zap and an exit sale still execute against the pool. A deposit swap plus an exit swap does not close the prior result. Two price-free shapes were left open. Summing liquidity across ranges was rejected. `getRate` must not be copied from the current whole-book Wings quote. Fee accrual inside a raw liquidity unit was not established. The failed-sale rule in that report is a proposal, not a V2 observation. |
| Fee-vault report | docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md | source observation of that report | The adopted object there is idle target plus an assignment of target-denominated fees. Depositors do not fund the pool position. That report does not answer the case where deposited capital is the pool principal. Its offset counterexample and its uncredited-fee counterexample are about a different ratio. It does not redefine `getRate`. |
| Swap-capture conclusions | docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md, conclusions only | source observation of that report | A deposit swap plus an exit swap does not eliminate the quote-rule or executed-price extraction in the domains that report rechecked. The same-pool TWAP it read is not an independent price. The price-free join's identity is acceptance-time only. Post-sale immunity was not adopted. Self-fill sign was left in disagreement. Not re-litigated here. Not re-executed. |
| Held-reserve rule | docs/agent/INDEXEDEX_AGENT_LAW.md, section "Uniswap V4 SE buffer hooks: held-reserve valuation (APEX D60, LOCKED 2026-09-22)" | source observation | A buffer hook values a held reserve as raw balance, or as `held x rate` when a provider is configured. It must not derive that rate from `previewExchangeIn` or `quoteAssets` on the Standard Exchange it holds. Providers fail closed on revert, short return, or zero. The section applies to buffer hooks under `contracts/hooks/uniswap/v4/standardExchange/**`. It is not, by itself, a product contract for this vault. |
| Diamond pattern | .agents/skills/crane-architecture/SKILL.md | source observation of that skill | Facet, target, and repo are separate. Per-instance state is a repo slot on the diamond, ERC1967 form `bytes32(uint256(keccak256(...)) - 1)`. Facets expose selectors through the diamond. `PkgInit` and `PkgArgs` live on the package interface. I did not open the diamond fallback source. |
| Public query | not used | not used | No search and no fetch. No private excerpt was sent. Excluded third-party source was not opened. |
| PoolManager source | not opened | unverified | Fee-growth split and unlock-callback ownership are requirements below, not a trace of manager source. |

## Assumptions

- Target-token liquidity may exist only in the underlying pool. No independent price is available. None is assumed.
- The later implementer will not see excluded third-party source. This file plus the IndexedEx paths it cites has to be enough.
- Uniswap V4 will call the unlock caller back, and a position's liquidity can be changed only by its owner. I did not open that manager in this pass. If a deployment's manager cannot separate tokens owed to pre-add liquidity from the liquidity delta, the deposit requirement is to revert, not to mark those tokens at spot.
- The three reports are prior council records. Their ledgers were not re-run. Their disagreement is not this pass's peer agreement.
- `ConstProdUtils._calculateFeePortionForPosition` was not re-read here. The rejection of the V2 fee-share mint rests on the call site I opened and on the wrap report's description of that path.
- Optional context was present. It is a constraint on consumers of `getRate` and on diamond structure. It is not a second product.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| V2 share-mint conversion | required | examined | `BetterMath._convertToShares` and the InTarget exact-in LP and zap-in branches were opened. The OutTarget comment was opened and rejected as the mint. |
| V2 exit conversion | required | examined | `_redeemLpSharesFrom` and `_withdrawSwapDirect` were opened. Other OutTarget routes were not read function-by-function. |
| Wrap report | required | examined | Receipt choice, fee limit, and the adopted equation's prior statement. |
| Single-token fee-vault report | required | examined | Different object. Used as a boundary, not as the mint. |
| Swap-capture report | required, conclusions only | examined | Conclusions used. Ledgers and member files of that run were not opened. |
| Crane architecture skill | optional | examined | Diamond, repo slot, package struct rule. Fallback source not opened. |
| Held-reserve rule | optional | examined | Present. Not extended into a new hook product. |
| QuoteTarget bodies | not required | not examined | Call sites were grepped. Bodies were not read. The mint equation is not taken from them. |
| `ConstProdUtils` body | callee of the rejected fee path | not examined | Call site and the wrap report were enough to reject the path. |
| PoolManager, quoter, periphery router | not in the admitted scope | not examined | Requirements fail closed where that source would be needed. |
| Excluded third-party pair-token source | forbidden | not examined | Not searched, not opened, not quoted. |
| Peer responses, draft, final | forbidden on this pass | not examined | Peers read before submission: no. |

## Conclusions

Observation. The executed V2 mint is `floor(uReceived * (S + 10^d) / (U_before + 1))`. I re-read `BetterMath._convertToShares` and the InTarget branches that call it. Received units are not in the denominator. The comment in `_exchangeOut_zapInVaultDeposit` that adds `lpReceived` into the denominator is not the executed mint. On the exact-in LP branch, `S` includes fee shares just minted from a reserve-dependent estimate, and `U_before` is a live pair balance. On the zap-in branch, `U_before` is the booked LP reserve, and a live-balance mismatch reverts.

Observation. The executed exact-in exit burns shares, assigns LP with the floor inverse, and, when a pool token is requested, withdraws that LP amount and swaps only the other token from that withdrawal.

Observation of the admitted reports, not a new execution. A live square-root price, a same-pool TWAP, and a whole-book liquidation quote are not a safe issuance denominator. A deposit swap plus an exit swap does not close the prior extraction result. The wrap report left the receipt shape open and rejected summing liquidity across ranges. The fee-vault report's idle-target share does not put depositor capital in the pool. Current Wings `getRate`, as that prior work describes it, is a whole-book quote over supply. This response does not redefine `getRate`.

Inference. A V4 position is not a V2 pair token. One range's liquidity is a homogeneous unit only for that `(pool, range)`. Fees owed to the position are token amounts, not extra units of that liquidity. Marking those tokens at spot, or minting shares from a reserve-ratio fee estimate, puts a price-dependent quantity into acceptance. Booking them as token entitlements of the pre-change supply does not.

Proposal. The specification below adopts one non-transferable liquidity-unit receipt for one position, an outer ERC-20 share minted only by the re-read floor equation, fee value in token units through a per-share accumulator, no swap on entry, a slice-only sale on exit, the diamond as the only PoolManager callback address, and `getRate` as the normalized one-whole-share withdrawal-and-sale preview. It rejects the basket, the idle-target fee-vault, the V2 fee-share mint, the OutTarget comment's denominator, and any claim that the exit sale closes extraction.

No council consensus is available. Peers were not read. The basket dissent carried below is the wrap report's recorded disagreement, not a vote from this pass.

This specification is not implementation authorization. It does not authorize tests, installs, deployment, or Git.

## Proposed specification

Normative language: must, must not, and revert are requirements. Equations are exact integer requirements, not measured runs. Nothing here authorizes an agent to implement it.

Names in this section are requirements vocabulary for a later IndexedEx package. They are not names, constants, or control flow from an excluded implementation.

### Shared terms

- The vault is one Crane diamond proxy. `address(this)` during a facet delegatecall is that proxy.
- One position: one pool key, one `tickLower`, one `tickUpper`, one salt. All four are fixed at initialization.
- `target` is one of the pool's two currencies, fixed at initialization. The other currency is `opposing`. `target` need not be `currency0`.
- `U` is booked liquidity of that one position, in the pool's liquidity units, as an integer. It is not a token balance and not a price.
- `S` is the outer share total supply.
- `d = 9`. `shareDecimals = 18`. `oneShare = 10^18`. `Q = 2^128`. These are fixed at initialization. `d` is the virtual-share offset, not the target's decimals. `dT` is the target currency's decimals, used only to scale `getRate`.
- `10^d` and `+ 1` appear in both the mint and the liquidity assignment. They are not a second offset added only on mint. They are not real shares minted to the vault or to `address(0)`.
- Floor division reverts on overflow. It does not wrap.

The V2 package I opened stores share decimals 18 and `decimalOffset` 9 (`UniswapV2StandardExchangeDFPkg.initAccount`). Adopting those two integers keeps the virtual term equal to the conversion I re-read. The new vault must not be that V2 package, and it must not use that package's reserve asset. The pair token is not this receipt.

### Decision 1. Receipt shape

Chosen rule. One homogeneous receipt for one `(pool, range)`.

The receipt is the booked liquidity `U` of the single position. Each liquidity unit is an equal claim on that position's liquidity and on no other range, no idle donation, and no fee tokens that accrued before the unit was credited. The receipt is not a second token. It cannot be transferred, withdrawn, or sold apart from the outer share. The only transferable claim is the outer ERC-20 share of this diamond.

The outer share owns that receipt and a fee-accumulator claim defined in Decision 3. It does not own an unaccounted idle sleeve, another range, or a right to be minted against a liquidation quote.

Rejected alternative. A componentwise basket of idle balances and liquidity per range, with an in-kind proportional join.

Evidence class. Proposal for this vault. The wrap report left both shapes open and said summing liquidity across ranges fails because equal numerical liquidity in two ranges is not the same claim. That rejection is a source observation of the report. Choosing the single receipt is a proposal required by this question's one position and one liquidity-unit claim.

Dissent carried, not resolved by peers. The wrap report records the basket as a sufficient price-free join when every backed component is funded in its own units. That dissent stands for a multi-component book. It is not this vault. This specification does not claim the basket is unsafe inside the conditions that report stated. It claims this vault does not have that book.

Also rejected. A wrapper whose unit is principal marked at a square-root price, a quote, a sum of liquidity across ranges, or `floor(supply * credit / quote)`. Evidence class: source observation of the wrap report's "what fails" statement. Not re-derived from Wings source in this pass.

### Decision 2. One outer share, one range

Chosen rule. One outer share must not own more than one range.

Initialization binds the diamond to one position. No later call may add a second tick range, replace the salt, or add another position's liquidity into `U`. A second range is a different vault. Rebalancing and range moves are out of this specification.

Rejected alternative. Several ranges under one share, whether by summing liquidity or by a componentwise join inside this share.

Evidence class. The sum is already rejected by the wrap report (source observation of that report). Extending one share across ranges by a basket join is the Decision 1 dissent, not a second mode of this vault (proposal).

### Decision 3. Fees

Chosen rule. Trading fees increase holder value in token units, through a per-share accumulator. They do not change `U` or `S` at acceptance, and they are not marked at spot.

Unit. `currency0` and `currency1` native amounts owed for fee growth on existing liquidity. Not extra liquidity. Not target NAV. Not a square-root price. Not a TWAP.

When. On every deposit, exit, and permissionless `sync`, before `S` or `U` changes. `getRate` applies the same pending delta in the preview and writes nothing. A bare token transfer is not recognition.

Who captures fees that existed before the deposit. Only shares that were already in `S` when that fee growth accrued. The depositor's new shares start with a zero claim on the pre-sync accumulator. A deposit must checkpoint first. Leaving owed fees uncredited so the new supply can take them on exit is forbidden. The fee-vault report's uncredited-fee counterexample is a different ratio; the requirement it illustrates is adopted as a boundary: old fees are not a donation to the next mint (source observation of that report, applied here by proposal).

Accounting, with `S > 0` at the sync:

```text
feePerShare_i += floor(delta_i * Q / S)
dust_i += delta_i - floor(floor(delta_i * Q / S) * S / Q)
```

`delta_i` is the newly owed amount of currency `i` that belongs to the pre-change liquidity and was not already included in `feePerShare_i`. Dust is unallocated. Dust must not enter `U`, must not be paid to a holder above that holder's checkpoint claim, and must not be given to a later depositor by folding it into a future `delta`.

If `S = 0`, any nonzero tokens the protocol reports are dust under that same rule. They are not the first depositor's mint bonus.

On each holder's balance change, settle that holder first:

```text
owed_i = floor(balance * feePerShare_i / Q) - debt_i
unclaimed_i += owed_i
debt_i = floor(balance * feePerShare_i / Q)
```

Then apply the balance change and set `debt_i = floor(newBalance * feePerShare_i / Q)`. A mint therefore adds shares with no increase in `unclaimed`. An exit pays `floor(unclaimed_i * sharesBurned / balanceBefore)` of each currency after the pre-burn settle, and reduces `unclaimed_i` by that amount. A transfer settles both parties so the transferred shares' accrued claim moves with the shares. Transfer must not change `S`, `U`, or `feePerShare`.

Holder value increases because `feePerShare_i` increases when the position earns fees. That increase is not a share mint. A spot move that does not change owed token amounts must not change `shares` minted for a given `uReceived`.

Fees are counted once. Tokens the protocol pays on a removal fund the accumulator claims. They are not a second payment to the exiting holder, and they are not new liquidity.

Rejected alternatives.

- V2 `_calcVaultFee` / `_calcAndMintVaultFee`, which mints shares to `feeTo` from a reserve-dependent LP-equivalent before the depositor conversion and adds those shares to `S`. Evidence class: source observation of that call site. The wrap report left the economic significance of that reserve read untraced. This specification does not adopt the path, so `S` on the depositor mint is not fee-adjusted by a price.
- Marking uncollected fees at the current square-root price and putting that mark in the issuance denominator, in `S`, or in `U`. Evidence class: source observation of the wrap report's fee limit; proposal of the rejection.
- Converting fee tokens into extra liquidity before the mint. That conversion needs a composition at the current price. Evidence class: inference from the fact that liquidity is a two-currency position; not a PoolManager trace.
- The fee-vault report's idle-target assignment, where depositors do not fund the position and opposing fees are not sold. Evidence class: source observation of that report. Different object. This vault's depositors fund the position, so opposing fees are realized only on the slice exit in Decision 5, not at acceptance.

No usage-fee share is in this specification. A later authorization could take a fraction of collected fee tokens in kind before they enter `delta_i`. It must not do that by minting shares from a price. This file does not add that take, and the mint path must not call a fee oracle.

### Decision 4. Single-token entry

Chosen rule. Single-token entry that swaps is not in this specification.

Specified entry is a two-currency add to the one position. Either amount may be zero. The vault must not swap to manufacture the missing side. If the current tick and the range make one side unused, that side is refunded in the same call. If the amounts produce no liquidity, the call reverts. Tokens that do not become liquidity are refunded. They are not booked as fees, as `U`, or as a claim on existing liquidity.

A same-pool swap placed before this call by some other contract is outside the vault. The vault must not itself swap on deposit.

What a same-pool deposit swap would not protect, if a later specification added one. It would change how much liquidity the input produces. It would not remove execution-price exposure from that quantity. Paired with the exit sale, it would not close the extraction result in the swap-capture conclusions. This specification does not add that swap and must not be read as claiming the pair of swaps is safe.

The current tick may determine which currency the add consumes and how many liquidity units the consumed amounts produce. That is composition of `uReceived`. It is not the issuance denominator. The denominator remains `U_before + 1`.

Rejected alternatives. Zap-in through the pool, as V2 does before counting LP. Evidence class: source observation of the InTarget zap branch and of the wrap report's statement that spot enters the LP quantity there. An exact-out entry that sizes the share count from pool reserves. Evidence class: the OutTarget function I opened sizes a zap from reserves after a fee-share mint; the wrap report says exact-out can consult reserves before the converter. Not adopted. ERC-4626 `deposit` of the target token as the reserve asset. Evidence class: proposal. V2's conversion asset is the pair token, which I observed. Target wei are a different unit. Using them as `assets` would reintroduce a mismatched-unit mint.

### Decision 5. Single-token exit

Chosen rule. Exit burns shares, removes only that slice's liquidity, and sells only the opposing currency from that slice.

```text
uOut = floor(shares * (U + 1) / (S + 10^d))
```

`S` and `U` are the pre-burn values, after the fee sync and with no fee-share mint. This is `_convertToAssets` with Floor, which I re-read. It is not `floor(shares * quote / S)`. It is not a whole-book liquidation.

The call then removes exactly `uOut` from the one position. It does not remove the rest of the position. It pays the exiting holder's fee claim from Decision 3, once. It swaps exactly the opposing amount from that removal plus the opposing amount of that fee claim. The swap input is that sum and no more. It does not include the vault's remaining opposing inventory, other holders' fee tokens, unallocated dust, or donated balances. It does not flash-borrow opposing. It does not remove more liquidity to improve the fill.

Target paid is target from the removal, plus target from the fee claim, plus target proceeds of that swap. The pool fee on that swap is a cost of the exit, not a second fee minted to the exiting holder. Fees the remaining liquidity earns because it filled the swap accrue to the remaining position after the exiting claim is fixed. They are not paid back to the exiting holder. No sign is assigned to that residual. The swap-capture report left self-fill sign in disagreement; this file does not re-litigate it and does not claim the residual is zero.

Failed-sale rule. The single-token exit reverts unless the swap completes and the target paid is at least the caller's `minTargetOut`. Revert restores `S`, `U`, position liquidity, fee accounting, and balances. Unfilled opposing is not credited as target. Target is not taken from other holders, from dust, or from donated balances. Partial success is forbidden. Returning opposing in kind is not this exit. An in-kind two-currency withdrawal is a different product and is out of scope.

Also revert if `shares` is zero, if the caller cannot burn those shares, if `uOut` is zero, or if `uOut` exceeds `U`. V2 `_redeemLpSharesFrom` burns and then converts; I did not see a zero-asset revert there. The zero-`uOut` revert is a proposal, stricter than that path, so a rounded-away liquidity claim is not deleted and donated to survivors.

The sale is mandatory when the slice's opposing amount is nonzero. The vault must not keep that opposing inside the position or on the diamond in order to skip the swap. If the slice's opposing amount is zero, the swap input is zero and the target paid is the target side only.

Rejected alternatives. Selling the vault's remaining opposing balance, which the swap-capture conclusions attribute to the current Wings short-sleeve path. Evidence class: source observation of that report's conclusions; I did not re-open Wings in this pass. Paying `floor(shares * liquidateAll(book) / S)`. Evidence class: source observation of the wrap report's exit proposal and of the swap-capture conclusions. Treating a failed swap as a successful target payment. Evidence class: proposal, consistent with the wrap report's failed-sale proposal and stricter about in-kind residual.

This exit does not close the prior extraction result. A deposit swap plus this sale still does not. The specification must not claim that it does.

### Decision 6. Diamond boundary

Chosen rule. The diamond proxy is the position owner and the address PoolManager calls back.

The diamond calls `unlock` on the pool manager. The callback selector is on a facet cut of that same diamond, so the callback executes by delegatecall with `address(this)` equal to the diamond. No other address in the package may be the unlock caller, the callback target, or the position owner. A library used by delegatecall is still the diamond. An external helper that calls `unlock` is not.

The diamond owns the position, `U`, `S`, the fee accumulator, the dust balances, the target identity, and token balances that are removal or fee proceeds during the callback. Those in-flight proceeds are paid, refunded, or booked as fee-claim funding before the callback returns. They must not become `U`. After the callback, position liquidity equals `U`. Donated currency balances are not holder property and are not swap inputs.

A facet may store, in its own bytecode immutables, values that are identical for every vault using that facet, such as a chain-singleton pool manager. A facet must not store the position key, `U`, `S`, the fee accumulator, dust, or the target in facet-address storage. Those live in a diamond repo slot, ERC1967 form as in the crane-architecture skill. `PkgInit` and `PkgArgs` for the package live on the package interface, not on the package contract.

Direct calls to the facet implementation must not be able to own a position. The implementation's own storage is never initialized. Position-changing entry points revert unless diamond storage shows this proxy was initialized. Uninitialized storage reverts.

During an open unlock, the only share-supply change allowed is the single mint or burn that opened that unlock. The callback must not reenter deposit, exit, or `sync` in a way that mints or burns again.

What must not be built. A copied external clone, a child vault, an adapter, or a forwarded position manager whose address is the PoolManager callback. The position-modifying logic is this package's facet, executing as the diamond. This specification does not make the vault the pool's hook. The pool may already have a hook. That hook is not given allowance to spend the vault. This file does not name or track an excluded implementation.

Rejected alternative. A facet or clone that holds the position and is the callback address, with the diamond as a bookkeeping front. Evidence class: proposal required by the brief's callback sentence, plus the skill's observation that facet logic executes as the diamond. I did not open PoolManager source.

### Decision 7. `getRate`

Chosen rule. `getRate` is the normalized preview of withdrawing one whole share and selling that slice. It is not an issuance NAV. It is not `liquidateAll(book) / S`. This council does not redefine it.

```text
uOut = floor(oneShare * (U + 1) / (S + 10^d))
```

Preview, without writing state: sync the pending fee delta under the current `S`; take one whole share's pro-rata of the aggregate holder fee entitlement

```text
fee_i(oneShare) = floor(oneShare * F_i / S)
```

where `F_i` is the total currency-`i` amount holders are collectively entitled to after that virtual sync, including pending fees and excluding dust. Remove `uOut` in the simulation, using the pool's current composition for that slice only. Add `fee_i` for the opposing and target currencies. Quote a swap of exactly that opposing input in this same pool, against the pool state after the simulated removal, including the pool fee. Do not quote a spot multiplication. Do not quote a TWAP. Do not quote a sale of the remaining book.

```text
q = targetFromRemoval + fee_target(oneShare) + saleProceeds
getRate = floor(q * 10^18 / 10^dT)
```

`q` is target native units for one whole share (`10^18` share wei). `getRate` is WAD whole target tokens per whole share, so a rate provider can return it without a second scaling. The held-reserve section says providers expose that WAD shape and fail closed on revert, short return, or zero. This file does not change that section and does not deploy a provider.

`getRate` must revert, and a provider must be able to treat that revert as failure, when:

- `S = 0` or `S < oneShare`
- `uOut = 0` or `uOut > U`
- the position is missing, the pool is uninitialized, or the slice composition cannot be simulated
- opposing input is nonzero and the sale cannot be quoted as that exact input after removing only `uOut`
- the quoted sale output is zero while opposing input is nonzero
- `q = 0`
- the call is made while unlock settlement is open
- producing the number would require an independent oracle, a same-pool TWAP as the value, a whole-book liquidation, or selling more than the slice

Do not return a synthetic `10^18` at zero supply. The swap-capture conclusions describe that synthetic as the current Wings behavior. It is not this preview.

`getRate` is a view. It must not swap, modify liquidity, or mint shares. The mint path must not call `getRate` and must not use its result as a denominator.

A named holder's exit can differ from `shares * getRate / 10^18`. Fee checkpoints differ by mint time, the multi-share sale is nonlinear, and `getRate` uses pro-rata `F_i`, not one holder's `unclaimed`. The actual exit pays Decision 5. It must not be "corrected" to pay `shares * getRate / 10^18`.

The held-reserve rule values a buffered holding as `held x rate`. That linear product is not equal to a multi-share slice sale. This specification does not resolve that gap and does not authorize a hook to replace the one-share preview with a whole-book quote. A hook that holds this share must not value it by `previewExchangeIn` or `quoteAssets`. Raw share balance is not a target valuation: the share is not the target token, so the identity-leg case in that rule does not apply. This file does not create that hook.

Small positions fail closed. With `d = 9` and the first-mint ratio `S = U * 10^d`, one whole share previews `10^9` liquidity units. Until `U` can fund that preview, `getRate` reverts. That is the requirement, not a reason to change the definition of a whole share.

Rejected alternatives. `floor(oneShare * A / S)` from the fee-vault report, which is idle target over supply and sells nothing. Evidence class: source observation of that report. Whole-book Wings `getRate`. Evidence class: source observation of the swap-capture conclusions. A per-wei rate. Evidence class: proposal; the retained meaning is one whole share.

### Decision 8. Invariants a later agent must test

These are requirements for a later authorized test pass. This run does not authorize writing or running them.

1. Mint equality. After a successful deposit, shares minted equal `floor(uReceived * (S_before + 10^d) / (U_before + 1))`, with `S_before` and `U_before` excluding the new shares and the new liquidity, and with no price-derived fee mint in between.
2. Denominator. The received liquidity is not in the denominator. A path that uses `(U_before + uReceived + 1)` is a defect. So is a path whose denominator is a square-root price, a same-pool TWAP, a liquidation quote, an idle balance, or a fee balance.
3. Spot invariance of the mint. Given the same `uReceived`, `S_before`, and `U_before`, a spot move does not change shares minted. The same move may change how many liquidity units a token amount produces, and may change `getRate`.
4. One position. After initialization, pool key, ticks, and salt are unchanged. `U` contains no other range.
5. Book integrity. `U` increases only by `uReceived` of a successful deposit and decreases only by `uOut` of a successful exit. At the start and end of those calls, position liquidity equals `U`. A bare currency transfer does not change `U` or `S`. A mismatch reverts.
6. Old fees. After fees accrue and another party deposits, the new holder's claim on that already-accrued fee is zero. Dust is not paid to the new holder. `S` and `U` are unchanged by the fee sync itself.
7. Slice sale. The swap input of an exit equals the opposing amount from removing `uOut` plus the opposing fee claim of the burned shares. The remaining position's liquidity and the other holders' fee claims are not inputs. Donations and dust are not inputs.
8. Failed sale. If the swap cannot complete or `minTargetOut` is not met, state is unchanged. Unfilled opposing is not reported as target. No other holder's target is spent.
9. `getRate` identity. In a static state, `getRate` equals the Decision 7 preview, or it reverts in a listed case. It is not `liquidateAll(book) / S`. The mint function does not read it.
10. No deposit swap. A deposit call does not submit a swap. A zero-liquidity deposit reverts and does not mint shares.
11. Callback address. The pool manager's unlock callback is invoked on the diamond. The facet implementation's address is not the position owner. A direct call to the facet cannot open a position.
12. Transfer. A share transfer does not change `S` or `U`, and does not let either party claim the other's remaining fee entitlement.
13. Rounding and offsets. Mint and exit both floor. Both use `d = 9` and `+ 1`. No extra virtual shares are minted. First deposit with `U_before = 0` and `S = 0` mints `uReceived * 10^d` shares. Redeeming all of those shares assigns `uReceived` back, before fees.
14. Exit is not the rate times shares. A multi-share exit pays the actual slice result. It does not pay `shares * getRate / 10^18`.
15. Non-claims. No invariant says a round trip is profitless, that incumbent token principal is unchanged after the exit sale, or that a deposit swap plus this exit closes the prior result. A later profit on an external swap plus this exit does not contradict this specification. A mint denominator that moves with spot does.

### Normative sequences

Initialization. Position liquidity is zero, `U` is zero, `S` is zero, accumulators are zero. `target` is one pool currency. Ticks are aligned to the pool's spacing and ordered. The diamond, not a facet address, will be the unlock caller. No seed liquidity and no pre-minted real shares. Virtual shares exist only inside the formula.

Deposit. Revert if position liquidity is not `U`. Checkpoint fees under `S`. Pull the caller's currencies. Inside the diamond's unlock, add liquidity to the one position and measure the liquidity delta the protocol actually applied. That delta is `uReceived`. Refund unused currencies in the same call. Revert if `uReceived` is zero. Mint `floor(uReceived * (S + 10^d) / (U_before + 1))` shares to the recipient. Revert if that quantity is zero or below the caller's minimum. Set `U` to `U_before + uReceived`. The recipient's fee debt is set so the new shares have no claim on the pre-sync accumulator. Revert if position liquidity is not `U` at the end.

The preview of a deposit uses that same equation. If the protocol's actual delta differs from a pre-quote, shares are computed from the actual delta, and `minShares` protects the caller. The preview is not `getRate`.

Exit. Revert if position liquidity is not `U`. Checkpoint fees under `S`, including the exiting holder. Compute `uOut` from the floor inverse. Revert if `uOut` is zero or greater than `U`. Settle and burn the shares, paying the fee claim once. Remove only `uOut`. Swap only that slice's opposing amount. Pay target to the receiver. Revert on a failed swap or a missed minimum. Book `U` down by `uOut`. Fees earned by the remaining liquidity from that swap are not part of the exiting claim.

`sync`. Checkpoint fees. Do not change `S` or `U`. Do not swap. Do not transfer holder claims out.

### Worked ratio check

This is algebra on the adopted equation, not a test run. First deposit: `S = u * 10^d`, `U = u`. Redeem-all assigns `floor(u * 10^d * (u + 1) / (u * 10^d + 10^d)) = u`. A second deposit of `u1` against that book mints `u1 * 10^d`. Fees must stay out of `U` and `S` for that cancellation to survive. That is why Decision 3 does not mint fee shares and does not convert fees into liquidity.

## Limits

- Runtime or extraction proof: none. No project test, Forge trace, or pool-manager execution was run. The equations were not executed.
- Not examined: PoolManager, quoter, and periphery source; `ConstProdUtils` body; QuoteTarget bodies; other OutTarget routes beyond `_exchangeOut_zapInVaultDeposit`; peer responses; the draft; the final. Swap-capture ledgers were not re-run.
- `getRate` times a large balance is not the multi-share exit. The locked hook law linearizes. This file does not change either rule and does not close the gap.
- Self-fill sign and post-sale principal preservation are not settled here. The wrap and swap-capture reports left them open. This specification does not assign them.
- The basket remains a prior-report dissent for a different book. I did not read this pass's peers, so I do not know whether they adopt Decision 1.
- A same-block price move can change slice composition and `getRate` without changing the mint equation. That is disclosed. It is not an independent price.
- Live files can move. Line-level claims are from the tree opened for this response.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
