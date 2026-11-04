# Specification fidelity audit and correction requirements

Final identity: pair-spec-fidelity-final-r2. Reviewed draft: `coordinator/draft.md`, immutable `pair-spec-fidelity-r1`, SHA-256 `31c5cab73e3a62883c07a53f590255350a146617c67f5da8a348866562c99874`.

The final is a coordinator revision after one advisory pass. The preserved draft, not this revised wording, was member-reviewed. See `coordinator/resolution.md` for every substantive disposition.

## Verdict

**No. The supplied report does not correctly document the supplied PairToken implementation. Do not use it as a source-equivalent specification or as a source-equivalent clean-room development handoff.**

All four independent reviewers reached that conclusion: Astra, Grok, MiniMax, and Kimi. Their agreement supports the review result but is not a substitute for source evidence or a runtime proof.

The decisive mismatch is explicit in the report itself. `docs/research/v4-own-vault-spec-20261027-01a177b3/REPORT.md:6` asks for a new IndexedEx Crane design, while line 19 says the PairToken specification question was not admitted and the third-party source was excluded. This audit compared the source anyway under the user's current explicit request. The old exclusion is evidence of the report's intended scope, not a restriction on this audit.

The report is an alternative design proposal, not a faithful specification with a few missing details. Its principal economic requirements must be replaced or separated to describe PairToken. This audit does not modify that report or supply implementation authority.

## Scope, evidence, and participation

- Target report: the path above, read completely and archived as `evidence/specification.md`.
- Target code: Sourcify sources for chain `4663`, address `0x56C8c249d4c021e93635b120aC68A9a36eb01753`, retrieved October 27, 2026. The JSON reports exact creation/runtime matches and verification on October 12, 2026. Those are Sourcify observations, not a bytecode check independently performed by this council.
- Source archive: `evidence/sourcify-sources.json`; readable bundle: `evidence/sources.md`, 28 files. Retrieval identity and original/archive SHA-256 digests are in `evidence/manifest.md`.
- Method: static documentation-to-source comparison. No tests, compilation, deployed-state reads, transactions, or economic/security proof.
- Coordinator: invoking agent, not an additional vote. Actual coordinator model was not exposed through task metadata.
- Requested and actual participants: four substantive independent originals, all completed, with no substitutions.

| Member | Requested Native route | Actual identity exposed in completion notification | Task |
| --- | --- | --- | --- |
| Astra | `chatgpt-subscription/gpt-6-astra:high` | `council-member(chatgpt-subscription/gpt-6-astra)` | `st_01a17d68` |
| Grok | `xai/grok-4.7:xhigh` | `council-member(xai/grok-4.7)` | `st_01a17d69` |
| MiniMax | `minimax/MiniMax-M3` | `council-member(minimax/MiniMax-M3)` | `st_01a17d6a` |
| Kimi | `kimi-coding/k3.1-pro:high` | `council-member(kimi-coding/k3.1-pro)` | `st_01a17d6b` |

Owner of these task handles: invoking session `01a17d57-ab12-74e2-b0aa-283ffbf92a1e`. Reasoning suffixes are requested settings; notifications do not independently expose all effective reasoning settings. MiniMax's adaptive-thinking override was observed in configuration, not inferred from its prose. Credentials and billing were not inspected. Actual process/isolation details beyond explicit `isolated:false` admission were not exposed.

Originals are preserved in `members/<member>/response.md`. Each was independent and assigned the same brief. The coordinator read all originals and the complete PairToken contract, and checked key math/helpers and findings against the archived source. Member-specific dependency coverage remains visible rather than being promoted to coordinator-wide examination.

## Confirmed findings

Severity is relative to source-equivalent specification use, not vulnerability severity. Report locations below use original report line numbers. Source ranges explicitly labeled bundle refer to `evidence/sources.md`; named symbols are from original `src/pair/PairToken.sol`. For PairToken only, bundle line equals original source line plus three. The exact original-source anchor table below removes any numbering ambiguity.

### F1 - Blocker: the accounting unit and mint formula are different

Report: Terms and section 1, lines 46-80; section 9 items 1-3.

Source: `PairToken.basket`, `previewDeposit`, `_quoteShares`, `deposit`; readable bundle lines 217-290 and 500-521.

The report uses booked liquidity `U` and virtual terms:

```text
shares = floor(uReceived * (S + 10^9) / (U_before + 1))
```

