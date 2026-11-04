# Member response

## Identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Member label: astra
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/astra/response.md
- Requested role: council-member
- Requested model and reasoning: chatgpt-subscription/gpt-6-astra:high
- Actual role: not exposed
- Actual model and reasoning: not exposed
- Task ID: not exposed
- Session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Specify IndexedEx's own Crane diamond vault whose deposited capital backs one homogeneous Uniswap V4 position, whose issuance is price-free in liquidity-claim units, and whose share has a one-target-token withdrawal-and-sale preview and exit.
- Required targets: `contracts/protocols/dexes/uniswap/v2`; `docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md`; `docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md`; conclusions only of `docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md`.
- Optional context: Crane architecture skill, read at its canonical path `lib/crane/.claude/skills/crane-architecture/SKILL.md`; held-reserve valuation section of `docs/agent/INDEXEDEX_AGENT_LAW.md`.
- Admitted read scope: the brief, required targets, their direct V2 conversion and withdrawal dependencies, optional context, and repository/council instructions. No excluded third-party source, current peer response, current draft, or current final was read.

## Evidence

All repository paths below are relative to the IndexedEx root. Observations concern text opened in this run, not a deployed instance.

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| E1 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol`, `_exchangeIn`, LP deposit branch, lines 556-616 | source observation | The converter receives the pre-inbound LP reserve. On the pretransfer route the code subtracts this call's inbound amount from the live balance; otherwise it snapshots the live balance before pulling. Fee shares are checkpointed before conversion. |
| E2 | Same file, `_exchangeIn`, zap-in branch, lines 700-778 | source observation | The code requires live LP to equal the booked reserve, obtains LP through `_swapDeposit`, and converts the received LP against the pre-zap booked reserve. |
| E3 | `lib/crane/contracts/utils/math/BetterMath.sol`, `_convertToSharesDown`, `_convertToShares`, `_convertToAssetsDown`, `_convertToAssets`, lines 693-800 | source observation | Mint uses floor rounding and `(totalShares + 10 ** decimalOffset) / (reserve + 1)`. Redeem uses the inverse ratio with floor rounding. I re-read these bodies before choosing the equations below. |
| E4 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol`, `_exchangeIn`, zap-out branch, lines 785-883; `UniswapV2StandardExchangeCommon.sol`, `_redeemLpSharesFrom`; `UniswapV2StandardExchangeInFacet.sol`, `_redeemConstantProduct` | source observation | Exact-in redemption assigns LP with the inverse converter and passes that assigned LP into withdrawal and sale. The facet's native redemption delegates to the common path. |
| E5 | `lib/crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol`, `_withdrawSwapDirect`, `_determineTokenAmounts`, `_swapWithdrawnTokens`, lines 428-470 | source observation | Withdrawal returns two amounts. The service sells the opposing amount returned by that withdrawal and adds the withdrawn target amount. It does not size this sale from the vault's entire opposing balance. |
| E6 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol`, `_calcVaultFee`, `_calcAndMintVaultFee` | source observation | V2 fee shares use a reserve-dependent fee estimate and then increase the supply used by conversion. This is not a reason to copy that fee calculation into a price-free design. No economic exploit of that fee calculation was established here. |
| E7 | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`, `_exchangeOut_zapInVaultDeposit` | source observation | Its explanatory comment includes received LP in a purported mint denominator, but its actual conversion call uses `vault.vaultLpReserve`. E1-E3, not that comment, determine the equation. |
| E8 | `docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md`, Conclusions, especially "What a wrapper must emit" and "Equations, if a sufficient shape is met" | source observation | The report leaves homogeneous receipt versus componentwise basket unresolved, rejects adding unlike ranges, and requires fee attribution and slice-bounded liquidation. It explicitly does not establish post-sale immunity. |
| E9 | `docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md`, Conclusions and Accounting | source observation | Its chosen target-backed product does not put depositor capital in the fee position. Its accounting corrections show why fee timing and consistent mint/exit ratios matter. Its sponsor assignment is not supplied by that report. |
| E10 | `docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md`, Conclusions, lines 34-94 only | source observation | The accepted conclusions reject deposit-plus-exit swaps as a general repair, preserve the zero-old-opposing case, distinguish acceptance proportionality from post-sale behavior, and deny an independent-price interpretation of the same-pool reference. These conclusions were accepted, not re-litigated. |
| E11 | `lib/crane/.claude/skills/crane-architecture/SKILL.md`, Core Pattern, Storage Slot Pattern, Diamond Factory Package, IFacet | source observation | State belongs to namespaced repositories used by targets through the diamond. Facets expose selectors and metadata. Package argument structures belong on interfaces. |
| E12 | `docs/agent/INDEXEDEX_AGENT_LAW.md`, "Uniswap V4 SE buffer hooks: held-reserve valuation", lines 233-243 | source observation | Held reserves are raw balances or balances times configured rates. Buffered non-identity legs require providers. Reads fail closed; a hook does not replace that rule with a held-size vault preview. |

