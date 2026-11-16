# Migration DETF bounded implementation handoff

Date: 2026-11-10.

**Verdict: ready-for-bounded-implementation**, exclusively for the default-preserving package/child preparation increment in section 5. **The complete funded Migration package is not ready to compose from the three reports unchanged.** Section 4 identifies the concrete receipt/SY accounting prerequisite. Section 3.4 withdraws the earlier adoption of permissionless pooled-budget genesis and identifies its unresolved authority split. Neither limitation blocks the five-path preparation increment. This verdict does not close task 3, task 5, E4, E5, or any original-plan checkbox.

The next increment is working production-code extraction with real ordinary registry-proxy regression coverage, not an inert Migration package, temporary ordinary-child substitution, arbitrary-credit issuer, or test-only lifecycle setter. It can finish without E1/E2/E3 and without a completed future lifecycle. Root may amend the phase run to execute this exact increment; this report itself executes no code.

## 1. Inputs, authority, and evidence convention

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.

Read completely:

- `docs/incidents/2026-09-16-dtf-recovery/migration/package/ownership.md`, lines 1-145.
- `docs/incidents/2026-09-16-dtf-recovery/migration/package/bootstrap.md`, lines 1-168.
- `docs/incidents/2026-09-16-dtf-recovery/migration/package/children.md`, lines 1-183.
- `/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase03-brief.md`.
- `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` (hereafter **Plan**), including all task/acceptance rows and completion limits.
- `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-02/docs/incidents/2026-09-16-dtf-recovery/migration/pricing/evidence/verification/report.md` (hereafter **Pricing**), as context only.

All three required upstream outputs were present and read; no missing output is treated as PASS. Applicable worktree routers, assistant coding/deployment/testing rules, DETF agent law, canonical Crane architecture/deployment/testing/adversarial skills, IndexedEx testing/adversarial skills, and test-review discipline were read. This report follows Plan's Migration exceptions rather than imposing ordinary unowned/linear-bond defaults on the new family.

For the root-requested follow-up, also read the owner-role and donation/claim requirements at `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_DRAFT_PRD.md:124-154,304-326` (hereafter **PRD**). These selected sections, not the whole PRD, were reopened. Plan's later overrides still control; the stale PRD price-setting language grants no authority (Plan:40).

**Phase01** below means `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/phase01-verification.md`. Its section 6, lines 301-327, expressly permits independent task-3 ownership/bootstrap/lifecycle and task-5 cliff/reward work while withholding affected attribution ABI. That permission is not evidence that a completed Migration lifecycle already exists.

Source aliases below are exact directory prefixes beneath this worktree:

| Alias | Exact prefix |
| --- | --- |
| `D/` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `C/` | `contracts/vaults/detf/common/` |
| `W/` | `contracts/hooks/uniswap/v4/standardExchange/weighted/` |
| `K/` | `lib/crane/contracts/` |
| `R/` | `contracts/registries/vault/` |
| `T/` | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/` |
| `TC/` | `test/foundry/spec/vaults/detf/common/` |
| `M/` | proposed `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/` |
| `TM/` | proposed `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/` |

Every current-code assertion below comes from source inspected independently, not merely from an upstream locator. All new names, algorithms, tests, and acceptance conditions are proposals. No runtime outcome is inferred from source inspection. Some upstream line numbers drift: for example, core initialization is currently `D/UniswapV4DetfRepo.sol:98-110`, and `_firstBondOtherPayment` is `D/UniswapV4DetfTarget.sol:852-858`; use the independently read anchors here.

## 2. Reconciled ownership, storage, and immutable wiring contract

### 2.1 One administrator, not four interchangeable roles

Observed: Crane stores `owner`, `pendingOwner`, confirmation, buffer duration, and buffer end in one canonical namespace. Initialization only writes owner and duration; it neither rejects zero nor prevents repetition. `_onlyOwner` compares the actual caller against the current stored owner. Evidence: `K/access/ERC8023/MultiStepOwnableRepo.sol:30-45,83-98,108-122`.

**Required Migration contract:** no second `migrationOwner`, cached administrator, `tx.origin`, or fee-recipient authority. Initial owner is a nonzero explicit argument. All administration, activation, and retained harvesting use current Crane owner. Creator, fee recipient, registry owner/operator, package deployer, hook owner, and Migration administrator remain distinct. Registry deployment authority is independently owner/operator/package based (`R/VaultRegistryDeploymentTarget.sol:44-76,141-159`); a permissionless package helper does not turn its caller into the administrator (`D/UniswapV4DetfDFPkg.sol:100-102`). Plan MIG-P12 and section 6 govern the future administrative selectors.

**Actual buffer semantics, not the comments' promise:**

1. Initiation by A sets pending B and `now + buffer`; it does not clear a pre-existing confirmation flag.
2. Confirmation by A requires elapsed buffer and matching pending address.
3. B may accept immediately, without confirmation or expiry. Only acceptance changes current owner, then clears pending/confirmation/end.
4. Before acceptance, B has no owner permissions. After acceptance, A has none. Contract owners must make actual calls; their external callers do not inherit owner authority.

Evidence: `K/access/ERC8023/MultiStepOwnableRepo.sol:158-176,189-213,224-242,253-274`; `K/access/ERC8023/MultiStepOwnableTarget.sol:23-54`. Do not repair Crane or promise delayed acceptance in this family.

### 2.2 One parent initialization contract

Use interface-owned Migration arguments containing unchanged `IUniswapV4Detf.PkgArgs baseArgs`, nonzero `owner`, explicit `ownershipBufferPeriod`, and the bootstrap lane's once-configured `weth`. Include all four in canonical encoding and salt material, clearing **only** `baseArgs.hook` in the salt copy. The added WETH argument reconciles the ownership and bootstrap reports; it is not an ordinary-family argument change.

Observed base arguments contain metadata, hook/policy, creation/opening rates, creator, child metadata, and four route tables, but no administrator (`D/interfaces/IUniswapV4Detf.sol:32-55`). Ordinary decoding rejects trailing/noncanonical payloads; salt deliberately excludes hook; processing requires registry caller (`D/UniswapV4DetfDFPkg.sol:197-216`). The factory additionally separates salts by package address (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201-218,326-328`).

Extract the compatible initializer, passing the package's actual fee classification, type declarations, fee oracle, bond package, and receipt package explicitly. Do not bake ordinary interface IDs or ordinary child addresses into the shared helper. Preserve all validation, order, route stores, metadata, and events in `D/UniswapV4DetfDFPkg.sol:223-304`. Preserve the core once-only hook guard (`D/UniswapV4DetfRepo.sol:98-110`). The eventual Migration package initializes Crane owner in the same transaction; any second initialization must revert all preceding writes. Do not install any initializer selector.

