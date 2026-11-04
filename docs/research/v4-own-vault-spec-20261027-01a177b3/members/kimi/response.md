# Member response

## Identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Member label: kimi
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/kimi/response.md
- Requested role: council-member
- Requested model and reasoning: kimi-coding/k3:high
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Write an implementable requirements specification for IndexedEx's own Crane diamond vault that earns trading fees on one homogeneous Uniswap V4 position, mints shares from a price-free liquidity-unit claim, and can be valued and exited in one target token. Settle the receipt shape. Do not reconstruct any third-party implementation.
- Required targets: contracts/protocols/dexes/uniswap/v2 share-mint and exit conversion; docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md; docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md; docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md conclusions only
- Optional context: .agents/skills/crane-architecture/SKILL.md (present, read); docs/agent/INDEXEDEX_AGENT_LAW.md held-reserve rule (present, read)
- Admitted read scope: the required targets, the optional context, and the brief. No third-party Pair Token source was fetched, opened, quoted, or searched for. Public queries: not used.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| V2 exact-in share mint | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol, `_exchangeIn` branches "Underlying Pool Vault Deposit" and "ZapIn Vault Deposit" | source observation | Both call `BetterMath._convertToSharesDown(amountIn_or_lpReceived, reserveBefore, vault.vaultTotalShares, ERC4626Repo._decimalOffset())` where the reserve base is the pre-pull live balance (LP route) or the pre-zap booked `vaultLpReserve` guarded by a live-balance equality revert (zap route). The received units are not in the denominator of the executed call. |
| Share/asset conversion formulas | lib/crane/contracts/utils/math/BetterMath.sol, `_convertToShares` and `_convertToAssets` | source observation (re-read before adopting the equation) | `_convertToShares` computes `assets._mulDiv(totalShares + 10**decimalOffset, reserve + 1, rounding)`; `_convertToAssets` computes `shares._mulDiv(reserve + 1, totalShares + 10**decimalOffset, rounding)`. Confirms `shares = floor(uReceived * (S + 10^d) / (U_before + 1))` and the inverse `uOut = floor(shares * (U + 1) / (S + 10^d))`. |
| OutTarget comment vs executed mint | contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol, comment in `_exchangeOut_zapInVaultDeposit` | source observation | The comment writes `shares = floor(lpReceived * (S + 10^d) / (R_before + lpReceived + 1))`. The executed code it annotates calls `_convertToSharesDown(lpReceived, vault.vaultLpReserve, ...)` with the pre-zap reserve only. The comment is not the mint; the specification adopts the executed form. |
| V2 exact-in exit | UniswapV2StandardExchangeInTarget.sol `_exchangeIn` branches "Underlying Pool Vault Withdrawal" and "ZapOut Vault Withdrawal"; `_withdrawSwapDirect` via `UniswapV2Service` | source observation | Burn shares, assign LP with `_convertToAssetsDown` against the booked reserve, then sell only the opposing token from that LP burn through the pool. The vault's remaining opposing inventory is not sold. Reserve is re-booked from the live balance after the transfer. |
| V2 backing guard | UniswapV2StandardExchangeOutTarget.sol `UniswapV2LpBacking.requireHeld`, `LPReserveMismatch` reverts | source observation | Production guards require live held LP to cover (or exactly equal) the booked reserve at zap boundaries. Pattern carried into invariant I4 below. |
| Wrapper shapes and their limits | docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md | source observation of that report | Two price-free shapes (per-range homogeneous receipt; componentwise basket); scalar mark, cross-range liquidity sum, principal-as-unit, and quote-denominated issue all rejected; transferable receipt reopens a timed LP-sale channel and is not required; fee accrual inside a raw liquidity unit is not provided by the pattern; proposed exit equations and failed-sale rule. |
| Target-fee vault accounting and counterexamples | docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md | source observation of that report | One ratio for mint and exit; mint-time virtual offsets and later-credit fee rules both demonstrated to extract from incumbents (1001-in/1005-out; 100 uncredited fees, 100 in, 150 out); fees must be collected and included before any supply change; `getRate` as normalized one-whole-share redemption, fail-closed reverts. |
| Prior extraction result | docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md, Conclusions section only | source observation of that report | A deposit swap plus an exit swap does not close the quote-rule or executed-price rows; a price-free per-component join removes the acceptance-time ownership distortion under stated conditions but is not post-sale immunity; the same-pool TWAP is a poke record, not an independent price. Cited, not re-litigated. |
| Held-reserve valuation law | docs/agent/INDEXEDEX_AGENT_LAW.md, "Uniswap V4 SE buffer hooks: held-reserve valuation (APEX D60, LOCKED 2026-09-22)" | source observation | A hook values a held reserve as raw balance or `held x rate` via a configured `IRateProvider.getRate()` (WAD per whole share), reads fail closed (`RateProviderFailed` on revert, short return, or zero); a hook never derives a rate from the Standard Exchange it holds. This vault's rate provider plugs into that rule. |
| Crane diamond layering | .agents/skills/crane-architecture/SKILL.md | source observation | Facet-Target-Repo three-tier pattern; all state in ERC-1967 diamond-storage repos; facets are stateless logic exposing selectors via `IFacet`; DFPkg bundling. Used for decision 6. |
| V4 position and fee mechanics | none opened (outside admitted read scope) | inference | That PoolManager keys positions by `(owner, poolId, tickLower, tickUpper)` where owner is the `unlock` caller that receives `unlockCallback`, and that V4 fees accrue as token-denominated claims (feeGrowthInside) rather than compounding into liquidity, is stated from general protocol knowledge. A later implementer must verify both against the admitted V4 sources before relying on them. |