Public queries: not used. No source excerpts were sent to a public search or fetch service. The equations and operation contracts below are proposals and static reasoning, not runtime evidence.

## Assumptions

- **Proposal, not an existing product requirement:** this initial package supports one initialized, hookless, fixed-fee pool, two ERC20 currencies, and one immutable range. Arbitrary hooks, dynamic fees, native currency, rebalancing, and multiple ranges are excluded. This makes exact withdrawal-and-sale simulation a bounded protocol integration problem rather than simulation of arbitrary hook programs.
- Both currencies follow the repository's supported-token policy: no transfer fees or rebasing. Pausing and blacklisting may make an operation fail. A quote cannot certify that an arbitrary future receiver will pass token-specific restrictions.
- The target is one of the two pool currencies. The same pool may be its only exchange venue. No outside price, arbitrage restoration, sponsor, or independent liquidity source is assumed.
- **Proposal:** there are no vault-level management fees, performance fees, or fee-share mints in this version. Pool trading and protocol fees remain part of actual execution. A later vault-fee policy needs a separate requirement decision.
- The homogeneous position is directly owned by the diamond, not through a transferable position NFT or an external receipt issuer.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| V2 executed share conversion | required | examined | E1-E3; converter body re-read, including the inverse. |
| V2 executed single-token exit | required | examined | E4-E5; traced from facet/common or exact-in dispatcher into the withdrawal-sized sale. |
| V2 fee and exact-out context | supporting | partially examined | E6-E7; relevant functions read, not a review of every V2 route. |
| V2 wrapper report | required | examined | Read its conclusions, equations, alternatives, qualifications, and remaining sections. |
| Single-token fee-vault report | required | examined | Read; distinguishes the separate sponsor-funded design from this depositor-owned position. |
| Swap-capture report conclusions | required | examined | Only the requested conclusions and their subsections were opened; no model rerun. |
| Crane architecture | optional | examined | Canonical skill opened; architecture requirements below are proposals aligned with it. |
| Held-reserve law | optional | examined | The requested section was present and opened. |
| Eight decisions | required | examined | Each is settled below with a rejected alternative and evidence class. |
| V4 implementation/runtime conformance | not part of this read assignment | not examined | This is an independently proposed specification, not a claim that existing V4 contracts already satisfy it. |

## Conclusions

**Proposal:** adopt a componentwise receipt with exactly one range: one raw liquidity unit plus its pro-rata entitlement to the two fee currencies. Require a new depositor to fund both the new liquidity and the existing fee balances proportionally in kind. This is the basket option, deliberately limited to one homogeneous position. It is not a pure-liquidity wrapper that silently grants new holders old fees.

This choice keeps accrued fees attached to transferable shares and included in their exit preview, without a spot-priced fee conversion, forced compounding, or historical fee debts attached to individual accounts. Its cost is explicit: deposits may require both tokens even when the position itself is one-sided. Single-token entry is not part of this version. Single-token exit is supported when the redeemed slice can actually be sold; otherwise it reverts, and a separately requested in-kind redemption remains available.

No statement below authorizes implementation. There is no claimed council consensus: current peer responses were not read.

### Definitions and common accounting

