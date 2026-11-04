# Astra advisory: FullSpread frozen draft r1

## Identity

Astra, independent council member. Assigned route: `chatgpt-subscription/gpt-6-astra:high`. This is the assigned label, not a runtime, provider, account, or reasoning-effort attestation.

This is one advisory pass. It does not replace my original contribution, publish a final PRD, authorize implementation, or request another review round.

## Draft under review

- Revision: `fullspread-se-prd-draft-r1`.
- Path: `docs/research/fullspread-se-prd-20261030-01a18660/coordinator/draft.md`.
- Supplied SHA-256 provenance: `6c9d4a741bf96f5e5d1fe238459962e51568d2836e3838077c5afa1e8ff8a946`.
- I read the complete frozen draft, lines 1-398, in two bounded reads. I did not recompute the supplied hash or independently attest file bytes against it.

## Disposition

**REQUEST CHANGES**

The selected product is coherent: one full-range diamond/share supply, current explicit twelve-facet packaging, self-funded standard exact-input execution inside an existing manager unlock, and an executable one-share rate distinct from SY accounting. I support those choices.

The draft is not yet decision-complete for implementation. It conflicts with the existing action-level unlock architecture, makes the newly selected entry-fill rule subordinate to the inherited rule it changes, prescribes a different manager deployment pattern from the inspected harness, and contains an impossible nonpayable revert assertion. Its integration matrix also conflates one-SE and two-SE hook topologies. These are contract and acceptance corrections, not objections to the owner's product.

## Material corrections with requirement IDs

### C1 - High: Preserve action-level callback dispatch or explicitly specify a different architecture

**Affected:** FS-UNLOCK-01, FS-UNLOCK-02, FS-A17, FS-A18, FS-A19.

The locked branch says "call `unlock` once," and FS-A17 demands one unlock and one accepted callback. That does not describe the current PairToken execution exemplar inspected during my original. Its `_action` opens an authenticated unlock for each selected manager action; `_start` also checks the manager state. Maintenance collection, swap, addition and the user operation can produce several such actions under one public operation guard.

A literal one-unlock-per-public-call implementation would require a deliberately different callback payload, execution loop, settlement/read-check sequencing, and callback result contract. The draft currently calls it inherited behavior while specifying none of those changes. Removing only `_start`'s unlocked rejection also cannot work because `_action` independently rejects an already-unlocked manager.

**Required correction:** preserve the existing per-action model for this family unless a complete replacement is deliberately specified. Replace the locked branch with:

> Locked: retain the inherited action dispatcher. For each selected manager action that requires an unlock, commit its operation and payload, call the bound manager's `unlock`, authenticate and consume that commitment once, execute and settle that action, verify its actual deltas and expected state, and verify the manager has relocked. Keep the public-operation guard active across the entire plan, intervening token calls, and final payout/commit.

Add to the borrowed branch:

> Dispatch each selected action directly to the same internal action/account/settlement implementation, in the diamond's context. Bypass both action-level `unlock` and public `unlockCallback`; do not bypass state witnesses, fee separation, or settlement checks.

Replace FS-A17's exact count with:

> A multi-action locked operation performs exactly the unlock/callback sequence required by its selected plan. Each commitment is consumed once, unsolicited/replayed callbacks fail, and the shared operation guard remains active between actions. Its borrowed equivalent performs zero nested unlocks and zero public callback invocations.

**Evidence:** retained original-source context: PairToken `UniswapV4PairTokenStandardExchangeVaultExecution.sol`, `_start` at approximately lines 317-326 and `_action` at approximately lines 544-570. No source was reopened during this advisory.

### C2 - High: Register complete entry-swap consumption as a real delta and resolve inheritance precedence

**Affected:** section 1.2, section 2 introductory precedence, section 2.1, FS-MONEY-01, FS-A07, inherited S1-OP-02, S1-A13, S1-A15, S1-A40 and S1-A68.

