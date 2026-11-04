# Member response

## Identity

- Run ID: se-fullspread-prd-quality-20261103
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: `docs/reviews/se-fullspread-prd-quality-20261103/members/grok/response.md`
- Requested role: council-member
- Requested model and reasoning: `xai/grok-4.7:xhigh`
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the rewritten full-spread PRD say each locked requirement clearly enough that two implementors would copy it the same way?
- Required targets: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`
- Optional context: none supplied as a second review target. The clarity standard is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, including the 2026-11-03 overrides. A later override wins. `docs/vaults/PRETRANSFER_DIRECTIVE.md` is binding for pretransfer sentences.
- Admitted read scope: the brief, the required PRD, the blockers file, and the pretransfer directive. No peer responses. No public search.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Rewritten PRD, all 644 lines | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | source observation | Revision `fullspread-se-prd-rewrite-20261103`. Locked sentences are restated in sections 1.3 and 1.4 and repeated in the money, facet, unlock, quote, hook, and test sections. |
| Clarity standard, all 413 lines | `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md` | source observation | 2026-11-03 overrides F1, F2, F5, F6, F7, and F12 sit above earlier B-01 through B-13 sentences. The file still contains earlier sentences that those overrides replace. |
| Pretransfer directive | `docs/vaults/PRETRANSFER_DIRECTIVE.md` | source observation | Locked 2026-11-02. One maximum against the unbooked held balance. Overstated maximum refunds that balance, does not pull, and is not a revert. |
| Public query | not used | source observation | No excerpt was sent to a search service. |
| Runtime | not run | source observation | No Forge, tests, installs, deploys, wallets, or Git. |

Line numbers below are from those reads. A "two implementors" impact is inference from the sentence that was read, not a second source.

## Assumptions

- A later sentence in the blockers file wins over an earlier sentence there, as the brief and the PRD precedence table say.
- Awkward wording is not a defect when one behavior satisfies every operative sentence. A defect is a sentence two implementors would copy differently, a contradicted sentence left beside a lock, or a requirement too unclear to test.
- `compound()` is copied as the no-argument call used throughout the PRD. That argument list is not listed as a defect. `donate` is different: the same file requires arguments and never orders them.
- `Donation()` with no fields is a clear PRD copy. F7 says `Donation()` fields were not named. That is not a positive field list, so "no fields" is not treated here as a contradicted lock. Two implementors of the PRD copy no fields.
- The accepted ABI report, the preview-consumer index, and source contracts were not opened. A finding does not claim those files are silent.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` | required | examined | All 644 lines read and compared with the locks. |
| `IMPLEMENTATION_PLAN_BLOCKERS.md` | required as the clarity standard | examined | All 413 lines read. Later override wins. |
| `docs/vaults/PRETRANSFER_DIRECTIVE.md` | required for pretransfer sentences | examined | Whole file read. |
| Accepted return-ABI report cited by the PRD | not in the admitted read scope | not examined | The PRD incorporates it by reference. This review does not claim that report is silent. |
| Preview-consumer report and index | not in the admitted read scope | not examined | The PRD names them as the consumer list and says not to paste the index. |
| Peer responses | forbidden | not examined | Peers were not read. |
| Source contracts | not in the admitted read scope | not examined | No code was used to fill a gap in the PRD. |

Checked and not a defect, because the PRD states one copy:

- `getRate` and `rateAsset` stay withdrawn. FS-OWN-03, FS-OWN-29, and FS-RATE-01 agree. The external provider is not this vault's rate.
- The sleeve stays absent. FS-OWN-04 and FS-OWN-12 do not restore `localReserves()` or the 5% band.
- `previewExchangeOut` returns zero. `exchangeOut` reverts `ExchangeOutNotAvailable()` and moves no tokens. FS-OWN-08, FS-OWN-19, and FS-A09 agree.
- F14's principal-only withdrawal sentence is rejected at PRD line 257. The PRD does not contain "pays only the principal" or "principal fraction". The floor formulas at line 222 match F2's share of `feesAccrued` and of each booked balance, measured before the burn and rounded down. The conflict is the narrower bullet at line 418, listed below, not the absence of F2.
- The owner check is a live `feeTo()` read, not a stored owner. That replacement is clear. The callee is not. See the finding.
- The 30% clamp is `3e17`. A resolved fee above 30% is used as 30%. A resolved fee of 30% or less is used as read. The fee is taken from `grossShares`, not minted on top. A pass-through, including underlying-to-underlying `exchangeIn`, takes no fee. FS-OWN-24.
- The floor is `MIN_SHARES` (`1_000`) at `address(0)`, inside `totalSupply()`, and not part of `grossShares`. FS-OWN-11 forbids `ERC20Repo._increaseBalanceOf` and the shared facet path. FS-A05 names `_mint`. The lock file's N-01 says that path writes `balanceOf` and `totalSupply` directly. Those sentences can be copied as one mint.
- A single overstated pretransfer maximum refunds that unbooked balance, does not pull the shortfall, and is not a revert. That matches F1 at blockers line 21 and the directive. "Do not spend that declared amount" does not create a second single-leg outcome, because refunding the whole unbooked balance and not pulling already forces that leg to use zero. The open case is the other declared amounts in the same call.
- The 48% remark is not a required swap. FS-OWN-33 copies F5 and forbids an "about half" swap.
- No `QuoteWorkLimit`, no 64-step cap, and no minimum tick spacing. Section 6 and FS-OWN-22.
- A borrowed one-token exit does not call `unlock()`, does not pay from a sleeve, and does not revert `UnderlyingUnavailable` for an unpullable fraction. FS-OWN-13 and FS-OWN-31. The swap is the FS-OWN-30 claim, not principal alone.
- The already-unlocked path is canonical `exchangeIn` only. The other named routes revert `ManagerAlreadyUnlocked`. FS-X01 and FS-UNLOCK-01.
- Selectors `0x89d61912` and `0xd02d3063` stay. There is no `WithRefund` sibling. `0x676ec907` is not advertised.
- Caller-facing amounts stay on the WETH face. The other-chain substitution address is an explicit non-specification, not a second package field. FS-OWN-17.
- FS-A20's "or" is not a separate defect. Line 445 assigns a funding or route failure to the inherited error and a borrowed-path context miss to `InvalidUnlockedContext`. Step 1's "or" is not assigned that way. See the finding.

## Conclusions

The PRD does not yet say every locked requirement so that two implementors would copy it the same way.

What the sources show: most 2026-11-03 overrides are applied as one sentence, and the old principal-only withdrawal sentence is not left as a requirement. What I infer: twelve sentences still split a copy, either because an earlier lock remains beside the later one or because the PRD names a gap and does not close it. Agreement with other members is not available. Peers were not read. This is not a council consensus.

## Review findings

### One-token donation spend is two rules

- Location: PRD line 190. Compared with PRD lines 168 and 170, blockers line 150, and blockers line 266.
- Invariant or requirement: The later booking lock says `donate()` also compounds, and both calls process the combined balance of collected fees and the booked remainder. A one-token call may swap fees or a booked remainder. Blockers line 150, the earlier B-05 sentence, says the one-token swap spends the donated tokens only.
- Impact: Line 190 keeps both. "swaps its own tokens" copies the earlier sentence. The next sentence spends "the combined one-token maintenance balance from FS-OWN-14." One implementor swaps only the new donation. The other swaps that donation plus same-token fees and the same-token booked remainder. The amounts that move, and the accepted sandwich surface, are not the same.
- Fix direction: Keep the combined-balance spend already stated at lines 168 and 190. Qualify or remove "swaps its own tokens" so it cannot be read as "donated tokens only." Do not add a third spend rule. The opposing-token exclusion already in line 190 can stay.
- Evidence class: source observation of the two sentences; inference that they license two spend amounts.

### Sibling pretransfer amounts are unnamed