**Proposal.** Use the following units and records:

| Symbol | Meaning |
| --- | --- |
| `K` | Immutable pool identity: PoolManager, both ordered currencies, fee configuration, tick spacing, and hook identity. The selected hook identity is zero. |
| `R` | Immutable lower tick, upper tick, and position salt. Owner is the diamond address. |
| `L` | Actual raw liquidity of precisely `(K, R, diamond)`. |
| `U` | Internally recorded receipt units, always equal to `L`. One unit identifies one raw unit of that position's liquidity; it is not an amount of either currency. |
| `F_i` | Accounted fee reserve in native units of currency `i`, after fee collection. Includes prior fee-matching contributions; excludes position principal, unsolicited transfers, and current depositor credit. |
| `P_i` | Additional collectible position fees since the last checkpoint, in native units of currency `i`. A preview uses `F_i + P_i` without mutating state. |
| `S` | Outer ERC20 share supply. |
| `u` | Actual newly funded liquidity units, not a target-valued input credit. |
| `s` | Exact number of shares requested for redemption. |
| `d` | V2 converter decimal offset. Fixed at zero for this package. This is distinct from ERC20 display decimals. |
| `h` | One whole outer share in raw units: `10^18`. Outer shares have 18 display decimals. |
| `dT` | Target token decimals, validated and fixed at deployment. |

No inner ERC20 contract is needed. `U` is an auditable internal receipt ledger; the diamond's outer ERC20 is the only transferable receipt. The following specialization is intentional:

```text
d = 0
U = L
S = U
```

No authorized operation may change `S` or `U` alone. In particular, no administrative mint, reserve donation credit, performance-share mint, or liquidity-only compound exists. Fees grow `F_0` and `F_1`, not `U`.

This makes the virtual offsets symmetric and harmless to the stated proportional join. It also avoids inventing an unsupported fractional ownership ratio between an internal wrapper and its wholly owned outer vault.

### Decision 1: Receipt shape and exact mint equation

**Chosen rule - proposal:** select the componentwise basket:

```text
B = (L, F_0, F_1), with exactly one identified range
```

Only the first component is liquidity. Fee currency balances are separate native-token components and must not be summed into `L`. A receipt unit carries prospective earnings from its liquidity and a proportional claim on already accrued, accounted fees. There is no unrelated idle investment sleeve.

For `U > 0`, checkpoint all collectible old fees before admission, producing `F_i`. A requested new liquidity amount `u > 0` requires:

```text
feeMatch_i = ceil(u * F_i / U), for i in {0,1}

principalCost_i = actual currency i cost of adding u liquidity
depositUsed_i = principalCost_i + feeMatch_i

sharesMinted = floor(u * (S + 10^d) / (U_before + 1))
```

`U_before` excludes `u`. Its value is captured before the position addition. `S` is also the pre-mint supply. No `sqrtPrice`, TWAP, target exchange rate, liquidation quote, or converted fee value appears in this equation. E1-E3 were re-read to establish precisely this V2 form.

With the selected `d = 0` and `S = U`, the equation gives `sharesMinted = u` exactly:

```text
L' = L + u
U' = U + u
S' = S + u
F_i' = F_i + feeMatch_i
```

The general converter form remains the specification, rather than a misleading comment with post-deposit `U + u` in the denominator. Implementations may algebraically simplify it only while enforcing the specialization.

At bootstrap, require `S = U = L = 0` and no accounted fee liabilities. Then `feeMatch_i = 0`, add actual funded liquidity, and mint `u` shares. Unsolicited pre-existing currency balances are not seed assets or deposit credit.

**Inference: acceptance proof.** Ignoring only the explicitly directed integer rounding, incumbent ownership is unchanged at admission:

```text
U / (U + u) * (L + u) = L, because L = U

U / (U + u) * (F_i + u * F_i / U) = F_i
```

With the ceiling fee match, incumbent fee backing cannot decrease. The entrant's extra fee match is less than one native unit per nonzero fee component. Full-precision multiplication/division is required; multiplication overflow may not silently change rounding.