The eventual storage division is fixed: Crane owns administrator/transfer state; the existing parent repo remains authoritative for reserve liveness, expansion timestamp, routes, and child identities; the Migration repo owns finalized activation, once-configured WETH, token-keyed pending donation inventory, and separately counted bootstrap self supply. Bond cliff flags and beneficiary pending role gons belong to their respective child namespaces. Do not copy any of these authorities into another ledger. A retained `migrationActivated() external view returns (bool)` reads parent state; children consult their initialized parent, with no child gate setter. Source/configuration/consumption and receipt/SY split fields are not frozen by this preliminary contract. Existing authoritative layouts are `K/access/ERC8023/MultiStepOwnableRepo.sol:40-45`, `D/UniswapV4DetfRepo.sol:98-129`, `C/bondNft/DETFFundedBondRepo.sol:13-18`, and `C/claimToken/DETFFundedStakingRepo.sol:24-36`.

The hook's self-leg and owner must both identify the predicted **parent proxy**, not the administrator (`D/UniswapV4DetfProcessArgsLib.sol:53-64`). Predict with owner/buffer/WETH included, then construct the hook for that prediction; the existing predict-hook-deploy sequence is `D/TestBase_UniswapV4Detf.sol:289-321`. Different owners require independently bound hooks.

### 2.3 Child composition and authority

| Child | Independently observed construction | Fixed handoff requirement |
| --- | --- | --- |
| Bond NFT | Parent completes once, passes itself and reserve hook, then initializes fee/creator reserved IDs (`D/UniswapV4DetfTarget.sol:810-830`). Bond repo rejects parent/LP rebinding (`C/bondNft/DETFFundedBondRepo.sol:33-43`). | Migration-selected bond and metadata facets; parent-only fresh cliff creation. Keep the common registered-package deployment ABI and all three guarded ERC721 transfer replacements (`C/bondNft/DETFNFTVaultDFPkg.sol:48-53,83-93`). |
| Receipt | Parent completion requires bond first and rejects a second receipt (`D/UniswapV4DetfTarget.sol:833-849`). Receipt package accepts selected facet but deploys through the generic callback factory (`C/claimToken/RebasingClaimTokenDFPkg.sol:39-59,95-108`). | One actual sDETF child, not an extra receipt layer. Migration reward-aware facet, same parent/bond/oracle and nine-decimal initialization. Do not turn this generic child into a registered vault category. |
| Raw and staking SY | One selected registered package creates two wrappers with distinct `isStaking` modes (`C/sy/DETFSYDeploymentLib.sol:15-27`; `C/sy/DETFSYDFPkg.sol:41-51,99-117`). | Preserve both wrappers and immutable backing identities. Staking-SY egress must satisfy section 4; an empty SY `claimRewards` API does not prove payout closure. |

Parent package dependencies are immutable constructor values and post-deploy wires bond, receipt, then SY (`D/UniswapV4DetfDFPkg.sol:65-97,306-318`). Common bond/receipt/SY packages already inject selected facets, but their interface declaration methods are non-virtual (`C/bondNft/DETFNFTVaultDFPkg.sol:68-75`; `C/claimToken/RebasingClaimTokenDFPkg.sol:76-85`; `C/sy/DETFSYDFPkg.sol:66-74`). Later add only the declaration extensibility genuinely needed for new interfaces; facet injection alone must not falsely advertise unsupported interfaces.

Reserved NFTs are minted to bond custody, fee recipient, and creator-or-fee fallback, separately from funded user positions (`C/bondNft/DETFFundedBondTarget.sol:82-105`). They are not administrator identities or preminted entitlement principal.

### 2.4 Irreversible activation is a routing invariant

The callback factory stores package context and retains it after deployment; it is not a one-shot authorization token. Base cuts include a temporary post-deploy hook and only the ERC8109 query selector, not a generic updater (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:218-231,261-309,343-410`). The temporary hook delegatecalls its caller (`K/factories/diamondPkg/PostDeployAccountHookFacet.sol:19-23`); factory completion removes it (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:425-451`).

Future activation must use the current owner, shared parent lock, a fixed complete administration selector set, actual nonzero owning facets, and no initializer/delegatecall payload. Zero-address cuts are skipped; wrong owners revert (`K/introspection/ERC2535/ERC2535Repo.sol:104-116,155-169,245-270`). Remove every administration selector including activation itself atomically with the lifecycle transition; retained reads and harvesting stay outside that facet. This implements Plan:334-344, not a generic upgrade facility.

Final proxy resolution reads its own selector map and an absent target fails (`K/proxies/MinimalDiamondCallBackProxyResolution.sol:24-26`; `K/proxies/Proxy.sol:29-32`). Existing-address factory deployment returns before initialization (`K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:215-216`). Therefore the proof obligation is absence of a usable routing/delegatecall edge after construction and activation, including callbacks and factory init variants, not an assertion that the factory has no callable initializer.

## 3. Bootstrap, supply, and reward-order reconciliation

### 3.1 Bootstrap is not an ordinary first bond

Observed deadlock: parent donation forwards to child; child requires live/enabled; parent donation callback also requires live (`D/UniswapV4DetfTarget.sol:731-745`; `C/bondNft/DETFFundedBondTarget.sol:317-379`). Ordinary first bond joins a separately minted self-leg, then additionally opens personal principal and funds issuance rewards (`D/UniswapV4DetfTarget.sol:576-595,632-694,714-724`). Neither path is an empty donated-capital bootstrap.

Retain the bootstrap report's separate donation-accounting and genesis concepts, subject to the unresolved genesis authority in section 3.4. The following accounting requirements do not approve its permissionless pooled-budget caller policy:

- `donateMigrationCapital(tokens,amounts,nativeAmount,minLpOut,deadline)` is the proposed payable inbound donation operation. `bootstrapMigrationReserve(legs,anchorIndex,minLpOut,deadline)` is a separate proposed operation spending pooled budgets (`bootstrap.md:47-56`); its caller authority is not settled. Each genesis leg identifies an accepted representation, booked amount, and minimum converted-share output; require exactly one representation per external hook leg. Although no direct price or self-mint argument is supplied, the selected anchor and amounts determine self mint under the opening formula. Before live, funding requires zero LP minimum and returns zero LP; after live, the donation operation spends only the current batch's measured budget, retains refunds, and enforces its actual minimum. Require `msg.value == nativeAmount`, reject duplicate ERC20 inputs, and account separately if wrapped native and explicit WETH are both supplied. Permission to contribute assets is not permission to choose genesis using other donors' booked assets.
- Book exact transaction-local ERC20 receipts and exact ETH-to-configured-WETH receipt. Native ETH is an adapter input, not a zero-address hook currency: the hook rejects zero currencies (`W/UniswapV4StandardExchangeWeightedBufferHookInitTarget.sol:81-92`). WETH identity belongs in Migration args/salt, not shared ordinary arguments.
- A funding call may book only one leg and mint nothing. Genesis consumes explicitly selected booked donation budgets for every external leg, plus the generated self-leg. Earlier successful donations survive a later failed bootstrap. No beneficiary, caller-supplied credit, pretransfer credit, or new funding-finalization flag.
- Size self supply from actual consumed anchor capital using the existing opening/creation rule (`D/UniswapV4DetfCommon.sol:265-269`). Match other leg requirements using `D/UniswapV4DetfTarget.sol:852-858`. For raw canonical-pair inputs use consumed payment, not post-deposit liquidation value (`:610-629`). For shares/other supported inputs preserve pre-conversion pair equivalence (`D/UniswapV4DetfCommon.sol:170-179`), verify the predicted consumed quantity against the actual receipt, and revert on mismatch.
- Use operation-local receipt validation (`contracts/utils/ExchangeInAmount.sol:16-38,48-75`). Do not inherit `_firstBondShares`' refund-to-`msg.sender` at `D/UniswapV4DetfTarget.sol:676-694`: these are pooled protocol donations, not that caller's refund.
- Full-book genesis is enforced at `W/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:142-147`. Even direct SE shares undergo partial genesis redemption (`W/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol:201-214`). Opening PoolManager doors (`W/UniswapV4StandardExchangeWeightedBufferHookInitTarget.sol:53-64`) does not supply underlying liquidity. The real V3 fixture separately seeds pools and activates SE positions (`D/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol:44-63`).
- Mint only self-leg `G`; join with caller minimum/deadline and fixed bond-child LP recipient. The ordinary helper hardcodes zero minimum and a short deadline (`D/UniswapV4DetfCommon.sol:451-462`), so reuse must preserve the new call's limits. Require successful live hook and net child LP before setting parent live and exact bootstrap timestamp.

For a clean empty genesis, acceptance is:

```text
new DETF supply = G = separately recorded bootstrap self mint
personal bond principal = receipt supply = totalGons = 0
feeWeight = creatorWeight = accountedBacking = 0
reserved IDs = 0, 1, 2; no personal NFT
hook LP supply = locked minimum LP + fee LP + net child LP
protocol LP = parent LP + child LP, not external fee/seed LP
```

These are required observations, not run results. Hook allocation/refunds are explicit at `W/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol:500-519`; protocol LP counts only parent/child holdings at `D/UniswapV4DetfCommon.sol:95-104`; receipt initialization sets index but creates no gons/weights (`C/claimToken/DETFFundedStakingRepo.sol:52-64`).

Keep donation budgets, legacy custody/undonated recoveries, transient new principal, unsolicited balances, and staking backing separate. Per asset, receipts plus conversion outputs minus conversion inputs and accepted reserve inputs must equal remaining donation inventory. Use events for historical reconciliation rather than duplicate mutable reserve valuations. Budgeted residual handling is mandatory on Migration, including after activation: ordinary sweep reads whole balances (`D/UniswapV4DetfCommon.sol:483-544`), and parent exposes direct/self-call sweep routes (`D/UniswapV4DetfMaintenanceTarget.sol:45-62`). A facade-only replacement leaves internal sweep calls unsafe.

Preserve live donation/Permit2 entry routes without inventing pre-live child success. Parent forwarding currently enters the locked bond child without holding the parent lock; the child then calls the locked parent join (`D/UniswapV4DetfTarget.sol:731-745`; `C/bondNft/DETFFundedBondTarget.sol:251-275,354-367`). A blanket parent lock around forwarding would deadlock that authorized callback. New parent-resident budget operations take their own parent lock and must not route through this child-first cycle. Locks guard each proxy's storage, not the entire graph (`K/access/reentrancy/ReentrancyLockModifiers.sol:21-29`); neither SY nor a caller-selected address joins the locked-parent synchronization exemption.

### 3.2 Empty baseline and parent-before-child settlement

Observed: expansion calculates from reserve/supply/time, then mints and calls staking funding without checking aggregate reward weight (`D/UniswapV4DetfCommon.sol:314-325,349-385`). Staking rejects a nonzero reward with zero aggregate weight (`C/core/DETFFundedStakingMath.sol:79-94`). Bootstrap self supply therefore cannot be treated as participation.

Required Migration-only policy:

1. Read real `stakingState`: empty means `totalGons + feeWeight + creatorWeight == 0`, not receipt supply alone (`C/claimToken/StakedDETFTarget.sol:51-56`).
2. All pending expansion projections return zero while empty, including the index preview (`D/UniswapV4DetfQueryTarget.sol:33-41`).
3. For live empty state, settlement advances the baseline to **this transaction's timestamp**, before the completed-epoch early return, and mints/distributes nothing. Do not bank empty-period dust or fractional epochs for the first entrant.
4. Parent issuance settles old participation under its lock **before** minting new principal. Then mint exactly `P`, approve exactly `P`, call the genuine parent-only migration child creation, and clear approval. Never replay ordinary bonus/self-leg/seigniorage issuance for a migration award.
5. Child synchronization while parent is locked returns zero only for the wired bond/receipt (`D/UniswapV4DetfMaintenanceTarget.sol:16-27`). It cannot settle earlier participants on the parent's behalf. Keep child-origin synchronization before local locks (`C/bondNft/DETFFundedBondTarget.sol:46-48,94-95`; `C/claimToken/StakedDETFTarget.sol:34-38,241-246`).

Ordinary defaults retain existing epoch math. Every installed Migration facet embedding common preview/settlement code must use the same policy, not just a new retained facade. Parent direct stake/unstake also settles (`D/UniswapV4DetfTarget.sol:344-374`); these paths must retain valid mature-principal exits.

### 3.3 Stage 1 closure is route-specific

Gate inbound ordinary external-asset-to-DETF, external-asset-to-sDETF, and bond/reserve-LP purchases before price-based primary/swap selection (`D/UniswapV4DetfTarget.sol:200-230,261-279,527-554`). Merely closing primary mint leaves swap fallback reachable. SY's external-input acquisition calls parent exchange, while direct DETF/sDETF inputs use separate branches (`C/sy/DETFSYTarget.sol:196-217`). Audit both.

