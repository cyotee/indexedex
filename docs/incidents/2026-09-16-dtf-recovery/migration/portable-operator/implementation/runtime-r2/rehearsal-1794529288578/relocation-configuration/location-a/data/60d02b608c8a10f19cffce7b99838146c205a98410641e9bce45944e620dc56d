# Migration DETF implementation and test plan

- **Date:** 2026-11-10.
- **Revision:** migration-detf-implementation-plan-r5-owner-first-bond.
- **Owner clarification:** 2026-11-11; original-wallet configured surrender is Stage 2-only, enabled atomically with ordinary deposits and permanent entitlement-loader removal; sections 1.3-1.5 govern, including the paid owner-first-bond prerequisite.
- **Status:** Implementation-and-test work plan; execution and deployment are not authorized by this file.
- **Baseline:** [MIGRATION_DETF_DRAFT_PRD.md](MIGRATION_DETF_DRAFT_PRD.md), revision `migration-detf-discussion-r20`, with the later owner-approved clarifications in section 1 of this plan.
- **Approval:** After reviewing the initialization, arguments, stored data, formulas, surrender and harvesting workflow, the owner said: "Good, all of that looks correct. Please write the implementation plan file."
- **Deliverable boundary:** This plan is the only new artifact produced by the planning task. The PRD, historical ledger, frozen evidence, contracts and scripts are not changed.
- **Execution prerequisites:** Source-specific custody, surrender conservation and frozen-quote reproduction must pass the explicit evidence gates below. Historical holder ancestry is not a prerequisite. Planning does not establish that all deployed legacy routes already work.

## 1. Accepted requirements and precedence

The later owner clarifications govern where r20 differs. An executor must read this section before interpreting the older decision table or acceptance criteria. Do not silently restore the former full-credit-regardless-of-principal rule.

| ID | Accepted requirement |
| --- | --- |
| MIG-P01 | Quote the **original entitlement** once, using its verified original ETH and DTF contributions against the same frozen post-funding snapshot. Sum the two user-DETF outputs. Neither configuration nor quoting mints DETF. |
| MIG-P02 | Distribute that precomputed credit proportionally as eligible assets are surrendered. Do not run the nonlinear mint preview again on smaller partial contributions. Combining already quoted entitlements sums their credits; batching does not redefine the economic quote unit. |
| MIG-P03 | For a fixed-principal old NFT, read original principal and actual remaining principal. The new credit is `floor(originalCredit * remainingPrincipal / originalPrincipal)`. Remaining principal includes still-locked principal, excludes already withdrawn principal, and excludes rewards. |
| MIG-P04 | A burned, nonexistent or empty old NFT earns no migration credit. Its configuration need not be deleted. Check the actual position at surrender; configuration is not proof that principal remains. |
| MIG-P05 | Whole-NFT surrender consumes that source NFT identity completely. The credit corresponding to withdrawn principal does not remain available for another NFT migration. A supported token/receipt obtained by claiming follows its own source-defined surrender rule; do not pay twice for the same remaining underlying claim. |
| MIG-P06 | Do not premint all configured migration entitlements. Surrender requires a matching configured entitlement for the original acquiring wallet; otherwise revert before custody, consumption or issuance. Mint only the credit actually delivered on successful surrender, and fund a **new bond NFT for every successful surrender operation**. Failed custody or bond creation reverts the entire operation. |
| MIG-P07 | Each new compensation/migration bond has a 90-day principal cliff from its actual creation timestamp. Later surrender creates a new clock, not an addition to or restart of an earlier bond. Migration has no new expiry deadline. |
| MIG-P08 | Rewards participate from actual bond creation, but every new-instance reward payout requires activation. Activation neither backdates nor discards accrual. Preserve the separate principal obligation. |
| MIG-P09 | Independent compensation remains a distinct, recipient-keyed Stage 1 path without surrender. Configuration does not issue it; explicit execution creates a funded bond. It cannot overlap exposure awaiting surrender. |
| MIG-P10 | Stage 1 supports idempotent, complete configuration replacement, including previously processed records. Keep configuration separate from issuance, consumption and custody. Corrections cannot resize delivered bonds, reopen consumption, or create retroactive top-ups/deductions. |
| MIG-P11 | Activation atomically opens ordinary new money, eligible legacy surrender and reward payouts, and removes all entitlement configuration/amendment and discretionary compensation issuance selectors. Stage 1 rejects every surrender-triggered credit route before custody or consumption. No owner, factory, initializer, generic cut or indirect execution route may restore configuration or expose an intermediate open state. |
| MIG-P12 | The proxy's current Crane Ownable owner administers configuration, activation and harvesting. Initial ownership is explicit in `PkgArgs`. Fee recipient, creator, deployer and registry authority remain distinct. There is no contribution-price setter. |
| MIG-P13 | Scripts arrange reserve funding before dependent snapshot/configuration/issuance work. No independent funding-complete or configuration-finalization gates. All-leg donations and later harvested-asset donations remain supported. |
| MIG-P14 | Harvesting is owner-only, bounded, whole-batch atomic and optionally staged. Assets stay in recovery custody between stages, with the new DETF as their fixed eventual donation destination. No ordinary bond purchase with harvested DETF. |
| MIG-P15 | Retain every accepted legacy category and both generations. The surrendering wallet must be the wallet recorded for the original qualifying acquisition/contribution, have a matching configured entitlement, and actually hold and surrender the eligible asset. A different current holder does not inherit that wallet's configured compensation. Partial surrender consumes only the applicable proportional credit from the recorded entitlement. No intermediate-transfer ancestry proof or legacy-transfer notification is required. |

### 1.1 Explicit differences from r20

- MIG-D07, MIG-D13, MIG-D26, MIG-D29, MIG-R13, MIG-R16, MIG-R25 and MIG-R42 must be read with MIG-P03 through MIG-P05: the original contribution is still the quote input, but remaining eligible principal determines the **fraction delivered**.
- The original contribution is not reduced and re-quoted. `preview(originalContribution) * remainingFraction` is the rule, not `preview(originalContribution * remainingFraction)`.
- MIG-R24 through MIG-R26 and MIG-AC21 through MIG-AC24 continue to fix pricing, but subsequent surrender consumes stored credit rather than calling a live or partial-input mint preview.
- MIG-R33/MIG-R36 and MIG-AC35/MIG-AC39/MIG-AC41 must be read with the later same-wallet restriction in section 1.3: actual surrender is required, but configured compensation does not move to another wallet with a token transfer. No ledger observing intermediate legacy transfers is required.
- MIG-AC07, MIG-AC36 and MIG-AC49 no longer require the same delivered amount after principal has been withdrawn. Rewards still do not add credit.
- The stale "price setting" role in MIG-R41 grants no authority.
- Older loss-ledger valuation formulas, blanket 1:1 conversion, linear output-rate setters, no-credit-after-custody wording and linear vesting do not supersede these requirements.

The plan records these overrides without rewriting the PRD or historical evidence. Numerical recipient allocations, funding split and real deployment addresses remain execution inputs, not approved amounts.

### 1.2 Owner clarification: token/receipt surrender is the claim boundary

On 2026-11-11, the owner clarified: "Compensation rights inherently transfer with the tokens because we're requiring the tokens to be surrendered." Users supplied the legacy system with DTF or ETH and received a token or receipt; the migration collects those old assets so their underlying DTF/ETH can be harvested.

This first clarification established actual asset surrender, rather than transfer-history reconstruction, as the claim boundary. The subsequent same-wallet and configuration requirements in section 1.3 narrow who may exercise it. Do not require the sequence of previous holders, complete transfer/claim/wrapper ancestry, or authenticated chain execution-build provenance.

Read the source's actual units and remaining claim, take custody or extinguish/control that claim atomically, and credit only the eligible amount surrendered. Source-specific custody, conservation across real claim/wrapper operations, duplicate-use protection and recoverability still require executable evidence. A balance without actual surrender is not a completed migration.

This clarification replaces the earlier transfer-history interpretation of E2. It does not remove any legacy category, change the agreed frozen valuation and NFT remaining-principal rules, authorize live repricing, or conflate recipient-keyed independent compensation with token-backed surrender. Historical phase01/phase06 ancestry investigations remain archived findings under the superseded interpretation, not blockers to this clarified mechanism.

### 1.3 Later owner requirement: original wallet and configured entitlement

The owner subsequently required users to surrender from the same wallet address used to acquire the assets so the original contribution remains tied to surrender. The owner also directed: "If a user tries to surrender assets, and we have no original compensation recorded for them, so they have no entitlement configured, revert the transaction."