**Rejected alternatives:** pure liquidity issuance that gives free access to pre-existing fees; target-valued fee buy-in; summing fee tokens and liquidity; a componentwise minimum over unlike units without actually funding each component; a separate copied wrapper contract; fee attribution that ignores latent collectible fees.

**Evidence class:** source observation for E1-E3 and E8; inference for the preservation equations; proposal for the basket choice, fixed offset, and matching rule. This is not observed V2 fee accounting.

### Decision 2: More than one range per outer share

**Chosen rule - proposal:** no. A package instance owns exactly one immutable `(pool, lowerTick, upperTick, salt)` position. Increasing or decreasing its liquidity is permitted. Changing the range, salt, pool, or target is not.

The componentwise receipt selected above contains one liquidity component and two fee components, not several range liquidities. A different range requires a different diamond and share token. There is no migration, rebalancing, range rolling, or manager-created second position.

**Rejected alternatives:** summing raw liquidity across Core/Upper/Lower or other ranges; treating numerical equality of liquidity as economic fungibility; retaining the old position while opening a new range under the same receipt. A true multi-range componentwise basket could be separately specified, but it is not this product.

**Evidence class:** E8 is source observation of why unlike ranges do not share a unit; choosing a one-range product is a proposal. It does not revive a retired V4 family.

### Decision 3: Fee recognition, holder value, and old-fee protection

**Chosen rule - proposal:** recognize both fee currencies in their native units, without a target mark and without mandatory compounding.

Before every mint and burn:

1. Reconcile position liquidity against `U`.
2. Collect all currently collectible fees for this position through the diamond's PoolManager interaction.
3. Separate fee amounts from principal amounts returned by any liquidity modification. Do not infer earned fees from a marked change in total position value.
4. Increase `F_i` by the actual settled fee amounts once. Record the corresponding fee-growth checkpoint so the same amount cannot be recognized twice.
5. Use these updated fee reserves in deposit fee matching or redemption allocation.

Collection may settle the entire position's fees even when only a slice is redeemed. Entire-position collection is not entire-position payout. The accounted remainder remains owed to remaining units.

Between checkpoints a share's economic fee entitlement includes `P_i`. Collecting changes custody and accounting, not who earned the fees. A permissionless checkpoint may collect and account fees but may not sell them, distribute them to its caller, mint shares, or alter liquidity.

At fixed `U`, fee growth increases `F_i / U` or its pending counterpart. Holder value increases through greater token entitlement per receipt, not by setting a target price for the book. Target realizability remains a separate execution question.

A new depositor receives a fraction of the resulting fee reserve only after contributing `ceil(u * F_i / U)` of each fee currency. Thus the entrant can own part of the old fee inventory, but cannot acquire that entitlement without funding an equal or greater replacement in the same token. There is no waiting-period trick and no delayed credit after the entrant joins.

Transfers move the whole fungible receipt, including its fee claim, to the new owner. They need no per-account historic fee debt. The same fee entitlement is included in the receiver's later redemption.

**Rejected alternatives:** crediting old fees after mint; fee conversion to target using spot or TWAP; an estimate of fee yield derived from price movement; forcing old holders to sell or compound all fees merely to admit a new depositor; detached dividends that would make total holder value differ from the share's withdrawal-and-sale preview. E9's separate sponsor-funded assignment is not a substitute for this owned-position fee claim.

**Evidence class:** E6, E8, and E9 are source observations; the funding argument is inference; this fee reserve and admission policy is a proposal.

### Decision 4: Single-token entry

**Chosen rule - proposal:** single-token zap entry is excluded from this version. The canonical operation is exact-liquidity, maximum-two-token-input admission:

```text
depositLiquidity(u, maxAmount0, maxAmount1, minShares, receiver, deadline)
```

These are proposed semantic arguments, not a claim about an existing ABI.

The operation must pull caller-attributed funds, checkpoint fees, determine the exact principal costs at the execution state, fund `u` liquidity plus both fee matches, verify `minShares`, and refund unused current-call inputs in kind. It must never use another holder's fees or an unbooked balance to complete the depositor's payment. Direct pretransfer credit is not supported in this version.

