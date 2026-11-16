# Migration SY production component

Date: 2026-11-10.
Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-04`.
Branch: `work/dtf-migration-phase-04`.
Base: `6e27ecaa242c4acca132e3575a160514aad07b11`.

**Delivered: production raw and principal-denominated staking SY implementations
through one selected facet and the existing registered SY package. Source/LSP
checks passed. Compilation, assembled-proxy integration and runtime acceptance
are pending the parent integration lane. This is not E4/E5 closure.**

Authority is the phase04 implementation instruction and complete
`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase04-core-brief.md`,
the complete main-checkout Migration implementation plan, accepted phase03
`migration/package/egress-contract-r3.md` and `egress-r3-verification.md`,
and phase04 `migration/core/interfaces.md` plus its actual interfaces.
The ownership/bootstrap implementation handoff, repository routers, assistant
rules and canonical Crane architecture/deployment/testing/style skills were
read. R3 replaces r1/r2; current-owner-only genesis is settled. E1/E2 remain
unanswered without attribution or atomicity relaxation.

## 1. Exact files and storage ownership

Prefixes are repository-relative inside the worktree above:

- `M/` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/`
- `C/` = `contracts/vaults/detf/common/`
- `D/` = `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`
- `K/` = `lib/crane/contracts/`

| Authored production path | Delivered behavior |
| --- | --- |
| `M/sy/UniswapV4DetfMigrationSYRepo.sol` | Separate ERC1967-derived namespace containing only per-account `lastK` and accounting phase. No tickets, duplicate balances, reward liabilities or internal-owner slots. |
| `M/sy/UniswapV4DetfMigrationSYTarget.sol` | Both modes, R3 principal accounting, exact old-holder checkpoints, standard external/self burn, RT reward API, native remainder extension, phased calls and measured parent route packets. |
| `M/sy/UniswapV4DetfMigrationSYFacet.sol` | All 29 existing product selectors plus the three R3 selectors; six product interface declarations. |
| `C/sy/DETFSYTarget.sol` | Virtual dispatch on the implemented transfer/deposit/redeem/rate/preview/reward methods and `_acquireDetf`; reward mutability permits Migration's stateful implementation. Ordinary method bodies are unchanged. |
| `C/sy/DETFSYDFPkg.sol` | Preserve the ordinary six interface IDs in order and append deduplicated IDs advertised by the actual selected SY facet. Package metadata, diamond configuration, vault declaration and stored vault types use this result. No argument, salt, registry, initialization or cut-schema change. |

This report is the only documentation edit. Shared interfaces, receipt/reward
and bond implementations, parent sources, tests, dependencies and configuration
are not owned or edited by this component.

Canonical `ERC20Repo` remains the sole authority for balances, supply and
allowances. `DETFSYRepo.backingGons` remains A; `rawBacking` remains raw
principal. Migration never writes `conversionDustGons`: n native staking
principal creates exactly n shares and n*k backing gons. Receipt owns R2,
U and tokenized reward custody, not the SY repo.

## 2. Package and interface contract

Use the unchanged `IDETFSYDFPkg.PkgInit` with
`syFacet = UniswapV4DetfMigrationSYFacet`, real ERC2612/ERC5267 facets,
the real fee oracle and vault registry. Register a distinct selected package
instance through the manager registry; no new standalone SY deployment
framework, factory or per-instance argument is introduced.

`DETFSYDeploymentLib._deploy` still invokes the registered package twice:
`isStaking=false` then `isStaking=true`, preserving distinct metadata,
the actual parent/receipt identities, and every directional route. Its
`DETFChildSYRepo._initialize` fixes the two different addresses once.
The parent must wire its genuine receipt and RT before this step, then
verify both completed wrapper identities and interfaces. The SY reads RT
from the parent; there is no setter or locally cached alternate RT.

