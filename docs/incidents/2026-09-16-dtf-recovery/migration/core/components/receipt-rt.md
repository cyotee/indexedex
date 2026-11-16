# Migration receipt and reward-token component handoff

Date: 2026-11-10.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
Branch: `work/dtf-migration-phase-04`.
Base: `6e27ecaa242c4acca132e3575a160514aad07b11`.

**Production source implemented; compilation and runtime proof pending parent
integration.** This component does not claim a deployed proxy, passing Forge
suite, EIP-170 size, callback execution, or E4/E5 closure. No Forge command,
test issuer, SUT substitute, public action, commit, or delegation was used.

Authority is the current phase04 implementation instruction and complete
phase04 brief, original Migration implementation/test plan, accepted
`egress-contract-r3.md`, `egress-r3-verification.md`, and actual shared
`core/interfaces.md`/Solidity interfaces. Repository rules, relevant canonical
skills, and ownership/bootstrap handoff were read. R3 supersedes the earlier
egress designs; current-owner-only genesis is settled. E1/E2 and actual
recovery E3 remain open without relaxed attribution or atomicity.

## Implemented paths and deployment composition

Prefixes are repository-relative:

- `M/` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `C/` = `contracts/vaults/detf/common/`
- `K/` = `lib/crane/contracts/`

Seven new production files:

| Path | Implemented responsibility |
| --- | --- |
| `M/claimToken/UniswapV4DetfMigrationStakedDETFRepo.sol` | Native liquid basis P, exact-gon R0/R1/R2 and aggregate, E, U, accounting phase. No duplicated funded state. |
| `M/claimToken/UniswapV4DetfMigrationStakedDETFTarget.sol` | Receipt transfer/exchange policy, canonical funding with captured role custody, checkpoints, fixed-beneficiary releases, rights assignment, typed bond/SY/RT custody operations, phase and coverage checks. |
| `M/claimToken/UniswapV4DetfMigrationStakedDETFFacet.sol` | All 34 product selectors and seven implemented interface declarations. |
| `M/sy/rewards/UniswapV4DetfMigrationRewardTokenRepo.sol` | Once-only parent/receipt bindings, phase, fixed q=`1e18`; ERC20Repo remains the token balance/supply authority. |
| `M/sy/rewards/UniswapV4DetfMigrationRewardTokenTarget.sol` | Ordinary native ERC20, 27-decimal metadata, receipt-only activation-gated mint/burn, caller-owned redemption, preview and binding queries. |
| `M/sy/rewards/UniswapV4DetfMigrationRewardTokenFacet.sol` | All 16 RT selectors and four implemented interface declarations. |
| `M/sy/rewards/UniswapV4DetfMigrationRewardTokenDFPkg.sol` | Actual interface-owned constructor/instance arguments, generic factory deployment, cuts, metadata, canonical argument validation, reciprocal bindings, once-only initialization and post-deploy checks. Updates reject. |

Exactly two existing production files changed:

| Path | Change and ordinary default |
| --- | --- |
| `C/claimToken/StakedDETFTarget.sol` | Added `virtual` to `transfer`, `transferFrom`, `fundRewards`, `retireEscrowDust`, `_exchange`, `_synchronize`. Their existing bodies and ordinary behavior are unchanged. Existing virtual distribution dispatch is reused. |
| `C/claimToken/RebasingClaimTokenDFPkg.sol` | `facetInterfaces` now reads the selected receipt facet and appends nonduplicate extension IDs. The original seven IDs remain in their original order; the ordinary selected facet adds none. Constructor, initialization, three cuts, permit facets and generic deployment path are unchanged. |

All shared interfaces, other components, canonical funded repo/math,
dependencies, configs, ordinary tests, pricing sources and snapshots were
read-only in this lane.

Deploy the existing `RebasingClaimTokenDFPkg` with its real existing
`IRebasingClaimTokenDFPkg.PkgInit`, selecting the Migration receipt facet and
the canonical ERC2612/ERC5267 facets. This declares nine interfaces on the
Migration receipt package, not seven ordinary-only IDs. Its product cut has
34 selectors; permit/nonces/domain separator and EIP712-domain query add
four more, for 38 package-owned selectors before factory introspection.
No standalone replacement receipt deployment framework was introduced.