The input maxima are budgets, not received-value marks. The caller selects `u`; if the actual required currency amounts exceed either maximum, the entire operation reverts. Any discrepancy between actual liquidity added and `u` also reverts.

In a one-sided range an entry can incidentally require only one currency when both the principal cost and fee-match cost of the other are zero. That is not a generic single-token zap guarantee. Accrued opposing fees may require a second currency even when current principal is entirely target.

The operation performs no swap. There must be no unaccounted pool operation between its fee checkpoint and admission. Pull funds before the acceptance snapshot, guard callbacks, and verify the expected position/pool accounting before minting. Unexpected intervening changes revert rather than assigning them to the wrong cohort.

**Rejected alternatives:** silently swapping target input to meet all components; accepting target in lieu of a missing opposing fee contribution; minting from the amount of target received; returning a success receipt while postponing the missing component.

**Evidence class:** E2 and E8-E10 are observations of the entry/execution distinction; exclusion and operation semantics are proposals. A later same-pool zap would affect the amount of funded liquidity and execution exposure. It would not be a repair merely because exit also swaps. External acquisition of the two inputs can still trade against incumbent liquidity; this specification makes no immunity claim about that trade.

### Decision 5: Single-token exit and failed-sale rule

**Chosen rule - proposal:** burn exact shares, remove only their liquidity and fee slice, then sell only that slice's opposing currency. Exact-target-out redemption is not supported.

After checkpointing fees, snapshot `S`, `U`, and `F_i` before the burn:

```text
uOut = floor(s * (U + 1) / (S + 10^d))
feeOut_i = floor(uOut * F_i / U)
```

The selected specialization gives `uOut = s`. Require `0 < s <= ownerBalance` and `s <= S`. Allowance is required when burning someone else's shares.

Let `principalOut_i` be the actual proceeds of removing `uOut` from the single position, excluding fees already attributed by the checkpoint:

```text
slice_i = principalOut_i + feeOut_i
opposingToSell = slice_O
targetPaid = slice_T + actualTargetFromExactInputSale(opposingToSell)
```

The pool state for the sale is the state after removal. Fees earned by remaining vault liquidity during this sale belong to remaining receipts; they are not added to this departing redeemer's payout. They may remain pending until the next checkpoint.

Required post-accounting, apart from those new pending sale fees:

```text
L' = L - uOut
U' = U - uOut
S' = S - s
F_i' = F_i - feeOut_i
```

Settlement must have a separate call-local slice budget. The sale may not read `balanceOf(diamond)` as its permitted input. It must not sell the remaining fee reserve, remaining position, unrelated balances, or unsolicited surplus. Fees already included in `slice_O` are part of the redeemed slice, not permission to sell every collected opposing fee.

If `slice_O = 0`, omit the sale. Otherwise execute exact-input opposing-to-target in the same pool, subject to the caller's price limit, minimum total target output, and deadline. Require the entire opposing input to be consumed. A price-limit partial fill, insufficient depth, settlement failure, transfer failure, or minimum-output failure reverts the entire redemption, restoring the shares and position.

No residual opposing token is returned from a successful target-only exit. No synthetic target credit, IOU, stale rate payment, or borrowing from remaining holders is allowed.

Provide a separately named, explicitly selected `redeemInKind` operation using the identical slice allocation and returning `slice_0` and `slice_1` without swapping. It is not an automatic target-exit fallback. It permits exit when the vault is the only relevant liquidity provider and removal leaves no sale venue.

When `s = S`, the specialization removes all `U` and all accounted fees exactly. New bootstrap cannot inherit old accounted claims. Any unsolicited surplus remains excluded; there is no administrative sweep of accounted holder assets.

**Rejected alternatives:** paying `s * liquidateAll(book) / S`; selling all opposing balance; performing the quote before removal and treating it as execution; silently returning mixed tokens from a target-only endpoint; guaranteeing target liquidity that is not there.

**Evidence class:** E3-E5 are source observations of the V2 inverse and slice sale; E8/E10 delimit the safety claim; the V4 allocation, strict revert policy, and separate in-kind endpoint are proposals.