PairToken instead reads position amounts at the live square-root price and adds idle balances to form reserves `r0,r1`. For ordinary two-sided reserves:

```text
grossShares = min(floor(amount0*S/r0), floor(amount1*S/r1))
used_i = min(amount_i, ceil(grossShares*r_i/S))
```

If supply is zero or both reserves are zero, its quote is integer `sqrt(amount0*amount1)` using checked multiplication. With exactly one reserve zero it quotes only against the other reserve and uses zero of the empty side. There is no booked `U`, offset 9, or issuance based on the liquidity actually added.

**Consequence:** a report-conforming implementation mints a different claim and different share amounts. **Correction direction:** a source-equivalent baseline needs the complete piecewise basket rule, exact floors/ceilings, and quote/pull ordering; the report's liquidity-unit rule must remain explicitly separate.

### F2 - High: first-deposit economics and slippage ordering are missing

Report: sections 1, 4, and 8; no genesis/dead-share specification.

Source: constants and `deposit`, `_quoteShares`; bundle lines 62-69, 260-294, 503-511.

At zero supply, the geometric quote must exceed `1000`, and the add must open positive liquidity. PairToken mints `1000` shares to the dead address and subtracts them from the recipient's gross quote. The `minShares` check occurs before that subtraction. `previewDeposit` returns the gross quote, not net recipient shares. Dead shares remain part of ordinary outstanding supply; the report's zero-supply residual lifecycle is a different model.

**Consequence:** initial supply, minimum-acceptance behavior, and recipient proceeds cannot be reproduced. **Correction direction:** specify the dead mint, constants, guards, gross/net distinction, and operation order.

### F3 - Blocker: fee ownership is reversed

Report: Product line 44; sections 3 and 8; transfer/claim invariants.

Source: `compound`, `_compound`, `_carve`, `_ratioSwap`, transfer functions; bundle lines 159-183 and 415-497.

PairToken collects into the vault, attempts a factory-configured protocol carve, and redeploys usable idle balances into the position, potentially after a ratio swap. It does not mint shares for compounding. The collective share property benefits. There are no account fee indices, debts, historical unclaimed balances, escrow liabilities, or `claimFees` API. Transfers only move shares; they do not crystallize seller-retained fees.

The collection branch consumes settled `callerDelta` returned by `_modify(0)`, not a fee-index allocation directly based on the separately returned `feesAccrued`. It encodes each amount as `uint256(uint128(delta.amount_i()))`. Caller delta may include hook effects under the supplied interface.

**Consequence:** rights to earnings, transfer semantics, deposited property and exit amounts all differ. **Correction direction:** describe collective compounding and actual return-value use; remove or separately label the report's personal-fee subsystem.

### F4 - High: protocol routing and compounding rules are omitted

Report: sections 1 and 3 reject compounding and omit a protocol take.

Source: embedded factory/fee-manager interfaces, `_compound`, `_carve`, `_ratioSwap`, `_deployInLock`; bundle lines 22-32, 418-497, 579-613.

Runtime factory reads supply `feeManager`, `protocolFeeBps`, `maxZapBps`, and `maxZapTickMove`. The attempted protocol amount is `floor(collected_i*protocolFeeBps/10000)` when manager and rate are nonzero. Notification reverts are caught; ERC20 routing first approves and attempts clearing approval after a caught notification revert. This is not a guarantee that every external failure is caught, approval is always cleared, or a successful ERC20 notify actually consumed tokens. Factory getter failures can propagate.

If either idle balance is strictly greater than `1000` raw units, compounding computes fitting liquidity and upward-rounded needs, selects the heavier leftover (token0 valued with two sequential square-root-price floors; token0 wins ties), returns a zero swap when the selected leftover is at most `1000` or active pool liquidity is zero; otherwise it proposes half the selected leftover, floored, and clips the swap by:

```text
floor(floor(active-pool-liquidity-implied input reserve * maxZapBps / 10000) / 4)
```

A zero swap does not itself skip the subsequent deployment attempt. The remaining usable idle is added at the post-swap price. The compounding cap is not the user-zap vault-basket cap, and compounding does not apply the user-zap tick-movement guard. Ordinary deposit and redemption call `_compound` and can therefore cause swaps.

**Consequence:** yield, integration dependencies, execution order, and failures are underspecified. **Correction direction:** document the actual algorithm and call sites without inventing factory values or notification behavior absent from the bundle.

