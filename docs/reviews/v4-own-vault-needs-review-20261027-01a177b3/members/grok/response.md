# Member response

## Identity

- Run ID: v4-own-vault-needs-review-20261027-01a177b3
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/v4-own-vault-needs-review-20261027-01a177b3/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the published vault specification, and any implementation it has, meet these four needs: a reserve exposed to trading fees, a deposit of either token, a withdrawal into a single token, and a quote of one vault share into a single token? Report gaps and failures. Do not confirm by assertion.
- Required targets: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md
- Optional context: docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/resolution.md. Not opened. Not a second target.
- Admitted read scope: the specification, repository files it cites where a four-needs claim depends on them, and a repository search for an implementation. No third-party Pair Token source. Wings, DETF, and hook packages were identified by path and were not reviewed as this vault.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Published specification | docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md, read in full | source observation | One new Crane diamond, one Uniswap V4 position, one range, one salt. Shares mint from liquidity units. Fees accrue and are escrowed outside the share. Entry pulls both pool currencies and does not swap. Exit removes a liquidity slice, sells only that slice's opposing principal, and pays one configured target. `getRate` previews that exit for one whole share and writes nothing. The report says it is not implementation authorization and does not change Wings. |
| Fee split and entry refusal | REPORT.md lines 44, 133-139, 208, and 253 | source observation | Line 44: deposited capital funds the position; trading fees accrue in the two pool currencies and sit in fee escrow; they are not part of the share's redeemable property; share exit pays one configured target; fee escrow is claimed separately, in kind. Line 133: no vault-initiated swap. Line 135: entry pulls both currencies; either amount may be zero only when the current tick leaves that side unused; zero `uReceived` reverts. Line 139: the vault must not add a swap to accommodate an external swapper; this file does not add a zap route. Line 208: deposit step is "Pull both currencies. No vault swap." Line 253: "It does not let this vault swap on entry." |
| Share exit and quote | REPORT.md lines 84, 151-155, 177-196, and 226 | source observation | Line 84 binds one pool key, one tick range, one salt, and a target currency. Lines 151-155: `uOut` is the floor assets conversion; remove exactly `uOut`; sell only that slice's opposing principal; pay target from that removal's target principal plus sale proceeds; revert below `minTargetOut`; no in-kind fallback. Lines 177-196: `getRate` is the normalized preview of `redeemTarget` for one whole share (`10^18`); it simulates that removal, quotes an exact-in sale of the opposing principal against post-removal state, sets `q` to target proceeds, and normalizes `q`. It excludes `unclaimed`. Line 226: exit pays target or reverts. |
| PoolManager callback and fee return | lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol lines 55-63 and 94-120 | source observation | `unlock` calls `IUnlockCallback(msg.sender).unlockCallback` and reverts `CurrencyNotSettled` if a nonzero delta count remains. `modifyLiquidity` is `onlyWhenUnlocked` and `noDelegateCall`, passes `owner: msg.sender`, and returns `feesAccrued` separately from `principalDelta`. The accounted `callerDelta` is `principalDelta + feesAccrued`. Zero-delta fee collection inside `pool.modifyLiquidity` was not re-read. |
| Share and liquidity conversion | lib/crane/contracts/utils/math/BetterMath.sol lines 726-739 and 784-800 | source observation | `_convertToShares` is `assets * (totalShares + 10**decimalOffset) / (reserve + 1)`. `_convertToAssets` is `shares * (reserve + 1) / (totalShares + 10**decimalOffset)`. That matches the specification's mint and `uOut` equations. It converts shares to liquidity units, not to a target-token amount. The token quote is the specification's later sale, not this function. |
| Implementation search, contracts | contracts/**/*.sol, 1286 files | source observation | No matches for `redeemTarget`, `minTargetOut`, `feePerShare`, `function claimFees`, or `v4-own-vault`. `FeeEscrow` matched only an import of `PonsV2FeeEscrow` in contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol. That file was not opened. It is not this vault. |
| Implementation search, other source trees | test/**/*.sol, 3072 files; scripts, 406 files; lib/**/*.sol, 10700 files | source observation | No matches for `redeemTarget`, `minTargetOut`, `feePerShare`, or `v4-own-vault` in test or scripts. No matches for `redeemTarget`, `minTargetOut`, or `v4-own-vault-spec` in lib. |
| V4 package paths | directory listing under contracts/vaults and contracts/hooks/uniswap/v4 | source observation | The only standard-exchange Uniswap V4 package directory is contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings, whose DFPkg is `UniswapV4UpperLowerWingsStandardExchangeVaultDFPkg`. DETF V4 paths are named detf, bondNft, and standardExchange variants. Hook paths are named stable, weighted, and quad. Those bodies were not read. They are not this specification's one-range vault. |
| Public queries | not used | not used | No public query was sent. No excluded third-party source was fetched. |
| Timed-out whole-repo search | not used | unverified | An unbounded repository search hit its time limit before reaching this report. It is not evidence of absence or presence. |