### Decision 6: Diamond ownership, callbacks, storage, and package boundary

**Chosen rule - proposal:** the ERC20 share address, PoolManager position owner, settlement caller, and PoolManager callback recipient are the same diamond address.

The diamond owns:

- The single position identified by `K`, `R`, and its own address.
- Accounted collected fee reserves, current-call settlement credit, and ordinary custody balances.
- `U`, share supply/balances/allowances, fee checkpoint records, immutable product configuration, reentrancy state, and bounded callback authorization.

Facets are shared executable code. They may use compile-time constants and shared code immutables that do not vary by vault. Per-vault values must be written and read through the diamond's namespaced Repo storage during delegatecall. Facet-local balances, constructor-written mutable storage, or an external singleton ledger must not be the backing of a vault claim.

The diamond initiates the PoolManager unlock and exposes its callback selector through its facet table. A callback is accepted only from the configured PoolManager during the expected operation. The context binds the operation kind, pool, range, caller credit, receiver, permitted currencies and amounts, and nonce or equivalent single-use authorization. Check the sender and the active context; neither alone is enough.

The callback must not be an arbitrary-call interpreter. It cannot supply a different range, redirect another user's settlement, spend fee reserves as deposit credit, or start a second user operation. User entrypoints remain guarded while the expected PoolManager callback is permitted through its dedicated path. Completion clears authorization and settles all currency deltas.

Ordinary share transfers need not harvest, but must not be usable to change supply or evade an active settlement guard. Views used as economic quotes must fail during an in-progress vault operation rather than exposing a partially updated book.

Facets/targets/services/repos follow E11. Package arguments live on the package interface. Deployment uses Crane FactoryServices/CREATE3 and the IndexedEx manager's registered package path as directed by `CLAUDE.md`; this is a later implementation requirement, not permission to deploy here. Initial package configuration must be complete before activation. This proposal has no post-activation owner path that changes the pool, range, target, accounting, or position custody.

**Rejected alternatives:** an independently calling helper that owns the position while the diamond claims to own it; state stored on shared facet addresses; an external cloned issuer presented as the vault's internal receipt; arbitrary callback calldata as authority; restoring a retired vault family or translating excluded third-party control flow.

**Evidence class:** E11 is source observation of Crane structure. Owner/callback identity is a supplied constraint from the brief. The operation context, state ownership, and immutable product boundaries are proposals; V4 runtime conformance was not tested.

### Decision 7: One-whole-share `getRate`

**Chosen rule - proposal:** `getRate()` previews the target output of this vault's actual one-whole-share target redemption. It is not issuance NAV.

At one coherent state `X`, form the same effective fee reserves an execution checkpoint would obtain:

```text
effectiveFee_i = F_i + collectiblePendingFee_i(X)

h = 10^18
u_h = floor(h * (U + 1) / (S + 10^d))
f_i(h) = floor(u_h * effectiveFee_i / U)

p_i(h) = principal produced by removing u_h at X
b_i(h) = p_i(h) + f_i(h)

X_minus = pool state after that exact removal
z(h) = exact-input target proceeds from selling all b_O(h) at X_minus
q(h) = b_T(h) + z(h)

getRate() = floor(q(h) * 10^18 / 10^dT)
```

For `b_O(h) = 0`, set `z(h) = 0` without invoking a swap quote. For this package `u_h = h`, provided the redemption is available.

The preview must simulate the removal's effect on active liquidity and initialized ticks before simulating the sale. It must include swap fees, integer rounding, tick crossing, available liquidity, and the canonical directional price limit. A spot multiplication, TWAP multiplication, pre-removal swap quote, or sum of individually quoted token values is not a conforming substitute.

The canonical limit is the protocol's widest valid limit for the opposing-to-target direction, fixed by the integration rather than supplied by a caller to `getRate`. The default target-exit preview uses the same limit. An executing caller may request a stricter limit and minimum output; those extra protections can cause execution to revert even when the canonical preview exists.

The economic preview is address-independent because accrued fees travel with fungible shares. It includes fees, not a detached historic account balance. A holder-specific transfer ban can still stop payment; the view does not promise an arbitrary receiver can accept tokens.

