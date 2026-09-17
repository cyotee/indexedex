# APEX 2026-09-17 remediation and regression tests

- **Status:** draft
- **Created:** 2026-09-17
- **Updated:** 2026-09-17
- **Source request:** A security auditor wrote this report /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/docs/audits/APEX-IndexedEx-Audit-2026-09-17.pdf. I need to write a PRD to write tests that fix these errors, and write tests that prove these errors have been fixed.
- **Owner clarification:** If the report contradicts our project law, than our law is wrong.

## Summary

Deliver production fixes, executable reproductions, and permanent regression tests for the findings in the [APEX re-audit](APEX-IndexedEx-Audit-2026-09-17.pdf). Tests first demonstrate the reported behavior on the affected version, then prove the corrected behavior through production-deployed proxies while valid user operations continue to work. Tests do not themselves fix contracts: each confirmed implementation defect requires a production correction and evidence linking that correction to its regression. Existing FullSpread remediation is reused and independently checked rather than duplicated.

Unrelated callers must not receive prior inventory through input-credit or refund paths. **The owner explicitly directs this remediation to supersede conflicting project law.** Public-prepayment and unsolicited-transfer rules that permit the reported behavior must change, together with tests that currently bless that behavior. The findings cannot be closed as accepted design risks. The audit establishes the security outcomes to achieve; its proposed implementation shortcuts still require executable proof that they achieve those outcomes.

The outcome is a reviewable evidence bundle, not a claim that existing live instances have been repaired. This drafting session inspected local source and specifications; it did not execute the auditor's PoCs, run Foundry, query the chain, or verify current exposure.

### Source and version boundaries

| Evidence | Identity and interpretation |
| --- | --- |
| Audit | Seven-page PDF, dated 2026-09-17; auditor will / zauth, Vector APEX v1.23.5. Page references below are PDF pages. |
| PDF identity | SHA-256 `1065dfd9d0b85dd53b3af1c073fdaa5bc5301891847554b10926e205c4207485`. |
| Audited source | IndexedEx `aca16198a87ab292a87e104f85fd7035fbb3320d`; Crane `d87c74b7` as reported. Resolve and record the full Crane revision during reproduction. |
| Reported chain reproduction | Robinhood mainnet, chain ID 4663, block 64025200 for 001-M. Reported on a local fork; no live transaction is requested here. |
| Inspected checkout | IndexedEx HEAD `ee7827f137e2a4d7d9a8fee65902f9ba930819bc`; Crane HEAD `dfc93a9bcf7bcb4376333a10c74d924417b2bfbe`; substantial pre-existing tracked and untracked changes. HEAD alone does not identify the inspected files. |
| Existing V3/V4 work | Preserved implementations are under `contracts/protocols/dexes/uniswap/`; current replacements are named `UniswapV3FullSpreadStandardExchangeVault` and `UniswapV4FullSpreadStandardExchangeVault` under `contracts/vaults/standard/exchange/protocols/uniswap/`. |

The audit's counts, profits, classifications and claims of live exposure are **auditor-reported**, not independent results of this PRD. Its registry address is abbreviated and its original PoC source is not included in the PDF. Recover the full registry from checked deployment artifacts or verified chain reads; never invent its missing bytes. Independent tests can be written from the documented sequences without the original PoC files.

### Finding coverage

| Finding | Report severity / deployment | PDF | Required disposition and proof |
| --- | --- | --- | --- |
| APEX-2026-001-M | Critical / live at reported observation | 1–2 | Historical V3/V4 stale-reserve reproduction; corrected FullSpread delivery and positive controls; R3. |
| APEX-2026-001-M2 | Scope extension of 001-M / seven reported vaults | 3 | Complete instance and implementation inventory; historical-state replay and version mapping; R4. Not a separate arithmetic defect. |
| APEX-2026-003 | High / live custody vault | 3 | Reproduce public-share burn/refund; replace unsafe public-custody behavior; verify corrected authorization and supported withdrawals; R5. |
| APEX-2026-008 | High / pre-deployment | 3–4 | Orbital prior-face-balance refund reproduction, all five reported reachable sites, corrected conservation; R6. |
| APEX-2026-009 | High / pre-deployment | 4–5 | ERC-4626 and Morpho self-share sweep, burn authorization and refund bounds; R7. |
| APEX-2026-004B | High / pre-deployment | 5 | Idle-underlying sweep through all three cited ERC-4626 routes; R8. |
| APEX-2026-005 | High / structural | 5–6 | Canonical local-balance calculation, separate delivery/refund authorization, complete affected-consumer inventory; R9. |
| `beforeSwap` guard claim | Withdrawn false positive | 6 | Retain negative caller/context tests; no invented guard fix; R10. |
| Weighted dust claim | Downgraded to informational | 6 | Preserve successful buffering controls; prove residual behavior with production SE integrations; R10. |