For every token, receipt, NFT or claim surrender, require a matching configured original entitlement for that source/claim and the surrendering wallet. That wallet must be the recorded original qualifying acquiring/contributing wallet and must currently control the eligible asset. A token balance, approval or current NFT ownership alone does not create eligibility. Surrender must not create an entitlement on demand or fall back to an unconfigured wallet allowance.

Check configuration and wallet identity before taking custody, consuming credit or minting/funding a bond. Missing configuration or a mismatched wallet reverts the entire transaction without asset movement, consumption, supply change or a new bond. Existing consumed/issued records and the remaining eligible amount still limit subsequent use. Successful surrender credits the same eligible wallet, never an arbitrary beneficiary.

An ordinary transfer to another wallet does not transfer the configured compensation record. The recorded original wallet can surrender only assets it actually controls; no intermediate transfer history is required. Original ETH/DTF records and frozen quotes remain attached to the configured entitlement, with partial delivery and rounding tracked against that record. Independent compensation remains its separate no-surrender path; permissionless capital donations do not require a personal entitlement and do not earn one.

### 1.4 Owner-approved Stage 2-only surrender

The owner explicitly approved rejecting legacy-asset surrender in Stage 1 and enabling it only in the same atomic activation that enables ordinary new-capital deposits and removes every entitlement configuration/amendment and discretionary compensation issuance selector. This supersedes all earlier statements allowing preactivation surrender.

Stage 1 permits configuration, reserve funding, independent compensation issuance, and the current owner's paid first ordinary bond under section 1.5. Every token/NFT/claim surrender-triggered credit entrypoint rejects before taking custody, changing consumption or issuing a bond. Stage 2 allows surrender only against frozen configured original-wallet entitlements. Use the same finalized activation state; no extra switch or callback-accessible intermediate state is allowed.

Because configuration and surrender cannot overlap, no partly surrendered migration entitlement can be amended. Delete the proposed remaining-fraction correction versus post-use lock choice: neither is needed. Independent compensation already issued during Stage 1 remains governed by its distinct issued-fact preservation rules. Principal clocks start when each bond is actually created; activation does not reset existing independent-compensation clocks.

### 1.5 Owner-approved paid first bond before activation

The owner resolved the empty-participation reward failure by allowing the current proxy owner to buy the first genuine ordinary bond during Stage 1, and explicitly selected an on-chain prerequisite: activation must reject until that purchase has completed successfully. No bootstrap-self-leg or first-reward weight seed is approved. Use the existing paid purchase, funded principal, standing-weight top-up and reward distribution machinery rather than a new reward formula.

This is a narrow first-purchase exception, not an owner bypass for all acquisition routes. Require actual authorized payment and a nonzero funded ordinary bond under the existing purchase terms. Configuration, donations, reserve self-leg minting, independent compensation, arbitrary stake transfers or a synthetic marker do not substitute for that purchase. Record successful completion atomically with the real purchase; failed payment, custody, funding or callback rolls back the prerequisite. A completed qualifying purchase is an instance fact, not a requirement that its NFT remain with the owner who bought it or that ownership never change.

All other Stage 1 ordinary acquisitions and all legacy surrender remain closed. Reward accrual follows existing funded accounting, while every Stage 1 reward payout, including fee/creator delivery, remains gated. The purchased bond retains ordinary purchased-bond terms; compensation and surrender bonds retain their separate 90-day cliff. The purchase is paid capital, not compensation or a use of harvested recovery inventory.

Activation checks completed owner purchase before changing selectors or stage. Independent compensation alone must not unlock activation. After the purchase, activation retains its all-or-nothing cut and opens ordinary deposits, eligible surrender and reward payouts. Postactivation ordinary purchases retain their normal permissions. Preserve frozen snapshot semantics and all previously configured credit; do not recapture or reprice the snapshot because a bond was purchased. Operator sequencing includes the paid purchase and reconciles a confirmed purchase rather than replaying it on resume.

Acceptance: prove current-owner-only real Stage 1 purchase and normal economics, failed-purchase rollback, nonowner/pending-owner/former-owner and other-acquisition rejection, activation rejection without that purchase even with independent compensation, successful activation and ordinary deposit after purchase, Stage 1 reward-payout closure, and unchanged Stage 2 NFT/W-L surrender/recovery. No test may hide D1 by merely adding unrelated compensation to the fixture.

## 2. Implementation grounding

All paths in this plan are repository-relative. A proposed file is explicitly marked new.

| Existing surface | Source anchor | Consequence for implementation |
| --- | --- | --- |
| Base interface and arguments | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol`, `PkgArgs` | Reuse compatible base arguments; define Migration args on a new interface. Do not add owner fields to every ordinary package. |
| Package composition and initialization | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol`, `facetCuts`, `initAccount`, `calcSalt`, `postDeploy` | Compose a distinct package; preserve metadata, registry, self-leg and child wiring. Include owner in Migration salt material while preserving deliberate hook-address prediction behavior. |
| Registry deployment | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol` | Existing helper uses `vaultRegistry.deployPkg` and artifact bytecode; use the same registered path. |
| Mint preview | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:175` | `_entryPreviewMint` is live and includes a swap fallback. Calling it unchanged does not implement frozen migration pricing. |
| Pair conversion and gross quote | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:170` and `:259` | Preserve `_pairEq` route semantics and `_quoteMintGross` uplift; freeze their dependencies. |
| User/inventory split | `contracts/vaults/detf/common/core/DETFMintSplitLib.sol:19` | Use `_splitLiveGross` user output, not gross, ordinary bond bonus, or an invented linear rate. |
| Weighted quote orchestration | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol:39` and `:138` | Quote can use raw/buffered reserves, provider rates, underlying SE deposit/redemption previews and disable-dependent branches. Two raw balances alone are insufficient. |
| Weighted fee/math | `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol`, `applyTradingFeeNet`, `quoteExactIn` | Preserve fee rounding, scales, weighted exact-in domain limits and output-budget conversion. |
| Donation forwarding | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:731` | Existing donation forwards to the bond child; its live-reserve requirements do not prove empty-reserve bootstrap works. |
| Bond creation and exact backing | `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:94` | Reuse exact pull/stake/gons checks. Configuration must not call `createFundedPosition`. |
| Claim and retirement | `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:134` and `:190` | Direct child claims need cliff/reward-gate integration. Fully claimed principal does not prove the NFT has burned if rewards remain. |
| Funded claim arithmetic | `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:97` | Existing `_claim` vests principal linearly. Preserve ordinary behavior; introduce a Migration cliff path, not a global replacement. |
| Staking receipt | `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol` | Include direct receipt exits, synchronization and reward operations in the Stage 1 payout audit. |
| Bond child package | `contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol` | Current V4 child binds shared `DETFNFTVaultDFPkg`; migration-specific behavior requires explicit composition. |
| Ownable | `lib/crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol`, `_initialize(address,uint256)` | Initialize proxy storage once; preserve pending-owner and buffer semantics. |
| Cut and routing | `lib/crane/contracts/introspection/ERC2535/ERC2535Repo.sol:245`; `lib/crane/contracts/proxies/MinimalDiamondCallBackProxyResolution.sol` | Local Remove cuts require the **current owning facet address**, not a generic zero-address recipe. Verify actual routing and loupe. |

Source constraints confirmed during the planning review:

- `MultiStepOwnableRepo._acceptOwnershipTransfer` checks the pending caller but does not check confirmation or buffer expiry; `MultiStepOwnableTarget.acceptOwnershipTransfer` forwards directly to it. Do not claim the existing ownership buffer enforces an acceptance delay. Follow the actual current-owner transition for authorization; a generic Crane ownership repair is outside this migration plan and must not be silently included.
- `UniswapV4DetfCommon._realizeExpansionIfNeeded` can call reward funding after an elapsed epoch, while `DETFFundedStakingMath._allocate` rejects nonzero rewards with zero aggregate weight. Donation bootstrap must explicitly handle the interval before the first funded participant.
- `UniswapV4DetfMaintenanceTarget.synchronizeRewards` deliberately returns without settlement for wired child callbacks while the parent lock is held. The migration parent must settle existing participation before adding new principal rather than relying on that callback.
- `DETFFundedStakingRepo._distribute` delivers fee/creator allocations as staking receipts. Sending those receipts to a recipient is already a reward payout; blocking only subsequent redemption is not sufficient.
- `DETFFundedBondMetadata` currently describes linear vesting and renders linear progress. Migration metadata must describe and display the cliff and activation-gated claims without changing ordinary bond metadata.

### 2.1 Evidence inputs, not issuable uploads

Use these existing incident artifacts:

- `ENTITLEMENT_LEDGER_PROVENANCE.md`: acquisition method, original contribution joins, units and reconciliation limitations.
- `sources.json` and `manifest.json`: evidence boundaries and fingerprints.
- `evidence/weighted-bonds.csv`, `evidence/earlier-cp-bonds.csv` and `evidence/transfers.csv`: original purchases and ordered ownership/conversion evidence.
- `positions.csv`, `held-exclusions.csv`, `custody-inventory.csv`, `observed-recoveries.csv`, `conversions.csv`, `exceptions.csv`: reconciliation inputs, not ready-to-issue allocations.
- `account-ledger.csv`: historically non-issuable. Never upload it directly as current compensation.

The recorded chain is Robinhood Chain, ID 4663. The pre-incident last full block is 64394556; attack block is 64394557. The later weighted evidence cutoff is 108944663 on November 8, 2026. None of these is the new reserve's funded snapshot.

Recorded identities below come from the provenance report, not a fresh on-chain validation:

| Source | Recorded address | Required unit/model |
| --- | --- | --- |
| Contribution/recovery DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` | 18-decimal asset |
| WETH | `0x0bd7d308f8e1639fab988df18a8011f41eacad73` | 18-decimal asset |
| Weighted DETF | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` | 9-decimal liquid token |
| Weighted NFT | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | Fixed-principal position; reserved IDs are not user purchases |
| Weighted sDETF | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` | 9-decimal rebasing receipt; replay in gons |
| Weighted SY | `0xB55604CF4dcdABB362078e106D20F98512391EdF` | Wrapper shares, not a second claim on its backing |
| TokenStaking | `0xE4c9Ff4Cfd17AE73ECb3825ebDf7db113C146d00` | Claim weights, not an assumed ERC-20 |
| Claim vault | `0xAf5C0cD3fDEdd10bee00Eff77Fa0429Bacdb41f0` | Custody of SY for old claims |
| Earlier CP DETF | `0xaf0E1967c8F755c747615c5427108Bc549CA1122` | 18-decimal liquid token |
| Earlier CP NFT | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | LP-share lock, not funded DETF principal |
| Earlier CP receipt | `0x4AC89aD061A531FA62ddceED53520C2750113b01` | 18-decimal rebasing receipt |

