# Member response

## Identity

- Run ID: v4-pair-spec-fidelity-20261027-01a17d57
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/v4-pair-spec-fidelity-20261027-01a17d57/members/grok/response.md
- Requested role: independent council member, as assigned in the user message. A separate runtime role field was not exposed.
- Requested model and reasoning: not stated in the user message
- Actual role, model, reasoning, task ID, and session ID: role not exposed; provider xai, model grok-4.7, reasoning xhigh from PI_PROVIDER, PI_MODEL, and PI_REASONING_LEVEL. Session ID 01a17d68-beab-78f5-a157-ba1f09e178eb from PI_SESSION_ID. Task id st_01a17d69 was observed in PI_SESSION_FILE, not supplied as an assignment field.
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the specification snapshot of docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md correctly document the verified PairToken at chain 4663 address 0x56C8c249d4c021e93635b120aC68A9a36eb01753 so it can be used for clean-room development of that source?
- Required targets: the full specification snapshot; src/pair/PairToken.sol and the bundle dependencies it calls; every report section; every material public entrypoint; the brief's topic list.
- Optional context: the original report path, used only to interpret the manifest digest. It is not a second normative specification.
- Admitted read scope: this run's brief.md, evidence/, the member-response template, and the native-council skill. No peer responses, no project implementation files, no network, no public query.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Council question and write rule | docs/reviews/v4-pair-spec-fidelity-20261027-01a17d57/brief.md | coordinator-supplied | Full review. Compare the snapshot with the frozen source. Write only this response. No implementation. |
| Fetch metadata | evidence/manifest.md | coordinator-supplied | Retrieved 2026-10-27T12:48:44.213Z. HTTP 200. Stated JSON SHA-256 ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98. Stated specification SHA-256 15c6d7790aa1f8eca1c36ec0d147483359e2ff7d018c56ed8240e394d2c878e3. Match id 55980642, creation and runtime exact_match, verifiedAt 2026-10-12T10:33:37Z, chain 4663, address 0x56C8c249d4c021e93635b120aC68A9a36eb01753. |
| Specification text | evidence/specification.md, 321 lines, 23588 bytes | source observation | Full text read. It is a Crane-vault research report. It says the PairToken question was not admitted and that a later agent must not open that source. |
| Original report digest | docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md, 23587 bytes | source observation | SHA-256 equals the manifest specification digest. The snapshot is that file plus one trailing newline. Content line numbers match. |
| Source JSON | evidence/sourcify-sources.json | source observation | Parsed metadata matches the manifest. All 28 sources.*.content strings match the fenced bodies in evidence/sources.md exactly. |
| JSON file digest | same file, 147695 bytes | source observation | Recomputed SHA-256 is b092a33582f4a7f6c76564b0a5ea276561b84347ab66494eea81e462442fcea0, not the manifest digest. The hasher matches the known SHA-256 of the string abc. Comparison below is of the parsed contents and the matching readable bundle. |
| PairToken | evidence/sources.md heading src/pair/PairToken.sol, original lines 1-693 | static analysis | Full contract read. Line numbers below are original source lines inside that fence. |
| Called dependencies | same bundle, files named in Coverage | static analysis | Read at the functions PairToken calls. PoolManager and PairTokenFactory implementations are not in the bundle. |
| Public query | not used | not used | No web query and no private excerpt was sent. |

Source links and Sourcify metadata are observations. Conclusions below are inference from the static comparison. Textual agreement is not a runtime proof, and disagreement was not executed.

## Assumptions

- Original-source line numbers are the lines of each JSON content string. Those strings matched the fenced sources.md bodies with no diff.
- The report's statements that a difference is intentional are taken as intentional. They are still contradictions if the document is used as a specification of this contract.
- outDelta > 0 in PairToken._deployInLock treats a positive swap delta as tokens received. That is an observation of this contract's use of BalanceDelta, not a reading of a PoolManager implementation.
- The prior report's sentence that the excluded source was not read is a statement in that document. This pass does not establish whether that historical claim is true.

## Coverage

Status here is examination status. Fidelity is in the Reason column and in Review findings. No row is a runtime correctness claim.