### Existing authority and conflicts

| Specification or test | Consequence for this PRD |
| --- | --- |
| [Shared V3/V4 remediation PRD](../../contracts/vaults/standard/exchange/protocols/uniswap/UNISWAP_V3_V4_STANDARD_EXCHANGE_REMEDIATION_PRD.md) | Preserve old source; prove stale-reserve exploit on old code and prevention on new packages; source changes do not upgrade deployed instances. |
| [FullSpread liquidity-leak PRD](../../contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md), D2/D9/D10/D15/D19/D24 | Preserve local held accounting, exactness rules and bounded refunds. Supersede D2/D9 wherever raw unassigned surplus authorizes arbitrary callers or excludes the audit's donation attacks. Update D12/D24 self-call behavior if it can consume protected input. A balance difference alone is no longer sufficient authorization. |
| [Rebasing-aware custody PRD](../../contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md), API-07/API-12 | Supersede the public-balance ownership exception for both SE and SY. Preserve supported authorized withdrawals and SY's burn-exactly-requested/no-remainder-refund semantics; require attributable funding. |
| [Custody adversarial suite](../../test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol), `test_ADV_publicSharesArePublic` | Retain as historical evidence only; replace the current-version expectation of third-party consumption with rejection/no-gain assertions and a valid authorized integration control. |
| [Orbital adversarial suite](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_Adversarial.t.sol) | Remove the exclusion of bare face donations from security coverage. Add the auditor's actual scenario; booked-inventory tests alone do not cover it. |

## Requirements

1. **R1 — Give every report item a traceable, evidence-based disposition.**
   - [ ] Maintain `docs/audits/apex-2026-09-17-evidence.md` with one row per finding and separate rows for both retractions. Each row records PDF page, affected source/function, public selectors, package/version, reproduction test, corrected-version test, fix revision, execution evidence and residual limitation.
   - [ ] Use explicit states: `REPORTED`, `REPRODUCED`, `FIX_IMPLEMENTED`, `VERIFIED_FIXED`, `WITHDRAWN`, `BLOCKED`. A code edit alone is not `VERIFIED_FIXED`. The owner's clarification rules out closing a retained finding as accepted public-custody behavior.
   - [ ] Record full repository/submodule revisions, dirty-source patch or file hashes, compiler/profile configuration, runtime artifacts and test fixtures for each evidence run. Historical and corrected builds have separate artifact/cache provenance.
   - [ ] Map the reported ten credit implementations and payout sites to current code and classify their actual custody model. Audit-wide counts of 125 payouts and 20 raw-balance payouts are reported reference counts, not a substitute for a concrete list. Explain count changes from renames, deletions and new versions.
   - [ ] Preserve existing in-progress work and its validation records. Reuse tests that already prove an acceptance condition, recording exact test names; add missing assertions rather than duplicating entire suites.
   - [ ] Link structural finding 005 to the concrete exploit regressions it governs and scope finding 001-M2 to instance-level 001-M evidence. Neither requires an invented independent exploit simply to fill a row.

2. **R2 — Require a failing security assertion before each production correction and a passing assertion after it.**
   - [ ] For each confirmed behavior defect, run the same security property against the vulnerable and corrected versions. Before the fix it fails because the forbidden balance, refund or credit actually occurs; after the fix it passes. Compilation failure, missing artifacts, unavailable RPC and a setup revert do not count as reproduction.
   - [ ] Where historical behavior is intentionally preserved, a clearly named baseline-demonstration test may pass by asserting exploitation. Keep it separate from the corrected-version security regression; record the corresponding security-property failure in the evidence bundle.
   - [ ] Use separate honest depositor, attacker, market trader, caller, payout recipient and fee recipient where their roles differ. Record input costs, minted/burned shares, refunds, backing, protocol positions and relevant reserves immediately around the attack operation.
   - [ ] Negative tests assert the precise intended error and unchanged affected state. Successful-path tests assert exact transfers and share changes, including the legitimate unused-input refund. Reject broad `expectRevert()` and success inferred only from a return value.
   - [ ] Include a valid operation from the same prepared state beside every attack rejection. A disabled route, zero output caused by rounding, or an unrelated access failure is not proof that accounting was repaired.
   - [ ] Execute through actual package-deployed proxies with real registry, fee oracle, pools and SEs. Do not rewrite the vulnerable arithmetic inside a harness and present that as end-to-end proof; pure helper boundary tests supplement production-route tests.