Refresh source identities, runtime code/selector bindings, holdings and recoveries at a pinned execution-evidence block before generating operational configuration. Local current contracts are implementation references, not proof that an old deployed address runs identical code.

## 3. Mandatory feasibility gates

These gates are work-product checks, **not new on-chain lifecycle flags**. They prevent an executor from substituting a different product when a required route is unproved.

| Gate | Required result | Failure handling |
| --- | --- | --- |
| E1: source route closure | For every accepted category/generation, pin address, runtime identity, units, ownership read, surrender operation, remaining-unit read and harvest/conversion route. Demonstrate custody and rollback on a local fork. | Record the concrete missing method or incompatible behavior. Do not mark a category supported, silently omit it, or change its entitlement rule. |
| E2: configured-wallet surrender and conservation | Demonstrate actual surrender by the recorded original wallet against its matching configured entitlement, only after activation, with preactivation rejection proven. Reject unconfigured wallets and other current holders. Measure eligible units received or claims extinguished; consume only that record's available credit and prevent double use. No intermediate-transfer proof or owner update is needed. | Fix concrete configuration, wallet-binding, custody or consumption failures. Do not accept balances alone, create entitlements during surrender, introduce mutable postactivation approvals or require transfer ancestry. |
| E3: frozen quote closure | Implement a snapshot evaluator reproducing the mint branch and all amount-dependent nested quote inputs under the actual configured weighted reserve routes. Later changes to any live dependency must not affect it. | Do not replace the calculation with rates, current reads, a different hook, or split large entitlements to bypass quote limits. Report unsupported quote domains concretely. |
| E4: donation bootstrap | Demonstrate an empty new instance reaching a funded, quoteable reserve with ordinary new money disabled, without fabricating user bonds or preminting migration entitlements. Separately account for any required reserve self-leg. | Existing live donation success does not close this gate. Specify and test the Migration-only bootstrap adaptation before loading operational entitlements. |
| E5: payout closure | Enumerate DETF, bond, staking/SY and callback paths; no Stage 1 reward payout, no early migration principal, no ordinary-package behavioral regression. Include unexpectedly long Stage 1. | Do not rely on the operator activating quickly, and do not invent a principal lock extension or defer accrual. Fix the route composition before completion. |

E2 checks configured original-wallet identity, actual surrender and consumption; it does not reconstruct token history. Ordinary transfers need not notify Migration and do not move configured compensation to another wallet. Surrender must remove the eligible asset or claim from the recorded wallet's control and place it in recovery custody or consume it through the source-defined route. Authenticated execution-build records, native transaction-prefix commitments and intermediate-holder proofs are not prerequisites. Actual source identity, units and recovery behavior remain E1 requirements.

Source categories requiring explicit rows are: both DETF generations; both NFT models; sDETF/earlier receipts; SY; TokenStaking/claim-vault rights; underlying SE shares; fungible LP tokens. An NFT LP lock and a fungible LP token are separate rows. A source with no exposure must be proven absent from the approved dataset, not omitted by assumption.

## 4. Architecture and file boundaries

Use a distinct package under:

`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`

This directory and the Migration files below are new. Reuse compatible ordinary facets directly. Extract only the narrow internal extension points needed when existing methods are not virtual; do not copy the whole DETF stack.

| Planned component | Responsibility |
| --- | --- |
| `interfaces/IUniswapV4DetfMigration.sol` | Product structs, events, errors and persistent/configuration surfaces |
| `interfaces/IUniswapV4DetfMigrationDFPkg.sol` | Interface-owned `PkgInit`/`PkgArgs`, including explicit owner and compatible base args |
| `UniswapV4DetfMigrationRepo.sol` | Lifecycle, snapshot, source configs, entitlement configs, separate consumption and custody accounting |
| `UniswapV4DetfMigrationAllocationTarget.sol` / `Facet.sol` | Stage 1 source/entitlement loading and replacement, snapshot capture, independent compensation issuance and one-time activation; all callable selectors removable |
| `UniswapV4DetfMigrationTarget.sol` / `Facet.sol` | Persistent surrender, quote/entitlement queries and bounded custody/harvest operations |
| `UniswapV4DetfMigrationSnapshotLib.sol` | Frozen-state evaluation using existing mint split and canonical weighted arithmetic; no live fallback |
| `UniswapV4DetfMigrationDFPkg.sol` | Registered package composition, ownable initialization, child packages, gated ordinary issuance surfaces |
| `UniswapV4DetfMigration_Component_FactoryService.sol` and `UniswapV4DetfMigration_Pkg_FactoryService.sol` | CREATE3 facets and registry package deployment using artifact bytecode |
| `bondNft/UniswapV4DetfMigrationBondNFTVault{Target,Facet,DFPkg}.sol` and interface | Reuse funded custody/accounting; migration-position cliff and new-instance reward gating |
| Source-specific adapter files under `migration/legacy/` | Typed, verified source reads/calls. No user-selected arbitrary target, selector or delegatecall. Final adapter list comes from E1. |
| `TestBase_UniswapV4DetfMigration.sol` and `TestBase_UniswapV4DetfMigration_Adversarial.sol` | Real registry-deployed Migration system with production reserve/staking/child components |

Use integrated custody in the Migration proxy for surrendered legacy assets and staged proceeds. Keep new-bond principal in the existing funded bond/staking custody arrangement. Those are separate accounting domains. Source adapters do not gain discretionary withdrawal authority.

If selector or bytecode size requires splitting a target, split within this boundary without changing roles or public behavior. No upgrade authority, generic execution router, expiry, cancellation, new funding certification, source-admission backdoor or frontend project is added.

### 4.1 Ordinary components and migration exceptions