## Assumptions

- "A deposit of either token" means the depositor can choose one pool currency and deposit only that currency, including while the current tick uses both sides. It does not mean the two-currency entry may receive a zero on the side the tick already leaves unused.
- "A withdrawal into a single token" and "a quote of one vault share into one token" mean the configured target currency. They do not require a caller choice of either pool currency at exit.
- "One vault share" means one whole share, `10^18`, as the specification defines it. The token-denominated quote is section 7's `q`. `getRate` is the normalized publication of that quote.
- "A reserve exposed to trading fees" means the vault holds one in-pool position that accrues trading fees to holders. It does not require those fees to be inside share redemption or inside `getRate`.
- Per-need grades below are specification grades. Absent code is a coverage fact. It is not used to invent an implementation defect, and it is not used to mark a specified behavior failed.
- The research resolution was not opened. Nothing in it is assumed.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md | required | examined | Read in full and checked against the four needs. |
| docs/research/v4-own-vault-spec-20261027-01a177b3/coordinator/resolution.md | optional | not examined | Not required for the four needs. Not opened. |
| An implementation of this specification | required by the question, no path supplied | absent | Completed symbol searches and package listings found no contract. See Evidence. |
| lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol | cited context | examined | `unlock` and `modifyLiquidity` only. Not a review target. |
| lib/crane/contracts/utils/math/BetterMath.sol | cited context | examined | The two conversion functions the specification cites. Not a review target. |
| Cited V2 exchange files | cited context | not examined | The four-needs grades do not depend on re-reading `initAccount` or the exact-in LP branch. The 18 and 9 constants are specification statements, not re-verified here. |
| Wings, DETF, and hook packages | not this target | not examined | Named from paths only, to exclude them. Not reviewed as this vault. |

## Conclusions

Specification grades, from the text that was read, not from an implementation:

- Need 1, a reserve exposed to trading fees: met.
- Need 2, a deposit of either token: failed.
- Need 3, a withdrawal into one token: met.
- Need 4, a quote of one vault share into one token: met.

No contract implements this specification. Code therefore meets none of the four needs. That is a coverage gap. It is not a reading of Wings, DETF, or hook source, and it does not turn the three specified behaviors into code defects.

Need 1 is met on this reading. Line 42 states one diamond owns one Uniswap V4 position. Line 44 states deposited capital funds that position and trading fees accrue in the two pool currencies. Section 3 attributes those fees to holders through an index and `claimFees`, outside `U` and `S`. `PoolManager.modifyLiquidity` returns `feesAccrued` separately from principal and records `owner: msg.sender`, which is the mechanism the specification uses to harvest fees onto the diamond. Fee value is not part of the share's redeemable property and is not in `getRate`. That separation does not remove the position from the fee path. If the required reading were instead "the redeemable reserve includes trading fees," that stronger reading would be failed. The words asked do not require it.

Need 2 is failed. The specification accepts both pool currencies together. It allows one amount to be zero only when the tick already leaves that side unused. It forbids a vault swap, refuses a zap, and says in line 253 that it does not let this vault swap on entry. A depositor who holds only one token cannot deposit while the tick uses both sides. Out of range, the unused token alone yields zero liquidity and the call reverts, so the depositor still cannot choose either token.