Do not blanket-disable mature bond principal or receipt exits to compensate for missing payout accounting. Preserve existing route-specific registry checks rather than adding a universal pause: parent mint/bond and child donation check inbound policy (`D/UniswapV4DetfTarget.sol:269-271,535-552`; `C/bondNft/DETFFundedBondTarget.sol:371-379`), whereas direct funded receipt exits pay held DETF (`C/claimToken/StakedDETFTarget.sol:194-218`).

### 3.4 Pooled genesis authority: actual split, not an assumed policy

**Disposition: needs-fix before implementing the proposed pooled genesis surface.** `bootstrap.md:50,60-66` would let any caller choose an anchor and amounts from pooled donations, execute the first join, set liveness/time, and prevent another bootstrap. That is materially more discretion than merely contributing assets. This corrects this handoff's earlier statement that both proposed operations could be accepted as permissionless donations.

**Source-backed premature-execution analysis:**

1. Ordinary first-bond selection is backed by this caller's payment: `_seatBond` calls `_pullToken`, which pulls from `msg.sender`; full-book completion pulls other required pair amounts from that caller too (`D/UniswapV4DetfTarget.sol:597-616,649-673`; `D/UniswapV4DetfCommon.sol:388-396`). This is not precedent for choosing how much of another donor's pooled inventory to consume.
2. The genesis self mint is `G = floor(nativeToWad(anchor, consumedAnchor) * 1e9 / openingAnchor)`, using creation fallback (`D/UniswapV4DetfCommon.sol:265-269`). Different valid consumed amounts can produce different `G` even with the same anchor; changing anchor adds another degree of choice. Selecting amounts is therefore an indirect self-supply choice, despite the absence of a `mintAmount` argument.
3. Under the proposed ABI, an arbitrary caller can execute as soon as a valid full-book subset exists, with its own minimum/deadline. It need not wait for all intended recovery funding, select all booked inventory, or supply this call's capital. Missing legs/dust/unready SEs may still prevent a join; once those checks pass, none proves operator intent. A caller could also donate a missing leg to enable its selected subset. This is an inference from the proposed permissions and budget checks, not an executed vulnerability in current code.
4. The first successful call fixes the historical bootstrap self mint and initial epoch timestamp. Proposed repeat-bootstrap rejection and later donation-without-self-mint are explicit at `bootstrap.md:52,65-66`; current `_setReserveLive` rejects a second transition (`D/UniswapV4DetfRepo.sol:174-180`). Later ordinary issuance/expansion can change total supply, so this is not a claim that total supply is forever constant. It is a claim that corrective donations alone do not redo the chosen genesis mint.
5. Fixed LP custody prevents diversion to the caller, but not premature selection of reserve composition/self supply. Hook owner-only liquidity also does not authorize the outer caller: the hook owner is the parent proxy, and the parent is the caller at the join (`D/UniswapV4DetfProcessArgsLib.sol:53-64`; `W/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:142-147`). All otherwise-valid outer callers reach that same identity.
6. Owner-controlled snapshot capture can withhold dependent configuration/issuance, but cannot by itself undo genesis. Capture is once after funding and not an arbitrary price setter (Plan:169-177). A later donation or an operator script check is not a reset of `G`. No reset, replacement genesis mint, or cancellation authority is approved here.

The normative text establishes two facts but does not explicitly reconcile this newly proposed split operation:

| Reading | Read authority | Consequence |
| --- | --- | --- |
| Selecting the initial use of pooled recovery capital/self supply is migration administration. | PRD MIG-R41:138-152 says all migration administration follows current owner; MIG-R20/R31:308-318 describes the owner's recovery funding and operator sequencing. | Selection must be authorized by current Crane owner, independently of permissionless asset contributions. |
| Genesis is simply part of the required donation route, with no added owner restriction. | PRD MIG-R02:130-132 forbids expanding owner-only capabilities beyond specified roles; MIG-R21:310 requires all-leg donation. Plan MIG-P12/P13:28-29 specifies owner configuration/activation/harvest and scripted funding, while the all-leg donation/bootstrap row at Plan:318 gives amounts/minimums but no explicit caller. | A reader could preserve permissionless donation execution, but that does not establish that arbitrary spending of pooled prior donations or arbitrary early genesis was intended. |

**Conclusion:** the proposed permissionless pooled selection is not established as compatible with owner-administration law. Conversely, this reviewer must not silently install a new owner-only surface solely by reclassifying it. The genuine unresolved question is: **who is authorized to select and finalize the one-time genesis amounts/anchor from pooled donation inventory before intended funding is complete?** It is not a question about whether ordinary donations remain supported, and it is separate from the already prohibited funding-certification flags.

**Proposed clarification for root/owner disposition, not an accepted decision:** "The one-time selection and consumption of pooled donation budgets for reserve genesis, including the anchor determining self supply, requires the current Crane Ownable owner; contributions and subsequent ordinary donations remain permissionless." This is one concrete resolution direction, not authority to implement it. Until that split is resolved, do not freeze either permissionless pooled bootstrap or a new owner-only alternative. Do not add a commitment setter, funding target, finalization flag, or mutable mint-rate policy to avoid the question.

Call this prerequisite **BOOTSTRAP-AUTH**. It gates the new pooled-genesis API/implementation and E4, not section 5's preparation work, task-5 accounting analysis, inbound receipt accounting, or ordinary regression. Its eventual adversarial witness must start with partially accumulated real donations and let a non-owner attempt valid smaller/alternate-anchor full-book genesis before the operator's intended transaction; a mere missing-leg revert is not coverage. Under the proposed owner-only clarification, acceptance would be exact unauthorized revert with donation budgets, supply, LP, liveness, and timestamp unchanged, followed by successful owner genesis. That expected authority is conditional on disposition, not silently made product law by this test proposal.

## 4. Task-5 blocker: cliff gating alone is insufficient

### 4.1 Accepted child contract

The existing exact pull/stake/gons pipeline is reusable without changing its funding test: `C/bondNft/DETFFundedBondTarget.sol:94-125`; fresh position records use actual timestamp at `C/bondNft/DETFFundedBondRepo.sol:46-56`.

Future Migration child adds parent-only `createMigrationPosition(uint256 principal,address recipient)` and a separately namespaced per-ID cliff marker. It supplies `90 days` internally, creates a fresh ID, and cannot accept an old timestamp, duration, source adapter, or caller credit policy. Ordinary `createFundedPosition` and Stage-2 ordinary purchases remain unmarked and linear.