| Declared interface | All installed methods and implementation |
| --- | --- |
| `IERC20` | `totalSupply`, `balanceOf`, `allowance`, `approve` use common canonical storage. `transfer`, `transferFrom` are Migration implementations with settlement before every affected share change. |
| `IERC20Metadata` | `name`, `symbol`, `decimals` remain common metadata; decimals are 9 in both modes. |
| `IStandardizedYield` | `deposit`, `redeem`, `exchangeRate`, `yieldToken`, `assetInfo`, `getTokensIn`, `getTokensOut`, `isValidTokenIn`, `isValidTokenOut`, `previewDeposit`, `previewRedeem`, `getRewardTokens`, `accruedRewards`, `rewardIndexesCurrent`, `rewardIndexesStored`, `claimRewards`. All 16 remain installed; no alias replaces a standard method. |
| `IStandardVault` | `vaultFeeTypeIds`, `contentsId`, `vaultTypes`, `vaultConfig` remain common queries of initialized registry metadata and parent accounting asset. |
| `IUniswapV4DetfMigrationSY` | `claimRewardRemainder`, `attributedSyGons`. Staking attribution is common A; raw attribution is zero. |
| `IUniswapV4DetfMigrationAccounting` | `migrationAccountingPhase`, separately advertised because interface inheritance does not include inherited selectors in a derived interface ID. |
| `IERC20Permit` | Actual separate `ERC2612Facet`: `permit`, `nonces`, `DOMAIN_SEPARATOR`. The original EIP712 name/version initialization and canonical allowance repo remain unchanged. |
| `IERC5267` | Actual separate `ERC5267Facet`: `eip712Domain`. |

The product facet has 32 unique selector entries. The existing package
adds three permit selectors and one domain selector, giving 36 product/
permit/domain selectors before callback-factory base introspection.
Its three Add cuts use each selected facet's actual `facetFuncs()`.
No initializer, updater, generic execution, ticket or `redeemInternal`
selector is supplied by the SY facet.

Ordinary `DETFSYFacet` advertises no extra IDs: its package still returns
exactly the original six, in the original order. No Migration selector or
behavior is installed by merely rebuilding an ordinary package.
Package-level `updatePkg`/`postDeploy` are unchanged and are not SY facet
selectors. Final callback-factory routing/removal still needs live loupe
verification in the parent lane.

## 3. Every input/output path and budget

All executions retain `deposit(address,address,uint256,uint256)` payable
and `redeem(address,uint256,address,uint256,bool)`. Nonzero `msg.value`
is rejected; these existing wrappers have no native-ETH route. Native
parent donations are a separate surface, not an inferred SY route.

| Mode and path | Actual caller, source, output and budget |
| --- | --- |
| Raw deposit DETF | SY pulls exactly the declared amount from `msg.sender`, measures the delta, adds that amount to `rawBacking`, and mints exactly it to the selected share receiver. Existing DETF inventory is not credit. |
| Raw configured receipt deposit | Only if present in `tokensIn`. Raw SY checkpoints its own ordinary receipt wallet before measuring input, then pulls exactly the caller's packet. SY approves only that packet to the fixed parent, which executes receipt -> parent -> exact unstake. Only measured new DETF becomes raw shares. Input refunds, if any, return to the deposit caller. This is an existing-principal route in Stage 1, not ordinary acquisition. |
| Raw configured external deposit | Activation is checked before pulling input or entering the parent's primary/swap selection. SY pulls the input, approves only it, executes the actual parent route, verifies both output and refund against local deltas, clears approval, returns the operation's refund to the payer and mints only measured DETF output. |
| Staking deposit receipt | SY itself performs the approved `transferFrom(caller,SY,n)` in Acquiring phase. The receipt's fixed-SY ingress checkpoints the source wallet and leaves its old rewards in R0. Common acquisition measures newly received physical gons; final k must divide them exactly. |
| Staking deposit DETF | Actual caller DETF is pulled, approved exactly to the fixed receipt and staked to this SY; approval is cleared. The new gon delta at final k determines native principal shares. |
| Staking configured external deposit | Same gated actual parent acquisition as raw, followed by exact receipt staking. Final k is read after any active issuance distribution and receipt acquisition, not before. No prior SY backing or incidental rebase value is credited as a new input. |
| Raw redeem DETF | Burn the selected issued shares, debit `rawBacking` by exactly x and transfer x held DETF to the receiver. |
| Raw configured receipt output | Burn/debit x, enter Paying, checkpoint raw SY's ordinary receipt wallet before measuring output, approve exactly x DETF to the fixed parent and call its actual DETF -> receipt route. Verify local receipt/output deltas and clear approval. Transfer only this new receipt packet to the chosen receiver; prior raw-SY receipt principal is not swept. |
| Raw configured external output | Burn/debit x, enter Paying, approve exactly x DETF to the parent, execute the configured real output route to SY, verify its output and input refund, clear approval, and forward only measured output to the receiver. Any DETF input refund follows the principal to that receiver. |
| Staking redeem receipt | Checkpoint the selected source, burn x shares and debit x*k from A in Accounting. Call fixed receipt `transferSyPrincipal(receiver,x,k)`. It verifies actual post-debit A and physical coverage, transfers x*k existing gons and credits x native basis. |
| Staking redeem DETF | Same effects, then fixed receipt `withdrawSyPrincipal(SY,x,k)`. Verify exactly x newly received DETF, enter Paying and transfer exactly x to receiver. No full-account retirement is used for pooled SY custody. |
| Staking configured external output | Same fixed principal withdrawal and exact new DETF check, then Paying and the actual parent output route with exactly x approved. Verify output/refund deltas, clear approval and forward only this operation's result. |