### F5 - Blocker: redemption property, haircut, output choice and failures differ

Report: section 5, lines 143-161; section 7; exit sequence.

Source: `redeem`, `redeemZap`, `_redeemToSelf`, `_swapOnly`; bundle lines 354-410, 541-550.

For shares `s`, pre-burn supply `S`, and actual position liquidity `L`, source redemption uses:

```text
payout = floor(s * 9990 / 10000)
liqOut = floor(L * payout / S)
removed_i = uint256(uint128(removalCallerDelta_i))
amount_i = removed_i + floor(idle_i * payout / S)
```

The removal caller delta includes principal, fee deltas, and applicable hook deltas under the supplied interface; it is not guaranteed to be principal alone. The explicit same-width signed-to-unsigned `uint128` conversion reinterprets a negative `int128` as an unsigned value before widening. This is a source observation, not a demonstrated reachable negative-delta failure, overflow, or exploit.

It burns the caller's `s`, retains 10 basis points in the vault's property, and includes proportional idle balances. Ordinary `redeem` pays both currencies with independent minima. `redeemZap` lets the caller choose either currency per call and swaps the unwanted redeemed amount with redeployment disabled. There is no configured permanent target or report-style virtual-offset removal.

Zero removed liquidity is not independently rejected. A small positive burn can return zero if minima permit. Swaps request exact input with near-extreme sqrt limits, but this contract does not explicitly assert complete consumption or independently require positive output. Do not import the report's full-fill/zero-output revert guarantees.

**Consequence:** ordinary and edge-case payouts and reverts differ. **Correction direction:** specify both routes, sequential rounding, retention, sender-only burn, selected-token behavior and actual minima/partial-fill boundaries.

### F6 - High: the report excludes a material entrypoint and misstates entry funds

Report: section 4, lines 131-141; Recommendations line 301.

Source: `deposit`, `zapDeposit`, `_addAll`, `_pull`, `_refundNative`; bundle lines 260-347 and 647-679.

`zapDeposit` is implemented. It requires existing supply and both basket reserves positive; validates the input token/native value; bounds nominal input by the selected pre-zap **vault basket reserve** times runtime `maxZapBps`; pulls measured receipt; requests a half-input swap; adds fitting idle; checks tick movement against runtime `maxZapTickMove`; and mints against the pre-zap basket using deployment used amounts. It is not an external-router substitute.

Paired deposit compounds and quotes/checks shares before pulling amounts. ERC20 receipt is balance-measured but shares are not recomputed from that measurement. Quoted unused ERC20 is not pulled; pulled funds that do not fit the add remain idle, rather than being universally refunded. Native requires exact value and uses a reservation to exclude current input/refund from incumbent idle; refunds go to the sender, not the share recipient.

Unlike the report's booked-`U` reconcile-or-revert rule (report lines 157 and 238), ordinary source deposit does not maintain or compare such a ledger: the explicit positive-added-liquidity guard is for genesis. F4 also explains why a paired deposit or redemption may swap during compounding even outside a named zap route.

**Consequence:** a report implementation removes the zap and changes balances, shares, and refunds. **Correction direction:** specify both routes and exact transfer/reservation/order behavior. Do not infer comprehensive fee-on-transfer safety merely from balance measurement.

### F7 - High: idle balances and donations belong to a different claim

Report: section 2 line 86; section 5 line 153; invariant 5.

Source: `basket`, `_idle`, `receive`; bundle lines 224-234 and 647-651, receiver at 136.

Source idle is the actual currency balance minus the operation-scoped native reservation stored in the ordinary state variable `_reservedNative`. Direct currency transfers become part of the basket and can fund redemption and compounding. They are not filtered by the report's excluded-donation/fee-escrow categories.

**Consequence:** subsequent quotes and ownership differ even without a new share mint. **Correction direction:** record source balance-based ownership, not a proposed segregated property ledger.

### F8 - High: initialization, position identity and callback boundaries are different

Report: sections 2 and 6; one-callback sequences in section 8.

Source: `initialize`, `positionLiquidity`, `_unlock`, `unlockCallback`, `_modify`, `nonReentrant`; bundle lines 124-155, 217-221, 550-644.