## Assumptions

- The vault holds exactly one position in exactly one V4 pool, with pool key and tick range fixed at deployment. This is taken from the question's "one homogeneous Uniswap V4 position" and settles decision 1's scope.
- The target token is one of the two pool tokens. Target-token liquidity may exist only in that pool; no independent price is assumed anywhere in the specification.
- V4 position ownership and fee mechanics per the inference row above. If the admitted V4 sources contradict either, decisions 3 and 6 need rework before implementation.
- A permissionless compound operation is acceptable as a liveness dependency; the specification never requires it for solvency, only for fee realization.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| V2 share-mint conversion | required | examined | `BetterMath._convertToShares` re-read; both executed mint call sites opened in InTarget. |
| V2 exit conversion and slice sale | required | examined | InTarget withdrawal branches and OutTarget exact-out sizing opened; `_withdrawSwapDirect` call sites read. |
| v4-v2-lp-wrap report | required | examined | Read in full; shapes, rejected marks, exit equations, and fee-gap list carried into the specification. |
| v4-single-token-fee-vault report | required | examined | Read in full; collect-before-supply-change rule and both integer counterexamples adopted as constraints. |
| v4-swap-capture-evidence report, conclusions only | required | examined | Conclusions section read; numeric rows cited as stated, not re-litigated. |
| crane-architecture skill | optional | examined | Present. Facet-Target-Repo and storage-slot rules used for decision 6. |
| INDEXEDEX_AGENT_LAW held-reserve rule | optional | examined | Present. Rate-provider and fail-closed requirements used for decision 7. |
| Receipt shape settlement | required by question | examined | Settled in decision 1 with the dissent recorded. |

## Proposed specification

Everything in this section is proposal unless it quotes an opened source. It is not implementation authorization. Notation: `U` is the vault's booked liquidity-unit reserve (the position's liquidity `L` as reported by PoolManager for the diamond's one position); `S` is share supply including any fee shares minted earlier in the same call; `d` is the ERC-4626 decimal offset; `uReceived` is liquidity units actually added to the position by one call.

### Decision 1. Receipt shape: one homogeneous receipt for one (pool, range)