Revert on any of these conditions:

- Uninitialized instance or pool; unsupported/inconsistent bound configuration.
- `S = 0`, `U = 0`, `h > S`, zero assigned liquidity, or a broken `S = U = L` reconciliation.
- Active vault settlement or inability to read a coherent state.
- Fee accounting, principal simulation, or swap simulation failure, including an incomplete tick traversal or short/malformed dependency return.
- Full opposing slice cannot be sold under the canonical limit, including no residual sale liquidity after removal.
- Zero native target output, zero normalized output, arithmetic overflow, or unsupported normalization.
- Any detected settlement inconsistency that would prevent the modeled redemption.

Do not substitute `1e18` at bootstrap, zero on failure, a cached successful quote, or a whole-book average.

**Observation and inference:** E12 permits held-balance-times-configured-provider valuation; it does not make a provider independent or manipulation-resistant. A hook integrating this share must obey that held-reserve rule and bind the correct target-denominated provider. A one-share rate multiplied by many shares is the prescribed rate convention, not proof that liquidating that many shares yields the same total. Same-pool swaps can change this rate intra-transaction. This specification supplies no independent price and no assertion that the rate is safe for arbitrary downstream credit creation.

**Rejected alternatives:** `liquidateAll(book) / supply`; target NAV as issuance reserve; a rate excluding attached fee entitlement; an extrapolated one-share quote when one whole share cannot actually be removed; a sale of the remaining vault's opposing inventory.

**Evidence class:** E3-E5 and E8 support the withdrawal-first model as observations; the one-whole-share meaning is a supplied constraint; the exact preview contract and reverts are proposals. No existing preview engine was verified.

### Decision 8: Required invariants and later acceptance tests

**Chosen rule - proposal:** a later implementation must demonstrate the following through the real diamond and real protocol integration. These are requirements, not authorization to write or run tests in this assignment.