Initialization is one-shot with a nonzero manager; the first successful caller becomes `factory`. It derives min/max usable ticks from tick spacing, uses zero salt, and configures no target. `NotFactory` is declared but not used. Clone deployment is described by source NatSpec; the factory implementation and actual deployed clone transaction/bytecode are not supplied. Crane facets, DFPkg/registry and storage repos are not this implementation.

The callback checks the configured manager and decodes operation data; there is no armed single-use flag binding budgets/caller/recipient. User money entrypoints use `_entered`; callback and ordinary ERC20 transfers do not use that modifier. A single user action may cause multiple collect/deploy/add/remove/swap unlocks, not one report-style encompassing callback. Settlement resolves positive/negative deltas, but the concrete manager implementation is absent.

**Consequence:** initializer ABI/trust, range identity, deployment assumptions, callback admission and external-call order differ. **Correction direction:** separate observed contract behavior from clone-factory comments and missing implementations; label diamond/armed-callback adaptations as changes.

### F9 - High: `getRate` is not a source function; the real previews are unspecified

Report: section 7, lines 177-200.

Source: `basket`, `previewDeposit`, `previewRedeem`; bundle lines 224-253.

There is no `getRate`, `redeemTarget`, normalized target-token preview, or corresponding hook-domain guard. `previewDeposit` uses the present basket without compounding and returns gross genesis quote. `previewRedeem` returns two basket amounts after retention; zero shares or supply returns `(0,0)`. It does not simulate removal and sale, check holder balance, or share the report's one-whole-share revert domain.

Actual redemption floors a liquidity slice and idle allocation separately; preview floors proportional total basket amounts. Pending compounding and this rounding distinction mean exact execution equality is not guaranteed.

**Consequence:** integrators cannot reproduce source views using the report. **Correction direction:** document existing views and their execution differences. Keep an IndexedEx `getRate` requirement as a separate adaptation; this finding does not recommend changing that project's rate contract.

### F10 - High: interfaces, sequences and acceptance criteria are not source-complete

Report: sections 8-9 and the absent full ABI appendix.

Source: entire PairToken public surface, events/errors and token helpers.

The report's invariants primarily test its alternative accounting. It omits concrete approval/allowance behavior, sender-only redemption, native handling, metadata, constants, events and error identities. Finite `transferFrom` allowance is consumed; max allowance remains unchanged; transfers reject zero recipient and do not sync fees. `Redeem` on the zap route emits pre-swap pair amounts, not final single-token output. Different token-transfer helpers have different error behavior.

**Consequence:** passing the report's future tests would not establish source equivalence. **Correction direction:** provide a traceable interface/branch/rounding/sequence baseline and derived acceptance criteria, not an additive appendix that leaves contrary core requirements intact.

## Exact original-source anchors

These anchors use original `src/pair/PairToken.sol` line numbers, not bundle numbering.

| Symbols | Original lines |
| --- | --- |
| Public state/getters and constants | 47-74 |
| Events; custom errors | 54-55, 116-118; 102-114 |
| Manager/non-reentrancy modifiers; receiver | 120-133 |
| `initialize` | 138-152 |
| ERC20 operations and mint/burn helpers | 156-197 |
| Pool/key/token/liquidity getters | 201-218 |
| `basket`; previews | 221-230; 233-250 |
| `deposit`; `_addAll`; `zapDeposit` | 256-302; 308-346 |
| `redeem`; `redeemZap`; `_redeemToSelf` | 351-406 |
| `compound`; `_compound`; `_carve`; `_ratioSwap` | 412-496 |
| `_quoteShares`; `_minShares` | 500-529 |
| `_deploy`; `_swapOnly`; `_unlock`; callback | 533-571 |
| `_deployInLock`; `_modify`; `_resolve` | 576-642 |
| Idle/native/pull/refund/token helpers | 646-691 |

F10's interface and failure observations are anchored by the public state, events/errors, ERC20, receiver and token-helper rows above; the complete public surface is inventoried below.

## Coverage

### Every report section

All rows were examined in each initial review; their fidelity is summarized below. Prior-council administrative assertions were read, not independently reconstructed.