- Location: PRD line 238. The call that has more than one declared amount is the inlined `exchangeBundleInForSingleOut` at lines 125-126.
- Invariant or requirement: F1, blockers line 21, and the pretransfer directive specify one maximum against one unbooked balance. They do not say what the other declared amounts in the same call do. The PRD copies that silence and says so.
- Impact: The single-leg case is copyable: refund that unbooked balance, do not pull, and do not revert. For one overstated leg beside another declared amount, one implementor still uses the other legs, one uses none, and one reverts the whole call. F1 forbids a revert for the larger maximum itself. The sibling outcome is not one testable assertion.
- Fix direction: Do not invent the sibling outcome. The sentence that says it does not say what the other amounts do is not a copyable requirement. A lock has to say whether those other declared amounts are still used. Do not add an error. F1 already says a larger maximum is not a revert.
- Evidence class: source observation. The split is inference from the PRD's own silence.

### Borrowed-entry preconditions share one "or"

- Location: PRD line 444. The error gloss is lines 324 and 326. Step 6, which assigns `SettlementMismatch` alone, is the settlement paragraph after line 444.
- Invariant or requirement: A failed borrowed-entry precondition has to revert one declared error, or two implementations will not revert the same way. `SettlementMismatch` is glossed as the close failure. `ReentrantOperation` is glossed as the FS-UNLOCK-02 guard. Line 444 does not use that gloss.
- Impact: "initialized", "idle", empty callback hash, zero reservations, and zero own deltas are five conditions. The failure of any of them reverts `SettlementMismatch` or `ReentrantOperation`. Two implementors will pair those conditions differently. A test that asserts one error cannot be written from this sentence.
- Fix direction: Map each precondition in step 1 to one error already declared in FS-FACET-01. Do not leave the "or". Do not add a new error. If the initialized check has no declared error, say that instead of choosing one.
- Evidence class: source observation of line 444; inference that the gloss does not close the "or".

### Bundle-deposit proportion is undefined

- Location: PRD line 208. The scarcer-token definition is line 170. The refund rule for unused declared entry input is FS-OWN-32 and FS-A07.
- Invariant or requirement: A bundle deposit must add one determined amount of liquidity. The already-locked blockers sentence says a bundle deposit does not run the balancing swap. It does not define "in proportion." Line 170's scarcer-token rule is stated for a both-token `donate` or `compound`, not for this user deposit.
- Impact: "in proportion" can be copied as the position-ratio scarcer token, as the smaller raw balance, or as a reject unless the caller already matched the position. Those deposits are not the same. "returns the rest" is the FS-OWN-32 refund of unused declared input, not the donation booking rule, if the reader joins FS-A07. That join is not what is unclear. The proportion base is.
- Fix direction: Name the proportion base with words already used for a matched-pair deposit, or say that no locked sentence defines it. Do not add a new formula. Say in the bundle-deposit sentence that "the rest" is the FS-OWN-32 refund, if that join is the intended one.
- Evidence class: source observation of line 208; inference that line 170 does not attach itself to line 208.

### `donate` has no parameter list

- Location: PRD lines 113, 190, and 214. The file contains no `function donate`.
- Invariant or requirement: The kept `donate` route has to be one function. Line 190 requires a token in `vaultTokens()` or the share, a directed amount, and `pretransferred`. Line 214 says this lock does not add a deadline. The accepted bundle signatures are inlined. `donate` is not one of them, and the PRD does not point it at the ABI report.
- Impact: Argument order changes the selector. A recipient is neither required nor forbidden. A token outside the accepted set is rejected, and the error is not named. Two implementors will not expose the same function.
- Fix direction: State one parameter list using only the arguments the locks already name, in one order. Do not add a recipient or a deadline. For a token outside that set, name an error already listed, or say none is named. Do not invent selector hex. If the unread ABI report already defines `donate`, cite that signature instead of a new one. This review did not open that report.
- Evidence class: source observation that the signature is absent from the PRD; inference that the described arguments do not determine order.

### `exchangeIn` correlation event is unnamed