Need 3 is met by the specification. Lines 153-155 and the exit sequence at line 226 remove exactly `uOut`, sell only that slice's opposing principal, and pay the configured target from that removal's target principal plus the sale proceeds. A failed or short sale reverts the whole call. There is no in-kind fallback. Fees are not part of this withdrawal; they are claimed in kind on a separate path. The need asks for a withdrawal into one token, not for fee value to be sold into that token, and not for the caller to choose which pool token is paid.

Need 4 is met by the specification. Section 7 defines `q` as the target-token proceeds of redeeming one whole share: simulate removal of that share's `uOut`, then quote an exact-in sale of only that removal's opposing principal against the post-removal pool, at the pool's current fee. `getRate` is `floor(q * 10^18 / 10^dT)` and writes nothing. It reverts when the sale cannot be quoted, the fill would be incomplete, the hook can change amounts, or supply is below one whole share. Those are fail-closed bounds on a specified quote, not a missing quote. The quote excludes `unclaimed`, which matches the share exit it previews. `BetterMath._convertToAssets` supplies the liquidity slice only. The token amount is the specification's sale on top of that slice.

What the sources show is the specification text, the two cited Crane functions, and the absence of a matching contract. What is inferred is that the out-of-range zero amount does not satisfy "either token," and that fee escrow outside the share still leaves the position exposed to trading fees. Agreement is not available. Peers were not read. This is not a council consensus.

## Review findings

### Either-token deposit is refused

- Location: docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md lines 133-139, line 208, and line 253
- Invariant or requirement: The vault can accept a deposit of either token. The depositor chooses one pool currency.
- Impact: Entry pulls both pool currencies and mints only from liquidity those amounts become. A single non-zero amount is accepted only when the current tick already leaves the other side unused. In range, a one-token deposit cannot mint. Out of range, the unused token alone reverts because `uReceived` is zero. Line 139 forbids adding a swap to accommodate a one-token caller, and line 253 states that this specification does not let the vault swap on entry. The vault therefore cannot take a deposit of a chosen token.
- Fix direction: Add a separate either-token entry to the specification. The caller selects one pool currency and an amount. Inside the armed callback, after the pre-mint fee sync, swap only the portion required to add liquidity at the current tick, then mint with the section 1 equation on `uReceived`. Bound the swap and the mint with caller minimums. Do not change section 1, share exit, or `getRate`. Do not claim that deposit swap closes execution-price exposure on the exit sale. Do not implement that route in this review.
- Evidence class: source observation

### No contract implements this specification

- Location: REPORT.md lines 38 and 251-253; completed searches of contracts/**/*.sol (1286 files), test/**/*.sol (3072 files), scripts (406 files), and lib/**/*.sol (10700 files); package directory contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings
- Invariant or requirement: The question asks whether any implementation of this specification meets the four needs.
- Impact: No Solidity uses this specification's receipt, fee index, either-token entry, single-token exit, or one-share target quote. Nothing in the searched source holds this reserve, accepts this deposit, processes this withdrawal, or quotes this share. The only standard-exchange Uniswap V4 package path is the upper-lower Wings package. REPORT.md line 38 says this specification does not change that vault. Wings, DETF, and hook packages were not reviewed as substitutes.
- Fix direction: Do not adapt Wings, DETF, or hook packages into this vault. The specification already withholds implementation authority. A later explicit authorization is required before any diamond is written. This finding does not grant that authorization.
- Evidence class: source observation

## Limits

- Runtime or extraction proof: none. No project test, deployment, or PoolManager trace was run. Static reading is not execution proof. Zero-delta `modifyLiquidity` fee collection was not re-read below `PoolManager`.
- Not examined: the research resolution; the cited V2 `initAccount` and exact-in LP branch; Wings, DETF, and hook bodies; peer responses; frontend, broadcast, and build artifacts. A documentation search matched paths under this review's members directory. Those files were not opened and were not used.
- `10^dT` was not re-derived from token decimals. Section 7 still defines `q` in target-token units before that normalization, so the quote of one share into one token does not depend on re-reading the V2 offset.
- The exit text implies the configured target is one of the two pool currencies. It does not state that constraint in a separate sentence. That implication was not graded as a separate failure.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