Construct RT through `IUniswapV4DetfMigrationRewardTokenDFPkg.PkgInit`:
`{rewardTokenFacet, diamondFactory}`. The real generic `deployToken(PkgArgs)`
uses `{parent, receipt, name, symbol}`; decimals and q are not arguments.
Argument processing and initialization check `receipt.detf()==parent` and
`parent.rebasingClaimToken()==receipt`. Initialization rejects rebinding
before initializing canonical ERC20 metadata. Post-deploy reads actual
bindings, decimals, zero supply and Idle phase. It does not demand the
parent's RT pointer before the parent has received the deployment result.

Parent integration must store that RT once before deploying the two SYs.
Receipt RT admission rejects a zero pointer and verifies reciprocal RT
bindings. RT mint/burn additionally require the parent's selected RT to be
this token. RT has no minter setter, installed initializer, updater, or
generic executor. Package lifecycle methods are not facet selectors.

## Finalized cross-component handshake

The root-confirmed ordinals are
`Idle=0, Synchronizing=1, Acquiring=2, Accounting=3, Paying=4`.
The actual bond and SY sources were also read after their implementation:
their creation, deposit, checkpoint, claim and output order matches these
receipt validators. No phase alternative was admitted to hide a mismatch.

| Receipt/RT edge | Required caller and phase | Index and custody contract |
| --- | --- | --- |
| Receipt public wallet entry | Receipt starts Idle, announces Synchronizing to real parent, then takes its local lock/Accounting | Parent settlement finishes before wallet accounting. A nested incompatible receipt entry rejects. |
| `fundRewards` | Fixed parent only; receipt may be Idle or Synchronizing | Exact DETF pull; canonical funded distribution; restore the saved phase, including Synchronizing. No intermediate Idle window. |
| Bond stake-to-self through `exchangeIn` | Fixed bond, Accounting | Existing physical bond gons cover existing attribution; exact newly pulled DETF creates exactly P*k. The new packet is intentionally not yet an opened position at this call. Bond verifies the delta and then mints/opens. |
| `deliverBondClaim` / `retireEscrowDust` | Fixed bond, Accounting | Delivery checks expected k; both require physical post-debit gons to cover the actual post-debit bond aggregate. Canonical retirement additionally requires the own final fraction to be less than k. |
| Receipt `transferFrom` ingress to staking SY | Fixed staking SY, Acquiring, real native allowance | Checkpoint the ordinary source and move exactly the requested principal packet. Direct push, another spender, and protected source inventory reject. |
| Stake-to-self for staking SY | Fixed staking SY, Acquiring | Existing physical inventory covers A; pull exact DETF and credit the new packet once. |
| `deferSyRewards` | Fixed staking SY, Accounting | Expected k and actual post-debit A. Move physical gons into R2, or U when beneficiary is SY itself. |
| `transferSyPrincipal` / `withdrawSyPrincipal` | Fixed staking SY, Accounting | Expected k and post-debit A. Transfer or burn exactly n*k; no pooled full-account retirement. Native withdrawal may pay DETF to SY for its later output route. |
| `issueSyRewardTokens` / `paySyRewardRemainder` | Fixed staking SY, Accounting | Expected k, activation and fixed beneficiary. Tokenization debits only whole q; remainder payment debits only payable gons from R2 modulo q. |
| `RT.redeem` -> `redeemSyRewardTokens` | RT remains Accounting, receipt explicitly synchronizes itself | Owner is RT's actual caller. Receipt checks activation, current k, actual owner balance, E/supply and minimum; only this RT can call. |
| RT mint callback | Fixed receipt in Accounting; RT initially Idle | Activation and selected-RT binding required; mint exact native amount and compare actual supply*q to updated E. |
| RT burn callback | Fixed receipt in Accounting; RT remains Accounting during its own redeem | Activation and selected-RT binding required; canonical owner-balance burn, then actual supply*q must equal updated E. |

SY deposit integration inspected: after acquisition it pins final k, switches
to Accounting, adds the measured incoming gons to A once, subtracts old
recipient reward gons before `deferSyRewards`, then mints n shares without a
second A addition. Receipt does not demand that the new shares already exist
during this bounded in-flight accounting step.

SY redemption debits shares/A in Accounting, calls the typed receipt method,
then changes to Paying for its parent output route. Raw SY remains an
ordinary receipt basis account and checkpoints its own receipt inventory
before measuring a configured receipt-route delta. Parent/raw SY are not
given permission to spend another custodian's pooled inventory.

## Public monetary path coverage

These are source traces, not successful transaction claims.