### Report sections

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Question, lines 1-9 | required | examined | States a different question: specify a new Crane vault, and do not reconstruct a third-party implementation. |
| Authorization and scope, lines 11-19 | required | examined | Line 19 says the PairToken specification question was not admitted and that implementers must not open that source. |
| Participation, lines 21-34 | required | examined | Process record of a different run. Not PairToken behavior. |
| Conclusions intro, line 38 | required | examined | Says this file is the specification a later agent implements. |
| Product, lines 40-44 | required | examined | Crane diamond, one chosen range, fee escrow, single-target exit. Contradicts PairToken. |
| Terms, lines 46-62 | required | examined | U, d = 9, Q = 2^128, fee index, debt, unclaimed, and remainder have no PairToken counterparts. S is only roughly totalSupply. |
| 1. Receipt and mint, lines 64-80 | required | examined | Offset-9 liquidity-unit mint. Not the source quote. |
| 2. One share, one range, lines 82-88 | required | examined | One position overlaps. Range selection, salt, target currency, and what the share owns do not. Binding sentence is line 84. |
| 3. Fees, lines 90-129 | required | examined | Escrow index and claimFees. Source compounds and carves a protocol fee. |
| 4. Entry, lines 131-141 | required | examined | Forbids a vault swap and does not add zap. Source compounds, which can swap, and has zapDeposit. |
| 5. Share exit, lines 143-161 | required | examined | Target sale of a liquidity slice. Source pays both legs after 10 bps retention. |
| 6. Diamond boundary, lines 163-175 | required | examined | Crane diamond and CREATE3 package. Source is an EIP-1167 clone. PoolManager modifier claims are not in this bundle. |
| 7. getRate, lines 177-200 | required | examined | No getRate in PairToken. Hook domain is line 196. |
| 8. Sequences, lines 202-228 | required | examined | Order and branches contradict deposit, redeem, and redeemZap. Line 216 is an unresolved or. |
| 9. Invariants, lines 230-249 | required | examined | Static disagreement with the source formulas. Not executed. |
| What this does not deliver, line 251 | required | examined | Process limits. The no-copy sentence matches the report's own exclusion. It does not document PairToken. |
| Evidence, lines 255-268 | required | examined | Cites Crane and V2 files, and marks the third-party source not examined. |
| Coverage, lines 270-279 | required | examined | Does not list PairToken entrypoints. |
| Disagreement, line 281 | required | examined | Records member dissent on zap, compounding, and getRate. Not source behavior. |
| Advisory review, line 288 | required | examined | Process record. |
| Recommendations, lines 297-301 | required | examined | Line 301 tells a later implementer not to add a vault zap. That rejects a source entrypoint. |
| Limitations, line 303 | required | examined | Does not disclose the formula gap with PairToken, because that source was outside its admitted scope. |
| Publication, line 311 | required | examined | Identifies the original report path used for the digest check. |

### PairToken public entrypoints

All of these were read. Report means how the snapshot treats them.

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| initialize | required | examined | Report binds a chosen range, salt, and target through an unspecified package init. Source derives the full usable range, forces salt 0, stores no target, and sets factory = msg.sender. |
| approve, transfer, transferFrom, allowance | required | examined | Report says transfer crystallizes fee escrow. Source transfer moves balances only. Allowance and infinite-approval behavior are absent from the report. |
| name, symbol, decimals, totalSupply, balanceOf | required | examined | decimals = 18 at line 49 overlaps. The report justifies 18 from a V2 initializer, not from this constant. Name and symbol are omitted. |
| poolKey, token0, token1, poolId, tickLower, tickUpper, initialized, factory, poolManager | required | examined | Report does not name these getters. tickLower and tickUpper are derived, not chosen. factory is a live dependency the report does not name. |
| positionLiquidity | required | examined | Live PoolManager read at salt 0. Report replaces it with stored U. |
| basket | required | examined | Source share base. Report does not specify it and rejects basket pricing. |
| previewDeposit, previewRedeem | required | examined | Present in source, absent from report. getRate is not either function. |
| deposit | required | examined | Contradicted. See topic comparison. |
| zapDeposit | required | examined | Source entrypoint. Report explicitly does not add it. |
| redeem | required | examined | Contradicted. Dual-asset output and retention are absent. |
| redeemZap | required | examined | Source single-token exit. Not the report's uOut sale. |
| compound | required | examined | Permissionless source entrypoint. Report has no counterpart and forbids the swap it can perform. |
| unlockCallback | required | examined | Both use a pool-manager callback. Armed-flag and fee-escrow rules are not this function. |
| receive | required | examined | Open native receiver at line 133. Report does not mention it. |
| Constants DEAD_SHARES, RETENTION_BPS, DUST, DEAD, and BPS | required | examined | BPS = 10_000 at line 59. DEAD_SHARES = 1000 at line 61. RETENTION_BPS = 10 at line 63. DUST = 1000 at line 65. None of these values appear in the report. |
| Errors and Deposit, Redeem, Compounded | required | examined | Report specifies neither the error names nor the events. NotFactory is declared at line 103 and has no throw site. |