- Chosen rule (proposal): the reserve asset is a single internal receipt class keyed by `(poolId, tickLower, tickUpper)`, denominated in V4 liquidity units of the diamond's one position. The receipt is a ledger claim, not a transferable token. One outer ERC-20 share owns only this receipt class: its entire backing is `U` plus nothing else. Idle token balances and uncollected fees are never in the mint or redeem base; they enter value only through the compounding path of decision 3.
- Rejected alternatives: (a) the componentwise basket (idle balances plus per-range liquidity as separate backed components) — unnecessary for a single-position product, and its in-kind join reintroduces multi-route refund complexity with no benefit when there is exactly one component; (b) a transferable receipt token — the wrap report records that transferability reopens a timed LP-sale channel the current position does not have and is not required by the V2 pattern; (c) any scalar that sums or prices components — rejected by both prior reports.
- Settlement statement: the wrap report left shape 1 versus shape 2 open. I settle it for shape 1 because the brief's product is one position; the dissent I carry is MiniMax's concern (recorded in the wrap report) that any single unit over a mixed book drifts into a mark — the specification answers it by making the book single-component and refusing to book anything else.
- Evidence class: inference from the wrap report's two shapes, under the question's single-position constraint.

### Decision 2. One outer share owns exactly one range

- Chosen rule (proposal): the share owns a pro-rata claim on the one `(pool, range)` receipt and on nothing else. There is no second range, no second pool, and no idle-balance component in the claim.
- Rejected alternative: multi-range ownership under one share. Summing liquidity across ranges into one unit is already rejected by the brief; a per-range sub-ledger join is the basket of decision 1, rejected there. A later multi-range product is a different vault family, not an extension of this share.
- Evidence class: proposal on the wrap report's conclusion that equal numerical liquidity in two ranges is not the same claim.

### Decision 3. Fee recognition: compound into liquidity units before any supply change

- Chosen rule (proposal):
  - Unit of recognition: liquidity units. Fees increase holder value only by increasing `U` while `S` is unchanged. Fees are never recognized in the mint or redeem denominator as token amounts and are never marked at any price.
  - Mechanism: a compound operation (a) collects the position's accrued token fees from PoolManager, (b) adds liquidity back into the same position with the collected tokens, swapping through the underlying pool only the imbalance needed to match the position's required token ratio at the time of the add, and (c) re-books `U` to the position's new liquidity. Any collected residue that cannot be added stays as an escrowed vault balance outside `U`, carried into the next compound; it is not redeemable and not in any denominator.
  - Timing: the compound step runs as the first step of every deposit, every redeem, and every `getRate` preview, before supply changes or previews are computed. It is also permissionlessly callable, so fee realization never depends on a privileged actor.
  - Capture rule: fees accrued before a deposit belong to the incumbents alone, because they are inside `U_before` before the entrant's mint is computed. This is the fee-vault report's collect-before-supply-change rule transported into liquidity units; its integer counterexample (100 uncredited fees, deposit 100, exit 150) is the failure mode this ordering excludes.
- Rejected alternatives: (a) recognizing uncollected fees in the denominator marked at the current square-root price — reintroduces the spot mark the wrap report rejects; (b) crediting fees as a second token-denominated reserve paid pro-rata on exit — that is a basket component, it pays old fees to new entrants unless pre-credited, and paying it in target on exit forces a sale the acceptance equation did not price; (c) the V2 reserve-ratio fee-share mint (`ConstProdUtils._calculateFeePortionForPosition`) — it reads live reserves and the wrap report left its economic significance untraced, so it is not adopted; (d) a mint-time virtual offset without the compound — the fee-vault report's 1001-in/1005-out counterexample rejects offsets as a substitute for real recognition.
- What the compound swap does and does not do: it executes against the pool and can self-fill against the vault's own liquidity; it changes no share price because it runs while `S` is fixed and only enlarges the common reserve. It is not a deposit swap and does not claim to close any prior extraction row.
- Evidence class: proposal grounded in the fee-vault report's ordering rule and the wrap report's rejected fee paths.