| Report section | Result against source |
| --- | --- |
| Question | Different design target. |
| Authorization and scope | Explicit source exclusion, not source-fidelity evidence. |
| Participation | Earlier process metadata only. |
| Conclusions framing | Does not establish source equivalence. |
| Product | One fungible position partly aligns; accounting, architecture and fee property differ. |
| Terms | 18 decimals and supply concept align; booked liquidity, offset and fee ledger do not. |
| 1. Receipt and mint | Contradicted; F1-F2. |
| 2. One share, one range | One fixed position partly aligns; chosen range/salt/target and excluded property differ; F7-F8. |
| 3. Fees | Contradicted; F3-F4. |
| 4. Entry | Paired route shape partly aligns; mint, swaps and refund/property rules differ; F1-F2/F6. |
| 5. Share exit | Contradicted; F5. |
| 6. Diamond boundary | Direct vault ownership/manager callback partly align; deployment and guards differ; F8. |
| 7. getRate | New proposed API, not source behavior; F9. |
| 8. Sequences | Different accounting and unlock boundaries; F1-F8. |
| 9. Invariants | Primarily tests the alternative; F10. |
| What this does not deliver | Does not remedy omissions and deliberately rejects some source routes. |
| Evidence | Cites V2/Crane, not a prior PairToken comparison. |
| Coverage | Explicitly says target source was not examined. |
| Disagreement and missing responses | Earlier design dissent, not evidence of source behavior. |
| Advisory review | Earlier review history, not this fidelity audit. |
| Recommendations | No-zap requirement conflicts with source. |
| Limitations | Static qualifications do not establish equivalence. |
| Publication | Artifact metadata only. |

### Complete public surface

All 17 named public/external functions, payable receiver, and 17 public getters were examined in the council. Member matrices retain original-source locators.

| Source surface | Source-equivalent report status |
| --- | --- |
| `initialize` | Wrong/omitted initialization and position parameters. |
| `approve`, `transfer`, `transferFrom` | Allowances omitted; transfer fee side effects contradicted. |
| `poolKey`, `token0`, `token1` | General pool concept only; concrete getters/native semantics missing. |
| `positionLiquidity` | Replaced by booked ledger/equality rules. |
| `basket` | Not specified; its price/idle property deliberately rejected. |
| `previewDeposit`, `previewRedeem` | Missing; `getRate` is not a substitute. |
| `deposit`, `zapDeposit` | Partial route resemblance versus explicit zap exclusion; actual math/order missing. |
| `redeem`, `redeemZap` | Wrong property/math/output/failure rules. |
| `compound` | Collective model contradicted. |
| `unlockCallback` | Sender check concept aligns; arming and operation boundaries differ. |
| `receive` | Missing unrestricted native receiver/property implications. |
| `name`, `symbol`, `decimals` | Metadata omitted; 18 decimals aligns. |
| `totalSupply`, `balanceOf`, `allowance` | Broad share/supply concepts only; dead supply and allowance specifics missing. |
| `BPS`, `DEAD_SHARES`, `RETENTION_BPS`, `DUST`, `DEAD` | Missing source constants. |
| `factory`, `poolManager`, `poolId`, `tickLower`, `tickUpper`, `initialized` | Missing/different initialization, identity and runtime dependency contracts. |
| `Transfer`, `Approval`, `Deposit`, `Redeem`, `Compounded` events | Exact payloads/order not specified. |
| Declared custom errors, arithmetic/external failures | No complete observable failure contract; unused `NotFactory` must not become an invented guard. |

### Dependencies and limits

The coordinator independently parsed all 28 readable bundle sections and compared each body with the archived JSON: 28/28 identical, no missing or extra source paths. This establishes rendering fidelity, not library correctness.

Astra and Kimi report full reading of all 28 bundled files. Grok and MiniMax distinguish focused reads, partial helpers and unexamined indirect dependencies; their narrower coverage must not be recast as full independent library audits. The coordinator read PairToken completely and checked the relevant currency, rounding, square-root, amount and liquidity helpers. No reviewer proved every library algorithm.

Not supplied: factory/fee-manager implementations, concrete deployed PoolManager/Pool swap engine, configured hook/token implementations, live factory parameters, deployed clone transaction/bytecode and chain state. Embedded interfaces and call sites show dependencies, not their full implementations. The original report's Crane/V2 citations are different artifacts and do not verify this target.

## Disagreement, qualifications, and rejected overstatements