### Dependencies

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| IPoolManager interface | required | examined | Full interface read. Documents unlock, modifyLiquidity return values, swap, settle, sync, take, and CurrencyNotSettled. Does not show onlyWhenUnlocked, noDelegateCall, or owner: msg.sender. |
| IUnlockCallback | required | examined | Full file. Callback is on msg.sender of unlock. |
| PoolKey, PoolId.toId | required | examined | Key includes fee, tickSpacing, and hooks. Id is keccak256 of the struct. |
| Currency.transfer, balanceOfSelf, isAddressZero | required | examined | Native is address 0. Redeem payout uses Currency.transfer. |
| BalanceDelta.amount0 and amount1 | required | examined | Packed int128 accessors. Sign convention beyond PairToken's own > 0 check was not implemented in this bundle. |
| TickMath.minUsableTick, maxUsableTick, MIN_SQRT_PRICE, MAX_SQRT_PRICE | required | examined | Full-range bounds and the swap price limits PairToken uses. |
| TickMath.getSqrtPriceAtTick algorithm | optional | not examined | Called as a black box. Its body was not re-derived. |
| StateLibrary.getSlot0, getLiquidity, getPositionLiquidity | required | examined | extsload readers. getSlot0 also returns protocol fee and lp fee, which PairToken discards. |
| StateLibrary.getFeeGrowthInside | optional | partially examined | Signature seen. PairToken does not call it. |
| Position.calculatePositionKey | required | examined | Owner, ticks, and salt. PairToken passes address(this) and bytes32(0). |
| SqrtPriceMath.getAmount0Delta and getAmount1Delta uint overloads | required | examined | Basket uses roundUp = false. Floor formulas read. |
| FullMath.mulDiv, mulDivRoundingUp | required | examined | Notices and the rounding-up wrapper read. The 512-bit mulDiv proof was not re-derived. Floor is the stated contract. |
| LiquidityAmounts.getLiquidityForAmounts | required | examined | Full file. Floor via mulDiv, then the smaller of the two side liquidities inside the range. |
| PriceMath.sqrt | required | examined | Floor integer square root. sqrtPriceFor was read and is not called by PairToken. |
| FixedPoint96.Q96 | required | examined | 2^96. Used by amount math and by _ratioSwap. |
| IHooks | optional | partially examined | Header and address-bit comment read. Remaining callback signatures were not. PairToken does not inspect hook bits. |
| CustomRevert, SafeCast, BitMath, UnsafeMath, IERC20Minimal, IERC6909Claims, IProtocolFees, IExtsload, IExttload, BeforeSwapDelta | optional | not examined | Present in the bundle. Not on a direct PairToken call, except indirect use through Currency.transfer and extsload. |
| PoolManager implementation | required for the report's modifier claims | absent | Not in the bundle. |
| PairTokenFactory implementation | required for factory behavior | absent | Not in the bundle. Only the four views and notify as PairToken calls them. |

## Conclusions

The snapshot is not an accurate behavior specification of this source. It is a coherent alternative vault design, and it says so. Line 19 records that a specification of the PairToken source was not admitted, that the report does not translate that source, and that a later agent must not open it. Line 38 nevertheless says this file is the specification a later agent implements. Those two sentences answer the council question: an implementer who follows the file will not reimplement the verified contract, and the file tells that implementer not to check.

The overlap is narrow. Both describe one ERC-20 claim on one Uniswap v4 position owned by the vault contract, not by a position NFT, with 18 share decimals and floor division somewhere in the share math. Both collect fees with a zero-liquidity modifyLiquidity poke, and both keep the pool key fixed after initialization. That overlap does not make the formulas, the fee path, the entry path, the exit path, or the deployment shape the same.

No council consensus is claimed. Peers were not read.

### Topic comparison

Tags used below: contradiction, omission, or intentional design change. An intentional change is still a contradiction for source-equivalent use. It is tagged intentional when the report names the rejection.

Receipt and ownership. Contradiction, and intentional. Source NatSpec, lines 32-37: the ERC-20 is a full-range v4 position; shares are quoted on the redeemable basket at the live sqrt price plus idle balances; the contract is an EIP-1167 clone; there is no position NFT. Report Product, lines 40-44: one Crane diamond, one chosen range, liquidity units as an internal ledger, fees outside the share, exit in one target currency. The share in the source owns a pro-rata claim on that basket, including idle balances. The report says the share does not own fee escrow, a donation, or another range.

Pool, range, and salt. Contradiction on selection; overlap on cardinality. initialize, lines 138-149, sets tickLower to TickMath.minUsableTick(key.tickSpacing) and tickUpper to maxUsableTick. Those are (MIN_TICK / tickSpacing) * tickSpacing and the max counterpart, with MIN_TICK = -887272 and MAX_TICK = 887272 (TickMath.sol lines 20-49). Salt is bytes32(0) at positionLiquidity line 216 and modifyLiquidity line 615. It is not stored. The report's line 84 binds a caller-chosen tickLower, tickUpper, salt, and target currency. A spec implementer can choose a narrow range or a nonzero salt and still satisfy the report. That is not this contract. The source also stores the whole PoolKey, including fee and hooks, and does not require the hook to be zero.

Share mint math. Contradiction. Report line 69, with d = 9 at line 52:

shares = floor(uReceived * (S + 10^d) / (U_before + 1))

The report calls that a source observation of BetterMath._convertToShares (line 74), not of this contract. _quoteShares, lines 500-518, does not use liquidity units, a decimal offset, or a virtual liquidity unit.

If supply == 0 or both basket reserves are zero, shares = PriceMath.sqrt(amount0 * amount1), both input amounts are used, and if supply == 0 and shares <= DEAD_SHARES the call reverts BadGenesis (lines 506-507). PriceMath.sqrt, lines 29-63, is a floor integer square root. The product amount0 * amount1 is not in an unchecked block, so a product above 2^256 - 1 reverts under the file's pragma solidity 0.8.26. That overflow revert was not executed.

If only one reserve is zero, shares are floor(amountOnThatSide * supply / thatReserve) and the empty side is not pulled. If both reserves are nonzero, shares = min(floor(amount0 * supply / r0), floor(amount1 * supply / r1)), and the used amounts are min(amount, ceil(shares * reserve / supply)) via mulDivRoundingUp at lines 515-516, then clamped to the offered amount. FullMath.mulDiv is specified as floor. mulDivRoundingUp adds one when the remainder is nonzero.