- Preserve normal token metadata, 9-decimal DETF/sDETF, route tables, reserve ownership, fee oracle, creator and registry integrations.
- Keep owner and source allowlisting specific to migration. This is not a universal `PkgArgs` token-policy allowlist.
- Gate every ordinary new-money entry route using the Migration lifecycle. A wrapper facade is insufficient if an inherited selector still reaches issuance.
- Add a distinct `createMigrationPosition` path to the Migration bond child, authorized only for its parent DETF. Reuse exact principal funding through a narrow internal helper.
- Mark compensation/migration bond IDs as cliff positions. Ordinary Stage 2 bond purchases keep their ordinary terms unless an explicit requirement says otherwise.
- Route claim calculation through a narrow overridable/internal policy point. Ordinary `_claim` behavior stays linear; Migration-marked positions use section 5.5.
- Reward gating concerns the entire new instance, including fee/creator and indirect settlement routes, not just the new Migration selector.
- Retain Stage 1 fee/creator reward backing and attributed rights under protocol custody rather than distributing reward receipts to those recipients before activation. Preserve the recipient and economic participation associated with each allocation; activation must not recalculate ownership or discard accrued rights.
- Extend the Migration child metadata composition as needed so its description, principal availability and rendered progress match the cliff. Reuse ordinary metadata for ordinary positions.
- Do not assume comments on ERC-721 transfer settlement describe actual payouts; inspect the actual transfer and synchronization call graph and test it.

## 5. Data and arithmetic contract

### 5.1 Domains, units and immutable snapshot

Use native integer units throughout. ETH/WETH and historical DTF are 18-decimal inputs for this recovery; DETF credit is native 9-decimal units. Earlier receipts, LP shares, gons and staking weights retain source-specific units. Parse CSV/JSON quantities as integer strings, never floating point. An unknown blank value is not zero.

Identify a source by chain, deployed source contract and source kind. The NFT entitlement key includes collection and token ID. Domain-separate any commitments by chain ID, Migration proxy and snapshot identity to prevent cross-instance replay.

Snapshot storage must contain, or make immutably available, the complete evaluator inputs:

- Hook/token ordering, effective raw and buffered balances, weights and scales.
- Frozen fee and seigniorage fractions.
- Provider-rate values and source-specific nested deposit/redemption quote state where required.
- Contribution-to-pair routes and output-budget conversion state.
- Snapshot identity and capture block provenance.

A hash or timestamp alone is not an evaluator. Snapshot capture reads the configured contracts; the owner does not submit arbitrary output prices. Capture once after actual funding and before dependent configuration. Later funding is a donation, not permission to recapture or reprice. Scripts check the observed state against their intended funding transaction receipts.

### 5.2 Original-credit calculation

For each original entitlement `i`, retain original ETH/DTF components `E_i` and `D_i`.

```text
W = 10^18
p = frozen seigniorage fraction
S = frozen quote book

pairEq(a, x) = existing contribution-to-pair preview evaluated on S
boosted(a, x) = floor(pairEq(a, x) * (W + p) / W)
gross(a, x) = existing weighted hook quote evaluated on S and boosted(a, x)
U(a, x) = floor(gross(a, x) * (W - p) / W)
U(a, 0) = 0

C_i = U(ETH, E_i) + U(DTF, D_i)
```

The hook fee is inside `gross`, once:

```text
fee = floor(boosted * frozenSwapFeeWad / W)
net = boosted - fee
```

Then preserve the canonical rated-input mapping, weighted math, domain checks, output-budget conversion and rounding. Do not replace this with the bare mathematical weighted-pool formula if buffered SE legs add conversion behavior.

Quote both components on the same unchanged book. Do not mutate simulated reserves between them or between recipients. Do not count routed intermediate DTF as another contribution. Do not include the ordinary mint inventory leg, bond duration bonus, LP self-leg, old rewards or current redemption value in `C_i`.

Computing a user quote does not authorize replaying ordinary mint side effects. Only delivered migration principal is minted by the migration operation; separately authorized bootstrap, ordinary issuance and funded rewards retain distinct accounting.

### 5.3 Entitlement configuration versus execution

Minimum semantic fields (packing is an implementation detail):

| Record | Configuration | Execution state |
| --- | --- | --- |
| NFT | Source identity, original acquiring wallet, original components, original eligible units, computed `C_i`, explicit configuration/evidence identity | Consumed flag, same-wallet surrendering owner, measured eligible units, minted credit, custody position and new bond ID |
| Independent compensation | Recipient, consolidated distinct original-entitlement components/credits and evidence identity | Issued flag/record, actual delivered amount and bond ID(s) |
| Fungible entitlement | Original acquiring wallet, supported source/class or claim identity, original contribution/native units and frozen credit basis, explicit configuration identity; no intermediate-holder history | Actual eligible units surrendered by that wallet, remaining/delivered credit, source consumption and recovery custody; ordinary transfers do not move this record |
| Custody position | Immutable source identity and permitted recovery route | Actual assets held, claimed amounts, intermediate conversions, undonated amounts and remaining rights |

Query surfaces live in the retained facet. Keep only configuration/administration operations on the removable facet so its entire callable surface can disappear.

Setters accept complete replacement values and recompute configuration with the same snapshot. They never accept a caller-provided `creditToMint`. Identical configuration is idempotent. Configuration revision/evidence events permit scripts to reconcile replacements.

Migration entitlement configurations may be replaced only in Stage 1, when all surrender is disabled and no migration units or credit can have been consumed. Once activation enables surrender, every configuration/amendment route is permanently removed. There is no partially surrendered entitlement correction policy: such a correction is unreachable. Independent compensation issuance remains a separate Stage 1 operation; its actual issued amounts and bond facts are preserved across authorized configuration replacements, without duplicate payment or retroactive adjustments.

### 5.4 Surrender arithmetic

For a fixed-principal NFT:

```text
P0 = verified original principal
Pc = actual already-withdrawn principal read from the old position
Pr = P0 - Pc

require P0 > 0
require 0 < Pr <= P0
creditToMint = floor(C_i * Pr / P0)
```

Read the remaining **total principal**, not just currently vested/claimable principal. Rewards do not increase `Pr`. Read authoritative state in the same protected operation that takes custody; reject inconsistent metadata and invalid amounts. Burned/nonexistent NFTs and reward-only positions fail even if configured.

After whole-NFT custody, mark the whole identity consumed. `C_i - creditToMint` is not another remaining NFT claim. A return/cancellation route is forbidden.

For partial fungible surrender against the source-defined eligible claim and frozen credit basis:

```text
Q = remaining eligible units
C = remaining prequoted credit
q = verified eligible units surrendered
require 0 < q <= Q

creditToMint = C                         when q == Q
creditToMint = floor(C * q / Q)           otherwise
Q_after = Q - q
C_after = C - creditToMint
```

Apply this arithmetic only after confirming the caller is the recorded original wallet and has the matching configured entitlement. An ordinary transfer does not move its configured credit or require a Migration ledger update. Keep rounding residue with that entitlement's remaining eligible claim; consuming the whole remainder transfers all remaining credit. Actual splitting, merging, claiming or wrapping must not create duplicate underlying claims or allow already surrendered assets to be credited again. Intermediate transfers do not need to be reconstructed.

Use full-precision `mulDiv` rather than overflowing products. A zero-credit surrender must revert before committing custody or consumption; do not create an empty bond or confiscate rounding dust. Users can surrender a larger eligible amount where available.

### 5.5 New bond and reward accounting

For each successful migration or independent compensation issuance:

```text
principal = deliveredCredit
claimedPrincipal = 0
startTimestamp = block.timestamp
duration = 90 days
unlockTime = startTimestamp + duration
```

Mint the exact principal to the parent funding path and use the child's exact pull/stake/gons attribution. Existing escrow surplus cannot substitute for this issuance.

```text
principalRemaining = principal - claimedPrincipal
principalDue = 0                          before unlockTime
principalDue = principalRemaining         at/after unlockTime

stakingValue = floor(stakingGons / currentGonsPerUnit)
require stakingValue >= principalRemaining
rewardsDue = stakingValue - principalRemaining
```

Reward payout requires finalized activation. Rejection changes no balances, gons, claim state or clocks. Successful claims debit the actual paid gons once. Preserve ordinary bond transfer authority and timestamps; transfer cannot pay Stage 1 rewards indirectly.

Use the existing funded distribution/index machinery; do not invent unfunded APY or calculate elapsed-time rewards from a marketing rate. Synchronize funding consistently around creation so earlier distributions are not attributed retroactively to a new bond.

In particular, settle existing participants in the parent before minting/staking new migration principal. Child synchronization while that parent's lock is held does not do this work. Initialize/advance the empty-system reward baseline so an elapsed epoch before the first funded position neither triggers `MissingRewardWeight` nor becomes a retroactive reward for that first position. Test both immediate and delayed first issuance.

### 5.6 Recovery accounting

For each selected legacy position and token:

```text
newlyReceived = balanceAfterClaim - balanceBeforeClaim
undonatedAfter =
    undonatedBefore
  + claimsReceived
  + conversionOutputs
  - conversionInputs
  - donations
```

Measure operation-local deltas; do not use the proxy's total balance as newly recovered proceeds. Separate tokens and units. A receipt claim and later DTF conversion are two stages of one recovery, not two recoveries.

Recovery selection is bounded and indexed by exact source/position. A failure reverts the selected transaction. Successful earlier stages remain in custody. Repeat calls may claim newly accrued assets, but not recount previously received or donated amounts.

## 6. Planned callable surfaces and routing

The following fixes semantic arguments and authority. Final source-adapter tuples are completed by E1/E2; they are not permission for arbitrary calldata execution.

| Surface | Caller and arguments | Behavior |
| --- | --- | --- |
| Deploy Migration package/instance | Registry path; interface-defined base args, nonzero owner, ownership buffer initialization | Initialize proxy once, wire real children, start Stage 1 |
| All-leg donation/bootstrap | Supported assets/amounts, native ETH value where selected, deadline/minimums appropriate to route | Measure receipt, initialize or add reserve liquidity; no personal credit |
| `captureMigrationSnapshot()` | Current owner; no arbitrary prices | Capture once after funding; no token issuance |
| Source configuration batch | Current owner; typed verified source definitions | Stage 1 only; replace complete config without changing execution history |
| NFT configuration batch | Current owner; original acquiring wallet, collection, ID, original components, verified baseline when source cannot expose it | Compute/store `C_i` and wallet binding; do not issue |
| Fungible/claim configuration batch | Current owner; original acquiring wallet, matching source/claim, original units and frozen valuation configuration | Stage 1 only; no reset of prior consumption; no intermediate-holder history |
| Independent allocation batch | Current owner; recipient and distinct original-entitlement components | Consolidate by recipient, quote and store; do not issue |
| Independent issuance batch | Current owner; recipients/configuration identities | Create funded cliff bonds exactly once under current configurations |
| First paid ordinary bond | Current owner in Stage 1; existing paid purchase arguments | Actual payment and funded principal; records the completed prerequisite under section 1.5; normal reward accounting and Stage 1 payout gate |
| `activateMigration()` | Current owner; no caller-selected cut; completed owner-paid first bond required | Atomic activation and removal, including its own one-time administration selector |
| NFT surrender | Recorded original wallet, also the actual owner; collection, ID, minimum credit, deadline | Stage 2 only; require matching configuration; verify remaining position; whole custody; proportional credit into a fresh bond |
| Fungible surrender | Recorded original wallet holding the asset; source, quantity, source-specific claim identifier only where needed, minimum credit, deadline | Stage 2 only; require matching configuration; partial atomic measured custody/consumption and a fresh bond; no transfer-ancestry proof |
| Nontransferable claim surrender | Recorded original wallet controlling the claim; typed source claim identity and supported operation | Stage 2 only; require matching configuration; atomically extinguish/control the old claim and receive assets/rights; no surviving independent credited claim |
| Read/preview operations | Public; source/position/amount | Show frozen original credit, live eligible fraction and expected current award; no live repricing |
| Harvest/convert/donate batches | Current owner; bounded source positions, fixed supported routes, minimum outputs/deadlines | No beneficiary parameter; proceeds stay in recovery custody or enter the new DETF |

No user-controlled historical amounts, original principal, output credit, arbitrary beneficiary, trusted pretransfer flag or source adapter address on surrender. Missing matching entitlement configuration or a wrong original-wallet identity reverts before custody, consumption or issuance; no automatic configuration fallback exists. Safe-transfer callbacks accept only the expected source/token/operation and do not trigger a second credit. Unsolicited asset transfers are not migrations.

### 6.1 Activation implementation

1. Verify current owner, Stage 1 and completed owner-paid first bond under section 1.5; enter the shared reentrancy guard.
2. Assemble the exact removable selector set from the deployed Migration administration facet definition. Resolve and check actual current facet ownership.
3. Apply the local ERC2535 removal with each selector's owning facet address; use no arbitrary initializer/delegatecall. The current `_processFacetCut` skips a zero facet address entirely, so a generic zero-address removal cut would not remove the selectors.
4. Set finalized activation within the same transaction, emit the activation event, and return. No external callback may observe usable partial activation.
5. Any failure reverts routing, activation and all other state.

A repeat call may be an absent selector after removal. It must never reinstall authority or modify finalized state. Verify all factory, package, ERC8109/cut, initialization and callback surfaces, not just a public `diamondCut` name. Ownership transfers after activation move only still-available permissions.

Normal Vault Registry disable/re-enable remains independent. Map existing inbound and exit checks route by route; do not blanket-disable mature exits or interpret finalized activation as bypassing the registry.

## 7. Work packages and dependencies

Test strategy: implement each behavior with a regression test capable of failing against the prior behavior, using real production proxies, reserve, registry, fee oracle, staking and bond children. Hermetic coverage is primary; pinned local forks establish actual legacy compatibility. No code execution is authorized by this plan-writing request.

### Task dependency table

| Task | Depends on | Deliverable |
| --- | --- | --- |
| 1 | None | Source/custody/conservation closure and reproducible valuation inputs |
| 2 | Source routes from 1 | Exact frozen preview evaluator and oracle vectors |
| 3 | 1, 2 | Migration package, owner, bootstrap, lifecycle and real TestBase |
| 4 | 2, 3; E2 for fungible path | Configuration/execution storage and loaders |
| 5 | 3 | Funded migration bond child and payout gates |
| 6 | 1, 4, 5 | Atomic source-specific surrender and credit |
| 7 | 3, 4, 5, 6 | Complete ordinary gate and irreversible activation |
| 8 | 1, 3, 6 | Bounded staged custody recovery/donation |
| 9 | 1 through 8 | Reproducible preparation and resumable scripts |
| 10 | 1 through 9 | Full integration, adversarial, invariant and fork evidence |

## Todos

- [ ] 1. Close legacy routes and entitlement provenance.
  - Recommended task executor category: deep-high.
  - Read the incident evidence/provenance files and verify actual deployed code at pinned chain/block identities. Add the execution evidence manifest under this incident's new `migration/` subdirectory; never rewrite frozen inputs.
  - Produce one source matrix row per category/generation listed in section 3, including exact selector/return schema, unit conversion, custody, remaining-unit calculation, disabled behavior, harvest path and test fixture.
  - Establish each supported asset's source-defined claim units, remaining principal where applicable, valuation inputs and recovery route. Reconcile independent-compensation originals separately; do not reconstruct holder ancestry as a token-surrender prerequisite.
  - Close E1/E2 with actual original-wallet surrender against its configured entitlement and measured custody/claim consumption only after activation, with preactivation rejection proven. Ordinary transfers require neither Migration notification nor a mutable owner approval, but do not transfer the wallet's configured compensation.
  - Prevent double payment for the same remaining underlying claim by checking actual source principal/claim state and consuming the matching entitlement and surrendered representation. Reject missing configuration and a different surrendering wallet without requiring intermediate-holder history.
  - Acceptance: all required source rows have executable evidence or an explicit concrete blocker; unresolved rows prevent full implementation completion, not a silent scope reduction.
  - QA: pinned fork `MigrationLegacySources` suite; include transferred NFTs, burned and reward-only NFTs, partial claims, rebasing receipts, wrapped ownership, nontransferable claim custody and rollback. Record chain/block/hash and code identity.
  - Evidence: `migration/source-manifest.json`, `migration/source-route-matrix.md`, `migration/surrender-spec.md` and fork run receipts. Preserve older attribution-investigation artifacts as historical evidence, not current prerequisites.

- [ ] 2. Implement exact frozen original-entitlement pricing.
  - Recommended task executor category: deep-high.
  - Add `UniswapV4DetfMigrationSnapshotLib.sol` and narrowly factor existing quote math only where required for reuse. Read the source anchors in section 2.
  - Close E3 with a full dependency inventory and exact frozen-state evaluator for the actual reserve/routes. Freeze fee/provider/SE-dependent values, not only reserves. A stored hash or scalar price is insufficient.
  - Use section 5.2. Preserve zero-component handling, native units, fee rounding, seigniorage rounding, nonlinear quote domains and original-entitlement grouping.
  - Acceptance: on identical pre-capture state, frozen calculation equals the canonical mint-branch result; live-state changes cannot alter it. Large original contributions outside existing quote limits fail explicitly rather than being secretly chunked.
  - QA: `MigrationSnapshot` suite with real weighted hooks, rate-bearing buffered legs, asymmetric decimals, threshold below mint gate, fee changes, pool movements, zero/one/two contribution components, rounding boundaries and invalid quote domains.
  - Evidence: frozen input vectors and differential outputs in `migration/quote-evidence.md`; exact source-read inventory.