3. **R3 — Close 001-M on both replacement Uniswap families without mixing valuation and delivery.**
   - [ ] Reproduce on each preserved family: honest deposit creates deployed liquidity plus positive local inventory; a separately funded actor trades directly against the real pool; stored reserve remains stale while deployed inventory changes; a zero-input attacker calls a pretransfer route and obtains an unearned claim or output. Demonstrate redemption where the path permits it.
   - [ ] On each FullSpread replacement, an unauthenticated no-transfer call fails its context/authorization check. Also execute a valid authenticated context that delivers zero input after the pool movement: it must fail the delivery check itself. Both attempts mint no shares, pay no output/refund, change no holder entitlement and leave no reusable credit. Assert each exact intended error; price movement alone never changes the stored local-custody baseline.
   - [ ] Exercise both token sides and both price directions, partial mismatch before the old clamp activates, `deployed == storedTotal`, and `deployed > storedTotal`. Include a rebalance followed by another external trade: a temporary reserve refresh cannot satisfy closure.
   - [ ] Cover single-input deposits, direct swaps, multi-input joins, exact-output routes, share deliveries and all associated refund paths. Cover no-position and no-price-movement controls, fees collected/uncollected, liquidity movement, imported positions, and V4 native wrapping on affected routes.
   - [ ] Preserve valid pulls and provide authenticated atomic pushes, exact-in delivery equality, exact-out funding against actual used input and measured refund caps. Confine Native SY self-call holder burns to input authorized for that operation, not arbitrary existing self-shares. Verify a real funded operation after price movement; verify zero/short delivery and attempted reuse after success.
   - [ ] Preserve FullSpread's existing booked-local semantics: `reserveOfToken` records held ERC-20 inventory at the specified operation boundary. Never subtract a live deployed quantity from a stored total to authorize input. Do not mechanically delete `deployed` while leaving a total-backing reserve in place; positive delivery controls must expose that incompatible accounting change.
   - [ ] Test callback/lock contexts already supported by V3 and V4, and ensure changed delivery/refund code cannot be reentered to credit or spend the same input twice.

4. **R4 — Treat 001-M2 as an instance-level scope requirement, not a one-vault fix.**
   - [ ] Inventory all seven addresses below and the custody address, recording chain/block, registry membership, package/facet identities, runtime code hashes, token identities, relevant balances and the mapping to a tested replacement version.
   - [ ] Recover and enumerate the full reported registry at the pinned historical state. Record discovered affected instances beyond these seven; neither token branding nor a currently closed gate is a safety classification.
   - [ ] Reproduce 001-M at block 64025200 for the primary reported vault. For every listed instance, execute the historical probe and record whether its gate is open, closed or unavailable at that same block. Do not demand seven profitable exploits when the report says only two were open, and do not label closed gates fixed.
   - [ ] Derive `reserveOfToken(address)` from the real interface and verify the report's `0x46f910ac` selector; validate decoding and token order against typed calls. Record the abbreviated registry-address limitation until recovered.
   - [ ] Historical fork tests run locally under the existing fork profile. Network failures and unsupported archival reads remain explicit blockers; they are not skipped green evidence. Record a fresh read-only assessment separately from historical reproduction when operational closure is evaluated.
   - [ ] The evidence distinguishes `replacement verified` from `existing deployment remediated`. No source patch, hidden factory, registry discovery change or periodic rebalance is proof that immutable deployed bytecode changed. Produce a replacement/migration handoff inventory; deployment and operational transactions require a separate request.

   | Reported instance | Report label |
   | --- | --- |
   | `0x999DaE02D22E5FEe1c4508430D5196d31d631009` | UniV4 WETH / DTF; explicitly marked open |
   | `0xb7D4Bb379D361AD442CddEE53eA71a33957826A7` | UniV4 WETH / DTF |
   | `0x3E33871A8740b294A48347BFFD8A5004E1578c0D` | UniV4 WETH / PONS |
   | `0x201d31a56c58a3489beC218c7A899d59A07A35f0` | UniV4 WETH / PONS |
   | `0xabC9C5B5c8118a15A440Ac59a1C74A718E65681C` | UniV4 WETH / PONS |
   | `0x17B5f1045Edf3b6215d0C38eB9FF50649d887D10` | UniV4 USDG / MARTIANS |
   | `0x64e0f5A5Cf0F579EFF0981A4fEDEA77964B74531` | UniV4 ETH / PONS |
   | `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` | Rebasing-aware custody vault, 003 |

   The PDF says two of seven gates were open but labels only the first address `OPEN`; do not invent the second identity.