There is no uReceived in the numerator. The current tick enters the quote because it enters basket(). The report says a spot move must not change minted shares for a fixed uReceived. That sentence is about a different mint.

Share burn math. Contradiction, and intentional on the single-target sale. Report line 148:

uOut = floor(shares * (U + 1) / (S + 10^d))

Source _redeemToSelf, lines 391-397: reject zero shares or zero supply with MinShares; measure idle; burn msg.sender; then payout = floor(shares * (BPS - RETENTION_BPS) / BPS). BPS is 10_000 at line 59. RETENTION_BPS is 10 at line 63. The same payout expression is the preview at line 247. Liquidity removed is uint128(floor(positionLiquidity * payout / supplyBeforeBurn)). Idle paid is floor(idleBeforeBurn * payout / supplyBeforeBurn) on each side. This audit does not claim the uint128 cast overflows. The source does not revert merely because liquidity out is zero. The integer payout of 1 share is 0. If both minimums are 0, the function text does not revert: liquidity out and idle out are zero, the burn still happens, and the zero amounts are not transferred. The report reverts when uOut is zero. Those are different failure rules, not two wordings of one rule.

Initialization and genesis. Omission plus contradiction. initialize is a one-shot external function. It reverts AlreadyInitialized or ZeroAddress if the manager is zero. It does not check the caller against a factory, despite NotFactory at line 103. factory = msg.sender. It does not initialize the pool, choose a target, or check currency sort. The first deposit with totalSupply == 0 requires the liquidity add to be nonzero, mints DEAD_SHARES (1000, line 61) to 0x000000000000000000000000000000000000dEaD, and subtracts those shares from the amount minted to to (lines 286-287). minShares is checked at line 272 against the pre-subtraction quote. A caller can therefore pass a minShares the gross quote meets and still receive 1000 fewer shares. zapDeposit reverts BadGenesis when supply == 0 or either basket reserve is zero. The report has no dead shares, no geometric-mean genesis, and no BadGenesis.

Native and ERC-20 deposits. Omission and contradiction. deposit, line 256, is payable and nonReentrant. Native is legal only as currency0, and msg.value must equal amount0; otherwise msg.value must be 0 (lines 651-653). _reservedNative keeps that value out of idle until the used native amount is known. ERC-20 pull measures the balance delta, so a fee-on-transfer token contributes what arrived (line 667), but the share quote is not recomputed from that delta. Excess ERC-20 is not pulled. Excess native is refunded to msg.sender, not to to, and a failed refund reverts TransferFailed. Tokens that are pulled and do not become liquidity stay idle and later sit in basket(). The report says unused amounts are refunded and are not a claim on liquidity. That is not this deposit. deposit also calls _compound before the quote, so a deposit is not swap-free when idle exceeds DUST.

Zap. Intentional omission, and a contradiction for source-equivalent use. Report line 133 forbids a vault-initiated swap. Line 139 says this file does not add a zap. zapDeposit, line 308, is a public single-token entry. It rejects a bad token, a native mismatch, and genesis. amountIn == 0 or amountIn > floor(reserveIn * maxZapBps / BPS) reverts ZapTooLarge (line 332). It swaps floor(amountIn / 2) and then adds every idle balance that fits the full range. Tick movement strictly greater than the live maxZapTickMove reverts ZapMovesPrice (line 339); an equal move does not. Shares are _minShares(used0, used1, preZapReserve0, preZapReserve1, preZapSupply) (line 342), not a liquidity-unit mint. used0 and used1 come from _modify after that deploy, so they are the net amounts that add consumed, which can include idle that was already in the contract. The report does not state this. This is an accounting difference, not an attack procedure. redeemZap, line 366, burns through _redeemToSelf and swaps the unwanted leg with _skipAdd set, so the redeemed legs are not put back. It checks one minOut. It does not check zap size or tick movement. The report's target sale is not this function: the source sale input is the post-retention basket leg, not the opposing principal of an offset liquidity slice, and an incomplete swap is not itself a revert.

Fees, compounding, and protocol fees. Contradiction, and intentional on compounding. Report lines 94 and 99 collect feesAccrued into an index floor(delta_i * 2^128 / S), crystallize per account, and pay claimFees in kind. PairToken has no fee index, no debt, no unclaimed balance, no remainder ledger, and no claimFees. _compound, line 416, pokes with liquidity delta 0 when position liquidity is nonzero, decodes the taken callerDelta as fees, and does not use feesAccrued as the escrow amount. _modify, lines 622-623, defines consumed amounts as fees - callerDelta when that difference is positive. After a nonzero collection, if feeManager() is nonzero and protocolFeeBps() is nonzero, the protocol amount is floor(fees * feeBps / BPS) on each side (line 427). _carve notifies the fee manager and, on failure, leaves the tokens idle and does not revert the user action. Idle above DUST (1000, line 65) is ratio-swapped and redeployed into the same position. The swap is clipped to floor(floor(reserve * maxZapBps / BPS) / 4) (line 494), not reverted for size, and is not tick-bounded. compound() at line 412 is permissionless and the same _compound runs at the start of deposit, zap, redeem, and redeemZap. Fees that have been compounded are inside the position and therefore inside later baskets. A transfer does not crystallize them, and the recipient receives the share claim on the compounded position. The report's rule that unclaimed fees stay with the sender has no source object to attach to.