- Location: PRD line 176. Bundle events are named at line 152.
- Invariant or requirement: F7 and line 176 say a caller deposit or withdrawal is correlated by the Standard Exchange event in the same transaction, and that this vault does not invent a second amount-bearing event. Line 152 names `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)` for the bundle routes only.
- Impact: `exchangeIn` is a caller deposit or withdrawal and has no event name. One implementor emits only ERC-20 `Transfer` plus the PoolManager events. Another emits the paired events on the one-token route. Another looks up an event this PRD does not name. A correlation test cannot be written from the sentence.
- Fix direction: Name the existing event that already correlates `exchangeIn`, or say that route emits no vault event beyond `Transfer` and the PoolManager `Swap` and `ModifyLiquidity` events already named. Do not invent an event. Do not extend the paired events to `exchangeIn` unless a lock already says they fire there.
- Evidence class: source observation of lines 152 and 176.

### Withdrawal `feesAccrued` is not tied to the unpaid-fee read

- Location: PRD lines 220 and 222. The unpaid-fee read is line 65.
- Invariant or requirement: F2, blockers line 27, books `feesAccrued` on a share-minting deposit and, on a withdrawal, pays the caller's rounded-down share of `feesAccrued` and of each booked balance. Those are two terms. Line 65 says the deployed read includes fees owed and not yet collected, and that a booked remainder is not in that read.
- Impact: Line 220 books the `modifyLiquidity` return value. Line 222 then uses `feesAccrued` again, beside `bookedBalance`. One implementor reads withdrawal `feesAccrued` as the unpaid fee-owed amount and treats tokens already booked as booked balance only. Another stores the deposit return in `feesAccrued` and also adds it to booked balance, then pays both. The second copy pays the same tokens twice.
- Fix direction: Say that the withdrawal `feesAccrued` term is the unpaid fee-owed read already named at line 65, and that tokens booked from an earlier `modifyLiquidity` return are only in the booked-balance term. Do not add a fee stock or a fee-origin store. Do not change the floor formula.
- Evidence class: source observation of the two uses of the name; inference that the PRD does not join them to line 65.

### `feeTo()` has no callee

- Location: PRD line 166. Repeated at lines 190 and 371. Line 404 says initialization does not store `feeTo()` as a stored owner. The usage-fee read is named at line 202 as `usageFeeOfVault(address(this))`.
- Invariant or requirement: F12, blockers line 31, is a live check that the caller is the address currently returned by `feeTo()`. The PRD copies that. It does not name the contract or facet that returns it. The FS-FACET-01 selector tables do not list `feeTo`. The factory exclusions do not include a fee facet.
- Impact: One implementor calls a vault `feeTo()` that is not on the listed cut. Another calls the package `oracle`. Another calls `feeTo(address)` rather than `feeTo()`. The owner check cannot be tested until the callee is one function. The live-versus-stored rule itself is clear and is not the defect.
- Fix direction: Name the existing function and the contract or facet that already returns `feeTo()`, and say whether that facet is already on the cut. Do not invent a `feeTo` selector. Do not restore a stored owner.
- Evidence class: source observation that the callee is unnamed; inference that more than one placement fits the sentence.

### `basicVaultFacet` is two facets

- Location: PRD lines 293, 304, 63, 194, and 363.
- Invariant or requirement: FS-OWN-07 and FS-OWN-23 say `vaultTokens` is `MultiAssetBasicVaultFacet` and that `reserveOfToken` and `reserves` are the family custom facet, which exposes only those two selectors. The cut has to name both facet addresses. `PkgInit` has one field called `basicVaultFacet`.
- Impact: Line 293 says `basicVaultFacet` is the custom implementation in FS-OWN-07. Line 304 says that field is not one shared facet, then splits the selectors across `MultiAssetBasicVaultFacet` and the family custom facet. Line 363 creates facet files for money, quote, out, query, and callback, and no reserve facet. One implementor puts the custom facet in `basicVaultFacet` and has no `PkgInit` field for `MultiAssetBasicVaultFacet`. Another puts `MultiAssetBasicVaultFacet` in that field and hangs the reserve selectors on `queryFacet`, whose row does not list them. The packages are not the same cut.
- Fix direction: Say which `PkgInit` field carries `MultiAssetBasicVaultFacet` and which carries the facet that exposes only `reserveOfToken` and `reserves`. Name that facet's file from the file list already required, or say the file list does not include it. Do not install the other multi-asset reserve selectors. Do not invent a third reserve view.
- Evidence class: source observation of the conflicting field descriptions.