5. **R5 — Reproduce and resolve 003's public-share custody and refund behavior.**
   - [ ] Deploy the real rebasing-aware package. An honest holder acquires static wrapper shares and transfers them to the vault; a separate caller then triggers SE withdrawal with the smallest burn that produces nonzero assets. Show who receives the asset payout and the remaining shares. Derive the burn from actual previews/rounding; the report's approximate `1e11` is not a universal constant.
   - [ ] Test both SE entrypoints, exact-input/exact-output limits, distinct caller/recipient, zero/short/exact/excess self-held shares, callback-added shares, intervening rebases and a second attempted redemption.
   - [ ] An unrelated caller cannot burn or refund the earlier holder's input. Merely changing the refund recipient or suppressing the refund is insufficient if an unauthorized caller can still burn the shares and withdraw their backing. Preserve valid holder/approved-owner withdrawals and an authenticated atomic integration path.
   - [ ] Explicitly resolve SY internal-balance redemption in the same policy change: it must not remain an alternate path to consume the inventory declared protected. Preserve its burn-exactly-requested and no-SE-remainder-refund semantics on supported authorized calls.
   - [ ] Retain asset-input pretransfer rejection with its exact error; the custody vault is not assigned 001-M merely because it supports static-share pretransfers. Preserve live rebase accounting, its documented decimal offset and zero-output protection.
   - [ ] Amend API-07/API-12 and the public-share tests as part of remediation. Both the SE refund attack and equivalent SY consumption must fail on the corrected version; documenting an atomic-use recommendation alone cannot close 003.

6. **R6 — Close 008's orbital refund of prior face inventory.**
   - [ ] On the production hook package, reproduce the reported sequence: a third party leaves 500 token0 on the hook; the attacker contributes 1 token0 through a normal liquidity operation; record hook, SE-share and attacker balances. Treat the reported 499-token net profit as a reference observation, not a hard-coded result for every fixture.
   - [ ] Map and test all five reported permissionless callers of `_refundConservation`, plus affected withdrawal users of `_freeTokenBalance`. Exercise each buffered leg, raw legs and identity-buffer legs independently.
   - [ ] Corrected operations return only unused input authorized for that operation. Pre-existing face inventory cannot become a refund or new input credit for the next caller; retained/buffered value remains accounted to existing holders. An attacker must not gain the earlier 500-token balance through either direct transfer or inflated share issuance.
   - [ ] Verify both booked idle face balances and unbooked donations as separate cases. The replacement `max(balance - book, 0)` expression alone does not prove the second case safe when book is zero. Assert book updates at the actual settle/buffer boundaries and no counting both face inventory and its resulting SE shares.
   - [ ] Test residual amounts `0`, `1`, `MAX_DUST_WEI - 1`, `MAX_DUST_WEI`, `MAX_DUST_WEI + 1`, and a material balance. Legitimate unused user input goes to its authorized recipient; protocol residual that cannot be buffered follows R10's fee/retention rule.
   - [ ] Preserve preview/execution agreement, honest join/withdraw behavior and supported SE exchange paths after the correction. Update conflicting public-surplus documentation with the implementation.

7. **R7 — Close 009 in both ERC-4626 and Morpho share-burn paths.**
   - [ ] Independently reproduce `_burnSeShares` in each production package: victim supplies self-held shares; an attacker supplies none, burns a small nonzero fraction, and receives the remainder. Record burned shares, refund and asset/receipt output. Include the report's 1/1000 split where the fixture's rounding permits it.
   - [ ] Enumerate all actual call sites; the report cites six, but route enumeration rather than a copied count determines coverage. Exercise SE-to-underlying and SE-to-receipt routes in both exactness modes where supported, including delegated Morpho paths.
   - [ ] Both the burn and the refund require authorized operation input. No whole-self-balance sweep, booked-share consumption or prior-user input consumption is permitted. Refund equals the permitted unused operation input, bounded by supplied input and the route's limit; a fat declared maximum does not create refund entitlement.
   - [ ] Add controls with booked self-shares plus funded caller input, overpayment, short funding, no funding, reused input and caller distinct from recipient. Verify exact supply reduction equals only the actual burn.
   - [ ] Preserve non-pretransferred owner burns and their insufficient-balance/allowance failures. Test min-output/max-input rejection and failed external payouts with full transaction rollback.
   - [ ] Remove the unsafe public-prepayment assumption as well as the overbroad-refund implementation. A smaller refund is not closure if the attacker can still consume the earlier holder's shares by declaring a larger input or maximum.