Redemption and retention. Contradiction. redeem, line 351, pays both currencies to to after _compound, requires amount0 >= min0 and amount1 >= min1, and emits those two paid amounts. There is no configured target currency. The caller of redeemZap chooses tokenOut per call. redeemZap emits the pre-swap basket amounts, not the single-token out. Retention is 10 bps of the burned claim, left in the position and idle for the remaining supply, which includes the 1000 dead shares. The report's unswept U residual is floor dust of a different equation. It is not this 10 bps, and it is not the dead-share dilution. The report also forbids an in-kind fallback. The source's ordinary redeem is the in-kind path.

Balances and donations. Contradiction. basket(), lines 221-231, adds idle to the floor token amounts of the position at the live sqrt price. _idle subtracts only _reservedNative. A direct token or native transfer therefore changes the next deposit quote and the next redeem payout. receive is open. PairToken never calls donate. The IPoolManager.donate notice says a donation goes to in-range liquidity providers. This bundle has no PoolManager implementation, so this pass does not claim that a donation becomes the next poke's callerDelta. The report says a donation is not part of the share and must not fund an exit. The source basket includes idle donations, and compounded collections become position liquidity without a matching share mint. The source has no stored U that could revert on that increase.

Previews and rate. Omission of the source previews; addition of getRate. previewDeposit quotes _quoteShares on the current basket and does not compound. Its notice at line 232 says pending fees are not included. deposit compounds first, so the preview and the execution can differ. previewRedeem applies retention to basket() and returns (0, 0) when supply or shares is zero, rather than reverting. It does not simulate a removal plus a swap. getRate at report lines 187-194 is a normalized one-share target quote that reverts when S < 10^18, simulates a post-removal exact-in sale, and excludes personal unclaimed fees. PairToken has no getRate, no target decimals, and no hook-domain revert. The 18-decimal overlap is the decimals constant at line 49, not evidence that the report documented this preview surface. The report's lines 74 and 151 cite BetterMath and a V2 exchange. Those files are not this verified contract.

Transfers and allowances. Contradiction on transfer; omission on allowance. _transfer, line 174, rejects to == address(0), subtracts from the sender, and adds to the recipient. It does not sync fees. transferFrom decreases allowance unless it is type(uint256).max (line 169). approve overwrites the allowance. The report's transfer rule, which crystallizes unclaimed to the sender, specifies a ledger this contract does not have.

Permissions, reentrancy, and callbacks. Contradiction. User entrypoints use nonReentrant by setting _entered to 1 (modifier at line 125). unlockCallback, line 550, is onlyPoolManager and is not itself nonReentrant. It decodes an Op from the callback data and will modifyLiquidity, swap, settle, sync, and take. It does not check a stored armed flag, caller, receiver, or amount budget. The report's section 6 says neither the manager check nor an armed flag is enough, and that no other address may be the unlock caller or the position owner. The source position owner is address(this) of the clone. initialize is not factory-gated. compound is permissionless. Hook data passed to modifyLiquidity and swap is empty. The swap price limit is MIN_SQRT_PRICE + 1 or MAX_SQRT_PRICE - 1 (line 586). The interface warns that a hook with a swap-delta flag can change the swap delta. PairToken does not read hook flags and does not revert because a hook is nonzero. Report line 196 reverts getRate unless the hook is the zero address or does not change removal amounts and swap outputs. That is not a revert on every nonzero hook.

Factory dependencies. Omission. At execution, PairToken reads feeManager, maxZapBps, maxZapTickMove, and protocolFeeBps, and calls notify(token, amount, poolId), with value for native. Those values are not snapshotted at initialize. The report's deployment sentence at line 173 names CREATE3 facets, one DFPkg, the IndexedEx manager vault registry, and DiamondPackageCallBackFactory. None of those names appear in this contract. The factory implementation is not in the bundle, so this comparison cannot say what those four views return. It can say the clone will call them.

Ordering. Contradiction. Source deposit order is check, reserve native, compound, quote, minShares, pull, add all idle liquidity, maybe dead-share mint, mint net shares, refund native. Report section 8 collects fees to pre-mint S, crystallizes, pulls with no swap, adds, then reverts if uReceived or minted shares is zero or below minShares, then mints with the offset formula. Source redeem order is compound, measure idle, burn, retention payout, remove that liquidity, pay both legs, check two minimums. Report exit order computes uOut before the burn, sells one opposing leg, and pays one target. Line 216 leaves an unresolved branch: if fees change between checkpoint and mint, attribute them to pre-mint S or revert. The source does not have that branch.

### What static disagreement does not prove

Section 9's invariants were not executed. From the formulas alone, invariants 1, 2, 6, 7, 12, and 15 describe ledgers and equalities this contract does not implement. That is inference from the missing ledgers, not a failed test. Invariant 13's redeemLiquidity(mintShares(u)) <= u is not a source function pair. A revert in deposit or redeem does roll back that call's state, which is ordinary EVM revert behavior and not evidence for the report's armed callback.