`_exchangeParent` always supplies `pretransferred=false`, the fixed parent
and `block.timestamp` as the existing no-deadline-SY ABI's execution
deadline. It uses `ExchangeInAmount.exchangeResult` and `requireReceipt`
for both tuple words and actual local balances. This code does not silently
assume the refund word is output or sweep an entire balance. Parent/core
route pricing, fees and nested-route semantics are not replaced.

The actual parent currently returns zero input refund from its external
exchange dispatcher. The wrapper nevertheless validates the actual tuple
against its packet and forwards only a validated refund. This is not proof
that any arbitrary configured underlying route refunds correctly; every
real configured route remains a parent-integration test obligation.

`getTokensIn/Out` and both validity methods retain the exact common sets:
DETF always; automatic receipt only for staking mode; every configured
direction retained. Unsupported inputs/outputs reject. Both rates are WAD.
Direct principal previews are 1:1; other previews call the fixed parent's
actual quote. Closed-stage external-acquisition previews return zero,
without selecting a primary/swap branch. Rewards never inflate a principal
preview. `assetInfo=(TOKEN,parent,9)`; raw yield token is parent, staking
yield token is the receipt.

## 4. Source, recipient and operator identities

| Caller graph | Principal source and reward owner |
| --- | --- |
| Direct `redeem(...,false)` | Source is the actual caller, not the chosen receiver. Checkpoint caller before burn; old R2 stays with caller. |
| `redeem(...,true)` | Source is actual issued shares at `address(SY)`. Any caller may burn that deliberately bearer balance. Underlying donations create no shares. |
| Approved atomic direct pull | Router calls `transferFrom(user,SY,x)`, spending exactly the user's canonical SY allowance. User and self are checkpointed before movement. Router then uses standard internal redeem for x; old user R2 is not redirected to router or receiver. |
| Caller-funded self deposit | Payer calls `deposit(SY,token,n,min)`, receives the operation's returned share count, then may internally redeem that count. The wrapper checkpoints pre-existing self shares before minting; no operation budget is inferred from total self balance. |
| Upstream contract push | The real upstream contract calls `transfer(SY,x)`, checkpointing that upstream holder, then its router uses standard internal redeem. No upstream-to-router approval or owner ticket is required. This preserves the handoff, not optional Pendle lifecycle support. |
| Delayed self-held shares | Checkpoint self rewards to receipt protocol U. Neither the next internal redeemer nor a new depositor receives U. Existing self principal remains bearer, not authenticated user escrow. |
| Parent-composed receipt exit | Remains user -> parent receipt pull -> exact unstake -> optional output. It is not SY internal redemption and grants no access to all parent or SY inventory. |

