# Weighted original-wallet source contracts

Date: 2026-11-11. Evidence-only handoff; no implementation or new runtime verdict.

## 1. Result, authority and evidence domain

All five assigned categories are retained: liquid weighted DETF, weighted
sDETF, weighted SY, underlying weighted SE shares (two distinct identities),
and weighted fungible LP. Real custody primitives exist for all six identities.
The existing evidence admits DETF-to-DTF, sDETF-to-DETF-to-DTF,
SY-to-sDETF-to-DETF-to-DTF, and DTF-custody-SE-to-DTF conversions at the
historical pin. It does **not** admit ordinary-custodian liquidation of the
disabled WETH SE or owner-restricted weighted LP.

None of these fungible categories is already an implemented same-wallet
Migration surrender path. Original-wallet configuration and eligible-unit
records are separate prerequisites from working ERC-20 transfers. Missing
original records mean rejection, not an inferred allocation.

Authority is the complete phase11 brief and the current **main-checkout**
`MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, revision
`migration-detf-implementation-plan-r3-original-wallet-entitlement`,
section 1.3, lines 56-64; arithmetic and configuration are at lines 184-282.
The owner's later original-wallet rule overrides the earlier bearer-right and
transfer-ancestry interpretations. Ordinary transfers neither move configured
credit nor require notification. No intermediate-holder proof, native-prefix
oracle or execution-build attestation is required.

Worktree:
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-11-same-wallet-sources`.
Read-only Git observations: HEAD
`3f577eeca049c1bd70a812d130941c8a38dd4781`, branch
`work/dtf-migration-phase-11-same-wallet-sources`; initial
`git status --short --ignore-submodules=all` was empty. Plain status exited
128, `expected submodule path 'lib/crane' not to be a symbolic link`; the
prescribed dependency link was preserved. No cache seed was made.

### Evidence locator conventions

These are absolute roots, not references to similarly named files in main:

| Alias | Absolute root |
| --- | --- |
| P | `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` |
| E | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence` |
| I | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery` |
| N | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05/docs/incidents/2026-09-16-dtf-recovery/migration/nft` |
| R | `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery/docs/incidents/2026-09-16-dtf-recovery/migration/nft-recovery` |
| M | This worktree's `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration` |

Historical source domain: Robinhood chain **4663**, L2 block **108944663**,
hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
This is not the new funded frozen quote snapshot. Source admission here is
bounded to recorded historical observations, not an assertion about live
November 11 chain state.

Load-bearing artifacts read:

| Locator | What it establishes |
| --- | --- |
| `E/weighted/report.md`, especially exact-interface, custody and gons sections; `weighted/source-state-summary.json:1-48` | Weighted source identities, native units, pin and source-state distinction |
| `E/weighted/deployed-source-extracts.json`, entries `staking`, `gons`, `sy` | Actual archived source text: staking transfer/unstake, gon debit and SY consumption |
| `E/verification/weighted-replay.results.json:49447-50963` | Independent actual DETF/sDETF/SY custody/conversion cases, with mined receipts; old ancestry UNPROVEN retained |
| `E/verification/other-metered.sources.json:2139-2738` | Exact weighted SE/LP selector routing, facet code hashes and metadata at the historical pin |
| `E/verification/other-metered.json:10454-12913` | Historical SE/LP custody, harvest attempts and successful-inner-call/failed-outer-call rollback cases |
| `E/verification/native-replay.json:8585-8900` | Actual weighted LP owner restriction, native-exit routing, mined failures and unchanged balances |
| `E/phase01-verification.md`, sections 2-4 | Independent evidence supersedes producer's overbroad route labels and HTTP-429 custody gap |
| `E/provenance/report.md`, Contribution joins, Category coverage, Unknown values | Original records are not approved allocations; units and missing numeric inputs |
| `I/positions.csv:1-6`; `I/sources.json:1-80` | Observed account/source keys and original input source inventory, not configured entitlements |
| `N/verification/report.md:1-80` | Actual bounded NFT surrender acceptance; not fungible surrender or recovery acceptance |
| `R/weighted/source-evidence.json:518-642,1910-2380`; `R/weighted/contract.md` | Archived one-word legacy exchange return, source caller/pull semantics and weighted recovery contract |
| `R/verification/report.md:1-100`; `R/correction-verification/report.md`, sections 1-3 | Original R1 growth-stranding failure and accepted correction, including terminal-burn and unbooked-gon cases |
| Current M files cited in section 3 | Present configuration, surrender and inventory boundaries at this task's base |

No historical file was rewritten or rehashed here. For traceability, previously
recorded hashes remain attributed to their reports, not presented as newly
computed: weighted executable
`17e618d198559cdf6bf77674286858911fa61532ca274e04b52f753aa9249df0`;
weighted source archive
`1ed706355a0238847dba503c6c4b590812f9fb3fbe583fff04d15d32de920f4d`;
independent weighted result
`b1bb1cf5059f5a70b872fac2aaa262cdc8ba91f453a8a817f8570b96ec67ac9f`;
provenance reconciliation
`874eb99734cb6f06a6c75982fbe9dcfc52f84e535c3666fb8d2f2f23b11f684f`.
The r1 plan hash retained in older reports identifies that older plan, not P r3.

## 2. Exact fixed identities and ABI boundaries

All entries are the weighted generation, not earlier CP.

| Tag | Fixed source address | Unit and source identity |
| --- | --- | --- |
| WD | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` | Liquid DETF, native 9 decimals |
| WS | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` | Rebasing sDETF, native 9 decimals; canonical internal gons |
| WY | `0xB55604CF4dcdABB362078e106D20F98512391EdF` | Static SY shares, native 9 decimals, backed by WS |
| WE | `0x999DaE02D22E5FEe1c4508430D5196d31d631009` | WETH/DTF underlying SE shares, native 18 decimals |
| DE | `0x2E9C1F705aB967c5Af59249203d7495bDabb223b` | DTF-custody SE/ERC-4626 shares, native **28** decimals |
| WL | `0x46E068c2393e189Fbc86632f67210aF253a42Aa8` | SE Weighted Buffer Hook fungible LP, native 18 decimals |
| DTF | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` | Recovery asset, native 18 decimals |
| WETH | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` | Native 18 decimals; distinct from ETH |

All six source proxies have recorded runtime Keccak-256
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
A common proxy hash does not identify the callable behavior. Retain these
selected facet bindings:

| Source / surface | Historical facet | Runtime Keccak-256 |
| --- | --- | --- |
| WD/WE/DE/WL ERC-20 custody | `0x1d17acA0e0717d90cea916372070a1BE4652223F` | `0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50` |
| WD exchange | `0x4886F86CD0DFFf8b8A836F858925eD4de3a2b291` | `0x1eadaa06571b1cca173491d149bab9b07d5d1b9dc83d268654e49d3179b1a460` |
| WS receipt | `0xB7581fe833a2B2380DD786B345D61FFB734D36EB` | `0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361` |
| WY operations | `0x4B6e65CfC9a16aae0DfA4257A680f4697275e5fc` | `0x6da9227c829765d0464b5eeee02c55ea45883e3af2767aea546f5e906e8b143d` |
| WE SY redeem | `0x614f204B98Ff2E6ba7C4a365CAf7A39f167924A6` | `0x7c02a5793a00529350c466cf37009b6e046109bedb49379087daef548f4faacf` |
| WE exchange | `0x4D9976E8Fd5C6f698DF0303C6056efAff47e6f48` | `0x8992feb5af0dea8274c8ad51e34c4d912c8257c217205dc0b18aa85e72d49ce5` |
| DE ERC-4626 redeem | `0xDbcEEFf98F2388b0eFA0C0fDA2e08cdd263Ce8f5` | `0x99b74f701969463d5147a782113b30bef06ef1c65f58902d410849d6d2cef616` |
| WL SY redeem | `0xe6275c805e712f609c5DeA5b07481A4229e966F7` | `0xb022d06e679e0e3ea6c8e081dc69e255d3d1f3d5363584fb0029d6aac8858565` |
| WL exchange | `0x1B7a7BC9044642C4e42e64f805f6400D75AD2c16` | `0xe5f44175a8c16c705c2c9e5e68b2c3efe842ce694c5e585d2211947802b10d84` |
| WL proportional/flexible native exits | `0xeF727DC325d91d4cdEa81f99fDB2c49C8eB30425` | `0xde852a6db9cd08e476a589f2e6d785fff605a264188c90196f5a92b40ec51151` |

WD/WS/WY archived verified sources are in `E/weighted/probe.sources.json`;
the deployed source paths are respectively
`UniswapV4DetfExchangeTarget.sol`, `StakedDETFTarget.sol` /
`DETFFundedStakingRepo.sol`, and `DETFSYTarget.sol`. Generic ERC-20 facet
metadata is Sourcify `match`, not `exact_match`. The selected weighted
exchange/receipt/SY sources have `exact_match` in the weighted report.
WE/DE/WL evidence authenticates runtime/routing and actual calls; it is not
an independent claim of byte-identical current Solidity or verified source
for every routed facet.

| Operation | Selector | Return schema / evidence limit |
| --- | --- | --- |
| ERC-20 `balanceOf(address)` | `0x70a08231` | uint256 |
| ERC-20 `approve(address,uint256)` | `0x095ea7b3` | bool |
| ERC-20 `transferFrom(address,address,uint256)` | `0x23b872dd` | bool |
| `decimals()` | `0x313ce567` | uint8; units above are not interchangeable |
| WS `gonsOf(address)` | `0x79a67521` | uint256 |
| WS `stakingState()` | `0xe082f1d4` | Seven uint256: totalGons, gonsPerUnit, accountedBacking, allocationDust, stakingDust, feeWeight, creatorWeight |
| WD/WS `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` | `0xd02d3063` | **One uint256**, 32 bytes, not current two-output exchange ABI |
| WY `yieldToken()` / `exchangeRate()` | `0x76d5de85` / `0x3ba0b9a9` | address WS / uint256 WAD |
| WY `getTokensOut()` | `0x071bc3c9` | address[]; advertisement alone does not prove each route |
| WY `redeem(address,uint256,address,uint256,bool)` | `0x769f8e5d` | uint256 actual output; archived source and successful call |
| DE `asset()` | `0x38d52e0f` | address DTF |
| DE `redeem(uint256,address,address)` | `0xba087652` | uint256 assets, successful burn/DTF-transfer receipt |
| WE/WL `redeem(address,uint256,address,uint256,bool)` and `exchangeIn(...)` | `0x769f8e5d` / `0xd02d3063` | Exact input signatures/routing observed; tested recovery calls revert, so they provide **no successful return-layout proof** |
| WL `owner()` / `ownerOnlyLiquidity()` | `0x8da5cb5b` / `0xfe884e28` | address WD / bool true |
| WL `exitProportional(uint256,address,uint256[],uint256)` | `0x8b72d9e5` | Actual caller fails; archived WD consumer expects uint256[] outputs, but this is not a successful standalone WL decode |
| WL `exitProportionalFlexible(uint256,address,bool[],uint256[],uint256)` | `0x94b74d12` | Exact inputs/routing observed; no successful return established by failed call |

Do not install a guessed success-return decoder for a blocked recovery path.
Its present implementation contract is custody-and-hold plus the exact caller
or disabled-source blocker below. No ERC-4626 `redeem(uint256,address,address)`
route is bound on WE or WL in `other-metered.sources.json`; do not substitute
DE's ABI. WL `withdrawSeShares(...)` is also unbound in `native-replay.json`.

## 3. Common original-wallet integration contract and current seams

This section is a **future narrow change**, not a claim about existing code.
Let MIG be the registry-deployed Migration parent proxy, the fixed custodian,
and the fixed eventual donation destination be that same new DETF instance.
Legacy calls target the fixed source proxies externally, never facets by
delegatecall. No arbitrary target, calldata, source adapter or beneficiary is
accepted from a user.

### 3.1 Configuration and keys

Use a domain-separated original-entitlement key containing chain 4663, MIG,
frozen snapshot identity, original acquiring wallet, original economic-record
identity, and admitted source/class or claim identity. A fungible position is
not keyed by an NFT token ID. Keep each original economic quote unit separate
even when multiple inputs belong to one wallet.

Required semantic configured inputs:

- Nonzero recorded original acquiring/contributing wallet and evidence identity;
  source address, weighted generation, source/class and original record key.
- Verified original ETH and DTF contributions, with both components explicitly
  known (a verified zero is valid). WETH observations need their admitted
  contribution interpretation; an unknown native component is not zero.
- Original eligible source quantity and exact unit tag; where representation
  conversion is needed, the verified native-unit/gon/share mapping and its
  record locator. A current balance cannot fill an absent original quantity.
- Frozen snapshot identity and computed original `C0`; recompute from original
  components, never accept a caller price or `creditToMint`.
- Disjoint exposure allocation across an NFT, its claimed receipts, liquid
  tokens, wrapper/backing and independent compensation. Canonical original
  identity must prevent configuring one economic claim under multiple aliases.

Keep immutable consumption/delivery and recovery-custody records apart from
replaceable configuration. Missing configuration, wrong source, wrong original
wallet or absent numeric unit mapping rejects **before** any source call,
credit debit, supply change or bond creation. Current possession or approval
does not supply original eligibility. No on-demand configuration fallback.

Original-record availability is limited: `I/sources.json` identifies S005/S006
as historical sales/input transactions, S001 as receipt balances/gons, S004 as
SY balances, S007 as candidate inventory, and S008 as funded NFT principal.
`E/provenance/report.md` finds 34 liquid, 198 receipt and 17 SY observations,
but zero standalone SE/LP ledger rows; this is not proof of zero exposure.
It records no approved allocation dataset or funded C0. S006 bond inputs
already overlap sale totals. S011 inbound WETH coverage is partial and native
ETH remains UNKNOWN. Do not upload `positions.csv` or `account-ledger.csv`
as original entitlements.

The actual wallet key in `I/positions.csv` is `account` plus `asset` and
`position_id`/`source_key` (for example
`weighted:liquid:0xec8c4eb216cbfc5b7f49b83cfbe6e34212863ae8`).
It identifies an observed holding, **not** the original acquiring-wallet
attestation or verified contribution allocation. Purchase input joins can
establish an original wallet for an identified purchase; they cannot assign
that purchase's entire credit again to every observed representation.

### 3.2 Credit, custody and atomicity

For each admitted record quote once:
`C0 = U(ETH, originalEth) + U(DTF, originalDtf)` on P's one funded frozen
book. No live redemption rate, current backing, old reward, LP value or partial
mint preview substitutes for this quote.

Apply P section 5.4 to the **configured eligible unit basis**, not to a
convenient displayed balance:

```text
Q = remaining eligible units; C = remaining prequoted credit
q = measured surrendered eligible units, 0 < q <= Q
c = C if q == Q, otherwise floor(C*q/Q), using full-precision mulDiv
require c > 0
Q' = Q-q; C' = C-c
```

Preflight the configuration, caller and nonzero-credit/quantity checks; then
perform the source-specific pull and verify its actual eligible-unit receipt.
Book only that receipt, permanently debit the corresponding record, and create
one exactly funded fresh 90-day cliff bond to the **same original wallet**.
Use the existing parent lock/idle-child discipline and exact bond funding
primitive. A later failure, including source delta, minimum, funding or bond
creation, reverts the entire surrender. Approval given in an earlier user
transaction is not itself rolled back, but all changes within surrender are.

For nonrebasing tokens, require exact holder decrease and MIG increase in
native units. For WS, use measured gons and the source's synchronized divisor;
pre-sync displayed-balance subtraction is not an exact custody test. Unsolicited
balances are not admitted custody or eligible-unit input.

Representation transformations do not issue more C0. Conversion output is
recovery inventory, never a second surrender credit. External ordinary
transfers do not move the wallet's record; assets returned to the original
wallet remain bounded by its unconsumed configured quantity/credit, with no
intermediate-transfer proof. Unsupported or unconfigured alternate
representations reject rather than opening another allocation.

Stage 1 replacement must preserve delivered bonds, consumed quantities and
credit; only the unconsumed eligible portion can use corrected configuration,
without `newTotal-oldPaid` top-ups. Activation removes all new configuration
selectors as well as existing administration selectors, while surrender,
queries and current-Crane-owner-only finite recovery remain callable.

### 3.3 Exact existing-code seam

| Current source | Observation and required narrow extension |
| --- | --- |
| `M/interfaces/IUniswapV4DetfMigration.sol:43-143,190-207,232-242` | Independent allocations have a recipient but no token-backed source quantity; `NftEntitlementInput` has collection/id/original units/components/evidence/known flag but **no original wallet**. Add an explicit original-wallet binding for NFT and separate source-specific fungible configuration/consumption/query types. Do not reuse independent no-surrender issuance. |
| `M/UniswapV4DetfMigrationAllocationTarget.sol:54-88,127-151` | Existing setters evaluate frozen originals. NFT setter is keyed only by collection/id; extend its wallet validation and add bounded fungible configuration with source/unit validation, original collision checks and preserved partial execution history. |
| `M/legacy/MigrationLegacyNftLib.sol:20-24,48-71` | Existing NFT preview rejects absent config and consumed IDs, but reads only current holder and principal, not original acquiring wallet. Preserve those checks and add original-wallet admission; current-holder equality is insufficient under r3. |
| `M/UniswapV4DetfMigrationTarget.sol:64-99` | Existing NFT surrender enforces caller == current holder, safe custody and a fresh bond, but no recorded original wallet. Insert original-wallet validation before the pull; add separate finite ERC-20 surrender entrypoints rather than treating the NFT entrypoint as fungible support. |
| `M/UniswapV4DetfMigrationRepo.sol:18-44,62-76` | No fungible entitlement/partial-consumption storage exists. Append distinct configuration, immutable consumption and custody accounting; reuse `_fundBond` exact mint/pull/stake path, not its independent issuance records. |
| `M/UniswapV4DetfMigrationAllocationTarget.sol:154-182` | Activation removes an explicit six-selector administration inventory. New setters must be included and their interface/package exposure updated; retained reads/surrender do not belong on the removable facet. |
| `M/UniswapV4DetfMigrationRecoveryRepo.sol:11-16,26-45` | Recovery inventory, weightedGons and NFT recovery positions exist, but do not authenticate fungible surrender. Only successfully measured new admitted custody may add fungible inventory/gons. Preserve per-origin execution evidence even if conversion inventory is aggregated. |
| `M/legacy/MigrationLegacyRecoveryLib.sol:40-133`; `M/UniswapV4DetfMigrationRecoveryTarget.sol:34-62` | Existing weighted receipt and DETF conversions are finite inventory-funded stages. Add measured WS/WD admission from the new surrender adapter and WY/DE conversion stages; do not authorize spending by raw MIG balances. |
| `M/UniswapV4DetfMigrationPolicy.sol:18-55`; recovery target `_donateRecovery` | Preserve existing donation/residual floors and fixed destination. Harvested assets cannot consume unrelated donations, unbooked tokens/gons or new bond backing. |

The phase05/07 implementation is evidence for its bounded NFT/custody/conversion
mechanisms. It predates r3 original-wallet binding. Neither accepted NFT
verification nor existing recovery inventory proves the new fungible adapter
or its r3 eligibility checks.

## 4. Liquid weighted DETF contract

1. **ABI/source:** WD, section 2 ERC-20 and one-uint256 exchange ABI. Archived
   exchange `UniswapV4DetfExchangeTarget.sol:9-20` and
   `UniswapV4DetfTarget.sol:429-495` are directly extracted in
   `R/weighted/source-evidence.json:1910-2380`.
2. **Wallet/source key and inputs:** original wallet + WD + original
   acquisition record, domain-separated as section 3. S006 can supply original
   transaction/component evidence where joined; S011/positions supply observed
   native holdings, not a configured original credit. Reject records lacking
   their original wallet, both known components or original eligible WD units.
3. **Units/credit:** original `Q0`, remaining Q and q are 9-decimal WD token
   units. No rebase index or `1e9`/DTF conversion rate is inferred. Apply section
   3.2 to prequoted C. A WD balance can mix acquisitions; it is only a custody
   bound, not a price or a new allocation. The exact missing input is the
   per-original-record WD quantity/component allocation, not a legacy transfer
   method.
4. **Custody:** original wallet approves MIG on WD, then calls the finite
   surrender; MIG calls `WD.transferFrom(wallet,MIG,q)`. Verify exact wallet
   and MIG WD deltas, record q and fund that wallet's fresh bond atomically.
5. **Recovery:** current MIG owner selects an inventory-bounded amount and
   minimum/deadline. MIG approves **WD itself**, calls
   `WD.exchangeIn(WD,q,DTF,min,MIG,false,deadline)`, then clears approval.
   Archived `_burnPath` pulls from its caller, explaining the self-source
   approval. Debit only booked WD and book actual positive DTF delta equal to
   the one-word return; keep DTF in MIG until fixed-destination donation.
   This invokes legacy protocol-managed reserve exit, not a direct WL exit by
   MIG. Partial/staged recovery is supported by the observed primitive.
6. **Evidence/gaps/tests:** independent
   `weighted-replay.results.json:49447-49542` measures **21,225,531 WD**
   custody from `0x082cb14f04d9c485473dedc00d604d7e9abca303`.
   WD conversion is independently observed after receipt/NFT paths as well;
   phase07 correction verification executes it through real Migration.
   New tests must compose direct WD surrender with configured-wallet checks,
   partial credit, new bond rollback, inventory admission and later conversion.
   The old EOA custodian at `0x000000000000000000000000000000000000c057`
   is not evidence for those integrated checks.
7. **Disposition:** **usable legacy custody and recovery primitives; missing
   per-original configuration/eligible-unit allocation and new adapter
   integration.** No new source-caller blocker is established for this route.

## 5. Weighted sDETF contract

1. **ABI/source:** WS and section 2 receipt ABI. Actual archived
   `StakedDETFTarget.sol:104-124,187-214` and
   `DETFFundedStakingRepo.sol:109-161` are in
   `E/weighted/deployed-source-extracts.json` entries `staking`/`gons`.
2. **Wallet/source key and inputs:** original wallet + WS + original economic
   claim record. A claimed NFT receipt must carry the allocated original
   contribution/remaining claim, not the NFT's whole credit a second time.
   Required original inputs are section 3 plus verified original eligible
   receipt/gon basis and its principal/reward separation. S001 and positions
   are balance/gon observations; claim receipts separately identify principal
   and rewards. No original record means rejection.
3. **Units/credit:** native display is 9 decimals; gons are canonical
   ownership units, not 18-decimal DTF or reward-free principal.
   Source transfer moves `qNative * synchronizedGonsPerUnit` gons.
   Preserve the exact configured eligible-unit mapping to Q/C; the existing
   bundle does **not** approve a numerical original-principal-to-eligible-gons
   allocation for every wallet. That numeric mapping is an explicit unit/input
   blocker; neither present `balanceOf` nor a pinned index resolves it.
   Index growth must not increase configured C. Do not decide that every
   displayed reward unit is new principal credit. At the historical pin
   k = `876973181092115404940326782759509937`; this is an observation, **not**
   a frozen compensation rate.
4. **Custody:** wallet gives native-unit allowance on WS to MIG. MIG calls
   `WS.transferFrom(wallet,MIG,qNative)` under the parent lock. The source
   synchronizes before transfer; read post-operation k and before/after gons,
   require exact `qNative*k` transfer and use the admitted mapping to debit
   eligible Q. Distinguish synchronization growth from transferred gons.
   Book only newly received attributed gons and their native representation;
   all credit/bond effects remain in the same reverting operation.
5. **Recovery:** no receipt allowance is required for direct custodian
   unstake. MIG calls
   `WS.exchangeIn(WS,qNative,WD,qNative,MIG,false,deadline)`.
   Require one-word return and actual WD delta equal qNative. Partial unstake
   debits qNative*k; full-account exit can retire **all** account gons,
   including fractions. Use actual gon debit, never spend unbooked gons.
   Reconcile native inventory from attributed gons at the synchronized source
   divisor, then use section 4's WD conversion and fixed donation.
   Recovery revaluation changes inventory, not C or compensation.
6. **Evidence/gaps/tests:** independent
   `weighted-replay.results.json:49601-50182` measures **38,283,506 WS**
   custody from `0x01b0b538d0201efacdde7bb0397abb2133723009`,
   **33,516,514,845,772,316,453,173,092,124,488,164,768,268,274 gons**
   received, exact same native WD output, then actual DTF.
   Accepted R1 correction independently converts the terminal NFT's additional
   **488,794 whole receipt units**, preserving unbooked gons and compensation.
   That is NFT-recovery-owned inventory evidence, not admission of an external
   wallet's fungible entitlement. New tests must add actual WS pull/admission,
   source synchronization, approved mapping/partial credit, growth after
   custody, mixed NFT-recovery and external-custody gons, full/fractional
   retirement protection, and late failure rollback.
7. **Disposition:** **usable transfer/unstake/recovery primitives; missing
   original eligible receipt/gon-to-credit mapping and configured-wallet
   integration.** Do not restore obsolete E2 ancestry as the blocker.

## 6. Weighted SY contract

1. **ABI/source:** WY, section 2 SY ABI; actual archived
   `DETFSYTarget.sol:94-134,225-253` in
   `E/weighted/deployed-source-extracts.json` entry `sy`.
2. **Wallet/source key and inputs:** original wallet + WY + original
   acquisition/claim record, including verified original components and
   eligible original share quantity. S004 and the 17 SY position rows supply
   static holdings, not approved original contribution allocations. Do not
   substitute TokenStaking weight or claim-vault shares for WY shares.
3. **Units/credit:** Q/q are 9-decimal static SY shares once configured.
   A share's backing slice is `shares * 1e36` gons; source converts through
   its synchronized receipt index and tracks conversion dust. The observed
   WAD exchange rate `1140285725447928057` is a **recovery** observation, not
   C0 valuation. Wrapper shares and WS backing are one claim. Missing input:
   original record's eligible WY share allocation and ETH/DTF components;
   do not award both wrapper and backing.
4. **Custody:** wallet approves MIG and MIG performs
   `WY.transferFrom(wallet,MIG,qShares)`, exact wallet/MIG share deltas,
   section 3 configured-wallet and credit checks, and one fresh funded bond.
   No source redemption before eligibility; no raw-balance/pretransfer mode.
5. **Recovery:** after custody, MIG calls
   `WY.redeem(MIG,qShares,WS,minReceipt,false)`. Source burns MIG's selected
   shares; no WY allowance is needed to burn the caller's own shares.
   Require exact WY decrease and measured WS receipt/gon increase consistent
   with actual source output. Book received WS gons only once, then perform
   section 5 unstake and section 4 WD conversion, possibly in later owner
   batches. Do not infer direct WY-to-DTF support from `getTokensOut`.
   MIG remains every external receiving custodian.
6. **Evidence/gaps/tests:** independent
   `weighted-replay.results.json:50241-50958` records wallet
   `0x11c17f25e958e4637dd26ca362adeae12e24ed5b` surrendering **8,094 SY**
   to the EOA fixture, its complete burn yielding **9,245 WS**, then
   **9,245 WD** and **52,221,256,856,930,805 DTF**.
   Existing Migration recovery stage enum has no WY redemption stage.
   New tests must execute WY surrender and this staged route through the real
   proxy, including synchronized dust, return/delta checks, zero/minimum output,
   exact original-share cap, wrapper/backing nonduplication and batch rollback.
7. **Disposition:** **usable legacy custody and staged recovery primitives;
   missing original-wallet/share allocation and bounded WY adapter/stage.**
   No new valuation rate is needed or supplied.

## 7. Weighted underlying SE contracts

Both identities are mandatory; one successful custody wrapper must not stand
in for the disabled WETH/DTF SE.

### 7.1 WE: WETH/DTF SE shares

1. **ABI/source:** WE, native 18 decimals; selected runtime/facets and exact
   failed SY/exchange signatures are in section 2 and
   `E/verification/other-metered.sources.json:2139-2338`.
2. **Wallet/source key and inputs:** original wallet + WE + original SE
   deposit/acquisition record. Require verified original paid ETH/DTF
   components, original eligible native shares and evidence. Zero standalone
   SE rows in the old ledger do not supply those records or prove absence.
3. **Units/credit:** Q/q are WE shares at 18 decimals. They are neither WD
   principal nor DE's 28-decimal shares. No nominal 1:1/LP/NAV conversion
   defines C. Exact missing numeric input is per-original acquisition's WE
   share quantity and contribution assignment.
4. **Custody:** configured original wallet approves MIG; MIG calls
   `WE.transferFrom(wallet,MIG,q)`, measures exact deltas and uses section 3
   atomic consumption/bond path. Historical fixture holder was **WL**, not
   an established user-authorized account. Impersonating WL demonstrated
   token mechanics, not an ordinary user's authority over WL inventory.
5. **Recovery:** only custody-and-hold is admitted. Tested
   `WE.redeem(MIG,q,WETH,min,false)` and corresponding DTF output, and
   `WE.exchangeIn(WE,q,output,min,MIG,false,deadline)` revert
   `VaultDisabled(WE)`, selector `0x1ba84b43`, with no output or share debit.
   Fixed registry `0x09682b00D873D913ada0bB69B4D4c9631810d0bc`
   returns disabled via `isDisabled(address)`, `0x4f6c171d`.
   Do not impersonate source governance, enable it or silently use another SE.
   Assets remain in MIG pending a separately admitted actual recovery path.
6. **Evidence/gaps/tests:** `other-metered.json:10454-11076` has exact
   custody **23,634,291,028,048,331,275,075 shares**, failed recovery and
   outer-revert rollback. `:10583-10686` includes mined failure
   `0x1965edcd8004ff758e628ff0f2637ffeddfcdd99a6c3005e396cd9745e77427b`,
   raw disable error and unchanged custody. New configured-wallet custody
   tests need an actually controlled original-wallet holding, not an
   infrastructure impersonation. Preserve a disabled-exit negative and held
   inventory; a future source-enabled recovery needs separate executable
   admission, not a forced-storage "success."
7. **Disposition:** **usable mechanical custody; concrete disabled-source
   recovery blocker plus missing original-wallet/source-unit configuration.**
   This category is not fully supported.

### 7.2 DE: DTF-custody SE/ERC-4626 shares

1. **ABI/source:** DE, native **28 decimals**, `asset()==DTF`,
   ERC-4626 `redeem(uint256,address,address)` returning uint256 assets;
   `other-metered.sources.json:2339-2538`.
2. **Wallet/source key and inputs:** original wallet + DE + original
   deposit/acquisition record, known original ETH/DTF components, original
   eligible DE shares and evidence identity. The old standalone SE inventory
   has no approved allocation rows. Source asset/totalSupply reads supply
   mechanics, not an original acquisition record.
3. **Units/credit:** Q/q are 28-decimal DE shares; output DTF is 18 decimals.
   Observed `1e10` relative scale in the demonstrated redemption is not a
   blanket contribution valuation or substitute C0. Missing exact inputs:
   original eligible shares and original contribution allocation per wallet.
4. **Custody:** wallet approves MIG on DE; MIG pulls exact native q and
   verifies holder/custody deltas in section 3's atomic funded surrender.
   Historical holder was WL, an infrastructure fixture, not an authenticated
   original end-user deposit.
5. **Recovery:** as actual share owner, MIG calls
   `DE.redeem(q,MIG,MIG)`. No share allowance is needed for its own
   ERC-4626 redemption. Require exact selected share burn and positive actual
   DTF delta equal the decoded assets return; book only that DTF and later
   donate to the fixed new DETF. Inventory-bounded partial/staged redemption
   is a finite new recovery stage, absent from the existing NFT stage enum.
6. **Evidence/gaps/tests:** `other-metered.json:11077-11498`, particularly
   `:11206-11289`, records burn of
   **1,622,646,459,016,401,842,967,981,100,000,000 shares**, actual
   **162,264,645,901,640,184,296,798 DTF**, and custody remainder zero.
   Mined success
   `0xb9d405ac37e7aa22f544912461c9945bfeb8c858938bd4fdea7264674c5f0ba6`
   includes both burn and DTF transfer. New tests must cover real
   original-wallet surrender/configuration, non-18 scale, partial burn/output
   rounding, source min/delta enforcement by MIG, insufficient inventory,
   fixed receiver and whole-batch rollback through the real proxy.
7. **Disposition:** **usable mechanical custody and actual redemption
   primitive; missing original records and DE surrender/recovery integration.**
   No disabled-source blocker was observed for DE.

## 8. Weighted fungible LP contract

1. **ABI/source:** WL, native 18-decimal fungible LP, section 2 route table.
   This is not weighted funded NFT `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E`,
   nor the earlier CP NFT/LP. See
   `other-metered.sources.json:2539-2738` and
   `native-replay.json:8585-8900`.
2. **Wallet/source key and inputs:** original wallet + WL + original
   liquidity acquisition record, original ETH/DTF components and eligible
   WL units. Old ledger has zero standalone LP rows, not a zero exposure
   conclusion. Fee-collector inventory is not evidence of a user's original
   qualifying contribution or authority to surrender collector assets.
3. **Units/credit:** Q/q are 18-decimal LP units, not WD supply, underlying
   WE/DE shares, or fixed-principal NFT units. Require an explicit original
   LP acquisition-to-contribution/share allocation before configuring C0.
   Neither reserve ratios nor present LP redemption value is an approved
   substitute. No such approved per-wallet numeric allocation is supplied by
   the evidence consumed here.
4. **Custody:** original wallet approves MIG; MIG calls
   `WL.transferFrom(wallet,MIG,q)` and measures exact deltas. Historical
   holder `0x20af9A1e21a59a411cd3b0c40E70AF9084770b2E` is the fee
   collector, explicitly `fixtureMayBeInfrastructure=true`.
   Mechanical pull/rollback PASS is not end-user original-wallet admission.
5. **Recovery:** **hold only** under the admitted ordinary-MIG caller.
   `owner()==WD` and `ownerOnlyLiquidity()==true`. Exact-in/SY exits to
   all five advertised outputs and both bound native exits reject
   `NotOwner(custodian)`, selector `0x245aecd3`. Native
   `exitProportional(q,MIG,minima,deadline)` and
   `exitProportionalFlexible(q,MIG,flags,minima,deadline)` are not made usable
   by MIG's ERC-20 ownership or approval. Do not transfer WL to WD and assume
   it can recover that new inventory: the passing WD exchange spends
   protocol-managed LP through its own route, not arbitrary surrendered WL.
   Any owner-mediated route for this specific surrendered inventory remains
   unproved; no legacy ownership/role changes are admitted. Every future
   output must still return to MIG, and WE outputs retain WE's disabled
   dependency.
6. **Evidence/gaps/tests:** `other-metered.json:11499-12913` measures
   **15,166,467,477,246,491 LP units** custody and failed five-output
   recovery; outer rollback is separately recorded. Historical native replay
   measures the same custody and source restriction. Its proportional
   failed tx is
   `0xa10d7a7ee0f69cf886b6cbcf5f8eede817b7ea32beafa1048bf78182ac8c372f`;
   raw trace returns
   `0x245aecd3000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266`.
   LP remains unchanged and all measured outputs are zero. Preserve the
   producer's separately pinned native failures too; do not confuse their
   hashes with this historical replay. Future tests need original-wallet
   holding/configuration evidence, atomic custody/credit, exact rejection of
   direct MIG exits and retained inventory. Successful liquidation acceptance
   additionally needs a concrete source-authorized fixed-recipient route for
   **these surrendered LP units**; present evidence supplies none.
7. **Disposition:** **usable mechanical custody; concrete ordinary-caller
   recovery blocker plus missing original-wallet/LP-unit configuration.**
   No claim that every possible legacy-owner-mediated route is impossible.

## 9. Existing executable evidence versus new integration acceptance

Historical results are not relabeled:

- Weighted independent replay exited 0 with **34 PASS, 1 FAIL, 2 UNPROVEN**.
  Its approved-operator claim-redirection protection **FAIL** remains true:
  a legacy approved operator can redirect NFT receipt payouts. New surrender
  must bind original wallet/custody and new bond recipient itself.
- Other-source original attempts include missing environment, unavailable
  public archive, receipt/trace parser failures and HTTP 429. They remain
  archived. The independent **metered historical replay** resolved source
  acquisition/custody at the historical pin, with **21 PASS, 4 FAIL,
  3 UNPROVEN**, exit 2. Those old acquisition failures are not current
  custody blockers. Actual disabled/NotOwner failures remain blockers.
- The original E2 attribution witness remains valid under its **old**
  transfer-following requirement. Its need for a postactivation authenticated
  intermediate-holder mechanism is superseded by P r3, not "fixed" by a new
  PASS label. Original record configuration, surrender conservation and
  nonduplication remain necessary.
- Phase05 acceptance covers two NFT surrender models; phase07 acceptance
  covers admitted NFT claims, weighted conversion and donation. Original
  phase07 R1 failure `RecoveryInventoryInsufficient(WS,1,0)` and stranded
  9,789/488,794-unit witnesses are preserved. Accepted correction revalues
  only already attributed gons, including after terminal NFT burn. It is
  evidence to reuse for a new fungible custody adapter, not an existing
  fungible-entitlement ledger.
- `E/provenance/report.md` preserves two frozen Markdown manifest mismatches
  and unknown numerical inputs. Neither a runner success token nor a hash
  check would turn them into approved original entitlements.

### Required new tests (specified, not run)

Use actual registry-deployed Migration and real admitted historical sources;
do not replace source balances, gons, bytecode, roles or ownership to obtain
an all-category success. Synthetic arithmetic can supplement, not replace,
actual custody and conversion evidence.

| ID | Narrow acceptance |
| --- | --- |
| W-T1 | For every six source identities, missing config, wrong original wallet even with balance/approval, wrong source/class, and unknown unit/component input reject before custody/consumption/supply/bond changes. Recheck before and after activation. |
| W-T2 | Original wallet with matching config and controlled actual asset succeeds; another holder cannot inherit credit after an ordinary transfer. Transfer away/back requires no history proof or notification, and original wallet cannot exceed remaining configured Q/C. |
| W-T3 | Partial, combined-original-record and terminal remainder arithmetic match P's remaining-credit formula; zero-credit dust rejects without confiscation. Frozen quote is unchanged by elapsed time, later donation, or partial size. |
| W-T4 | Complete Stage 1 replacement is idempotent, preserves delivered bonds/consumption, and applies only to unconsumed eligible units; no retroactive top-up or reopened origin under another source alias. |
| W-T5 | WD/WS/WY exact pulls create one precisely funded fresh bond each; approval failure, bad delta, minimum/deadline failure or downstream bond failure restores all in-transaction source and Migration state. |
| W-T6 | WS actual synchronized gon receipt and mapped eligible-unit debit, partial/full unstake, growth reconciliation, final fraction, mixed NFT/external receipts and unbooked gons preserve both recovery inventory and unrelated custody/backing. No growth creates compensation. |
| W-T7 | WY actual selected share burn to WS, then WD/DTF stages through MIG, with conversion dust, exact output booking and no wrapper/backing or NFT-descendant second credit. A later batch failure restores all selected stages, not prior committed batches. |
| W-T8 | DE 28-decimal actual custody/redemption and positive DTF output with no assumed decimal conversion; original approved wallet authority must replace infrastructure-only fixture evidence. |
| W-T9 | WE disabled and WL NotOwner negatives stay failing recovery routes with unchanged held balances; no arbitrary executor, role impersonation, source substitution or claimed liquidation PASS. Actual successful liquidation requires new route evidence first. |
| W-T10 | Fresh bond goes only to configured original wallet; independent compensation remains no-surrender and disjoint. Donations create no personal eligibility; unsolicited legacy transfers create neither inventory admission nor compensation. |
| W-T11 | Activation removes all old/new configuration routes irreversibly. Retained surrender/recovery uses original immutable records, current Crane owner, fixed recipients and measured budgets. Selected recovered DTF donation cannot spend unrelated funds, mint a second compensation award or buy an ordinary bond. |

For WE/DE/WL, absence of a proven user acquisition row is not resolved by
impersonating a hook or fee collector. Until an original record and controlled
asset are supplied, the positive eligibility fixture is missing; the correct
production behavior for that unconfigured wallet is rejection.

## 10. Finite handoff and limits

| Category | Legacy custody | Legacy recovery | Exact remaining handoff |
| --- | --- | --- | --- |
| Weighted liquid DETF | Actual PASS, native 9 units | Actual WD-to-DTF; reused in real NFT recovery | Original-wallet/acquisition/native-unit configuration, new partial-credit pull/admission and integration tests |
| Weighted sDETF | Actual PASS, measured gons | Actual WS-to-WD-to-DTF; accepted growth correction | Original eligible receipt/gon mapping excluding new reward credit, original-wallet config, new custody admission with old recovery protections |
| Weighted SY | Actual PASS, native 9 static shares | Actual WY-to-WS-to-WD-to-DTF in source fixture | Original share/contribution allocation, wallet config, new WY redemption/inventory stage and real-proxy composition |
| Weighted WETH SE | Actual mechanical PASS, infrastructure holder | Concrete `VaultDisabled(WE)` | Original share/contribution record and controlled wallet; hold only until actual source-enabled route admitted |
| Weighted DTF custody SE | Actual mechanical PASS, infrastructure holder | Actual ERC-4626 burn-to-DTF | Original 28-decimal share/contribution record, controlled wallet, new DE adapter/stage and real-proxy composition |
| Weighted fungible LP | Actual mechanical PASS, fee-collector holder | Concrete `NotOwner(MIG)` on tested direct routes | Original LP/contribution record and controlled wallet; source-authorized recovery route for surrendered LP remains absent |

Implementation order is finite: add configured-wallet/source-unit admission
and immutable partial consumption; bind the existing NFT inputs to the
original wallet too; connect measured WD/WS custody to existing bounded
conversion accounting; add WY and DE finite stages; retain WE/WL custody
rows with their exact recovery restrictions. Do not expose a configuration
as issuable while its mandatory original/unit inputs are unknown. Do not
claim all-category completion with WE/WL recovery unresolved.

This task ran no probes, RPC, compiler, tests, deployments, transactions or
runtime. No delegation, commits, dependency/configuration changes or edits
outside this directory were performed by this producer. The only owned
artifact is this contract. The held phase09 gas candidate, its runtime and
provider-access hold were not inspected, resumed or adjudicated.