The draft adopts complete consumption of the selected entry swap. The inherited S1-OP-02 explicitly permits partial entry fills and keeps unspent input in caller inventory before addition. Thus this is an economic-domain delta, even though the issuance equation and eventual `J_i` booking remain unchanged.

Section 1.2 lists only three deltas, section 2 says stage one controls disagreements on inherited IDs, and section 2.1 inherits S1-OP-02 without qualification. An implementer can reasonably preserve partial fills under that precedence while another implements FS-A07. The same problem exists for inherited blanket already-unlocked rejection and optional provider exclusion.

**Required correction:**

1. Add **FS-X04**:

   > For single-token entry, the selected positive half-swap must consume its entire specified input or the operation reverts. This narrows S1-OP-02's partial-fill domain; it does not change S1-ACC-07 share credit or the explicit booking of addition remainder `J_i`.

2. State that an explicitly enumerated FS delta overrides only the named clause of the inherited requirement, while all other clauses remain inherited.
3. Identify at least these amendments:
   - FS-X01 qualifies S1-SEC-01 and the unlocked-context sentence in S1-OP-05; it replaces the blanket rejection expectation in S1-A40 for the admitted standard branch.
   - FS-X02 supersedes S1-API-04's provider exclusion and the relevant excluded-integration portion of S1-A68.
   - FS-X04 changes the successful partial-entry-fill cases in S1-A13/S1-A15 into rejection cases, retaining their other accounting tests.
4. Correct section 2.1's reference to "the two deltas" to the final complete list.

Specify one conversion error, for example `IncompleteConversion(uint256 expectedInput,uint256 consumedInput)`, with the exact intended preflight/execution behavior. Require preflight to reject a predicted partial selected swap before funds are pulled or manager actions occur; an unexpected execution mismatch remains a state-change/settlement failure under the inherited rules.

Also replace "Zap credit stays the inherited booked donation" with:

> Zap shares are credited against attributable removable-principal growth `G_i`. The separate addition remainder `J_i` is booked to shared backing without extra shares, and previews/events disclose it. This is not permission to donate an exiter's unsold allocation.

The present phrase confuses credited growth with the uncredited residual.

**Acceptance:** FS-A07 must exercise both selected-swap failure and successful addition remainder booking. Retain positive issuance, unchanged `C_i=G_i`, no second-token payment, and zero remaining caller reservations. No requirement that every accepted unit become liquidity is needed.

### C3 - High: Use the actual production-first harness and manager deployment pattern

**Affected:** FS-ARCH-01 test placement, FS-TEST-01, FS-TEST-02, inherited S1-TEST-01/S1-A48.

FS-TEST-01 explicitly prescribes `new PoolManager(address(this))` after `CraneTest.setUp()`. The current PairToken base inspected during my original instead extends `IndexedexTest` and `TestBase_Weth9`, invokes both parent setups, and deploys the real manager using `create3Factory.create3WithArgs` with `ArtifactCreationCode.creationCode`. It obtains canonical facets and registers the family package through the manager.

The draft's general statement that everything follows production paths does not resolve its conflicting concrete instruction. It also leaves TestBase placement conditional despite the actual harness having been inspected.

**Required replacement:**

> Place `TestBase_UniswapV4FullSpreadStandardExchangeVault.sol` under the new family's `test/bases/`. Follow the current PairToken setup pattern: extend `IndexedexTest` and the canonical native-wrapper base, call their parent setups in the correct order, and deploy the actual canonical PoolManager through the existing artifact-backed CREATE3 helper. Deploy shared/family facets and registered packages through their current factory/manager paths. Bootstrap shares only through public paired entry.

The consuming hook and tested FullSpread vault must be bound to that **same** manager. Otherwise successful ordinary unlocks on two separate managers do not test FS-UNLOCK-02.

State the later artifact-first verification gate, normal runtime/initcode limits, `viaIR=false`, and default-profile hermetic tests explicitly. Reuse permissible peripheral funding tokens/receivers; do not turn the blanket phrase "tokens through production paths" into a ban on the current mintable non-SUT fixture pattern.