- **Verdict:** no independent member supports source-equivalence or readiness for the requested handoff.
- **Independent-design usability:** Kimi and MiniMax view the report as relatively coherent/useful in outline. Astra and Grok emphasize missing ABI, initialization/native behavior, quote/hook predicates and other unresolved choices. Coordinator conclusion: potentially useful as an alternative proposal; completeness and correctness of that design are not certified.
- **MiniMax F11 (withdrawn overstatement):** the interface's `feesAccrued` inflation warning is real (`evidence/sources.md:840-842`). Donation can also supply assets, however; the warning alone does not prove a liability/collected mismatch or the claimed exploit. Do not publish that claim as a confirmed vulnerability. The actual source delta distinction belongs in F3. For the alternative index design this remains an interface caution to resolve against actual settlement/manager behavior, not an established liability defect. MiniMax withdrew the stronger original claim in advisory feedback.
- **Archive hashes:** some originals read the manifest before its correction and report a mismatch. The archive adds one terminal newline. Removing it exactly reproduces the fetched response bytes/digest; source bodies and metadata match, and current manifest lists both original and archive hashes. No JSON re-serialization or unrecoverable response loss occurred. Preserve originals, correct the synthesis.
- **Clone/factory:** source comments describe EIP-1167 deployment, while executable initializer/storage are observed. Do not claim independently verified deployed clone mechanics.
- **Nonstandard tokens:** measured `_pull` receipt is not a source guarantee of general fee-on-transfer safety; paired share quote is not recomputed.
- **Security:** absence of the report's armed flag establishes non-equivalence, not a demonstrated vulnerability or proof the weaker boundary is safe.
- **Workflow:** MiniMax and Grok reported using assigned-path write/edit fallbacks because apply_patch was unusable in their task bridges. These are consultation-process deviations, not target-code defects. Native identities come from task metadata, not member signatures.

The report's proposal labels are honest about its own V2/Crane design baseline. A deliberate departure can simultaneously be a contradiction when used as a specification of PairToken; an omitted source behavior is a separate completeness gap. This review does not accuse the earlier report of concealing its chosen scope.

## Clean-room handoff and correction direction

There are three separate questions:

1. **Does this document specify PairToken? No.** Foundational behavioral contradictions block that use now.
2. **Does it describe a possible alternative IndexedEx vault? Yes, in outline.** The council did not certify it as complete, secure, or implementation-ready.
3. **Does this establish an unexposed-implementer process or legal clearance? No determination.** The old report asserts source exclusion; this council is source-exposed and these evidence/audit files contain source-informed material. Exact-match metadata, SPDX identifiers and documentary accuracy do not settle clearance.

For the requested source-equivalent development, a separate implementer-facing behavioral specification would need the basket/genesis equations, collective fee/protocol/idle model, both entry and exit routes, retention, real previews, initializer/position/callback boundaries, complete interfaces/events/errors, and traceable assumptions for missing external implementations. Its acceptance criteria must correspond to those behaviors rather than the alternative's `U`/escrow invariants.

Preserve the current report as a clearly labeled independent design rather than silently replacing its adopted product choices. Separate raw source and this source-informed audit from any later material approved for an unexposed implementer. This audit does not provide legal advice, create an approved clean-room process, rewrite the specification, or authorize implementation.

## Advisory outcome and publication

| Member | Advisory disposition | Final treatment |
| --- | --- | --- |
| Astra | Support; two non-blocking precision corrections | Zero-swap exits added; native reservation described as ordinary operation-scoped state. |
| Grok | Support with reservations | Exact callback casts retained; Grok and MiniMax fallback process notes both recorded. |
| MiniMax | Support with requested changes | All R-C1 through R-C11 addressed in the resolution; unsupported original claims explicitly superseded. |
| Kimi | Support; no changes requested | Source/provenance qualifications preserved. |

All four initial and all four advisory turns settled and their files were read. No missing response was treated as approval. No member dissents from the non-equivalence verdict. Differences about alternative-design completeness remain qualified, not voted away.

Published final: `docs/reviews/v4-pair-spec-fidelity-20261027-01a17d57/REMEDIATION_PRD.md`. The original report and production code were not edited. Originals, draft, feedback, evidence and resolution are retained. The final's post-advisory changes are coordinator-owned and not newly member-approved wording.

Verification: archived JSON parsed; 28/28 source bodies match; original/archive newline identity and digests checked; key findings and advisory locators re-read. No tests/builds were appropriate to this static review and none were run. JSON diagnostics could not run because the configured biome executable is not installed; no install was attempted. No runtime, security or legal-clearance certification is made.