8. **R8 — Close 004B's sweep of idle underlying.**
   - [ ] Reproduce with 250 underlying tokens supplied by a third party, followed by an attacker contribution of 10 through the real ERC-4626 SE. Record the earlier balance's destination, attacker input/output/refund, SE shares and protocol-vault receipts.
   - [ ] Cover both cited InTarget routes and the cited OutTarget route that call `_refundOrAbsorbAbove(tokenIn, msg.sender, 0)`. Test both booked idle underlying and unsolicited underlying; do not substitute receipt tokens for underlying.
   - [ ] Corrected pull operations snapshot or otherwise preserve prior held inventory and refund only this operation's unused authorized input. Prior idle assets remain backing or are deposited for existing holders, never refunded to the next caller or silently minted into that caller's share entitlement.
   - [ ] Verify supported authenticated funded push paths, receipt-input routes, exact-output overpayment and partial consumption. Treat zero-consumption/dust branches explicitly, with honest positive controls and exact supply/backing conservation.
   - [ ] A zero `keepBalance` argument is removed from any route where it exposes earlier holdings. Merely adding a balance subtraction without proving the source and update timing of its floor is not closure.

9. **R9 — Address 005 with one canonical availability rule and separate authorization rules.**
   - [ ] Inventory every in-scope credit/refund implementation with its balance unit, booked unit, synchronization point, declared amount semantics, authorized payer, credited recipient and residual destination. Review both Common implementations and caller/delegate paths.
   - [ ] Reuse a shared production helper for local availability: `available = balance > bookedLocal ? balance - bookedLocal : 0`. Where a route uses a capped budget, `budget = min(available, maximum)`. Its inputs must be local quantities in identical token units. Pool valuation, fees still in a pool and rebasing asset growth cannot authenticate delivery.
   - [ ] Keep exact-in equality checks distinct from exact-out capped budgets. A generic `min` helper must not conceal excess delivery that FullSpread exact-in currently rejects. Preserve actual-used rather than declared-max accounting on exact-output paths.
   - [ ] Verify `balance < book`, equality and greater-than cases; zero/max limits; token-unit boundaries; and no underflow/overflow. A deficit authorizes zero new credit and cannot trigger a fallback that returns the entire balance. Preserve family-specific insolvency/reconciliation errors outside this helper.
   - [ ] Test independently that a caller-declared maximum is not proof of ownership. An attacker setting maximum to all available shares cannot consume another operation's input. Do not present `_prepaidCredit` as an ownership check.
   - [ ] Route applicable non-historical consumers through the shared rule without forcing unlike custody models into one refund policy. Preserve the audited Uniswap reference trees. Every inventory row identifies the shared helper or a documented semantic exception with its own executable equivalent property.
   - [ ] Validate shared changes before family integrations. Do not merge a helper refactor as closure for 003/008/009/004B until their production-route regressions also pass. Agree its concrete placement/signature in the reviewed implementation plan; do not create a competing reserve ledger by default.

10. **R10 — Preserve the retractions and harden residual handling without misreporting findings.**
    - [ ] For the Balancer quad hook, direct unauthorized `beforeSwap` calls and calls made by an attacker inside an attacker-opened PoolManager unlock context fail with the real intended guard. A valid PoolManager call succeeds. Do not add a redundant guard merely because the initial audit searched for a different guard name.
    - [ ] Retain buffer-first donation controls for weighted, curve quad, Balancer quad, single-CP and dual-CP families. Assert who owns the resulting SE shares and the actual caller refund; do not assert merely that the face balance fell.
    - [ ] Add production-SE integrations beyond `SimpleYieldERC4626`, including a reachable partial-consumption or rounding-to-zero case. Record the actual consumed amount; no prior inventory may become the caller's refund. A forced mock preview alone does not establish reachability in production.
    - [ ] If no supported production configuration reaches a reported speculative branch, document the attempted preconditions and absence of runtime evidence. Do not relabel the withdrawn weighted finding High without a new reproduction. Ensure the refund-budget boundary itself has direct property coverage.
    - [ ] Material protocol residual is retained/booked or buffered for existing holders. Only unbufferable protocol dust within the existing dust bound goes to the configured nonzero `feeTo`; with zero `feeTo`, retain/book it. Never burn it by transferring to zero, send material balances through a dust helper, or redirect a legitimate user refund to the fee recipient.

