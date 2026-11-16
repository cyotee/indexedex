# Independent r3 source evidence

Date: 2026-11-10. All relative source paths resolve under
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03`.
These are inspected expressions and derived implications, not deployed facts.

Aliases:

- `C/`: `contracts/vaults/detf/common/`
- `D/`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- `K/`: `lib/crane/contracts/`
- `P/`: `lib/crane/contracts/protocols/perps/pendle/`
- `R/`: `contracts/registries/vault/`
- `W/`: `contracts/hooks/uniswap/v4/standardExchange/weighted/`
- `FundedPlan`: `contracts/vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md`
- `Plan`: `/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`

## 1. Required scope versus optional consumers

The complete Plan was read. MIG-P06/P07/P08, sections 4.1/5.5, task 5 and
section 8.2 require fresh exactly funded cliff positions, participation from
creation, no Stage-1 reward payout, and successful mature principal access.
Its source constraints explicitly identify receipt delivery as payout.
Task 5 requires receipt/SY, direct child, transfer and callback coverage.
No Plan component/task requires deploying a new Pendle yield factory,
market factory, gauge controller, voting system or router.

`FundedPlan:322-351` requires the real four-argument deposit/five-argument
redeem contract, both wrappers, directions, rate/asset/yield metadata and
reward methods. It expressly specifies that true internal burn consumes
issued SY held by SY, not caller-attributed underlying. The ordinary
fixed-gon share rate/empty reward list is separate from Migration's chosen
principal/separate-reward exception. `contracts/interfaces/IDETFStandardizedYield.sol:13-17`
exposes two distinct wrapper addresses, not a market or yield factory.

The Plan's section 3 category list is unchanged: both liquid DETF
generations, both NFT models, current/earlier receipts, legacy SY,
TokenStaking/claim-vault rights, underlying SE shares and fungible LP.
An optional new market is not a substitute for any of those legacy rows.

## 2. Source expressions independently inspected

| ID | Actual source expression and location | Consequence |
| --- | --- | --- |
| S01 | `C/core/DETFFundedStakingMath.sol:10-12,46-94`: `Q=1e36`, allocation scale `1e54`, `_toGons=mulDiv(amount,k,1)`, amount `gons/k`; rebase divisor `ceilDiv(totalGons,liability+fundedReward)`; allocation uses two floors. | Native units, allocation dust and staking dust cannot be replaced by approximate percentages. |
| S02 | `C/claimToken/DETFFundedStakingRepo.sol:185-201`: increase accounted backing, require actual backing, allocate `amount+allocationDust`, rebase with `staking+stakingDust`, then issue fee/creator gons. `C/core/DETFSeigniorageShareLib.sol:18-33`: nonnegative target-minus-existing top-ups. | Old gons participate before new role gons. Standing weights are not redeemable principal. |
| S03 | `C/claimToken/DETFFundedStakingRepo.sol:109-139`: full withdrawal uses this owner's entire gon balance; `_retireFraction` requires `g<k` and `g<=ownerGons`; liability released goes to staking dust. `C/bondNft/DETFFundedBondTarget.sol:200-208`: position retirement requires fully claimed principal and `positionGons<k`. | Canonical narrowly conditioned retirement exists. It does not authorize deleting an arbitrary pooled, deferred or sub-RT balance. |
| S04 | `C/claimToken/StakedDETFTarget.sol:147-166,200-246`: exact-in/out call the same `_exchange`; hard public pretransfer rejection; exact inbound delta; direct withdrawal burns caller receipts and transfers held DETF; synchronization before local lock. | Exact-out is a direct receipt capability, not an invented parent or SY exact-out selector. |
| S05 | `C/bondNft/DETFFundedBondTarget.sol:94-130,139-208`: parent-only pull, stake, cleared approval, exact gon delta, owner/approved-operator claim; debit position and aggregate before receipt transfer. `C/bondNft/DETFFundedBondRepo.sol:46-70`: actual timestamp and aggregate funding. | Migration specializes the cliff, delivery and gate; it cannot replace exact funding with a declared amount or old surplus. |
| S06 | `C/sy/DETFSYTarget.sol:65-121,196-256`: acquire actual gons/raw DETF, burn `internalBalance ? address(this) : msg.sender`; receipt output is direct; other outputs unstake then pay DETF or approve/call parent; final minimum after routing. | Three output classes and bearer internal shares are real source contracts. Ordinary appreciated redemption cannot be inherited unchanged by Migration. |
| S07 | `C/sy/DETFSYRepo.sol:38-69`: raw always adds DETF; only staking mode automatically adds sDETF; configured directions are added independently. `DETFSYTarget.sol:124-180`: rate, yield, metadata, previews and ordinary empty rewards. | Raw does not gain an unconditional receipt route. New Migration metadata/reward amounts must match its changed accounting. |
| S08 | `D/UniswapV4DetfTarget.sol:200-230,261-324,344-374,410-477`: explicit mint/stake/unstake/burn dispatch, primary/swap selection, exact receipt pull into parent, exact unstake, output-budget routing. | Gate ordinary acquisition before either branch. Preserve parent old inventory and both real output branches. |
| S09 | `D/UniswapV4DetfCommon.sol:314-325,349-385`: elapsed expansion and actual mint/approve/fund/reset. `D/UniswapV4DetfMaintenanceTarget.sol:16-27`: locked callback accepts only wired receipt or bond and returns zero. | Empty aggregate needs the specified baseline adaptation; parent must settle before adding principal. SY/RT do not gain a generic locked-parent exemption. |
| S10 | `K/tokens/ERC20/ERC20Repo.sol:157-166,297-301`: allowance is always checked/decremented, including maximum and owner-as-spender. `K/tokens/ERC2612/ERC2612Target.sol:39-58`: signed permit writes that allowance. | Neither an allowance nor a permit is reward-right assignment or protected-custodian authority. |
| S11 | `P/interfaces/IStandardizedYield.sol:62-172`: native deposit/redeem amounts, self/caller source, reward array aligned with listed token, WAD exchange rate and route/asset metadata. | Native RT, native receipt and gon amounts are distinct. ABI preservation alone is not unit compatibility. |
| S12 | `P/core/RewardManager/RewardManagerAbstract.sol:16-29,35-64`: initial index 1, uint128 stored fields, self excluded, `userShares.mulDown(index-userIndex)`. `P/core/libraries/math/PMath.sol:20,34-38,175-177`: division by `1e18`, checked narrowing. | With q=W, r3's `1+Q-k` is WAD-native-RT per native SY; index fits uint128. Accrued values can still overflow optional narrow consumers. |
| S13 | `P/core/StandardizedYield/SYBaseWithRewards.sol:7,74-95`: yield token must differ from reward token; checkpoint before share mutation. `P/core/YieldContracts/PendleYieldToken.sol:124-153,317-339,443-503`: principal burn/transfer is separate from retained reward accrual/payment. | Old holder's reward backing must not leave with its principal shares. A separate fixed-gon RT avoids a growing native-sDETF debt that the single consumer index cannot represent. |
| S14 | `P/core/StandardizedYield/SYUtils.sol:7-20`; `P/core/YieldContracts/InterestManagerYT.sol:63-79`: raw conversion by WAD and interest proportional to index delta. | Constant W rate supports 1:1 principal and zero rate-interest; it does not prohibit separate rewards. |
| S15 | `P/router/ActionMiscV3.sol:18-23,39-46`; `P/router/base/ActionBase.sol:94-129`: router pulls user SY straight to SY or asks YT to send SY there, then router calls old internal redeem. | Sender, principal operator and reward beneficiary differ; standard bearer burn needs no invented YT-to-router allowance/ticket. |
| S16 | `P/router/ActionAddRemoveLiqV3.sol:307-323`; `P/router/ActionSwapPTV3.sol:43-55`; `P/core/Market/v3/PendleMarketV3.sol:129-145,159-183`: market is actual SY sender; router performs onward redeem. | Correct last-hop handoff is not proof that market mint, pricing, controller admission or swaps work. |
| S17 | `P/core/YieldContracts/PendleYieldToken.sol:373-385,473-476`: first expiry calls SY reward claim before storing expiry data. `P/core/Market/PendleGauge.sol:84-86,109-114`; `P/core/RewardManager/RewardManager.sol:27-35`; `PendleMarketV3.sol:96-110,347-356`: market hooks harvest SY and controller. | These calls cannot be silently skipped. R3's Stage-1 rejection makes those optional operations unsupported, not successful zero-reward paths. |
| S18 | `P/core/Market/v3/PendleMarketFactoryV3.sol:39-63,69-116`: factory passes fixed controller and inserts market into its own set. `P/LiquidityMining/GaugeController/PendleGaugeControllerBaseUpg.sol:42-93`: cached validity or one of four immutable factory checks, else `GCNotPendleMarket`, before zero-emission handling. | New-factory membership does not create controller authority. R3 removes this unnecessary dependency; it does not repair/admit it. |
| S19 | `R/VaultRegistryDeploymentTarget.sol:44-76,141-165`: owner/operator deploys and registers package; instance caller must be owner/operator or registered package; requested package must be registered/enabled. | Manager authority is an existing deployment prerequisite, not conferred by Migration ownership or a model set. |
| S20 | `D/UniswapV4Detf_Pkg_FactoryService.sol:16-32`; `D/UniswapV4DetfDFPkg.sol:201-239`; `D/UniswapV4DetfTarget.sol:810-849`: artifact deployment, registry-only processing, post-deploy bond then receipt, once-wired identities. | Real parent/child composition path exists. New selected policies and RT wiring still need implementation, artifacts and real proxy checks. |
| S21 | `C/bondNft/DETFNFTVaultDFPkg.sol:48-53,68-117`; `C/sy/DETFSYDFPkg.sol:41-51,66-117`; `C/sy/DETFSYDeploymentLib.sol:15-27`: registered selected facets, three guarded NFT replacements, two SY modes. `C/claimToken/RebasingClaimTokenDFPkg.sol:39-59,76-108,137-149`: generic callback receipt child. | Do not invent a new registry category for receipt/RT. Declaration extensibility is needed; old nonvirtual declarations cannot advertise new interfaces by wish alone. |
| S22 | `K/factories/diamondPkg/DiamondPackageCallBackFactory.sol:201-231,261-309,343-451`; `PostDeployAccountHookFacet.sol:19-23`: early existing-address return, stored package context, temporary delegatecall hook, explicit hook removal. | Callback/init context is not itself a one-shot authorization. Completed proxy must lack the corresponding routing edges. Generic RT construction requires no Pendle governance. |
| S23 | `D/UniswapV4DetfProcessArgsLib.sol:26-64`; `W/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:142-147`: hook shape, exactly one parent occurrence, hook owner equals parent, full-book owner-only first join. | Current Migration owner authorizes outer genesis; actual parent satisfies hook caller authority. Neither source reading nor symbolic owner check proves real liquidity readiness. |
| S24 | `K/access/ERC8023/MultiStepOwnableRepo.sol:108-122,253-274`: current-owner equality; pending owner acceptance changes owner without checking confirmation/time. | Respect the now-selected owner-only genesis. Do not silently add a Crane ownership repair or assume pending owner is current owner. |
| S25 | `K/introspection/ERC2535/ERC2535Repo.sol:104-116,155-169,245-270`; `K/proxies/MinimalDiamondCallBackProxyResolution.sol:24-26`; `K/proxies/Proxy.sol:29-32`: nonzero owning-facet removal, no-init local cut, mapping-based resolution. | Activation must remove actual installed selectors atomically, not use zero-address cuts or assume absence of a named public updater proves irreversibility. |
| S26 | `K/tokens/ERC721/ERC721Repo.sol:153-169`; `K/access/reentrancy/ReentrancyLockModifiers.sol:21-29`: receiver callback precedes ownership mutation; lock is proxy-local. | Actual cross-proxy phase/caller tests remain mandatory; arithmetic predicates do not establish callback safety. |
| S27 | `D/UniswapV4DetfTarget.sol:527-595,714-724`: ordinary funding, duration and issuance-reward order. `C/bondNft/DETFFundedBondMetadata.sol:30-35,63-96,136-150`: current linear rendering. | Ordinary Stage-2 purchases stay unmarked/linear; Migration metadata must be specialized without changing ordinary rendering. |
| S28 | `C/bondNft/DETFFundedBondTarget.sol:212-218,260-389`; `D/UniswapV4DetfTarget.sol:731-798`; `D/UniswapV4DetfCommon.sol:483-544`: protected receipt/backing, bond-first donation callback, current whole-balance sweeps. | Preserve live donations and lock order; replace Migration residual handling with operation budgets, not inherited whole-balance spending. |

## 3. Independent conservation derivation

Funding preserves `B=floor(T/k)+Da+Ds`: floor allocation partitions
`f+Da`, the ceiling rebase consumes no more than staking allocation plus
staking dust, and post-rebase role issue adds exactly its native liability.
The receipt must have actually received `f` first (S01/S02/S04).

For any exact native principal packet,
`floor((T-n*k)/k)=floor(T/k)-n`. A principal exit therefore reduces both
native liability and accounted backing by n without borrowing fractional
gons. Wallet checkpoint `G-P*k` and SY checkpoint `s*(lastK-k)` move actual
existing gons to their old beneficiary's custody, not to the principal
receiver. After all principal leaves, only actual remaining gons participate.

The independent oracle records SY earnings eagerly at each funding, rather
than implementing the proposal's lazy lastK representation. Summing earned
intervals gives the same `s*(lastK-k)` over each unchanged-share interval.
It checks physical SY inventory as `sum(shares)*k + sum(unsettled earnings)`,
then moves settled earnings into physical receipt escrow.

RT issuance conserves escrow:
`R2_before = mintedRT*W + R2_after`. Redemption conserves it again:
`burnedRT*W = paidNative*k + retainedR0`. The token is not a second term
in total physical gons. A repeat claim at unchanged k is zero. Remainder
payment spends only `R2%W`, never the gons supporting whole standard claims.

Retirement uses S03's admitted conditions, not r1's stronger prohibition.
Stage-1 principal exit first checkpoints and therefore does not retire its
deferred rewards. A sub-RT remainder is not necessarily sub-native: at k=1,
W-1 gons can pay W-1 native units. It must not be retired under S03.

## 4. Inspection limits

The source reference LSP query on `DETFSYTarget.redeem` timed out. Direct
source reads supplied the call edges. The original Plan is absent from
the worktree inventory, so its expressly required main-checkout file was
read, as was the named main-checkout r3 brief. No other worktree was edited.
No source equivalence to a deployed legacy address, governance authority,
actual configured liquidity, compiler result or runtime proxy behavior is
inferred from this evidence.