### Source-equivalent implementability

Not implementable from this snapshot as a source-equivalent specification. The blocker is not a missing paragraph. The document specifies a different product and instructs the implementer not to open the source that would reveal the difference. A source-equivalent document would have to state the quote, genesis, retention, zap, compound, factory views, native rules, and public surface above, and it would have to be labeled as a description of this exposed source. This response is not that document and does not authorize writing one.

### Independent-design usability

Separately, the snapshot is not a complete implementation specification of its own Crane design. These are gaps in the report text, not PairToken defects:

- Line 216 allows either attributing late fees to pre-mint S or reverting. Both satisfy the sentence.
- Line 187 says the sale quote uses the same limits execution will use, and does not enumerate price limit, hook data, exact-in encoding, or fee source.
- Line 196 is not an executable predicate. A hook that does not change amounts, and a dynamic fee that can change inside the swap, name no flag or storage read.
- Native versus ERC-20 pull, sync, settle, take, and refund are not specified. Section 6 says deltas must be settled and does not say how.
- Who may initialize, the argument list, and name or symbol storage are not specified. Line 173 points at Crane package rules the report says were not re-opened.
- claimFees(account) at line 125 does not say whether account must be the caller, how native escrow is transferred, or whether the call takes the callback lock.
- remainder_i must be nonnegative, but the reverting call is not named.
- Transfer crystallization is not in the sequences. Allowance is absent. Target decimals dT are a symbol, not a rule for native currency.
- No error names. Failure behavior is prose. That is incomplete, not by itself contradictory.

An implementer can build some vault that meets the adopted sentences. Two such builds need not match each other on the unresolved branch, the sale limits, or settlement. Independent-design usability is therefore a sketch with blockers, not a build specification.

### Provenance and clean-room handoff

Factual record only. This is not a legal conclusion, and it is not a statement that use is prohibited or permitted.

- The report states that the PairToken question was not admitted and that reading that source to write a build specification is not a clean room (line 19). Its evidence table marks the third-party source not read (line 266).
- This council was given that source. evidence/manifest.md says the evidence contains third-party source and is not an unexposed-implementer handoff.
- src/pair/PairToken.sol line 1 and src/base/PriceMath.sol line 1 say SPDX-License-Identifier: BUSL-1.1. The v4-core files read here and LiquidityAmounts.sol say MIT.
- The report's PoolManager citations are lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol lines 55-61 and 94-118. That file is not in this bundle. The bundle has the Uniswap v4 interface and libraries.
- Document accuracy would not establish legal clearance. This comparison does not establish legal clearance. Source exposure and a matching or non-matching document are not a license grant and not a clean-room certification.

### Verdict

Not ready for clean-room development of the verified PairToken.

The snapshot is not a source-equivalent specification. It is an alternative design that explicitly excludes the source it would have to document. Source-equivalent implementability is blocked. Independent-design usability is incomplete. Clean-room clearance is not established.

Outstanding blockers:

1. The file tells the implementer to implement its own rules and not to open this source.
2. Mint, fees, entry, exit, range, salt, genesis, and architecture contradict the verified contract.
3. PairTokenFactory and the PoolManager implementation are absent, so factory return values and the report's modifier claims cannot be completed from this bundle.
4. The manifest digest of sourcify-sources.json was not reproduced from the file bytes. Metadata and the 28 rendered sources did match. This is an evidence-identity gap, not a behavior match.
5. No runtime, chain-state, or bytecode check was done. The manifest's exact_match flags are metadata, not a check this pass repeated.

## Review findings

Severity scale: Blocker means the snapshot cannot be used as a source-equivalent specification. High means a direct contradiction of a money or control rule. Medium means a material omission or a different failure rule. Low means a secondary omission or an evidence-locator defect. Intentional design changes are marked in the text. Fix direction is a documentation change, not code.

### Report is not a specification of this source

- Location: evidence/specification.md:19 and :38; src/pair/PairToken.sol:32-37
- Invariant or requirement: A source-equivalent specification states this contract's behavior. The report instead says the PairToken question was not admitted and that this file is what a later agent implements.
- Impact: Blocker. Using the report for clean-room development of 0x56C8c249d4c021e93635b120aC68A9a36eb01753 implements a different system and is instructed not to detect that.
- Fix direction: Do not label this report as the specification of that contract. If a source-equivalent document is still required, it is a different document. This finding does not authorize writing it.
- Evidence class: static analysis
- Conflict: contradiction with the council question. The exclusion itself is an intentional scope choice of the earlier report, recorded accurately as an exclusion, and that exclusion is why the fidelity answer is no.

### Mint formula is not the basket quote