11. **R11 — Make fuzz and stateful evidence non-vacuous.**
    - [ ] Add targeted fuzz properties for held/reserve/delivered/used/max relationships, mixed 6/9/18 underlying units and custody shares with their actual offset decimals. Check credit and refund bounds independently of implementation helper outputs. Require at least 10,000 cases per targeted arithmetic/delivery property in the recorded release run.
    - [ ] Run stateful campaigns for both Uniswap replacements, custody, ERC-4626, Morpho and orbital. Use at least three honest actors plus an attacker, funded successful operations, direct pool trades where relevant, donations, partial/exact-output operations, fee collection, rebalance, share transfers, reentry probes and attempted repeated credit.
    - [ ] Record at least 256 runs at depth 64 per campaign, with attempted/succeeded/expected-revert/unexpected-revert counters by action. Every required valid money action must succeed in a deterministic lifecycle and at least once during the campaign; fail the evidence gate if a required valid action never succeeds. Required attack actions must reach their intended checks and reject or conserve value as specified; they are not required to succeed. No blanket catch-and-ignore or assumption filter may hide unreachable setup.
    - [ ] Assert no unfunded share/output issuance; no refund above the permitted operation budget; no duplicate delivery/burn; conservation across held assets, protocol positions, outputs and fees; and preservation of other holders' entitlements. Account for legitimate swaps, yield, fees and rounding rather than asserting constant market value.
    - [ ] Failed operations roll back balances, supply, books, liabilities, context and allowances changed by that transaction. A prior separate transfer transaction is not rolled back by a later revert; tests explicitly distinguish those boundaries.
    - [ ] Retain minimized counterexample sequences and seeds. Audit-reported 1.8M math cases are not this program's evidence. Its eight-call/zero-success invariant, inconclusive symbolic runs and vacuous CEI scan cannot close any requirement here.

12. **R12 — Gate completion on production integration and reproducible evidence.**
    - [ ] After production changes, refresh concrete runtime artifacts before tests using the repository's [artifact build workflow](../testing/ARTIFACT_BUILDS.md). Record exact commands, exit codes, counts, versions and logs in the evidence file; never deploy stale `out/` bytecode as the corrected version.
    - [ ] Run changed-family regressions, positive route suites, relevant real buffer/router/SY integrations, facet/package declarations and proxy selector checks. Derive expected selectors from interfaces/Targets, then verify cuts, loupe and actual proxy calls.
    - [ ] Run the required full build and hermetic suite for release. Keep archival fork evidence separate and local. Any unrelated pre-existing failures are identified with baseline evidence and retained as explicit release limitations; do not claim the full suite passed.
    - [ ] Protect code-size/deployment constraints, supported exits when inbound is disabled, metadata/decimal behavior and instance storage isolation. Do not add ownership/pause powers to immutable products as an accounting workaround.
    - [ ] Complete R1's finding-to-test matrix. Every retained Critical/High has runtime reproduction and passing corrected-version proof. An unresolved reproduction, build, integration or archive blocker remains visible and prevents a claim of complete audit closure. Historical live-instance risk remains a separate operational status.
    - [ ] Deliver integration notes identifying changed custody semantics, supported atomic routes, required caller changes, replacement packages and incompatible existing instances. No release approval may imply migration has already happened.