### Decision 4. Single-token entry: in specification, with disclosed exposure

- Chosen rule (proposal): a depositor may enter with either pool token alone. Execution: (1) run the decision-3 compound step; (2) record `U_before` as the position's liquidity after compounding and before this call's add, reverting unless the booked reserve equals the live position liquidity (the V2 zap guard pattern, `LPReserveMismatch`); (3) swap a portion of the input through the underlying pool for the opposing token and add both to the position; (4) read the liquidity units actually received, `uReceived`, from PoolManager's delta — never from a pre-swap quote; (5) mint

```text
shares = floor(uReceived * (S + 10^d) / (U_before + 1))
```

  This is the executed V2 form re-read in `BetterMath._convertToShares`; the received units are not in the denominator. The OutTarget comment that adds them is not the executed mint and is not adopted.
- What it protects: acceptance-time proportional ownership. Because the mint and the reserve share one unit, the acceptance identity `S / (S + m) * (U + u) = U` holds for incumbents at the moment of the mint (the wrap report's form of the prior report's identity), and no old inventory is repriced at acceptance.
- What it does not protect: the entrant's swap executes at the pool's live price, so spot and execution determine how many units the deposit buys; the swap can self-fill against liquidity the vault owns; and per the swap-capture report's closed finding, a deposit swap plus an exit swap does not close the executed-price extraction rows. This specification claims none of those protections and forbids the documentation from claiming them.
- Rejected alternatives: (a) pricing the deposit's units by a pre-swap quote instead of the received delta — reintroduces a price into issuance; (b) a same-pool TWAP or `max(spot, TWAP)` denominator — the TWAP is a poke record, not an independent price, and the brief forbids it as the issuance denominator; (c) a two-token-only entry — workable but fails the product's single-token requirement.
- Evidence class: proposal; the mint equation is source observation of the executed V2 code, the exposure limits are source observation of the prior reports.

### Decision 5. Single-token exit: redeem a slice, sell only its non-target leg, revert on failed sale

- Chosen rule (proposal): (1) run the compound step; (2) compute the liquidity-unit slice

```text
uOut = floor(shares * (U + 1) / (S + 10^d))
```

  the executed inverse conversion (`BetterMath._convertToAssets` with floor); (3) remove exactly `uOut` liquidity from the position, receiving `(amtTarget, amtOpposing)` per the pool's current composition at the current square-root price — this is live composition, an observed property of concentrated liquidity, and a same-block price move can change how one-sided the slice is without changing `uOut`; (4) sell only `amtOpposing` through the underlying pool for the target token; (5) pay the redeemer `amtTarget + saleProceeds` in target.
- Scope limits: the sale never touches the vault's remaining position liquidity, never sells any other opposing inventory the vault holds, and never pays `entitlement(shares, quote, supply)` from a whole-book quote. The escrowed compound residue is not payable on exit.
- Failed-sale rule: if the sale cannot execute at or above the caller's stated minimum, or the removal itself fails, the entire redemption reverts atomically — no partial settlement, no paying unfilled opposing tokens as if they were target, no borrowing target from the incumbent book. An optional separate in-kind exit route may pay `amtTarget` and `amtOpposing` directly with no sale; it is a distinct route and is never used to satisfy the target-token route.
- Rejected alternatives: (a) whole-book liquidation quote paid pro-rata — the swap-capture report's quote-paid exit rows; (b) selling the vault's whole opposing balance to fund one redeemer — named in that report as `_swapDeficit`-style behavior and rejected; (c) returning residual opposing as target credit at a marked price — a spot mark in the exit, rejected.
- Evidence class: the slice-sale shape is source observation of the executed V2 `_withdrawSwapDirect` path; the revert rule and in-kind option are proposal per the wrap report's proposed failed-sale rule.

### Decision 6. Diamond boundary: the diamond owns the position and receives the callback