- [ ] 3. Compose the owner-configured package and donation bootstrap.
  - Recommended task executor category: deep-low.
  - Add the Migration interfaces, repo, DFPkg, factories and production-first TestBase from section 4. Read `IUniswapV4Detf`, base package, package factory and Crane owner/cut sources.
  - Initialize nonzero proxy-local owner and ownership buffer semantics once. Preserve creator/fee/registry distinctions. Use a distinct package identity and Migration-aware child packages.
  - Characterize actual Crane acceptance behavior from section 2; do not assert a delay the existing implementation does not enforce or make new migration permissions depend on that assumption.
  - Add all-leg donation and the Migration-only bootstrap needed to close E4. Account for externally received capital, reserve self-leg minting, liquidity ownership, residual assets and reserved child IDs separately.
  - Handle first-issuance expansion with zero aggregate staking weight, including a funding-to-first-issuance delay longer than one epoch. Preserve the no-backdating rule.
  - Ordinary new money remains closed throughout bootstrap. Do not create a fictitious compensated user bond to open the reserve.
  - Acceptance: two instances with different owners are isolated; real donations make the reserve quoteable before any migration credit issuance; configuration and unclaimed credit do not create supply.
  - QA: `MigrationDeploy` and `MigrationFunding` suites; wrong/zero owner, reinitialization, owner transfer buffer, contract owner, native ETH/WETH, partial funding, corrective donation, residual inventory, fee/creator roles and empty reserve.
  - Evidence: registry/proxy declarations, storage and source-of-supply reconciliation in `migration/package-evidence.md`.

- [ ] 4. Implement separate configuration and consumption records.
  - Recommended task executor category: deep-high.
  - Add removable allocation target/facet and retained queries. Implement typed source, NFT, fungible/claim and recipient configuration with full-value replacement.
  - Compute credit on-chain from the frozen snapshot. Scripts supply verified quantities, not arbitrary quoted awards.
  - Keep consumed NFT identities, independent issuance, custody and partial-fungible execution records outside replaceable configuration semantics.
  - Identical replays leave state equivalent and never issue. Correcting an already consumed identity never enables another payout. Correcting an unconsumed remainder must not recalculate delivered credit as a delta.
  - Acceptance: Stage 1 `100 -> 60 -> 60` configuration stores 60 without duplication; increases/decreases after delivery preserve bonds and history; source collections sharing a numeric ID remain distinct.
  - QA: `MigrationConfiguration` suite, including partial consumption/transfer followed by correction, batch regrouping, mixed independent and held exposure, unauthorized callers and source-definition replacements that must not redirect existing custody.
  - Evidence: configuration/execution state transition table and exact event reconciliation.

- [ ] 5. Add funded cliff bonds and activation-gated rewards.
  - Recommended task executor category: deep-high.
  - Add the Migration bond package/target/facet and minimal shared internal funding/claim extension points. Reuse exact pull, staking, gons and retirement machinery.
  - Mark only compensation/migration bond positions as 90-day cliffs. Implement section 5.5 and audit direct child selectors as well as parent routes.
  - Close E5 across principal-only, rewards-only, combined claims, fee/creator claims, sDETF/SY exits, transfers, synchronization and callbacks. Preserve mature principal rights even in an unexpectedly prolonged Stage 1.
  - Prevent direct Stage 1 delivery of fee/creator reward receipts, not just their redemption. Retain backing and allocation ownership so activation releases the correct accrued rights.
  - Update Migration metadata to show the cliff and reward availability; ordinary position metadata remains consistent with ordinary terms. Check parsed numeric attributes and rendered output rather than pinning prose strings.
  - Acceptance: every migration creates a distinct funded NFT with actual creation time; no early principal or Stage 1 rewards; ordinary packages and ordinary Stage 2 bonds retain their specified behavior.
  - QA: `MigrationBonds` and `MigrationRewardGates`; exact times at creation, unlock minus one, unlock and unlock plus one; activation between accrual/claim; transfer; repeated reward claim; old rewards excluded; ordinary-family regression.
  - Evidence: complete parent/child selector-to-policy table and backing/gons reconciliation.

- [ ] 6. Implement atomic surrender and proportional credit delivery.
  - Recommended task executor category: deep-high.
  - Add persistent Migration entrypoints and E1/E2-verified source adapters. Do not expose arbitrary executors, beneficiary selection or supplied principal/credit.
  - NFT path: require matching configured entitlement and the recorded original wallet as actual owner; verify source, unused identity and current eligible principal; take whole custody; calculate `floor(C0 * Pr / P0)`; mint exact delivered principal and create a fresh bond.
  - Fungible path: require matching configured entitlement for the recorded original wallet, verify its supported source and actual holding, pull or consume the eligible quantity, apply the record's frozen proportional credit, retain rounding residue and preserve the remainder. No intermediate-holder proof or legacy-transfer notification is required.
  - Reject missing entitlement configuration, wrong original wallet, nonexistent/empty/reward-only positions, zero-credit delivery, unsupported sources, prior consumption, short receipt and stale minimum/deadline. Missing configuration must leave balances, custody, consumption, supply and bonds unchanged.
  - Guard reentrancy across validation, receipt, consumption, child funding and safe-transfer callbacks. Final state must be all-or-nothing.
  - Acceptance: section 5.4 examples and conservation laws pass only after activation, with preactivation rejection proven; a long-delayed surrender gets its own full clock.
  - QA: `MigrationSurrender` plus source-claim conservation coverage; unconfigured wallets and different current holders revert; approved NFT operators cannot steal/redirect; configured original wallet with actual assets succeeds; claimed-principal race; callback changes; transfer/merge/split does not move configured credit; whole remainder; wrapper and cross-path double-use negatives.
  - Evidence: end-to-end legacy custody -> newly backed bond traces by source.

- [ ] 7. Complete startup gating and irreversible activation.
  - Recommended task executor category: deep-high.
  - Inventory every installed ordinary issuance selector, alias, indirect route and child callback. Compose gated versions or narrow shared policy hooks that leave ordinary packages unchanged.
  - Implement section 6.1 with local Remove semantics. Remove the administration facet's whole callable surface, including source updates, snapshot capture, allocation setters, issuance and activation itself.
  - Test actual registry-deployed proxy routing before/after; retained queries, surrender, donation, harvesting and bond claims remain reachable.
  - Inspect inherited factory/package/post-deploy/initializer and ERC8109 surfaces for restoration paths. An owner-change test alone is insufficient.
  - Acceptance: failed cut leaves Stage 1 and every selector intact; successful cut cannot be reversed through any exposed route; no callback reward payout or ordinary mint sees intermediate state.
  - QA: `MigrationActivation`, `MigrationSurface` and registry-disable tests with old/current/pending owners, distinct deployer/fee recipient, reentrant caller, repeated activation and package callback attempts.
  - Evidence: removed/retained selector census, loupe receipts and interface-support declarations.

- [ ] 8. Implement bounded custody recovery and donations.
  - Recommended task executor category: deep-low.
  - Implement owner-only harvest/convert/donate operations using typed E1 routes and integrated proxy custody. Selection work must scale with selected positions, not total inventory.
  - Maintain section 5.6 operation-local accounting and fixed destinations. Reset temporary allowances and preserve protected new-bond backing.
  - Distinguish legacy DETF generations from DTF and the new DETF self-leg. Convert/donate only through verified routes; no ordinary bond purchase.
  - Acceptance: selected batch rollback is complete; earlier stages survive later failure; newly accrued assets remain harvestable; repeating a completed stage cannot double-count.
  - QA: `MigrationHarvest` with failing middle item, smaller retry, partial maturity, repeated harvest, conversion failure, donation failure, malicious route callback, registry states and a large unrelated custody population.
  - Evidence: per-source recovery traces, asset-conservation ledger and measured batch gas.