Use one calculation policy for preview and execution; the current two direct linear calls are `C/bondNft/DETFFundedBondTarget.sol:134-139,163-187`. Marked principal is zero before unlock and full remaining principal at/after unlock; reward value remains `floor(positionGons/k) - remainingPrincipal`, with deficit rejection. Rewards-only and combined claims reject atomically before activation; principal-only remains possible at the cliff. Preserve exact paid-gons debit and reward-only NFT survival (`:179-198`; `C/core/DETFFundedStakingMath.sol:97-116`).

Transfers synchronize and convey the position; their code does not pay a claim despite the comment (`C/bondNft/DETFFundedBondTarget.sol:210-227`). Safe receiver callbacks occur before ownership mutation (`K/tokens/ERC721/ERC721Repo.sol:153-169`). Test this actual order and cross-proxy reentry, not an assumed post-transfer callback.

Migration metadata must render cliff principal and locked reward availability; replacing preview math alone leaves linear progress and claimable-reward language (`C/bondNft/DETFFundedBondMetadata.sol:30-35,63-96,136-150`).

### 4.2 Fee/creator custody is necessary, but not sufficient

Observed distribution captures reserved NFT owners, rebases ordinary stake, then issues role receipts (`C/claimToken/StakedDETFTarget.sol:170-183`; `C/claimToken/DETFFundedStakingRepo.sol:185-201`). Adopt the children report's Stage-1 protocol-held role receipts with beneficiary-keyed pending **gons**, captured at allocation time. This preserves subsequent rebase participation and distinguishes old recipients from later role owners.

After activation, release `floor(pendingGons/k)` by transferring already issued receipts; debit `paid*k`, retain sub-native residue, and never mint/fund twice. Merge identical beneficiaries. Activation must not scan recipients or retarget old allocations. Existing native transfer arithmetic is `C/claimToken/DETFFundedStakingRepo.sol:148-156`. This is a required future accounting construction, not an installed selector.

### 4.3 Independently verified payout counterexample

The following is a source-derived counterexample, not an executed exploit:

1. A migration bond reaches its cliff during prolonged Stage 1.
2. Valid principal-only claim pays sDETF to its recipient (`C/bondNft/DETFFundedBondTarget.sol:143-147,177-184`).
3. Later actual funding lowers `k` and increases that recipient's native balance without changing its gons (`C/claimToken/DETFFundedStakingRepo.sol:82-83,197-201`).
4. Current direct receipt withdrawal can redeem the whole increased balance; its ledger contains no principal/reward partition (`:24-36,109-123`; `C/claimToken/StakedDETFTarget.sol:205-218`).
5. Staking SY also converts represented gons into the grown native amount and can pay sDETF directly, bypassing parent exchange (`C/sy/DETFSYTarget.sol:94-121,220-229`). Its storage tracks backing/dust, not principal/reward rights (`C/sy/DETFSYRepo.sol:15-23`).

The ordinary suite intentionally checks wallet growth and full withdrawal (`TC/claimToken/RebasingClaimToken_Accounting.t.sol:53-70,73-109`). Those expectations must not be edited away globally.

**Required engineering gate T5-EGRESS:** before freezing Migration receipt/SY storage, ABI, and final package bindings, specify and prove one principal/reward partition across direct deposits, bond principal delivery, native transfers/allowances, parent intermediate custody, SY wrapping/transfers/redemptions, deferred role receipts, and fractional retirement. It must provide exact principal exit while retaining every locked reward right, with conservation under splitting/merging and repeated rounding. Full-account ordinary dust retirement must not erase retained rewards. Include `burnInternalBalance` and every configured SY output.

This is a new-instance accounting prerequisite, **not** legacy E2, not an owner-policy question, and not a demand for completed surrender/harvesting/lifecycle code before beginning work. Neither a blanket pause nor unrestricted post-cliff receipts satisfies Plan:263-291,409-418. The child report explicitly leaves this partition unfrozen (`children.md:83-96`); this reviewer does not replace it with an unsupported tuple or pretend the role-custody proposal solves it.

### 4.4 Exact children-section-2.4 reconciliation and proof placement

**Adopt the requirement, not an exemption:** growth earned on already claimed principal during prolonged Stage 1 remains activation-gated new-instance rewards. Paying mature principal must continue to work. Keeping old bond rewards in the NFT and fee/creator receipts in protocol custody does not account for new growth on the receipt subsequently held by the principal claimant. No owner-policy answer is needed to require this: Plan MIG-P08:24, principal/reward arithmetic at :275-291, and task 5 at :409-418 already require both obligations; PRD MIG-R23:320-324 preserves mature principal and ongoing funded participation.

A minimal accounting proof witness, without choosing storage/ABI, is:

```text
Principal-only claim delivers P native sDETF at funded index kc.
Its attributable receipt position is G = P * kc gons.
A later funded distribution produces index k < kc.
Current native value = floor(G / k).
Still-accessible principal = P; gated growth = floor(G / k) - P.
If P is then fully unstaked during Stage 1:
  principal payout = P;
  attributed gons paid = P * k;
  residual reward rights = G - P * k, retained for their owner.
Activation later releases those retained rights once, at the then-current index.
```

This is the local conservation obligation for an isolated position, not a frozen per-wallet struct or a proposal to reset reward participation. Its arithmetic follows existing bond paid-gons transfer and receipt conversion (`C/bondNft/DETFFundedBondTarget.sol:175-184`; `C/claimToken/DETFFundedStakingRepo.sol:82-83,109-123,148-156`). The proof must extend it to mixed holdings, partial exits, transfers, approvals, wrapper shares, and exact rounding. Principal withdrawal cannot erase the residual, relabel it as new principal, or make it spendable through another account/router. The original bond's separate remaining reward gons must not be counted again. If principal has actually left staking, do not invent further participation on withdrawn principal; retained funded reward rights keep their actual accounting treatment.

**Where proof is required:** the next functional task-5 increment must establish one complete receipt/SY transition contract before freezing those child layouts and final immutable package bindings, and must validate it before E5 acceptance. It can be developed against the genuine new-instance components without waiting for legacy ancestry or full harvesting. The proof must show a successful mature-principal exit and a successful later activated reward release, not merely a set of rejected exits. Staking-SY principal redemption must preserve the associated locked reward right even when shares are burned or internal balances used (`C/sy/DETFSYTarget.sol:94-121`); generic whole-account fraction retirement is not permission to destroy it (`C/claimToken/DETFFundedStakingRepo.sol:109-139`).