- Chosen rule (proposal): the V4 position is owned by the diamond proxy address itself. All liquidity modifications are initiated by the diamond calling `PoolManager.unlock`, so the diamond is the address PoolManager calls back (`unlockCallback`) and the position key's owner field. One facet exposes the `unlockCallback` selector and routes it to the liquidity target; that selector is accept-gated to `msg.sender == PoolManager` and protected by the reentrancy lock, since the callback re-enters the diamond mid-operation.
- What the diamond owns: the one position (pool key, tick range, liquidity `L`), the booked reserve `U`, the share supply and ERC-20 ledger, the escrowed compound residue, and the compound/fee accounting — all in Crane ERC-1967 diamond-storage repos (`DEFAULT_SLOT = keccak256(name) - 1` form), one repo per concern, per the crane-architecture skill's Facet-Target-Repo pattern.
- What a facet may store: nothing. Facets are stateless logic over repos, exposing selectors via `IFacet.facetName/facetInterfaces/facetFuncs`, matching the V2 facets opened (`UniswapV2StandardExchangeInFacet`, `UniswapV2StandardExchangeOutFacet`).
- What must not be a copied external clone: no third-party vault source (the brief's hard boundary); no copied V4 periphery PositionManager as the position owner — an external owning contract would put the callback and the position key outside the diamond and break the single-account boundary; no copied fee-accounting module from any external LP wrapper. All PoolManager interaction is direct calls from the diamond's own facets.
- Rejected alternative: a separate non-diamond position-holding contract with the diamond as a client — splits ownership from accounting, adds a cross-contract trust seam for callback gating, and duplicates state the repos already hold.
- Evidence class: proposal on the crane-architecture skill's layering rules; the owner-equals-unlock-caller property is the labeled inference of the Evidence table and must be verified against admitted V4 sources at implementation time.

### Decision 7. `getRate`: normalized preview of one whole share's withdrawal and sale

- Chosen rule (proposal): for one whole share `u = 10^dS` (share decimals), `getRate` simulates, in order: (1) the compound step's effect as of the current block — collectible fees and the resulting `U` increase, or a documented conservative choice to preview with the already-compounded `U` only, stated in the spec and kept identical in preview and execution; (2) the slice `uOut = floor(u * (U + 1) / (S + 10^d))`; (3) the removal amounts `(amtTarget, amtOpposing)` of `uOut` at current pool state; (4) the exact-in sale quote of `amtOpposing` for target through the pool at current state, including the pool fee; (5)

```text
q = amtTarget + saleQuote(amtOpposing)
getRate = floor(q * 1e18 / 10^dT)
```

  in WAD per whole share, `dT` the target token's decimals, matching the fee-vault report's normalization.
- What it is not: not `liquidateAll(book) / supply`, not an issuance NAV, not an input to any mint or redeem equation, and not a rate a hook may derive by reading this vault as its own reserve — under the locked held-reserve law a hook holding this share uses this provider as a configured `IRateProvider`, never a self-derived conversion.
- Revert cases (fail closed, per the locked law's `RateProviderFailed` semantics): zero share supply; `uOut` rounds to zero; position liquidity `U == 0`; the removal preview or sale quote reverts, returns short, or returns zero; pool locked or uninitialized. A synthetic `1e18` at zero supply is explicitly rejected — that is the production behavior the swap-capture report flagged.
- Disclosure: the preview is live-state dependent; a same-transaction trade can move it between quote and execution. That is a disclosed property of a withdrawal-and-sale preview, not a violation, and the caller's minimum-out parameter is the binding protection on the executed path.
- Rejected alternatives: whole-book quote over supply (the current production form, rejected by the wrap report for this purpose); zero-sale redemption preview (the fee-vault design's form — correct for that design where nothing is sold, wrong here where the exit sells).
- Evidence class: proposal; normalization form and fail-closed rule are source observation of the fee-vault report and the locked law.

### Decision 8. Invariants a later agent must test

These are requirements on the future test suite, not authority to write tests in this run.

- I1 Acceptance proportionality: for any entry minting `m` shares against received units `u`, incumbents' fractional claim on `U` is unchanged at the mint instant: `S / (S + m) * (U + u) = U` up to one-unit floor rounding in the vault's favor.
- I2 Round-trip loss bound: deposit then immediate redeem of the same shares returns no more target than deposited, minus disclosed pool fees and floor rounding; no profitable same-block round trip with no external price move.
- I3 Fee isolation at acceptance: fees accrued before a deposit but not yet compounded cannot be captured by the entrant — equivalently, the compound step's effect on `U` is applied before `S` changes in every entry, exit, and preview. The fee-vault report's 100/100/150 integer pattern is the canonical negative test.
- I4 Reserve-ledger agreement: at every state transition boundary the position's live liquidity equals the booked `U`; any gap reverts (the V2 `LPReserveMismatch` pattern). Direct token donations to the diamond never change `U` or per-share value until a compound books them.
- I5 Exit slice scope: a redemption's sale moves at most the opposing amount removed for that redemption; the vault's remaining position liquidity and escrowed balances are unchanged by the exit except for the removed slice. A whole-book sale on any exit path fails this invariant.
- I6 Failed-sale atomicity: any redemption whose sale misses the caller's minimum reverts in full; no state (share burn, liquidity removal, balances) survives the revert.
- I7 `getRate` consistency and fail-closed behavior: `getRate` equals the independently computed slice-withdrawal-and-sale preview for one whole share under the same state; it reverts on every case listed in decision 7 and never returns a synthetic constant.
- I8 Callback confinement: `unlockCallback` executes only when `msg.sender` is the PoolManager and only inside a diamond-initiated unlock; direct external calls revert. The position owner recorded at PoolManager is always the diamond address.
- I9 Rounding direction: every conversion rounds in favor of existing holders (floor on mint, floor on redeem slice, ceil nowhere on user-facing value flows).
- Evidence class: proposal, each item traceable to a source row in the Evidence table.

## Conclusions

- Observation: the executed V2 mint is `shares = floor(uReceived * (S + 10^d) / (U_before + 1))` with received units absent from the denominator (InTarget's two call sites plus `BetterMath._convertToShares`, re-read); the OutTarget comment that includes them is not the mint. The specification adopts the executed form only.
- Observation: the executed V2 exit assigns LP by the floor inverse conversion and sells only the redeemed slice's opposing token, re-booking the reserve from the live balance afterward.
- Inference: with one homogeneous position, the wrap report's open shape question resolves to the per-`(pool, range)` receipt, and the basket is rejected as unneeded; the fee-recognition gap the wrap report left is closed by compounding fees into liquidity units before any supply change, which is the fee-vault report's collect-before-supply-change rule restated in the vault's native unit.
- Proposal: the eight-decision specification above is complete enough to implement from this file plus the cited IndexedEx sources, with the one labeled inference (V4 ownership and fee mechanics) flagged for verification at implementation time.
- The specification does not claim that a deposit swap plus an exit swap closes the prior extraction result; it claims only acceptance-time proportional ownership plus slice-scoped exits, and it states the residual execution exposure in decisions 4 and 5.
- `getRate` is kept as the normalized one-whole-share withdrawal-and-sale preview; this response does not redefine it and does not treat it as NAV.
- No peer agreement is claimed; peers were not read. This is not council consensus.

## Limits

- Runtime or extraction proof: none. No test, Forge trace, or profit measurement was run; all equations are design statements or source reads.
- Not examined: the in-repo V4 sources (outside this run's admitted read scope), the swap-capture report beyond its conclusions, production Wings files, and any third-party Pair Token material (hard boundary, untouched).
- Live files can move; the V2 reads are not an atomic snapshot. The OutTarget comment-versus-code discrepancy is reported as observed on this date.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