- [ ] 9. Build deterministic preparation and resumable operator scripts.
  - Recommended task executor category: deep-low.
  - New tooling under `scripts/recovery/dtf-migration/`; Foundry transaction stages under `scripts/foundry/recovery/dtf-migration/`, following the existing `scripts/foundry/` layout. Keep preparation separate from broadcast.
  - Build a reproducible CLI: acquire pinned source and valuation evidence, normalize native integers, reconcile actual claim units/custody/recoveries, generate distinct independent and migration configuration datasets, and validate against snapshot quotes. Historical original-contribution records support the independent path and agreed valuation inputs, not a token-holder ancestry gate.
  - Checkpoints include chain/proxy/package identity, snapshot identity, source/evidence fingerprints, full configuration payload hashes, confirmed transaction receipts, actual bond IDs and consumption.
  - Separate deploy, fund, capture, configure, independent-issue, verify, activate and harvest commands. Default to read-only validation or simulation; no accidental broadcast on resume.
  - Before resending, compare observed on-chain state and confirmed receipts. Reorganize batches without replaying donations or issuance. Correct configuration with full replacement values, not script-generated deltas.
  - Acceptance: interrupted/reordered runs resume correctly; missing evidence is not zero; wrong chain/proxy/snapshot is rejected; an unclaimed entitlement remains unminted.
  - QA: script tests using deterministic fixtures and real local-chain integration. Subscribe to exact receipts/events with bounded timeouts; no timing sleeps. Exercise interruption after mining but before checkpoint completion.
  - Evidence: command help, input schemas, fixture outputs and resumable rehearsal report in `migration/operator-runbook.md`.

- [ ] 10. Complete integration, invariant, adversarial and fork validation.
  - Recommended task executor category: deep-high.
  - Complete sections 8 and 9, with one production fixture across deployment, funding, configuration, claims and custody. Add a local per-source/generation integration matrix and update applicable repository coverage records.
  - Extend invariants with actual successful-action witnesses: credit conservation, custody/issuance atomicity, escrow solvency, irrevocable activation, snapshot immutability, separate instances and unchanged ordinary behavior.
  - Benchmark bounded loading, independent issuance and harvest batches at small and large population sizes; select operational batch limits from measured gas and target-chain limits, not the permissive hermetic gas setting.
  - Run ordinary weighted DETF and common bond/staking regressions whenever shared code changes.
  - Acceptance: every baseline acceptance row has the disposition in section 9 and passing observable coverage; all additional Migration tests pass; no required source category is deferred.
  - QA: exact commands in section 10, plus a full scripted local rehearsal and pinned real-legacy fork cases. No production transfer or deployment is part of QA.
  - Evidence: commands, compiler version, source revision, exit codes, test summaries, gas bounds and unresolved pre-existing failures in `migration/verification.md`.

Commits are not authorized by the plan-writing request. If execution later includes explicit commit authorization, keep verified work packages independently buildable and use the repository's existing commit convention.

## 8. Test suite and invariant specification

New hermetic specs belong under:

`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/`

New pinned legacy forks belong under:

`test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/`

Use new Migration TestBases composed from existing production deployment helpers. Do not subclass or patch the SUT to fake policy, use `vm.store`/`etch` to manufacture state, mock the manager/registry/fee oracle/reserve, or bypass registry deployment. Local fork code at an old address is not replaced with current source to make a route pass.

| Test group | Required observations |
| --- | --- |
| Deployment/ownership | Full args initialization, metadata/decimals, registry discovery, all facets nonzero, two proxy owners, completed/pending transfer, invalid owner, no reinitialization |
| Funding/snapshot | Empty-reserve donation bootstrap; actual receipts, no personal credit, separate self-leg supply; immutable complete quote dependencies; exact user split |
| Configuration | Both paths, complete overwrite, identical replay, already-delivered record, partial remainder corrections, no payout on load, no consumed reset |
| Legacy NFTs | Matching configured original wallet and actual owner, original contributions, actual remaining principal, unconfigured/wrong-wallet/empty/burned/reward-only rejection, duplicate IDs across collections, whole identity consumption |
| Fungible surrendered-claim conservation | Configured original-wallet surrender only after activation, with preactivation rejection, unconfigured/different-holder rejection without state changes, no ancestry proof or owner update, measured custody, source-unit wrapper/claim conservation, partial surrender, residue and no double use |
| Bond/claims | New NFT each time, exact funded gons, 90-day cliff, no backdating, rewards from creation but no Stage 1 payout, transfer/exit bypass negatives |
| Activation | All selectors removed atomically, failure rollback, actual loupe, no restoration, no callbacks in intermediate state, persistent routes work |
| Harvest | Owner-only, selected bounded work, rollback, staged retry, actual token receipts, no duplicate recovery, no user harvest entitlement |
| Ordinary regression | Non-Migration package lacks exceptional roles/issuance; ordinary Stage 2 routes preserve expected behavior and registry rules |
| Script integration | Reproducible integer datasets, stale evidence detected, transactions reconciled on resume, corrections not deltas, no repeated donation/issuance |

### 8.1 Exact arithmetic examples

Use native DETF units in tests; human-readable quantities below are explanatory.

1. An original entitlement quotes to 1,000 DETF. Original principal 100 and remaining principal 40 yield 400 DETF, regardless of old rewards.
2. The same NFT with remaining principal zero reverts and leaves configuration, custody and supply unchanged.
3. Original contribution stays fixed when principal is partially withdrawn. Assert the delivered result is proportional to the original quote, not the smaller-input quote.
4. A fungible credit of 1,001 native DETF units on three eligible units yields 333 for the first unit, 334 for the next from the two-unit remainder, and 334 for the final unit. Aggregate never exceeds 1,001; whole-remainder surrender receives residue.
5. Batching distinct configured entitlements adds their already quoted credits without a second nonlinear quote on merged original ETH/DTF. Surrender requires the configured original wallet and actual eligible assets; a different holder cannot use or inherit that credit.
6. Contributions with one zero component still quote correctly. A zero-credit final result cannot commit custody.
7. Loading 10,000 configured DETF credit changes neither supply nor staking backing. A 400-credit surrender changes migration-issued supply and its bond principal by exactly 400.
8. Two surrenders a month apart create two different NFTs and unlock dates a month apart.
9. A principal-only claim at the cliff never includes rewards; a Stage 1 reward claim reverts even if the principal cliff has passed.
10. Waiting more than an expansion epoch between reserve funding and the first bond neither reverts on zero allocation weight nor attributes that waiting period to the newly created bond. A later bond does not participate in rewards settled before its creation.
11. Stage 1 distributions preserve fee/creator reward rights and backing without delivering reward receipts to them. After activation, the recorded recipients can receive the proper accrued allocation exactly once.
12. A wallet holding an otherwise supported asset but having no matching configured entitlement reverts on surrender. Balances, custody, consumption, supply and bond IDs remain unchanged; surrender does not create a configuration.
13. An asset transferred to another wallet cannot use the original wallet's entitlement. The configured original wallet can surrender an asset it actually controls, subject to remaining eligibility and prior consumption, without proving intermediate transfers.

### 8.2 Stateful invariants

- For unchanged configuration, remaining/delivered wallet-bound frozen credit conserves the configured eligible claim subject only to explicitly retained integer residue. Ordinary ownership transfers do not move that compensation record.
- No surrender succeeds without a matching configured entitlement and the recorded original wallet's actual eligible asset; rejected unconfigured/wrong-wallet calls leave custody, credit, supply and bonds unchanged.
- A configuration correction cannot modify any existing bond, consumption fact or custody event.
- No successful credit exists without matching irreversible custody or an authorized independent allocation.
- No custody debit or entitlement consumption survives failed issuance.
- `stakingValue(position) >= remainingPrincipal(position)` for every live funded bond.
- No migration principal leaves before its own `unlockTime`.
- No Stage 1 route pays new-instance rewards.
- No Stage 2 action restores or emulates configuration/independent-issuance authority.
- Pool trading, fee changes, provider-rate changes and later donations do not alter configured original credit.
- Total recovery balances reconcile by asset and stage; no recovered asset reaches an alternative beneficiary.
- Changing a current owner does not change pricing, registry ownership, an existing bond or consumed entitlement.

Adversarial coverage includes A0 donation-before-first-issuance, I1-I3 booked-inventory/pretransfer negatives wherever inherited, J1-J3 real proxy surface, K1 donation theft, E6 residual refund bounds where applicable, N1 callback mutation, fee/creator nondilution, source spoofing, wrapper double-credit, NFT claim/surrender races, activation reentrancy, and custody batch failure. State inapplicable catalog cases with a concrete reason; do not weaken a failing test to close the matrix.

## 9. PRD acceptance traceability

All 53 r20 acceptance IDs remain accounted for. "Revised" means apply the owner-approved rules in section 1, not delete the original test obligation.