`transferFrom` uses canonical `ERC20Repo._transferFrom`; max allowance and
owner-as-spender allowance decrement exactly as Crane specifies.
Permit writes that same native share allowance, not R2/RT/remainder
authorization. Zero and self transfers checkpoint every distinct affected
holder once. Approval and permit alone do not change shares or reward
ownership.

## 5. Reward accounting, phases and rollback

For staking holders, before any mint, burn or transfer:

```text
untouched zero-share cursor -> k
g = shares * (lastK - k), requiring lastK >= k
lastK = k
A -= g
receipt.deferSyRewards(holder, g, k)
```

Equality of lastK and k returns zero directly; canonical `_toGons` rejects
a zero divisor, so the positive difference is passed only when nonzero.
Receipt reads already-debited A, checks fixed caller/current k/physical
coverage, and moves g from SY to R2 or U. The public self account never
gets beneficiary R2. Shares remain principal; checked full-precision gon
products have no new economic cap or reset.

| API | Units, caller and delivery |
| --- | --- |
| `getRewardTokens` | Staking `[parent.migrationSyRewardToken()]`; raw `[]`. RT is distinct from receipt/yield token. |
| `rewardIndexesStored` | Staking `[1+1e36-k]`, initially `[1]`; raw `[]`. WAD-scaled native RT per native principal SY. |
| `rewardIndexesCurrent` | Announce Synchronizing, settle through fixed parent, enter Accounting/local lock, return the stored expression, then Idle. |
| `accruedRewards(a)` | Staking `[(receipt.R2[a]+latentGons(a))/1e18]`; self `[0]`; raw `[]`. Exact retained fractions remain in receipt custody. |
| `claimRewards(a)` | Any caller, fixed beneficiary a. Synchronize, require activation even at zero, checkpoint a, then call receipt `issueSyRewardTokens(a,k)`. Return and emit native RT, never native sDETF or exact gons. Self checkpoints into U and returns `[0]`; raw returns `[]` only after the same activation gate. |
| `claimRewardRemainder()` | Actual caller only; synchronize, activation gate, checkpoint caller, then receipt `paySyRewardRemainder(caller,k)`. Returns explicitly native sDETF from R2 modulo q. Raw active result is zero. |

Receipt performs the R2 -> E liability move, exact RT mint and native
remainder arithmetic. SY never mints RT or duplicates a reward balance.
Zero-share departed holders retain R2 and can claim later. RT redemption
is the separate receipt/RT lane, with retained R0 assigned to the actual
RT owner; this component does not replace that path.

All mutating share/reward entries first reject a non-Idle local phase,
announce Synchronizing before the external parent call, then announce the
operation phase before taking the ordinary local reentrancy lock.
Deposit uses Acquiring for pulls/parent acquisition/receipt staking, pins
final k and requires the measured incoming gons to equal n*k, then switches
to Accounting. It adds that incoming packet to A exactly once before
checkpointing the old recipient. Thus a typed checkpoint sees
`A_after = A_before + incoming - oldRewardGons`, already including its
genuinely received in-flight principal. The subsequent mint represents the
same packet and adds no gons again. At completion
`A = sum(shares[a] * lastK[a])`; no loose phase admission is needed.
Transfer uses Accounting.
Redeem uses Accounting for checkpoint, burn, A debit and pinned receipt
principal call, then Paying for onward DETF/parent output. Claims use
Accounting for their fixed receipt custody calls. A successful return
unlocks and restores Idle; errors are not caught.

The receipt source inspected during this pass checks precisely those
staking-SY phases: Acquiring for principal ingress; Accounting for
`deferSyRewards`, `transferSyPrincipal`, `withdrawSyPrincipal`,
`issueSyRewardTokens` and `paySyRewardRemainder`. No interface conflict
was found. The interface names actually called are `deferSyRewards`,
`issueSyRewardTokens` and `paySyRewardRemainder`, not the descriptive aliases
`deferSyGons`, `tokenizeSyRewards` or `paySyRemainder`.
Parent integration must admit only the fixed child's matching
phase/call and reject a token callback borrowing that phase. The existing
locked-parent synchronization no-op remains bond/receipt-only, not SY.
Activation must inspect all five child phases before its irreversible cut.