| Public surface | Executed source policy |
| --- | --- |
| `exchangeIn` and `exchangeOut`, DETF -> receipt | Inherited minimum/maximum checks dispatch into the Migration `_exchange`; deadline/zero/true-pretransfer checks remain. Exact DETF delta is required before canonical principal credit. Normal recipient is checkpointed; protected stake-to-self is fixed-caller/phase-only. |
| `exchangeIn` and `exchangeOut`, receipt -> DETF | Same dispatcher. Protected owners reject. Closed stage checkpoints surplus into R0 and requires the full requested native amount <= P; no clipping. Active stage may spend actual displayed balance and saturates basis subtraction. Exact DETF is paid from held backing. |
| Receipt `transfer` / `transferFrom` | Ordinary closed-stage source/destination checkpoint and exact n*k/P transfer; active ordinary transfers may spend physical native value without basis underflow. Self transfer preserves basis. Canonical allowance spending includes max allowances and owner-as-spender calls. |
| Staking-SY receipt input | The authenticated pull conveys principal and retains the sender's old growth in R0 in either stage. A request larger than checkpointed basis rejects, rather than spending the retained reward domain. After activation the owner can release R0 before depositing that released receipt. |
| `approve`, `allowance`, `permit` | Canonical native-unit allowance ledger. Permit writes only allowance/nonces through unchanged ERC2612; neither approval form authorizes deferred rights or custodian spending. |
| `checkpointRewards` | Actual caller only; move `G-P*k` existing gons to receipt escrow/R0, without changing T, B or principal. Deficits reject. |
| `fundRewards` | Exact parent-only pull; reuse `FundedRepo._distribute` with both role destinations initially escrow. This preserves the canonical two floors, rebase/dust and post-rebase role issuance. Capture each reserved NFT's owner at allocation. |
| New role allocations | Closed stage credits captured R1 only; active normal beneficiaries receive native receipts and basis. Protected custodian gifts remain separately attributed R1. Equal beneficiaries merge. No previously captured ownership is recomputed. |
| `claimDeferredRewards(0/1)` | Activation required even for zero. Pay floor(R/k) only to the caller; debit paid*k and retain the remainder. Domain zero also checkpoints the caller's new wallet growth. Domain two is not a native-release alias. |
| `claimDeferredRoleRewards(beneficiary)` | Permissionless trigger, fixed recorded beneficiary, activation required. Does not convert the beneficiary's active wallet growth into owner-only R0. Ordinary contract beneficiaries need no new claim callback and are never replaced with an EOA. |
| `transferDeferredRewardRights(0/2,to,gons)` | Actual owner only, exact booked gons, normal recipient. Custody and T do not move; no RT/receipt mint or ERC20 allowance authorization. R1 assignment rejects. |
| Bond delivery | Exact principal+reward native packet after post-debit coverage; positive reward independently requires activation. Recipient's later receipt growth remains distinct from still-attached NFT rewards. |
| Bond retirement | Fixed bond-only canonical sub-native fraction retirement after aggregate debit; emits exact retired gons and native staking-dust increase. No R0/R1/R2/E/U retirement path. |
| SY checkpoint / self earnings | Exact gons move from SY into R2/U after A debit. U remains backed within T and has no beneficiary payout or sweep. |
| SY principal receipt output | Exact n*k physical transfer and n basis to a normal recipient. Cannot bypass SY accounting by paying another protected custodian. |
| SY principal DETF output | Exact n*k burn, T reduction and B reduction by n, then exact held-DETF transfer. No `FundedRepo._debitPrincipal` full-account shortcut on pooled SY. |
| SY standard reward issuance | Active-only R2 -> E for `floor(R2/q)*q`, mint exactly `floor(R2/q)` native RT to the same beneficiary. Verify actual RT supply before and after. Keep R2 modulo q. |
| SY native remainder extension | Active-only payment of `floor((R2%q)/k)` native receipt to the fixed beneficiary. Whole-RT backing is untouched and unpaid gons stay owned. |
| RT ERC20 transfer/allowance | Fixed native balances, canonical ERC20Repo semantics and local phase guards. These do not alter funded gons, T, E or the index. |
| RT redemption | Actual caller's m native RT -> burn -> E debit m*q -> native receipt floor(m*q/k) to selected normal receiver; every remaining gon is R0 of the actual owner, not the receiver. Zero returns zero; positive zero-native redemption retains all represented gons when minimum is zero. |