- Location: report :52, :69, :74; source _quoteShares :500-518, PriceMath.sqrt :29-63, deposit :272 and :286-287
- Invariant or requirement: Source shares are a geometric mean at genesis and, afterward, the minimum pro-rata share of the two basket reserves, with ceil used-amounts. They are not floor(uReceived * (S + 10^9) / (U + 1)).
- Impact: High. An implementer mints a different claim, ignores the tick's effect on the quote, and omits the 1000-share genesis debit. minShares also binds the pre-debit quote, which the report's post-mint check does not.
- Fix direction: Replace section 1 with the _quoteShares branches and the dead-share subtraction, or mark section 1 as a Crane formula that is not this contract.
- Evidence class: static analysis
- Conflict: contradiction. The report's source-observation label points at BetterMath, which is not the verified contract.

### Fees are compounded and then carved, not escrowed

- Location: report :94, :99, :116, :125; source _compound :416, protocol fee :427, _modify :610-623, compound :412
- Invariant or requirement: Source fees are collected as the poke's callerDelta, a factory protocol fraction is notified best-effort, and the rest is swapped and added to the same position. There is no per-share index and no claimFees.
- Impact: High. The report's transfer, exit, and getRate rules all depend on an escrow the source does not keep. The source also has a live protocol fee the report explicitly does not add.
- Fix direction: For a source-equivalent spec, replace section 3 with collect, best-effort carve, and _ratioSwap redeploy, including DUST and the quarter zap cap. For the Crane design, label claimFees as not a PairToken function.
- Evidence class: static analysis
- Conflict: intentional design change on compounding, plus omission of the protocol carve and of which return value is treated as fees.

### Redemption pays both legs after 10 bps, and does not sell a liquidity slice

- Location: report :148, :155, :226; source redeem :351, _redeemToSelf :391-397, RETENTION_BPS :63, BPS :59, redeemZap :366
- Invariant or requirement: Source burn pays floor(shares * 9990 / 10000) of pre-burn liquidity and idle, in both currencies, with two minimums. Zero liquidity out is not itself a revert. One share has a zero payout.
- Impact: High. The report's single-target sale, minTargetOut, no in-kind path, and no-sweep residual specify a different exit, including different revert conditions.
- Fix direction: State the retention formula, the pre-burn supply, the dual minimums, and redeemZap as a separate entry. Do not describe 10 bps retention as the offset-formula residual.
- Evidence class: static analysis
- Conflict: contradiction. Single-target exit is an intentional report choice. Retention and dead-share dilution are omissions.

### Zap is a source entrypoint the report refuses

- Location: report :133, :139, :301; source zapDeposit :308, :332, :337, :339, :342
- Invariant or requirement: zapDeposit swaps half the input, deploys all fitting idle, bounds size by live maxZapBps and tick move by live maxZapTickMove, and mints the minimum pre-zap basket share of the consumed amounts.
- Impact: High for source-equivalent use. The report's recommendation not to add a zap drops a public money path. The source zap is also not the report's rejected deposit-swap sketch; it has its own quote and bounds.
- Fix direction: Either specify zapDeposit and redeemZap with the formulas above, or say in the document title that those entrypoints are out of scope because the document is not this contract.
- Evidence class: static analysis
- Conflict: intentional design change, stated at lines 139 and 301.

### Range, salt, and owner are not a configured diamond position

- Location: report :84 and :163-173; source initialize :148-149, salt :216 and :615, Position.calculatePositionKey
- Invariant or requirement: One full usable range, salt forced to zero, owner address(this) of the clone. No stored U. Position liquidity is reread from the manager. Compound can increase it without a share mint.
- Impact: High. A narrow range, a nonzero salt, a stored U mismatch revert, or a diamond callback owner fails this contract even if the rest were copied.
- Fix direction: Specify minUsableTick / maxUsableTick, salt 0, and live positionLiquidity. Move CREATE3 and DFPkg language out of any claim about this source.
- Evidence class: static analysis
- Conflict: contradiction. One position is the only overlap.

### getRate is added; source previews are missing and disagree with execution

- Location: report :177-196; source previewDeposit notice :232, previewDeposit :233, previewRedeem :243-247, basket :221, decimals :49
- Invariant or requirement: Source previews are basket quotes. Deposit preview does not compound; deposit execution does. Redeem preview can return zero. Neither preview is a normalized target-token rate.
- Impact: High. An implementer adds a function the contract does not have and omits the functions it does have. The report cannot be used to predict previewRedeem or the preview/execution gap.
- Fix direction: Document previewDeposit and previewRedeem, including the pending-fee exclusion and the zero return. Do not present getRate as a function of this contract.
- Evidence class: static analysis
- Conflict: omission of source previews; intentional addition of getRate, tied by the report to an IndexedEx rate rule rather than to PairToken.

### Genesis debit and minShares order are unspecified

- Location: source DEAD_SHARES :61, deposit :272, :286-287, _quoteShares :506-507, zapDeposit :308
- Invariant or requirement: First deposit must add nonzero liquidity, mints 1000 shares to the dead address, and checks minShares before that subtraction. Geometric mean at or below 1000 reverts BadGenesis. Zap cannot be genesis.
- Impact: Medium. Missing this changes the first depositor's received shares, the permanent denominator, and the zap precondition.
- Fix direction: Add the dead-share mint, the order against minShares, and the zap BadGenesis cases to any source-equivalent spec.
- Evidence class: static analysis
- Conflict: omission. Not named as a rejected alternative.

### Idle balances and compound swaps are inside the share