### Zero recipient and `address(0)` are not one reject

- Location: PRD line 242.
- Invariant or requirement: Section 2.1 rejects a zero recipient and the vault as recipient. Line 242 also says `address(0)` reverts `TokenNotExchangeable`, and it names `InvalidRoute` and `EmptyExchange` for the other rejects in the same sentence.
- Impact: One implementor uses `TokenNotExchangeable` for a zero recipient, because that is the named `address(0)` error. Another treats `address(0)` as the token and leaves the recipient error unnamed. The vault-as-recipient reject has no error in either reading. Two implementations will not revert the same way.
- Fix direction: Say whether a zero recipient uses `TokenNotExchangeable` or another error already declared, and name the vault-as-recipient reject the same way. Do not add an error.
- Evidence class: source observation of line 242.

### Unmapped bundle token combinations are not classified

- Location: PRD lines 113 and 115. The signatures are lines 120-126 and 139.
- Invariant or requirement: Deposit maps to `exchangeBundleInForSingleOut` with `tokenOut` as the share. Redeem maps to `exchangeBundleOut` with `tokenIn` as the share and `tokensOut` as the two ERC-20 faces. Line 115 says the one-token exit is not `exchangeBundleOut` with one output. FS-OWN-19 says an unsupported view route returns zero, and the execution route of an unsupported path still reverts. The PRD does not say these other combinations are unsupported.
- Impact: One implementor reverts an already-listed unavailable error when `tokenOut` is not the share, or when `tokensOut` is not the two faces. Another implements a success path for those combinations. Line 115 does not choose, because "is not the one-token exit" does not say the call reverts.
- Fix direction: Classify each unmapped combination as unsupported, and name the already-listed unavailable error for that function. Do not add a success path. Do not add an error. `ExchangeBundleInForSingleOutNotAvailable` and `ExchangeBundleOutNotAvailable` are already named as accepted interface errors. Say which combination uses which, or say the lock does not choose.
- Evidence class: source observation of the mapping sentences; inference that they do not close the other argument combinations.

### One-token exit claim is stated at two widths

- Location: PRD lines 418, 420, 222, and 224.
- Invariant or requirement: F2 and F6 say a one-token exit converts all unwanted withdrawn principal, plus the caller's opposing-token fee and opposing booked claim, or reverts `AmountOutNotMet` and does not burn shares. The caller's requested-token fee and requested booked claim are paid. The rest is booked for the other holders. Line 222 states that floor formula.
- Impact: Line 418 says the one-token exit converts "the caller's FS-OWN-30 booked claim." An implementor who follows that bullet omits the opposing fee from the swap. Line 420 says the withdrawal pays "the caller's FS-OWN-30 claim," which is the wider claim. Line 224 then says "The other holders' shares are booked, not swapped." That can be copied as booking shares, which FS-OWN-11 forbids as a second ledger. The floor formula books token amounts. These are not one exit.
- Fix direction: Make line 418 name the exiting claim already stated in the conversion sentence at line 224: unwanted withdrawn principal, plus the opposing-token fee and opposing booked claim. Replace "shares are booked" with the token booking already stated at line 222. Do not change the floor formula. Do not add a share ledger.
- Evidence class: source observation of the four sentences; inference that "booked claim" and "shares are booked" are narrower or different copies of F2.

## Limits

- Runtime or extraction proof: none. This is a static reading. It does not prove that an implementation matches the PRD.
- Not examined: the accepted ABI report, the preview-consumer index, peer responses, and source contracts. The PRD says the full 45-ID audit disposition was not read into this pass. This review did not read it either. The absence rows the PRD does restate were compared with the blockers table. Unnamed `PkgInit` field names for the six architecture addresses, and for the two Crane facet inputs, are marked by the PRD as not invented. They are not listed as defects. The testable lock is the seven immutables, written into the Protocol Aware Repo, with no second per-vault copy. Identifier spelling is not a second behavior in this review.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path. A fix direction is advice. It was not applied.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