**Evidence:** retained original-source context: `pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol`, `setUp` and `_packageInit`, plus the already-read repository router/testing law.

### C4 - High: Make the facet inventory an executable selector/interface contract

**Affected:** FS-FACET-01, FS-FACET-02, FS-ARCH-01, FS-A01 and inherited S1-A06/S1-A56/S1-A57.

The money-facet row omits `exchangeIn`, which is the critical entry this PRD changes. Other rows abbreviate away required SY reward/discovery methods. "Same split as PairToken" is useful inheritance, but it does not replace the requested sourced inventory, especially where the new selector must be added.

The factory exclusion list also omits ERC-8109, despite its explicit inherited exclusion. This can lead to a missing persistent-interface test or an extra package input/cut.

**Required correction:** restore an explicit interface and selector manifest, retaining all five shared facets unchanged:

| Field | Required selector inventory |
|---|---|
| `erc20Facet` | Canonical 9 ERC-20/metadata selectors. |
| `erc2612Facet` | `permit`, `nonces`, `DOMAIN_SEPARATOR`. |
| `erc5267Facet` | `eip712Domain`. |
| `basicVaultFacet` | `vaultTokens`, `reserveOfToken`, `reserves`. |
| `standardVaultFacet` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig`. |
| `moneyFacet` | `exchangeIn`, `depositPair`, `redeemPair`, `donate`, `compound`. |
| `quoteFacet` | `previewExchangeIn`, `previewDepositPair`, `previewRedeemPair`, `previewWithdrawalMode`, `previewZapCredit`. |
| `outFacet` | `previewExchangeOut`, `exchangeOut`. |
| `queryFacet` | Existing 11 family configuration/economic queries plus `getRate`. |
| `syMoneyFacet` | `deposit`, `redeem`, `rewardIndexesCurrent`, `claimRewards`. |
| `syQueryFacet` | All 12 existing SY view selectors, including token discovery, asset identity, rate and empty reward queries. |
| `callbackFacet` | `unlockCallback`. |

This totals **61 package selectors**, with factory-owned persistent selectors separate. Cite the current package's `_expectedSelectors`, package interface, and S1-ARCH-04 as provenance. Name the shared concrete facet paths and their interfaces, not just roles. Include ERC-8109 in the factory exclusions and final-proxy checks; no need to guess the temporary hook's concrete filename.

Clarify that `linkedComponents()` is facet implementation metadata, not an additional installed proxy selector. Define the full `...MoneyTarget.sol`, `...QuoteTarget.sol`, etc. filenames rather than leaving `MoneyTarget.sol` apparently as a literal shortened filename.

**Acceptance:** target/interface-derived controls, exact cuts, loupe mapping and actual calls through the registry-deployed proxy must cover all 61 selectors, all 16 SY methods, and the factory-owned union. A declaration test alone is insufficient.

### C5 - Medium: Nonpayable dispatch cannot produce `InvalidUnlockedContext` for nonzero value

**Affected:** FS-UNLOCK-02 item 2, FS-A20.

Canonical `exchangeIn` is nonpayable. A call attaching nonzero `msg.value` fails Solidity's nonpayable dispatch before the function body can choose the unlocked branch or throw `InvalidUnlockedContext`. FS-A20 currently demands an impossible family error for this case.

**Required correction:**

> The standard ABI remains nonpayable. Nonzero-value low-level calls fail at nonpayable dispatch with no vault effects. Within an admitted body call, a code-less caller, wrong recipient, or true pretransfer flag on the borrowed branch fails `InvalidUnlockedContext`.

Split FS-A20 into the body-validation assertions and a separate nonpayable assertion. Do not make the function payable to satisfy the mistaken test. Native hook integration continues through the wrapped face; direct native SY/paired methods keep their inherited payable contract.

### C6 - Medium: Complete the rate edge domain and avoid a shared-planner-only test oracle

**Affected:** FS-RATE-01, FS-A12 through FS-A15, FS-A29.

The semantic rate decision is correct. Two details remain:

1. For unrestricted allowed token decimals, `10^(d-18)` still overflows when `d-18 > 77`. The formula text does not specify that case, and a generic arithmetic panic would violate the promised zero-normalization error. Since the divisor then exceeds every possible uint256 `E`, the mathematical result is zero.
2. FS-A13 compares `getRate` to the same planner that implements it. That checks wiring/normalization but cannot detect a shared faulty exit model.

**Required addition:**

> For `d > 18`, if `d-18 > 77`, normalization is mathematically zero for any uint256 proceeds and shall revert `RateUnavailable`. Otherwise divide by the representable power. For `d <= 18`, detect overflow of the final normalized result and revert `RateNormalizationOverflow`. Do not add a decimals allowlist.

State the signatures `RateNormalizationOverflow()` and `RateUnavailable()` explicitly. Add tests for normalization overflow, zero normalized output, the divisor boundary, busy versus idle-unlocked reads, and genuine one-share sale failure after removal.

Retain the useful FS-A13 planner equality, but add a restored-identical-state **actual one-share redemption** with independently reconciled principal, fees, sale proceeds, target decimals and payout. This is the load-bearing executable-rate acceptance.

FS-A12/FS-A29 may use a specifically derived fixture where rates differ. Do not infer that idle balances by themselves necessarily cause inequality, or require all legitimate fixtures to have unequal rounded numbers. Independently assert each formula first; a numerical coincidence does not collapse the semantic distinction.

### C7 - High: Make hook acceptance specific to each family's actual topology

**Affected:** FS-HOOK-01, FS-HOOK-02, FS-HOOK-04, FS-A24 through FS-A27, FS-A30.

FS-A26 requires "this family and another SE family" to complete a two-vault exact-input hook swap, and FS-A27 applies "the same two-vault proof" to every family. The nonreserve `single/` hook has one SE binding and one pair token. Single CP has one buffered SE leg and one raw leg. Neither is a two-buffered-vault package.

Requiring the same topology everywhere either makes the test impossible under the selected bindings or encourages a test to relabel a raw/identity share transfer as underlying mint/burn in both vaults.

**Required family-specific matrix:**

- `single/`: actual FullSpread wrap and unwrap through the real hook's `beforeSwap`, same manager already unlocked, both exact-input directions. This is the one-vault borrowed execution proof, not the two-buffered-vault proof.
- `constantProduct/single/`: FullSpread as buffered leg and another real SE share as raw leg, where valid. Explicitly identify which leg is converted and which is only transferred.
- `dual/`: primary cross-vault proof. First trade two real share tokens as identity legs without mutating their backing. Separately configure two distinct underlying-token buffered legs and demonstrate actual issuance into one real vault and redemption from the other, reversing direction to reverse roles.
- `orbital/`, `weighted/`, Curve quad and Balancer stable: valid multi-leg bindings containing FullSpread and another real SE, with exact token/SE/provider/decimal/order settings and explicit buffered-versus-identity roles.

Record the observed package ranges rather than saying only "supported": Weighted 2-8 legs, Curve exactly four, Balancer schema-v2 dynamic arrays 2-5 legs. Fixtures need not imply a volatile FullSpread share has a stable peg.

A cited rejection under FS-HOOK-04 is a useful diagnosis, **not a passing substitute** for a required integration path. State which failures are intentional unsupported exact-output/budget domains and which leave the requested integration incomplete pending a separately authorized requirement. Preserve the existing prohibition on silently editing hooks or installing fake transition quotes.

Retain the disjoint-backing-PoolId qualification. This does not assume FullSpread has another conversion market: it still trades only in its own backing pool. Same-backing-PoolId sequential composition remains unverified, not impossible.

### C8 - High: Make combined gas and borrowed-context invariants acceptance obligations

**Affected:** FS-MONEY-01, FS-UNLOCK-02, FS-TEST-03, FS-A19/23/25/26/27.

The draft says combined gas is "measured and reported" and inherits ordinary family testing. That leaves the most important new integration invariants without explicit closure conditions. Passing S1-A70 for each inner call does not establish that two calls plus the hook and rate reads fit one 12M transaction.

Preserve existing acceptance IDs and append, for example, the following independent rows:

| Proposed ID | Required assertion |
|---|---|
| FS-A31 | Whole composed transaction, including both vault operations, hook/router work, rate reads and applicable transaction overhead, fits the 12M engineering ceiling for every claimed supported boundary fixture. Preview fits 5M. An oversized composed route is an unresolved/narrowed integration-domain gate, not a passing measurement. |
| FS-A32 | Busy-vault economic views and getRate reject; an idle vault answers while the common manager is unlocked. Shared basic reserves expose the last committed snapshot. |
| FS-A33 | Borrowed execution uses the same compound/fallback plan and fee attribution as ordinary execution from equivalent economic state, including full-compound and legitimate collection-only withdrawal cases. |
| FS-A34 | Own nonzero manager delta at borrowed entry rejects; every action closes only the vault's deltas. Hook/router debts remain intact inside the unlock and all required outer deltas close when the real outer unlock returns. |
| FS-A35 | Native-backed borrowed execution uses wrapped faces correctly, resets native sync before value settlement, and does not duplicate native/wrapped backing or consume another actor's sync-derived credit. |
| FS-A36 | Propagated outer failure restores the whole swap; a router that catches a rejected vault invocation retains only legitimate prior outer effects, while the vault's full state is restored and the router still owes its own settlement. |
| FS-A37 | A properly funded non-hook contract satisfying FS-UNLOCK-02 succeeds. The absence of a hook allowlist is an explicit permissionless funding contract, not an accidental missing authorization check. |
| FS-A38 | Disabled inbound issuance/donation and still-available supported exits behave consistently through actual buffered hook routes. |

Use complete state comparisons: supply/holder balances, both positions, booked and reserved custody, wrapper balances, and per-address deltas. Do not assert only that no tokens moved. Legitimate outer outstanding debts mean the manager must remain unlocked at the inner return.

This adds tests for the new behavior, not a new economic equation or a hook redesign. No gasleft-dependent domain or silent budget relaxation is proposed.

### C9 - Medium: Tighten package terminology and inherited traceability

**Affected:** FS-PKG-01, FS-PKG-02, FS-TEST-02, section 2.1.

These are smaller but implementer-visible corrections:

- `maxZapBps` is a zap-size limit also used by the compound quarter-cap, not a "fee bound." Name its domain `1..10000`; retain the nonnegative tick-move domain.
- State typed `IFacet`, `IPoolManager`, `IVaultRegistryDeployment`, `IVaultFeeOracleQuery`, `IWETH`, and `IDiamondPackageCallBackFactory` fields, and explicitly require both structs on the package interface.
- `NotCalledByRegistry` protects both caller and execution context: registry as `msg.sender`, bound diamond factory as delegatecall context. Checking only the sender is not the inherited contract.
- Require exact selector sets and compatible fixed links, not merely code presence/hash coverage.
- Explicitly retain shared ERC-20/EIP-712/basic/standard Repo initialization, zero fee-type IDs, actual face order, and contents hashing of a sorted copy. "Inherited vault metadata" should not leave these critical initialization obligations implicit.
- Name the six link order but clarify that SwapProjection and ExecutionPreparation are separate linked libraries in the existing Projection and Execution source-file split, not necessarily additional source files.
- Provide a compact inherited acceptance disposition ledger for changed rows, especially S1-A13, A15, A33, A40, A59, A60 and A68. It is unnecessary to repeat all 70 rows verbatim, but "all apply" is incorrect without their explicit FullSpread amendments.

**Acceptance:** FS-A01/02/03 and inherited package/surface tests must verify these concrete contracts, not just nonzero addresses and a changing hash.

## Dispositions of proposals the draft did not adopt

These dispositions refer to my original contribution retained in this session. I did not reopen it or read peers.

1. **Additional product-domain salt in original FS-07:** not expressly adopted. I accept omission if the final PRD deliberately inherits the current package salt contract and proves distinct sibling identity through its actual bindings/arguments. A new domain constant is not necessary merely to add another hash layer. Do not claim it was adopted or silently use a hook package's salt law instead.

2. **Exhaustive 61-selector inventory and explicit factory ERC-8109 exclusion:** compressed out of the draft. Retain these through C4. They are required interface-completeness evidence, not optional documentation verbosity.

3. **Named paired/quote/conversion behavior and `IncompleteConversion`:** the core economics are inherited, but the new selected-entry full-consumption delta and its error contract are not fully represented. Retain the narrow C2 correction; do not rewrite the inherited equations or change zap remainder credit.

4. **Exact current harness and artifact-backed manager deployment:** not adopted; the draft instead selects `new PoolManager`. Retain my original's current-harness recommendation through C3. This concerns executable test wiring, not changing the product's manager binding.

5. **Separate per-hook spec filenames:** the draft consolidates them into `...BufferHookIntegration.t.sol`. I accept consolidation. File count is not a correctness criterion. Preserve identifiable family-specific cases, fixtures and evidence under C7; do not let one large smoke test stand in for seven route-specific obligations.

6. **My full 42-row additional acceptance matrix and 70-row inherited ledger:** exhaustive repetition is not required. I accept a shorter matrix if C2/C4/C6/C7/C8 preserve the material obligations and explicitly map changed inherited rows. Missing tests for new execution context are not covered merely by citing ordinary-context baseline tests.

7. **Detailed internal types, witness and action accounting descriptions:** the draft relies on inheritance. I accept that for unchanged economics, including canonical `Position.State`, `Pool.TickInfo`, complete read witnesses and nonduplicated authoritative storage. C1 remains necessary because dispatch is not unchanged. No new simulator framework or extra integration facet is requested.

8. **Explicit operation-context event:** I proposed none; the draft correctly adds none. Existing event caller/amount semantics must remain correct through both branches.

9. **Hook-exclusive authorization versus self-funded contracts:** the draft adopts my self-funded alternative, not a proof of active hook/PoolId membership. I support that choice and recommend C8's funded non-hook success test to make the contract unmistakable. No hook allowlist or circular deployment binding is requested.

10. **Same-backing-pool sequential composition and optional transition interfaces:** the draft retains my bounded claim and separate change gate. I support those limits. I do not demand a broad projector extension or treat a nonlinear exit quote as a proof that rate-aware hooks cannot work.

11. **A separate accounting/NAV provider, independent oracle, queue, or changed redemption policy:** none is requested by this advisory. Preserve the normalized executable one-share rate. The unresolved economic safety of live-rate consumption must remain a limit, not a reason to silently substitute a different product.

The draft's attributed Grok/MiniMax/Kimi positions are treated only as statements in the frozen draft. I did not inspect their originals or independently verify those attributions.

## Limits

- Reviewed only the complete frozen draft supplied for this pass, using earlier conversation/source context for comparison. No original, peer, memory note, PRD baseline, source implementation, or new external evidence was reopened.
- The supplied hash is recorded as provenance only. No hash, shell/project command, Git operation, build, Forge/test run, installation, deployment, wallet operation, or delegation occurred.
- Static reasoning establishes the identified contradictions and missing acceptance contracts; it does not certify gas, compilation, stateful hook behavior, manipulation resistance, or deployment readiness.
- Only this owned `members/astra/feedback.md` is written. The original, frozen draft, peers, resolution, final publication target, code and configuration remain untouched.
- This advisory neither replaces the original nor authorizes implementation. The coordinator may resolve these corrections in the authorized synthesis. No further advisory round is demanded.

Stop after this feedback.