| ID | Required property and discriminating cases |
| --- | --- |
| I1: Identity | All position liquidity belongs to the diamond's one immutable key/range/salt. Wrong PoolManager, callback sender, pool, range, salt, or callback context reverts. A direct facet call cannot move diamond-owned funds. |
| I2: Unit backing | At every completed operation, `S = U = L`. Each mint is backed by the measured position-liquidity addition; each burn decreases liquidity by the same raw count. No protocol/admin mint or phantom receipt path exists. |
| I3: Exact V2 form | For funded `u`, issuance is `floor(u * (S + 10^d)/(U_before + 1))`, with fixed `d = 0`. A case where a post-deposit denominator gives a different result must reject that alternative. The inverse uses the same offsets. |
| I4: Price-free acceptance | For fixed `U`, `S`, fee reserves, and funded `u`, changing the pool's price cannot change minted shares or fee-match amounts. It can change token costs of funding `u`. Tests must keep these two facts distinct. |
| I5: Component funding | Every admitted `u` supplies its exact principal settlement plus `ceil(u * F_i/U)` of each fee component. Zero, one-sided, unequal-decimal, and large-fee balances are covered. Missing one component reverts; the other component cannot substitute for it. |
| I6: No old-fee capture | Fees pending before deposit are recognized before fee matching. Entrant admission does not reduce incumbents' fee backing in either token. Compare delayed collection with already collected fees; the admission result must agree for equal collectible totals. |
| I7: Collection conservation | Fees are recognized exactly once. Repeated checkpointing without intervening fees changes nothing. Collection of all fees during a small redemption does not allocate all of them to the redeemer. |
| I8: Slice confinement | `uOut` and `feeOut_i` are computed before supply mutation. Sale input is exactly the redeemed slice's opposing amount. Test with large unrelated opposing balances and fee reserves so a full-balance sale would be detected. |
| I9: No self-fill overclaim | Fees generated by the exit sale accrue only to remaining liquidity. The redeemer cannot receive them again. Remaining liquidity counts and fee entitlements reconcile, while its token composition is allowed to move because it participated in the sale. Do not assert unchanged incumbent token principal after the sale. |
| I10: Atomic failures | Partial fill, reached price limit, failed settlement, insufficient minimum output, expired deadline, transfer failure, or callback violation restores all shares, fee books, and position changes. No silent in-kind success from the target-only endpoint. |
| I11: Exit liveness boundary | An explicitly chosen in-kind exit succeeds when economically funded and token transfers work, even if no target sale route exists. Cover full vault withdrawal where no other liquidity remains; target-only may revert and must not fabricate payment. |
| I12: Rate parity | At identical state and canonical sale limit, one-whole-share execution agrees with `getRate` after the specified decimal normalization. Cover both target orientations, in-range and both out-of-range states, pending fees, zero opposing principal but opposing fees, tick crossings, complete tick removal, and full-sale failure. |
| I13: Bootstrap and final exit | Zero supply has no synthetic rate. The first funded join preserves `S = U = L`. Redeeming all real shares removes all accounted liquidity and fees. New bootstrap cannot inherit old holder liabilities or unsolicited balances as its own credit. |
| I14: Donation and attribution | Bare token transfers are neither depositor credit nor earned fees. Accounted fee reserves remain covered by actual custody. Fee donations made through the pool's legitimate fee mechanism, if collectible by the position, are accounted as position fees before admission. No unmatched raw-balance surplus is swept into the entrant's receipt. |
| I15: Transfer fungibility | After a share transfer, the receiver owns that share's current principal and fee entitlement, and the sender does not retain a duplicate fee claim. Supply and backing do not change. |
| I16: Rounding and bounds | Use full-precision directed division. Mint and redeem floors, fee-match ceilings, token settlement rounding, target normalization, small amounts, maximum supported liquidity, and non-18 token decimals are explicit. No conversion relies on unchecked wraparound. |
| I17: Surface and reentrancy | All advertised selectors are reachable on a deployed package diamond and agree with facet metadata. Reentrant token calls, nested user operations, stale callback replay, and economic views during partial settlement cannot spend another operation's budget or expose a usable partial rate. |
| I18: Custody partition | Each currency balance is partitioned into accounted fees, operation-local amounts, and excluded unsolicited surplus. An exit cannot use the latter two as another holder's entitlement, and a deposit cannot use accounted fees as input. Unexpected deficits fail closed. |

**Rejected alternatives:** testing only arithmetic helpers or a stand-alone facet; checking only that output is nonzero; treating a successful target exit as proof of manipulation immunity; re-running the closed extraction argument instead of validating this different admission contract.

**Evidence class:** proposals derived from the observed V2 conversion/slice path and the accepted prior conclusions. No invariant was exercised here.

### Economic boundary of the recommendation

**Inference:** the price-free guarantee is an acceptance-time ownership statement about the selected backing components. It is not a claim that target liquidation value cannot move, that a target-only exit always exists, or that every external round trip loses money.

The position still participates in the pool's trades. An exit sale can trade against remaining vault liquidity, alter its composition, and generate fees for it. A third party can trade before a deposit or before a rate read. Those exposures are not removed by calling the backing a receipt.

The design deliberately pays for its price-free fee inclusion with componentwise entry. If generic target-only entry, automatic compounding, arbitrary hooks, several ranges, or a universally manipulation-resistant target rate are mandatory, this specification does not meet those additional requirements. They cannot be silently supplied by reintroducing a scalar target-priced denominator.

## Limits

- Runtime or extraction proof: none. No project tests, simulation programs, builds, deployments, wallet operations, or Git operations were run.
- Not examined: excluded third-party materials; current peers, draft, and final; existing V4 implementation code; the swap-capture report outside its conclusions; every V2 route as a complete audit.
- Source scope: the two direct Crane dependencies were opened specifically to verify the requested executed V2 conversion and slice sale. Other cited V4 facts are observations of the admitted reports, not independent source verification.
- Live-source limitation: repository reads are not an atomic snapshot. This report does not claim revision-pinned runtime behavior.
- Unverified implementation obligation: a future implementation must build and validate an exact post-removal quote for its supported pool domain. Merely naming a quoter does not satisfy Decision 7.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