13. **R13 — Replace unsafe public custody with attributable delivery and update conflicting law.**
    - [ ] Treat caller-held authorized pull/burn as the default. Plain prior ERC-20 transfers, raw self-held share balances and `pretransferred=true` alone cannot authorize consumption or refunds. An ordinary separate transfer creates no permission for the next arbitrary caller.
    - [ ] Preserve push-based composition through an authenticated operation context: establish a local balance checkpoint before funding; bind the initiating caller, input token, authorized payer, permitted recipient and amount/limit; measure newly delivered input; consume its credit exactly once; clear the context on completion. Funding and consumption occur in one transaction. A callback transfers from the bound payer through an authorized integration; existing inventory is outside the delivery delta.
    - [ ] Reject pretransfer consumption without its valid operation context. Reject context hijacking, token/recipient substitution, nested/replayed consumption, unauthorized third-party allowance use and cross-vault credit reuse. Require successful real router/hook/SY integration tests for the new context; do not claim compatibility based on isolated token transfers.
    - [ ] For internally produced shares, derive credit from the authorized operation that produced them; a self-call or nonzero initiator alone does not make all existing self-shares spendable. Preserve the single-burn rule and no external access to another operation's credit.
    - [ ] Keep unassigned prior transfers outside user-delivery credit and caller-refund budgets. For an active product, account unassigned donations to existing holder backing; protect zero-supply activation through the existing first-mint rules. Do not invent a depositor identity or permissionless recovery claim for anonymous raw transfers. An explicit authenticated deposit route is required for funds intended to remain attributable across transactions.
    - [ ] Update affected family PRDs, shared reserve/pretransfer documents, canonical testing skills, integration instructions and current-version tests that authorize public consumption or exclude these report scenarios. Record old rule → replacement requirement → affected caller → test in the evidence file. Preserve historical evidence with its version clearly identified.
    - [ ] The implementation plan must pin the context API, storage lifetime, exact errors, interface/selector changes, callback authorization and every affected integration before code work. Do not delegate unresolved custody or compatibility choices to an implementer. The current draft selects attributable atomic delivery; it does not assert those interfaces already exist.

### Implementation/test locations to reuse

Paths below are existing discovery anchors, not evidence that their tests pass. Add `APEX001M`, `APEX003`, `APEX008`, `APEX009`, `APEX004B` and `APEX005` to new test names alongside the applicable I1–I3/E6/K/L/J catalog IDs, and record exact names in R1.