**Next coherent implementable unit remains section 5:** consume the shared initializer, funded-creation/claim dispatch, and distribution dispatch in existing production paths, with real ordinary-proxy regression. That bounded increment needs neither T5-EGRESS nor BOOTSTRAP-AUTH to be resolved because it changes no lifecycle, funding authority, or payout behavior. It is useful preparation, not an E5 deliverable. Actual Migration cliff/role components may be developed incrementally, but cannot be presented as complete safe children or installed as a final funded composition while section 2.4 is missing. No ordinary-child placeholder, fake issuer, blanket Stage-1 pause, or omission of E5 is authorized.

## 5. Exact next implementation increment

### 5.1 Allowed edit paths

Only these five repository-relative paths, under the worktree specified in section 1, are allowed for the **next source increment**:

| Path | Change |
| --- | --- |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol` | New internal library containing compatible initialization and route-table storage extracted from the current package. |
| `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol` | Delegate the existing initializer to that library with explicit current dependencies/declarations; no external ABI, salt, cut, or postDeploy change. |
| `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol` | Extract the existing creation body into a real internal helper; introduce one implemented virtual claim-calculation dispatch shared by preview/execution, and make the existing implemented `_claim` overrideable for future Migration permission checks. |
| `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol` | Extract the actual `_distribute` invocation into an implemented internal virtual distribution policy returning the existing allocation/growth; preserve owner lookup, exact backing pull, top-up order, events, and ordinary destinations. |
| `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol` | Extend real registry-proxy initialization assertions only where existing coverage misses the extracted state/wiring contract. |

No other source/test/script/config path is implicitly included. In particular, no shared Crane writes, new Migration package shell, ordinary-child placeholder package, fabricated activation/credit setter, source-adapter tuple, snapshot integration, owner policy change, or global staking-math rewrite.

The creation helper retains validation and funding and is immediately used by ordinary `createFundedPosition`; the calculation dispatch defaults to the existing real linear calculation; the distribution dispatch defaults to the existing real distribution. These are consumed implementations, not empty/no-op stubs. Do not add an unused no-op permission hook: the future Migration `_claim` override can enforce policy then invoke the implemented common path.

The claim dispatch must retain the token ID needed to select the future marker: use an internal view virtual `_calculateClaim(uint256 tokenId_,uint256 gonsPerUnit_)` returning the existing `StakingMath.BondClaim`, with the default reading the current position and calling the current linear math at `block.timestamp`. Both public preview and internal execution call it after their existing existence/reserved-ID checks. The creation helper keeps `(principal_,duration_,recipient_)`; the external ordinary entry retains `onlyDetf synchronized nonReentrant`. The distribution policy receives the real staking storage, amount, and resolved fee/creator recipients and returns the existing allocation and growth. No new external selector or storage field is needed for these seams.

### 5.2 Ordered code/test units and acceptance

| Order | Unit | Acceptance and independent oracle |
| --- | --- | --- |
| 1 | Characterize initialization through current real proxies, then extract the common initializer. | The ordinary package still canonically rejects obsolete payloads; prediction equals deployment; metadata/9 decimals, fee/type/contents declarations, thresholds, opening fallback, all route tables, inert state, and complete immutable child wiring match arguments. Redeploy same args preserves existing state; no init/postDeploy/cut selector appears on completed proxy. Existing deployment controls: `T/UniswapV4Detf_Deploy.t.sol:13-38`; actual fixture: `D/TestBase_UniswapV4Detf.sol:186-245,289-321`. |
| 2 | Extract funded creation and claim dispatch without changing ordinary economics. | Real ordinary parent bond purchase still reaches exact-funded child creation, actual timestamp/duration, exact position gons, linear halfway principal, separately claimable funded rewards, and isolated retirement. All three ERC721 transfer selectors remain on the guarded product facet. Sources: `C/bondNft/DETFFundedBondTarget.sol:94-198`; live-proxy controls: `T/UniswapV4Detf_BondNftPackaging.t.sol:13-55`, `TC/bondNft/DETFNFTVault_Surface.t.sol:38-88`, `TC/claimToken/FundedStakingSequence.t.sol:132-149`. |
| 3 | Extract funded distribution dispatch without changing destinations or order. | Current fee/creator owners still receive immediate ordinary receipts; existing holders receive index growth; unsolicited backing remains uncredited; full withdrawal retires only that account's fraction. Preserve accounting and fuzz sequence controls at `TC/claimToken/RebasingClaimToken_Accounting.t.sol:53-109` and `TC/claimToken/FundedStakingSequence.t.sol:55-129`. No Migration pending-rights storage is added in this unit. |
| 4 | Validate the increment and stop. | Artifact-first build succeeds; focused and ordinary V4/common suites execute with actual PASS counts and no new failure. Runtime artifacts correspond to edited source; old occupied CREATE3 identities are not treated as upgraded code. Record any independently established pre-existing failure. No task-3/task-5 completion claim. |

These units are intentionally default-preserving. Existing green controls need not be falsely described as failing-before Migration tests. Any new assertion must fail on a credible lost initialization field/guard/wiring regression, not on a renamed helper or source string. Do not weaken ordinary expectations to obtain green output.

### 5.3 Task-3/task-5 boundary and subsequent order

The selected increment ends after section 5.2. The following is the fixed continuation contract, **not an expanded current edit allowlist**:

1. **Task 5 next establishes T5-EGRESS**, then implements the Migration child policy using the extracted seams, including exact-funded cliff creation, gated claims, role custody, receipt/SY partition, and policy-aware metadata. This does not wait for E2, real legacy surrender, or completed harvesting. Its proof must identify the actual production caller used to exercise fresh cliff creation; impersonating the parent or installing an arbitrary-credit test issuer does not establish integration.
2. **Task 3 composes ownership and donation bootstrap** with the agreed real child artifacts, permanent lifecycle read, all required policy-bearing parent facets, and empty-baseline/residual policy. Resolve BOOTSTRAP-AUTH before freezing or implementing pooled genesis. It can then establish donated reserve quoteability without operational entitlements or actual-recovery E3. Do not label ordinary child bindings final and promise to replace them later on an immutable instance.
3. **Tasks 4/6/7 integrate genuine configuration/issuance/surrender and activation** only when their specific pricing/source contracts exist. The delayed-first-issuance and second-participant ordering tests attach to those genuine routes. Their absence does not block finishing the independent preparation increment or testing empty baseline synchronization.

Task 3 owns parent owner/args/salt, registry composition, donation budgets/self supply, baseline, parent settlement before principal, parent new-money gates, and residual custody. Task 5 owns bond terms/flags/claim math, all direct receipt/SY reward exits, pending role rights, child metadata, and local locks. Task 7 owns the final complete removable-selector census and irreversible transition. Parent settlement policy and child aggregate-weight read are one shared contract; do not introduce separate clocks or duplicate activation flags.

Minimum subsequent file boundary is concrete, not an all-contract rewrite:

- Parent: `M/interfaces/IUniswapV4DetfMigration.sol`, `M/interfaces/IUniswapV4DetfMigrationDFPkg.sol`, `M/UniswapV4DetfMigrationRepo.sol`, `M/UniswapV4DetfMigrationPolicy.sol`, `M/UniswapV4DetfMigrationTarget.sol`, `M/UniswapV4DetfMigrationFacet.sol`, `M/UniswapV4DetfMigrationDFPkg.sol`, `M/UniswapV4DetfMigration_Component_FactoryService.sol`, `M/UniswapV4DetfMigration_Pkg_FactoryService.sol`.
- Policy-bearing parent facets: `M/UniswapV4DetfMigrationExchangeFacet.sol`, `M/UniswapV4DetfMigrationBondFacet.sol`, `M/UniswapV4DetfMigrationMaintenanceFacet.sol`, `M/UniswapV4DetfMigrationQueryFacet.sol`; narrow seams only in `D/UniswapV4DetfCommon.sol` and `D/UniswapV4DetfTarget.sol`. The required behavior is sections 3.2-3.3, not inheritance of ordinary compiled facet behavior.
- Bond: `M/bondNft/IUniswapV4DetfMigrationBondNFTVault.sol`, `M/bondNft/UniswapV4DetfMigrationBondNFTRepo.sol`, `M/bondNft/UniswapV4DetfMigrationBondNFTVaultTarget.sol`, `M/bondNft/UniswapV4DetfMigrationBondNFTVaultFacet.sol`, `M/bondNft/UniswapV4DetfMigrationBondNFTVaultDFPkg.sol`, `M/bondNft/UniswapV4DetfMigrationBondMetadataTarget.sol`, `M/bondNft/UniswapV4DetfMigrationBondMetadataFacet.sol`; narrow declaration/rendering seams in `C/bondNft/DETFNFTVaultDFPkg.sol` and `C/bondNft/DETFFundedBondMetadata.sol`.
- Receipt: `M/claimToken/IUniswapV4DetfMigrationStakedDETF.sol`, `M/claimToken/UniswapV4DetfMigrationStakedDETFRepo.sol`, `M/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol`, `M/claimToken/UniswapV4DetfMigrationStakedDETFFacet.sol`; declaration extensibility in `C/claimToken/RebasingClaimTokenDFPkg.sol`. No receipt split ABI is approved before T5-EGRESS.
- SY: `M/sy/UniswapV4DetfMigrationSYTarget.sol`, `M/sy/UniswapV4DetfMigrationSYFacet.sol`; narrow policy/declaration changes in `C/sy/DETFSYTarget.sol` and `C/sy/DETFSYDFPkg.sol`, only after T5-EGRESS supplies the exact split contract.
- Genuine fixtures/specs: `M/TestBase_UniswapV4DetfMigration.sol`, `TM/UniswapV4DetfMigrationDeploy.t.sol`, `TM/UniswapV4DetfMigrationFunding.t.sol`, `TM/UniswapV4DetfMigrationRewardBaseline.t.sol`, `TM/UniswapV4DetfMigrationBonds.t.sol`, `TM/UniswapV4DetfMigrationRewardGates.t.sol`, `TM/UniswapV4DetfMigrationSurface.t.sol`, and later `TM/UniswapV4DetfMigrationActivation.t.sol`.

Allocation/legacy/snapshot implementations remain outside this increment; Plan:130-146,399-448 owns their later scope. Root must explicitly advance the bounded contract before those paths are edited.

## 6. Real-proxy commands and resource contract

**Specified for the next implementation increment; not run in this preflight.** Use the phase-03 worktree and current Solar-capable Foundry binary. Before first compilation, seed its own `out/` and `cache_forge/` from a verified warm checkout, coordinating against concurrent writers. Those paths are configured at `foundry.toml:8-13`. Keep shared Crane read-only; do not recreate its link, install dependencies, delete caches, or change profiles/source/test paths.

After all four production source edits, the focused artifact-first command is:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol \
  contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol \
  contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_BondNftPackaging.t.sol \
  --test-root test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault_Surface.t.sol \
  --test-root test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_Accounting.t.sol \
  --test-root test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol \
  -- -vv
```