The canonical `balanceOf`, `totalSupply`, `stakingState`, `gonsOf` and ordered
`previewDistributions` remain physical/funded queries. `egressState`
separates basis, latent/deferred gons and executable cap; receipt escrow,
bond, staking SY and RT report zero public spend authority. Direct SE
previews remain 1:1 conversion quotes, not account-authority assertions.

## Conservation and ordinary isolation

`DETFFundedStakingRepo` remains authoritative for physical G, T, k, B,
allocation/staking dust and standing weights. All amount-to-gon products use
canonical full-precision `StakingMath._toGons`; RT preview uses `Math.mulDiv`.
No economic cap, index reset, parallel staking pool or unfunded debt exists.

Every completed receipt accounting operation checks exact escrow equality:

```text
G[receipt] = aggregate(R0 + R1 + R2) + E + U
E = q * actual RT.totalSupply()
```

The E equality is checked at both receipt tokenization/redemption boundaries
and in the actual RT mint/burn callbacks. Moving gons or materializing RT
never adds to T. Native burns subtract n*k and n backing; canonical own-wallet
full active withdrawal and final-position fraction retirement alone may
move aggregate liability rounding to staking dust.

A closed-stage principal withdrawal checkpoints first, so its R0 survives
even when P and wallet G reach zero. RT quantum residue is never treated as
canonical retirement dust: q can exceed k and the native remainder method
pays its representable amount.

Ordinary active incoming receipts do not gratuitously escrow an existing
contract recipient's grown wallet balance. This is important for actual
contract role beneficiaries that can use ordinary tokens but have no
Migration-specific owner-call adapter. R1 release is always fixed-beneficiary;
the four protected protocol custodians are intentionally not normal payout
receivers and gain no rescue authority.

## Source checks actually performed

- Read `.git` pointer, worktree HEAD and branch ref: branch/base above match.
  No Git command or write was used.
- Inspected all nine changed Solidity files, the canonical funded math/repo,
  ERC20 allowance/burn implementations, actual ERC2612/ERC5267 facets,
  generic package interfaces, and current bond/SY consumers.
- Native LSP `lsp_diagnostics`, severity `all`, returned **No diagnostics
  found** for all nine files. The receipt target was checked again after its
  final source changes, also with no diagnostics.
- All **82 direct imports** across these files resolve to existing files.
- Interface/base-target-derived controls contain **34 receipt product
  methods** and **16 RT methods**. Both actual facet arrays have exactly that
  many assigned entries, sequential indices, no duplicate method entries,
  no missing method and no unexpected method.
- Read the permit facets themselves: exactly permit/nonces/domain separator
  and EIP712-domain query are added by the unchanged generic receipt cuts.
  No ordinary ERC20 facet can override the guarded receipt transfer paths.
- Inspected the common changes: six virtual declarations only in the
  receipt target; package declaration extensibility only in its package.
- The owned-source scan found no TODO/FIXME/FILL, placeholder, delegatecall,
  selfdestruct, tx.origin, `redeemInternal` or `materializeSyRewards`.
  The new target/facet inventory has no initializer/updater/cut, generic
  executor, sweep, unconstrained mint/burn, or setter entry.
- Root-confirmed phases were compared with actual current bond/SY code.
  **No cross-interface signature or phase conflict remains observed.**

These are bounded source/LSP checks, not compiler output, ABI/bytecode
selector-collision proof, live loupe observations, gas/size measurements,
signature execution, callback execution or behavioral tests. No source-string
test was added and no ordinary test was changed.

## Parent integration acceptance and cleanup

Parent integration is the sole compiler after the component barrier. It owns
artifact-first Solar build and real registered/proxy tests, including exact
ordinary regression, EIP-170 size and live declarations. In particular prove
long Stage 1, mature principal success, actual contract role/SY beneficiaries,
old-holder departure and later growth, wrong caller/phase/k, short receipt,
both SE directions/exact-out, allowances/permit, every actual configured
output, failed minimum rollback, RT zero/positive remainder, pooled dust
isolation, busy-child activation and cross-child callback rollback.

No source-dependent surrender, harvest, mutable attribution loader, wide
consumer, optional market deployment, or fake issuer was introduced. Their
unresolved full-release gates remain outside this bounded component.

No owned process, server, RPC listener, temporary directory, dependency or
cache was created. There is nothing to clean up. Warm artifacts and read-only
dependency links were preserved.