| Area | Production anchors | Test anchors |
| --- | --- | --- |
| Preserved V3/V4 | `contracts/protocols/dexes/uniswap/{v3,v4}/UniswapV*StandardExchangeCommon.sol` | Existing protocol suites and pinned historical fork reproduction; do not modify preserved source. |
| FullSpread V3/V4 | `contracts/vaults/standard/exchange/protocols/uniswap/{v3,v4}/UniswapV*FullSpreadStandardExchangeVaultCommon.sol` and In/Out targets/delegates | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/{remediation,adversarial,invariants,release}/` |
| Custody | `contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol`, SE/SY targets and `TestBase_RebasingAwareERC4626.sol` | `test/foundry/spec/protocols/staking/rebasingVault/`, particularly `RebasingAwareERC4626_Adversarial.t.sol` and buffer integrations |
| ERC-4626 SE | `contracts/vaults/standard/erc4626/ERC4626StandardExchange{Common,InTarget,OutTarget}.sol`; `contracts/test/bases/TestBase_ERC4626StandardExchange.sol` | `test/foundry/spec/vaults/standard/erc4626/`, including `adversarial/ERC4626StandardExchange_Adversarial.t.sol` and decimal suites |
| Morpho SE | `contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeCommon.sol` and its production TestBase | `test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/{adversarial,invariant,decimals}/` |
| Orbital and sibling hooks | `contracts/hooks/uniswap/v4/standardExchange/` family Common/Target/Withdraw implementations and existing TestBases | `test/foundry/spec/hooks/uniswap/v4/standardExchange/` family adversarial, liquidity, buffer, SE lifecycle and decimal suites |
| Historical replay | Existing Robinhood fork infrastructure and verified deployment artifacts | `test/foundry/fork/robinhood_main/`; new audit-specific files remain in this fork tree |

## Non-goals

- This request creates the PRD, not Solidity changes, test implementations, an execution plan or a task backlog.
- No live exploit execution, broadcasts, fund movement, registry disablement, deployment, migration or auditor messaging is authorized by this document.
- No edits to preserved historical Uniswap implementations; no claim that changing shared facets in source upgrades immutable instances.
- No monorepo-wide re-audit, unrelated economics redesign, frontend work, CREATE3 salt redesign, Balancer-hosted DETF functional expansion or deferred Slipstream work.
- No fabricated donor attribution from `msg.sender`, token balance, a declared maximum or historical logs. No claim that atomicity authenticates unrelated old surplus.
- No replacement of failing tests with looser profit bounds, arbitrary dust allowances, route disablement that breaks required behavior, or a mock system under test.

## Constraints

- Follow [CLAUDE.md](../../CLAUDE.md), [.github/ASSISTANT_RULES.md](../../.github/ASSISTANT_RULES.md), its coding/deployment/testing documents, and canonical Crane/IndexedEx testing skills except where the owner's clarification and this PRD require correcting conflicting security law. Unrelated product rules remain in force.
- Real facets use CREATE3/FactoryService; vault packages use the manager/registry path. Hook instances use their existing package and hook-factory/flag workflow; do not bypass it with an ordinary diamond deployment. Inherit existing production TestBases and initialize their parents.
- No SUT mocks, storage overwrites to manufacture the exploit state, spoofed production-contract authority to reach a favorable path, new package-specific Foundry profiles, `via_ir`, or compiler-setting changes to evade code-size failures.
- Keep `out/`, `cache_forge/` and configured source/test roots stable. Seed both artifact/cache directories for a new worktree, rebuild changed artifacts, and wait for compiler completion. Historical and replacement evidence must not contaminate one another's runtime artifacts.
- Preserve universal token policy and existing explicit family exceptions. In particular, the rebasing-aware wrapper's approved rebasing-asset handling and asset-decimals-plus-offset shares are not replaced with generic SE or 9-decimal DETF rules. FoT support is not introduced.
- Protect existing local changes. The new PRD does not authorize resetting or committing the working tree. Shared Common/helper changes must be integrated serially before dependent evidence runs; no concurrent writers to shared artifacts.

## Actors

| Actor | Role |
| --- | --- |
| Honest holder / depositor | Supplies real assets, owns shares and receives authorized outputs. |
| Attacker | Exercises permissionless calls with no/short funding, inflated maxima or another operation's residual inventory. |
| Independent market trader | Moves real pool prices without synchronizing the SE; its capital and trade costs are recorded separately. |
| Integration caller | Executes supported transfer-and-exchange flows; caller, payer and recipient may differ. |
| Fee recipient | Receives only specified fees/protocol dust, never user refunds or principal. |
| Maintainer / reviewer | Verifies corrected law, integration design and execution evidence; operational deployment remains separate. |

## Decisions

| ID | Decision | Status | Rationale |
| --- | --- | --- | --- |
| D1 | This draft targets fixes plus reproduction/regression evidence for all seven report entries; withdrawn/informational items receive controls rather than invented vulnerability fixes. | Assumed | Matches the request and the auditor's corrections. |
| D2 | Supersede project law that permits the report's prior-transfer, public-share or donation attacks; correct both implementation and tests instead of accepting those behaviors. | Decided | Owner: “If the report contradicts our project law, than our law is wrong.” |
| D3 | Reuse and verify the current FullSpread replacement work; preserve historical V3/V4 source and identify old/new code independently. | Assumed | Existing remediation already changed the baseline and contains material uncommitted work. |
| D4 | Require production-route red/green evidence, targeted fuzzing and stateful campaigns with success counters. | Assumed | The audit explicitly identifies vacuous invariant/CEI evidence. |
| D5 | Historical replay and complete instance mapping are required evidence for the reported live findings; hermetic fixes remain independently testable while archive access is unavailable. | Assumed | Neither current-source inspection nor a single-vault test establishes the reported deployment scope. |
| D6 | Retain/refill material protocol residual for holders; send only unbufferable protocol dust within existing limits to nonzero feeTo; retain it when feeTo is zero; preserve genuine user refunds. | Assumed | Prevents a blanket fee sweep from replacing a blanket caller sweep. |
| D7 | No deployment, migration, live operational change or automatic upgrade is part of this PRD's execution scope. | Assumed | Tests and source fixes cannot establish repair of existing deployed instances. |
| D8 | Shared availability arithmetic does not define ownership, does not redefine exact-in behavior and cannot alone close every finding. | Assumed | Local source and the report expose distinct reserve, custody and refund problems. |
| D9 | Use authorized holder pulls/burns and attributable atomic delivery contexts for composed push routes. Bare transfers do not create public spendable credit. Include the required integration changes. | Assumed implementation direction | Meets D2 while retaining funded push composition; concrete interfaces require review before execution. |

## Execute

_no plan yet_

Next: `$prd-review docs/audits/apex-2026-09-17-remediation-and-regression-tests.md`. Review the attributable-delivery design and affected integrations, then use `$prd-plan` to specify concrete interfaces and execution steps. Do not start implementation from this draft.