| PRD criterion | Planned coverage/disposition |
| --- | --- |
| MIG-AC01 | Task 7: ordinary mint and bond closed at deployment |
| MIG-AC02 | Task 6: every legacy surrender rejects before activation with no state changes and works against frozen configuration only after the atomic activation |
| MIG-AC03 | Task 7: indirect and mislabeled issuance bypass negatives |
| MIG-AC04 | Tasks 4/9: bounded replacement batches, replay and permanent cutoff |
| MIG-AC05 | Tasks 3/4/7: current-owner authorization and rollback |
| MIG-AC06 | Task 6: custody/credit atomicity |
| MIG-AC07 | Revised: tasks 2/6 use original quote times actual remaining-principal fraction; empty position fails |
| MIG-AC08 | Tasks 2/6: no old-reward increase |
| MIG-AC09 | Tasks 1/6/8: cross-representation and recovery duplicate prevention |
| MIG-AC10 | Task 8: recovery does not resize new bond |
| MIG-AC11 | Tasks 1/2/6: distinct LP-lock/funded/fungible units |
| MIG-AC12 | Tasks 3/10: ordinary package isolation |
| MIG-AC13 | Tasks 4/5/6: independent versus surrender path |
| MIG-AC14 | Task 5: common migration cliff class and reward gate |
| MIG-AC15 | Tasks 3/4/7/8: owner, not fee recipient/deployer; no price setter |
| MIG-AC16 | Task 3: closed-stage all-leg funding and backing |
| MIG-AC17 | Task 8: recovered DTF/legacy DETF donation, no ordinary bond |
| MIG-AC18 | Tasks 1/6: every category has a verified route; no silent deferral |
| MIG-AC19 | Task 5: cliff boundary principal checks |
| MIG-AC20 | Task 5: preserved accrued rewards and repeat-claim safety |
| MIG-AC21 | Revised: task 2 calculates full original credit once with exact mint split/fee; task 6 allocates it |
| MIG-AC22 | Revised: same original quote and same eligible fraction give same award; neither live nor partial-input re-quote |
| MIG-AC23 | Tasks 1/6: routed inputs, prior claims and recoveries do not duplicate |
| MIG-AC24 | Tasks 2/7: snapshot and original-credit immutability |
| MIG-AC25 | Tasks 5/6: actual per-surrender creation timestamps |
| MIG-AC26 | Task 7: activation/removal atomicity |
| MIG-AC27 | Task 7: actual selectors absent, including indirect restoration paths |
| MIG-AC28 | Task 7: repeated activation cannot change state; absent selector acceptable |
| MIG-AC29 | Tasks 6/7/8: retained operations after cut |
| MIG-AC30 | Task 7: no migration pause switch; normal registry semantics |
| MIG-AC31 | Tasks 3/4/9: funding-first resumable scripts without new gates |
| MIG-AC32 | Task 8: current owner alone harvests |
| MIG-AC33 | Tasks 8/10: selected work and measured gas independent of inventory size |
| MIG-AC34 | Task 8: repeat/overlapping harvest reconciliation |
| MIG-AC35 | Revised: tasks 1/6 require the configured original wallet and actual surrender; another holder does not inherit its compensation |
| MIG-AC36 | Revised: remaining principal changes delivered fraction, not original quote; rewards and live values do not reprice |
| MIG-AC37 | Tasks 4/7: no Stage 2 source/config/root/approval mutation |
| MIG-AC38 | Task 4: complete overwrite preserves delivered compensation and consumption |
| MIG-AC39 | Revised: tasks 1/6 conserve wallet-bound original entitlement and proportional frozen credit through actual surrender, without intermediate-holder history |
| MIG-AC40 | Task 6: final surrender and full failure rollback |
| MIG-AC41 | Task 6: partial fungibles and whole NFTs |
| MIG-AC42 | Task 6: surrendering owner receives bond; no redirection |
| MIG-AC43 | Task 5: ordinary permitted transfer preserves migration lock |
| MIG-AC44 | Task 8: whole selected harvest transaction rollback |
| MIG-AC45 | Task 8: staged recovery and fixed destination |
| MIG-AC46 | Task 3: per-proxy owner and initialization isolation |
| MIG-AC47 | Tasks 3/7/8: current/pending/former owner semantics |
| MIG-AC48 | Tasks 3/7/10: composition reuse and full actual selector checks |
| MIG-AC49 | Revised: tasks 4/6 load original NFT quote without minting, then inspect principal and deliver proportional credit |
| MIG-AC50 | Tasks 4/6: collection+ID identity, matching configured original wallet and actual current ownership |
| MIG-AC51 | Task 4: recipient consolidation excludes held exposure; sum original-entitlement credits |
| MIG-AC52 | Tasks 4/7: overwrite/replay/cut end-to-end scenario |
| MIG-AC53 | Tasks 5/7: complete preactivation reward-payout closure |

Additional mandatory acceptance: MIG-P01 through MIG-P15, E1 through E5, section 8.1 exact examples, unclaimed-entitlement zero issuance, and migration remaining open with fresh per-surrender bond clocks.

## 10. Execution commands and evidence

The plan-writing task does not run contract builds, tests or transactions. The commands below are for the later authorized implementation task after their referenced new files exist.

Build concrete production artifacts before any test/script that loads them:

```bash
forge build --use solar

forge test --use solar \
  --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/**'

forge test --use solar \
  --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/**'

forge test --use solar \
  --match-path 'test/foundry/spec/vaults/detf/common/**'

FOUNDRY_PROFILE=fork forge test --use solar \
  --match-path 'test/foundry/fork/vaults/detf/protocols/dexes/uniswap/v4/migration/**'
```

Use `python3 scripts/forge-artifacts.py test <edited-source.sol> --test-root <related-test-path>` during focused iterations according to `CLAUDE.md`; substitute actual edited paths, never run literal angle-bracket placeholders. Do not retarget `FOUNDRY_TEST`, delete caches or invent package profiles.

Run full hermetic `forge test --use solar` before the eventual PR handoff, with existing failures identified independently rather than edited green. Fork suites are local, pin their block inside the fixture, use configured RPC access, and do not enter CI. A missing archive/source capability is reported as an unrun check, not a pass.

New worktrees seed `cache_forge/` and `out/` from a warm checkout before the first compile. Use Solar on every compiling Forge command, no `via_ir`, and let cold builds finish. Use background monitoring with exit-code evidence rather than sleeps or polling.

The evidence report records exact commands, environment/compiler versions, exit status and behavioral results. No prose-pinning tests, source-grep tests or tests that only assert a copied configuration inventory. Declaration tests compare interface-derived controls with actual deployed routing.

## Final verification wave

- [ ] F1. Verify policy and source coverage.
  - Recommended task executor category: deep-high.
  - Confirm MIG-P01 through MIG-P15, all 53 PRD acceptance dispositions, every source category and E1-E5. No acceptance row is closed by a mock or a deferred unsupported source.

- [ ] F2. Verify production proxy and money-path behavior.
  - Recommended task executor category: deep-high.
  - Execute the local complete lifecycle and pinned legacy forks, inspect real loupe/registry/child surfaces, conservation and custody. Check ordinary-family regressions and the adversarial/invariant results.

- [ ] F3. Verify reproducibility and operator recovery.
  - Recommended task executor category: deep-low.
  - Rebuild configuration from saved evidence, replay interrupted script scenarios, confirm no duplicated funding/issuance and verify activation removes every administrator loading route.

- [ ] F4. Record implementation completion and deployment limits.
  - Recommended task executor category: writing.
  - Report changed files, exact verified behavior, test/build exits and any pre-existing failures. A still-open actual source/custody/conservation, quote or payout gate means implementation is not complete; the superseded ancestry-proof investigation is not such a gate.
  - Deployment, real funding, activation and compensation execution require separate explicit authorization and reviewed operational datasets. Do not infer those approvals from this plan.

## 11. Completion standard

Implementation is complete only when the full accepted migration behavior works through the real registry-deployed package, every required legacy source is supported with configured original-wallet surrender/custody and source-claim conservation, missing configuration and wrong wallets revert atomically, agreed original credit is frozen and proportionally consumed without intermediate-holder history, every surrender creates an exactly funded fresh cliff bond, activation is structurally irreversible, and the tests and resumable rehearsal demonstrate those facts.

This plan does not claim those conditions already hold. Its planning deliverable is the scoped architecture, accepted precedence, data/formula contract, ordered work packages, acceptance traceability and verification obligations needed to establish them.