The helper builds concrete dependents and runtime artifacts with Solar before tests; failed build prevents testing (`docs/testing/ARTIFACT_BUILDS.md:5-24,30-43`). Broaden once for the shared initialization/bond/staking changes:

```sh
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03
python3 scripts/forge-artifacts.py test \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol \
  contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol \
  contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol \
  --test-root test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf \
  --test-root test/foundry/spec/vaults/detf/common \
  -- -vv
```

Require compiler success, command exit 0, actual executed counts, and named behavioral witnesses. Exit 0 with no matching tests is not a pass: Pricing:25-53 documents that exact failure and its ABI-signature correction. Do not copy its old selector filter. Fresh fixtures must load current bytecode; do not reuse occupied deterministic addresses as an upgrade mechanism (`docs/testing/ARTIFACT_BUILDS.md:66-68`).

No RPC/node/broadcast is needed for this hermetic increment. Run finite builds/tests with completion monitoring and sufficient compilation time, not polling or short kill deadlines (`CLAUDE.md:49-63`). Keep runtime artifacts/worktree caches; clean only task-owned temporary resources. Record commands, compiler version, exits, counts, artifact binding, and baseline failures in the later phase evidence location authorized by root, not by overwriting upstream preflight reports.

For the later genuine Migration fixtures, the command contract is artifact-first build of all actually edited production files followed by:

```sh
forge test --use solar \
  --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration/**' -vv
```

That later command is not currently a check: the fixture/files must first exist and actual tests must execute. Full hermetic and pinned legacy fork gates remain Plan:596-620; neither is a circular prerequisite for section 5's preparation increment.

## 7. Remaining acceptance gates and AdversarialVerify

### 7.1 Exact gates preserved