- Location: basket :221-231, _idle :646, receive :133, _ratioSwap :469-494, DUST :65
- Invariant or requirement: Idle, including direct transfers, is part of the basket. Compound may swap idle above 1000 units and add the result to the position without minting shares. The report excludes donations and forbids a vault swap.
- Impact: Medium. Deposit quotes, redeem payouts, and position liquidity move for reasons the report tells an implementer to ignore or revert.
- Fix direction: Define the basket as position amounts at the live price, rounded down, plus idle excluding only _reservedNative. State that _compound may swap before deposit and redeem quotes.
- Evidence class: static analysis
- Conflict: contradiction on donations and swaps. The swap inside compound is not the named zap rejection.

### Factory views, permissions, and callback control differ

- Location: report :165, :173; source IPairTokenFactoryView :20-24, initialize :138, unlockCallback :550, NotFactory :103, nonReentrant :125
- Invariant or requirement: Live factory views gate zap size, tick move, and protocol fee. Initialize is one-shot and unauthenticated beyond that. The callback trusts pool-manager-delivered Op data. It does not use an armed flag.
- Impact: Medium. The report's CREATE3 package and armed flag will not reproduce who can initialize, who can compound, or what the callback checks. NotFactory is unused, so a spec that reverts NotFactory would also be wrong.
- Fix direction: List the four factory reads and notify, state that their implementations are not in this bundle, and describe onlyPoolManager plus encoded Op as the actual callback gate.
- Evidence class: static analysis
- Conflict: omission of the factory interface; contradiction on the armed flag and diamond deployment.

### Native, settlement, and failure behavior are missing

- Location: _checkNative :651-653, _pull :661-667, _refundNative :670, _resolve :628, _deployInLock :586, Currency.transfer
- Invariant or requirement: Native is currency0 only. ERC-20 pull is balance-delta measured and does not re-quote. Redeem payout uses Currency.transfer; manager settlement uses _safeTransfer after sync, or settle{value} for native. Swap limits are one unit inside the sqrt-price bounds. Observed reverts include NativeMismatch, MinShares, MinOut, ZapTooLarge, ZapMovesPrice, BadToken, BadGenesis, TransferFailed, and ZeroAddress.
- Impact: Medium. A source-equivalent implementer cannot recover these rules from the report. Which of Currency.transfer's wrapped errors actually surface was not fully examined, because CustomRevert was not read.
- Fix direction: Add the native rule, the two transfer paths, the named reverts, and the preview/execution difference. Do not invent a single failure enum the source does not have.
- Evidence class: static analysis
- Conflict: omission.

### Report PoolManager locators are not this bundle

- Location: report :94 and :165; bundle IPoolManager.sol unlock, modifyLiquidity, and error CurrencyNotSettled
- Invariant or requirement: Claims that modifyLiquidity is onlyWhenUnlocked and noDelegateCall, and that it records owner: msg.sender, are cited to a Crane file that is not in the frozen bundle.
- Impact: Low for PairToken fidelity, because PairToken already passes address(this) as the position owner it later reads. Medium for anyone treating the report's Crane citation as a fact about this Sourcify bundle.
- Fix direction: Cite the bundle interface for what it actually states, and mark the modifier and owner-recording sentences as not examined in this evidence.
- Evidence class: source observation of the bundle, and of the report's citation string
- Conflict: evidence-locator gap. Not a claim that the Crane file is false. That file was not read.

### Independent-design gaps

- Location: report :125, :173, :187, :194, :196, :216, section 8
- Invariant or requirement: A build specification has one meaning for each required branch and names the external surface.
- Impact: Medium for independent-design use. Not a PairToken defect. Line 216 is the sharpest gap: attribute or revert are both allowed. Sale limits, hook checks, settlement, initializer authority, and claimFees caller rules are underspecified.
- Fix direction: If the Crane design is the intended product, resolve line 216 to one branch and enumerate the missing surface. Do not fill those gaps from PairToken; the report forbids that, and the source does not implement those objects.
- Evidence class: inference from the report text
- Conflict: omission relative to independent implementability. Not a source contradiction.

## Limits

- Runtime or extraction proof: none. No tests, no chain reads, no bytecode comparison. Manifest exact_match was read as metadata only. Static formula disagreement was not executed. The uint128 casts and the negative-delta cast in the collect return were observed and not shown to be reachable.
- JSON digest: evidence/sourcify-sources.json bytes do not hash to the manifest digest. Parsed metadata matches. All 28 source contents match evidence/sources.md. The comparison is of those contents.
- Specification digest: the manifest hash is the original report, 23587 bytes. The snapshot is that text plus one trailing newline. Content line numbers match.
- Not examined: PoolManager implementation, PairTokenFactory implementation, TickMath.getSqrtPriceAtTick body, FullMath.mulDiv 512-bit proof, most of IHooks, and the indirect libraries named in Coverage. CustomRevert was not read, so redeem's wrapped transfer error is only partly characterized.
- Prior-council claim: source not read is a sentence in the snapshot, not a fact this pass verified.
- Peers: not read. No consensus is claimed.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
- Legal boundary: license identifiers are observations. No clearance, prohibition, or clean-room certification is made.