Invalid routes, short receipts, insufficient shares/allowances, stale k,
physical-coverage failure, parent failure, unauthorized receipt output
recipient and final minimum failure propagate without catch-and-continue.
Consequently all same-transaction parent funding, checkpoints, allowance
changes, burns, transfers and refunds revert together. This is a source
ordering argument, not executed callback/rollback evidence.

## 6. Source checks and required integration

Checks actually performed:

- Read the worktree `.git` pointer, HEAD and branch ref directly: exact
  branch/base above. No Git operation was run.
- Read actual standard SY, Migration SY/accounting/receipt, common
  package/deployment/storage, parent exchange/stake/unstake, canonical
  ERC20 allowance/transfer and permit/domain implementations.
- Native LSP symbols/references resolved the common SY and its deployment
  consumers. A later receipt-symbol request returned
  `analysis inputs changed since request`; its relevant production custody
  and phase source was read directly instead.
- Native LSP diagnostics, severity `all`, returned `No diagnostics found`
  for each of the five authored/edited production files. After the incoming
  packet was moved ahead of the typed checkpoint, a fresh diagnostic check
  of the changed target again returned `No diagnostics found`.
- All 54 direct imports across those five files resolve to existing files.
- Source census found 32 unique product selector entries at contiguous
  positions 0..31. Every original 29 method remains, plus exactly the
  three declared R3 additions. Permit/domain facets retain their 3+1
  methods separately.
- Compared pre-edit common target text with final text after stripping
  only added virtual qualifiers and the required reward mutability
  widening: equality. Ordinary method bodies were preserved.
- Traced source-before-change checkpoints, actual allowance operator,
  both burn sources, old self inventory/U, measured pulls/gons, local
  parent input/output/refunds, cleared approvals and final minimum checks.
- Sent the exact final phase/packet ordering and actual interface method
  names to root session `01a1c343-d102-7e05-9b68-d96021c7fb4e`, requesting
  relay to the receipt/RT lane. The tool accepted it as queued follow-up
  delivery; no acknowledgement or assembled integration result is inferred.

Source anchors in `M/sy/UniswapV4DetfMigrationSYTarget.sol`:
phase entry at 33; transfer paths at 57/67; deposit at 77; redeem at 110;
previews at 151/160; rewards at 168-225; checkpoint/latent arithmetic at
227-251; acquisition/output/parent receipts at 254-301; reward unit/index
helpers at 303-317. Common package declarations, cuts and initialization
are in `C/sy/DETFSYDFPkg.sol`. The actual inspected parent direct
composition remains `D/UniswapV4DetfTarget.sol:344-374`.

Pending, explicitly not claimed passed: Solar build and current artifact
binding; registered real-parent/receipt/RT/two-SY deployment; all configured
output pricing/fees and disabled-state behavior; actual token delta and
refund witnesses; mixed holders and prolonged Stage 1; both burn modes
and self U; zero/positive RT and fraction release; real permit signatures;
stale-index, wrong-caller and malicious callback rollback; busy-child
activation; actual interface IDs/loupe/cuts and EIP-170 sizes; unchanged
ordinary V4/common regressions. No Forge compiler, tests or RPC were run
because this lane is source/LSP-only before fan-in.

No SUT mock, subclass fixture, storage injection, etch, parent impersonation
or fake issuer was created. There is no new Pendle fork, factory,
controller, adapter, generic executor or omitted required direct/internal/
parent path. External consumers' Stage-1 harvesting, field-width and
fractional-accounting limitations remain as R3 specifies.

Cleanup: no owned process, RPC, port, temporary runtime root, dependency or
cache was created. Warm artifacts and shared read-only links were preserved.
No commit, delegation, shared configuration edit or public action occurred.