| Gate | Remaining requirement; no closure from this report |
| --- | --- |
| E1 | Actual source/category caller and custody closure remains incomplete. Phase01:128-182 records TokenStaking atomic claimant handoff and owner-restricted LP harvest limitations. This reviewer did not replay those probes or certify current deployed code. |
| E2 | Authenticated ordinary legacy-transfer ancestry remains unproved; balances/static allowances cannot supply the missing ordered history (Phase01:98-126). No trusted update, original-payer-only restriction, wrapper-only policy, pretransfer, two-step claim substitute, or affected attribution tuple is authorized. |
| Actual recovery E3 | Pricing:84-108,250-256 confirms only bounded direct-pair/V3-input/raw-DETF-output evidence and leaves actual configured recovery routes, bindings, unsupported recipes, and gas feasibility open. Pricing F1/F2 are reported unresolved there; no unaccepted correction or integration is assumed. |
| E4 | BOOTSTRAP-AUTH must resolve the pooled-genesis authority split; then real Migration empty-donation genesis, measured capital/self supply/residual reconciliation, closed ordinary new money, underlying redemption readiness, and quoteability must execute. Ordinary live donations or first personal bonds do not substitute. |
| E5 | T5-EGRESS plus all direct bond/receipt/SY/role/callback payout paths must execute, including retained growth on already claimed principal, prolonged Stage 1, mature principal access, and later exact-once release. This is an engineering mechanism prerequisite, not an owner-policy question or permission to omit E5. Role custody alone is not closure. |
| Task 3 / task 5 | Both remain incomplete. Section 5 prepares reusable production seams; it neither deploys Migration nor proves new-family money paths. |

### 7.2 Future failing-before witnesses

These are mandatory tests for the later functional units, not claims of current passes:

| Witness | Exact acceptance |
| --- | --- |
| Owner/initialization | Zero owner rejects atomically. Two owner/buffer/WETH variants predict isolated proxies/hooks. Pending owner cannot administer, immediate acceptance transfers authority, confirmation respects its actual buffer, former owner loses authority. Contract-owner calls work. Init/factory/postDeploy/cut attempts cannot mutate completed proxy. Sources: section 2. |
| Empty donation / supply | Partial funding changes only booked receipt inventory. Missing leg/short receipt/refund mismatch/failed minimum reverts the selected attempt, including `G`; earlier donations survive. Clean success has exactly section 3.1's supply/LP/role equations and no caller entitlement. Include nonzero LP fee, unrelated custody, unsolicited assets, native/WETH equivalence, and repeat bootstrap. Sources: section 3.1. |
| Premature pooled genesis | Construct a valid full-book subset before intended funding is complete; a non-owner tries selected smaller amounts and another anchor using already booked donations. Test the authority resolved by BOOTSTRAP-AUTH, not a conveniently invalid token/amount. The proposed owner's expected rejection and subsequent successful genesis are conditional on that authority disposition. Source/model reasoning: section 3.4. |
| Delayed first participation | Immediate, 8-hour, 25-hour, and 7-day empty intervals produce no funded reward/weight error. Issue at bootstrap + 9 hours: baseline equals issue time; issue + 8 hours - 1 has no epoch, issue + 8 hours uses canonical funded math. Do not convert empty history into dust. Sources: section 3.2. |
| Existing A before new B | At a due boundary, settle on pre-B supply/weights; then B receives exactly `P_B*k_afterSettlement` gons and zero precreation rewards. Include standing-weight-only participation. Exercise genuine parent independent issuance first and verified surrender later, never a fake issuer. Sources: section 3.2 and Plan:275-291. |
| Cliff / role / egress | Exact principal at unlock - 1/unlock/unlock + 1; independent fresh clocks; atomic Stage-1 reward/combined rejection; principal-only success; correct old beneficiary after role transfer; repeated release and dust conservation; mature principal followed by growth cannot escape through direct/exact-output/parent/SY/approved-transfer routes. Sources: section 4. |
| Activation / callbacks | Complete target/interface-derived live loupe census; actual owner-facet Remove cuts; failure rolls back both routing and lifecycle; successful cut cannot restore through owner change, same-args deployment, package/factory init, post-deploy hooks, child callbacks, or registry cycling. No intermediate callback pays rewards or opens ordinary issuance. Sources: section 2.4 and Plan:334-344,431-439. |

**AdversarialVerify: ready-for-bounded-implementation for section 5 only.** Independent source reconciliation rejected three unsafe inferences: that Crane acceptance waits for its buffer, that locked child synchronization settles parent issuance, and that cliff/role gates close receipt/SY payouts. It also rejected whole-balance sweep reuse for integrated custody and ordinary children as final Migration composition. The bounded preparation increment has real consumers and real ordinary-proxy oracles; it does not require unimplemented future behavior to pass.

**AdversarialVerify for a funded Migration package/E4/E5: needs-fix / unverified**, specifically T5-EGRESS, BOOTSTRAP-AUTH, and the functional witnesses above. The former is a required new-instance accounting mechanism; the latter is an actual authority split not settled explicitly by the admitted plan/source. No executable security acceptance is claimed. The named obligations cover retained post-claim growth with mature-principal access, premature pooled genesis, empty inventory/donation theft, exact receipt/refund isolation, access/routing, callback mutation, fee/creator attribution, and ordinary regression; a green declaration-only or revert-only suite cannot discharge them.

## 8. DoneClaim and cleanup

- **Deliverable:** this `implementation-handoff.md` only, written with `apply_patch`.
- **Inspected boundaries:** parent package/arguments/initializer/routes/expansion/donation/wiring; registry and Crane owner/factory/cut/proxy routing; funded bond creation/claim/transfer/storage/metadata; receipt funding/gons/withdrawal/distribution; SY backing and exits; weighted genesis/LP/refunds/doors; real deployment and ordinary regression controls cited above.
- **LSP:** parent package document-symbol request timed out. A later bond-target document-symbol request and expansion reference query succeeded. Source reads verified the reported implementations and callers. No fresh clean diagnostics, build, test, fork, or runtime observation is claimed.
- **Decision settled:** execute the five-path default-preserving preparation increment first, rather than create a purportedly deployable Migration package with unresolved immutable child payout behavior. T5-EGRESS must preserve growth on already claimed principal without blocking principal exit; it is an engineering prerequisite, not an owner-policy question or a demand for completed legacy migration. The follow-up withdrew unsupported permissionless pooled-genesis approval and records BOOTSTRAP-AUTH separately; neither caller policy is silently adopted.
- **Limits:** no builds/tests/Git/install/broadcast/delegation, no product edits, no pricing integration, no operational allocations or addresses approved. E1/E2/actual E3 remain open; task 3/task 5/E4/E5 remain incomplete.
- **Cleanup: none created** for task-owned processes, nodes, listeners, temporary directories, worktrees, caches, or executable artifacts. No cleanup command was needed. Shared Crane remained read-only. Tool-managed language-server/transcript infrastructure was not treated as an owned runtime resource or modified.
