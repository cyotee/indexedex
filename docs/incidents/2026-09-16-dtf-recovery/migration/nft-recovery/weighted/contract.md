# Weighted NFT recovery stage contract

Date: 2026-11-11.

**Disposition: source-admitted for the exact claim -> sDETF unstake ->
weighted DETF-to-DTF stages below.** Migration can execute them as the actual
NFT/token custodian through ordinary external calls. No legacy operator grant,
legacy DETF ownership, infrastructure impersonation or arbitrary executor is
needed. This is source admission, not proof that the baseline Migration proxy
already exposes recovery selectors or that integrated recovery/donation passed.

The concrete remaining prerequisite is installation and execution of the
bounded, retained, current-Crane-owner-only recovery surface with the inventory,
budget and atomicity checks below. The accepted baseline supplies real custody
and immutable consumption, not that recovery surface. No unresolved source
caller/recipient fact blocks these three weighted stages at the historical pin.
Donation into the same new DETF remains an implementation/integration gate,
not a fourth legacy conversion proved by phase01.

## 1. Scope and evidence domain

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-07-recovery`.
Independently observed branch: `work/dtf-migration-phase-07-recovery`.
Independently observed HEAD: `6e7d8b8dc2cda313c7fb19ec051bfb84612f5f31`.
Initial status with `--ignore-submodules=all` was empty, exit 0. Plain status
first exited 128 because warm-seeded `lib/crane` is a symlink; it was preserved.
Root's warm-seed exit-0 receipt was reused, not represented as a new run.

Historical source pin: Robinhood chain **4663**, L2 block **108944663**, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
No fresh pin was substituted. This pin is not the new funded pricing snapshot.

Reference **E** means
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence`.
Reference **N** means
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05/docs/incidents/2026-09-16-dtf-recovery/migration/nft`.
Reference **M** means the current worktree's
`contracts/vaults/detf/protocols/dexes/uniswap/v4/migration`.

Consumed evidence, all read-only:

| Reference | Actual input and meaning |
| --- | --- |
| P | Original main-checkout `docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`, revision r1, SHA-256 `56106853d29ddff963ff2b8a872bdfa1840ed95ed29806bdc10d728220b60be7`; complete plan, especially MIG-P12-P14, sections 5.6/6, task8 and recovery acceptance rows |
| E1 | Complete `E/phase01-verification.md`: independent capabilities, actual caller restrictions, adverse evidence and remaining gates |
| E2 | `E/weighted/probe.sources.json`: actual archived source content, ABI and published runtime/recompiled bytes |
| E3 | `E/weighted/probe.results.json` and `report.md`: historical source reads, raw RPC journal, successful source calls and their limits |
| E4 | `E/verification/weighted-replay.results.json`, `.sources.json`, `.exit.json`: independent historical replay, exit 0, 34 PASS / 1 FAIL / 2 UNPROVEN; positive source custodian is an EOA, not Migration |
| N1 | `N/weighted/contract.md`, `archive-audit.json`, and `N/source-verification/report.md`: accepted exact source/units/custody/consumption contract |
| N2 | `N/verification/report.md`, `evidence.json`: actual registry Migration surrender/custody, permanent consumption, fresh bonds and activation; not recovery execution |
| M1 | Current accepted `UniswapV4DetfMigrationTarget.sol:54-120`, `Repo.sol:20-44`, interface `IUniswapV4DetfMigration.sol:124-143`: separate custody and immutable surrender records |
| M2 | Current accepted `UniswapV4DetfMigrationTarget.sol:139-200`, `UniswapV4DetfMigrationPolicy.sol:19-70`: donation receipts, operation floors and residual budgets |

[`source-evidence.json`](source-evidence.json) contains 13 input fingerprints,
19 exact archived-source ranges, 28 selector/layout/facet bindings, raw
historical loupe journal locators, decoded mined call inputs/events and
**183/183 passing offline checks**. Checks recompute selectors, hash actual
recorded code, compare independent archives and published execution bodies,
join sent calls to mined receipts and reconcile actual claim/DTF transfers.
No successful source probe was rerun.

Archived-source citations below use original unescaped source line numbers:
**B** is the funded NFT facet archive, **S** the receipt facet archive, and
**X** the DETF exchange facet archive, each identified in section 2.
They do not mean today's similarly named Solidity source.

## 2. Fixed identities and execution bindings

Let **MIG** denote the actual registry-deployed Migration proxy executing the
new recovery operation. It is neither the former holder nor a caller-supplied
recipient. All legacy calls use zero native value and target the fixed proxy,
never a facet directly; no delegatecall into a legacy facet.

| Role | Fixed historical address | Native units |
| --- | --- | --- |
| Nft | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | Purchased NFT ID, not a fungible amount |
| Receipt | `0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c` | 9-decimal rebasing sDETF; supplementary internal gons |
| OldDetf | `0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` | 9-decimal liquid weighted DETF |
| Dtf | `0xeE5576Fa1Bcaa380e591D01245f406f3f384eb01` | 18-decimal DTF |

The Nft, Receipt and OldDetf proxy runtimes share Keccak-256
`0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601`.
Shared proxy code is insufficient: retain each historical selector route and
the routed facet's code identity.

| Tag | Facet address | Runtime Keccak-256 |
| --- | --- | --- |
| G, NFT ownership/approval | `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279` | `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8` |
| B, NFT position/claims | `0x3a07364eabA092472d40F0e6788b8891A31faD4D` | `0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52` |
| S, Receipt operations | `0xB7581fe833a2B2380DD786B345D61FFB734D36EB` | `0xcb505aba37d6ad909d8fb33dbf0091be50c9dd37f43e5df506bd240fc711b361` |
| T, OldDetf ERC20 | `0x1d17acA0e0717d90cea916372070a1BE4652223F` | `0xf250dca135b1de9a5fc9ceda732c06af7020fef1d45d7c43dfa92efe02b47e50` |
| Q, OldDetf preview | `0x1d38189B5f3548bc86838061F4318DBFA2f77680` | `0xcdb1b86aac1f571fc4f78937a4c670a6710ae2ab465d0f9c23acb87ddad7d8f4` |
| X, OldDetf exchange | `0x4886F86CD0DFFf8b8A836F858925eD4de3a2b291` | `0x1eadaa06571b1cca173491d149bab9b07d5d1b9dc83d268654e49d3179b1a460` |

G/T have Sourcify `match`, not full metadata `exact_match`; B/S/Q/X have
`exact_match`. Recorded on-chain bytes match the archive and independent
replay. Published recompiled execution bodies match after terminal CBOR
removal. No independent recompilation is claimed.

### Exact typed calls

| Proxy and signature | Selector | Facet | Return layout |
| --- | --- | --- | --- |
| Nft `ownerOf(uint256)` | `0x6352211e` | G | One address; absent/burned can return zero |
| Nft `positionOf(uint256)` | `0x46f96023` | B | One static tuple of five uint256: principal, claimedPrincipal, stakingGons, startTimestamp, vestingDuration; 160 bytes, no offset |
| Nft `previewClaim(uint256)` | `0xae648e90` | B | One static tuple of four uint256: vestedPrincipal, principalRemaining, principalDue, rewardsDue; 128 bytes |
| Nft `claimPrincipal(uint256,address)` | `0xf400c743` | B | One uint256 principal, 32 bytes |
| Nft `claimRewards(uint256,address)` | `0x6c7b69cb` | B | One uint256 rewards, 32 bytes |
| Nft `claimBond(uint256,address)` | `0x084c59ae` | B | Two uint256 outputs, principal then rewards, 64 bytes |
| Receipt `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` | `0xd02d3063` | S | **One uint256**, 32 bytes |
| OldDetf `exchangeIn(address,uint256,address,uint256,address,bool,uint256)` | `0xd02d3063` | X | **One uint256**, 32 bytes |
| OldDetf `previewExchangeIn(address,uint256,address)` | `0x89d61912` | Q | One uint256 output amount |
| Receipt `gonsOf(address)` | `0x79a67521` | S | One uint256 |
| Receipt `stakingState()` | `0xe082f1d4` | S | Seven static uint256: totalGons, gonsPerUnit, accountedBacking, allocationDust, stakingDust, feeWeight, creatorWeight; 224 bytes |
| Receipt / OldDetf `balanceOf(address)` | `0x70a08231` | S / T | One uint256 |
| Receipt / OldDetf `approve(address,uint256)` | `0x095ea7b3` | S / T | One bool; Receipt approval is not needed for direct unstake |

Nft `detf()` and Receipt `detf()` both use `0x8a91f8bc`, return OldDetf,
and route to B and S respectively. Receipt and OldDetf `decimals()`
(`0x313ce567`) return uint8 9. These bindings are also in the audit.
Use a legacy-specific exchange interface: importing today's two-output
exchange interface would decode the wrong return shape.

## 3. Custody authority and permanent identity

Before a claim, require the admitted chain/collection, purchased ID, matching
accepted `nftCustodies[Nft][id]` and consumed `nftSurrenders[Nft][id]`, then
actual `Nft.ownerOf(id) == MIG`. Recover from the immutable custody identity,
not replaceable entitlement configuration. An unsolicited unsafe transfer
alone is not an admitted surrendered position. Do not call the surrender
preview to authorize recovery: it correctly rejects already consumed IDs.

N1/N2 established whole custody in a genuine registry Migration proxy;
the token approval clears on transfer, and old owner-wide approvals remain
keyed to the old owner. The source `_claim` accepts the actual owner, token
approval or owner-wide operator (B `DETFFundedBondTarget.sol:163-184`).
MIG therefore qualifies directly as owner. It must grant neither approval
nor operator rights over the surrendered NFT.

The source allows approved operators to redirect claims, as the successful
E4 adverse test demonstrates. The new entrypoint must instead authorize the
current **Crane owner of MIG** and bind every payout to MIG. The old NFT
holder, pending/former Migration owner, fee recipient and deployer acquire no
recovery authority from those identities. Reuse Crane's actual ownership
semantics; do not invent another role or acceptance delay.

Claims retire the legacy NFT when paid, but never delete its permanent
surrender/consumption record, reopen entitlement, resize the delivered new
bond or create descendant credit. Configuration replacement cannot redirect
already held custody. Recovery remains a retained permission after activation.

## 4. Admitted stages

### W1. Claim the held NFT into Receipt at MIG

Primary proven call:

```text
MIG -> Nft.claimBond(id, MIG) -> (principalPaid, rewardsPaid)
```

The separately typed principal-only and rewards-only calls in section 2
are source-supported alternatives, not arbitrary selectors. E4 executed
combined and principal-only claims; rewards-only behavior follows the same
archived `_claim` with `(false,true)`, not a new runtime test by this lane.
No ERC20 or NFT allowance is required for MIG's owner claim.

The recipient is explicitly MIG, never zero. The source's zero-recipient
default resolves to the NFT owner, but must not become a caller option.
After that default, `_checkRecipient` forbids zero, OldDetf and Nft itself
(B `:239-242`); a distinct Migration proxy is permitted.

Claims run legacy `synchronizeRewards()` before the local source lock
(B `:45-48,142-160`). Preview uses only the stored index, so an earlier
preview is not the realized claim. With position P and the synchronized
receipt divisor k, the source computes:

```text
elapsed = max(block.timestamp - P.startTimestamp, 0)
vested = P.principal                                    if elapsed >= duration
vested = floor(P.principal * elapsed / duration)         otherwise
remaining = P.principal - P.claimedPrincipal
principalDue = vested - P.claimedPrincipal
stakingValue = floor(P.stakingGons / k)
rewardsDue = stakingValue - remaining
```

Duration must be nonzero, previously claimed principal cannot exceed vested
principal, and stakingValue must cover remaining principal. These are native
9-decimal legacy amounts, not ETH/DTF inputs, 18-decimal shares or the new
90-day compensation cliff. Principal-only selects principalDue; rewards-only
selects rewardsDue; combined selects both
(B `DETFFundedStakingMath.sol:96-117`).

The source increments claimedPrincipal only by principalPaid, debits
`(principalPaid + rewardsPaid) * k` gons and transfers that sum in Receipt.
Partial vesting leaves the remaining principal and original clock intact.
Repeated calls on a live position can pay newly vested principal or newly
funded rewards; without either, zero payout is permitted and books zero new
recovery. A zero payout is not completion. At maturity all remaining
principal is due, not another full original principal.

After a claim, if principal is completely paid and fewer than k gons remain,
the source deletes the position, retires that fractional dust and burns the
NFT. Dust is not another whole receipt unit. Otherwise the NFT remains live,
including a principal-paid/reward-only position. A later claim of a burned
ID rejects; do not require `positionOf` to succeed after a successful final
claim (B `DETFFundedBondTarget.sol:175-200,234-236`).

### W2. Unstake booked Receipt into OldDetf at MIG

```text
MIG -> Receipt.exchangeIn(Receipt, q, OldDetf, q, MIG, false, deadline)
    -> q
```

Input and output are both native 9-decimal units, exactly 1:1. Require
`0 < q <= booked undonated Receipt inventory`; no scaling or fixed WAD
exchange rate is needed. The receipt proxy burns/debits **msg.sender's**
own gons and transfers held OldDetf to MIG. It does not pull receipt
through transferFrom. **No Receipt allowance, operator grant or legacy
parent-only permission is needed.** Calling OldDetf's composed unstake is
not the selected route and would introduce unnecessary pull/approval work.

The source rejects expired deadlines, zero amount and `pretransferred=true`.
Minimum output cannot exceed q. It synchronizes first, debits before payout,
checks backing, and returns one uint256
(S `StakedDETFTarget.sol:126-160,187-214,230-236`).

Partial unstake debits exactly `q * k` gons. If q equals the caller's complete
native balance, `_debitPrincipal` retires all remaining account gons,
including its sub-native remainder; payout is still exactly q OldDetf.
Preserve this dust distinction and do not assume a full exit always debits
only `q * k` (S `DETFFundedStakingRepo.sol:107-124`).
The debit is of MIG's whole account ledger, not a separate NFT subaccount:
the wrapper must bound q by booked recovery inventory and preserve any
unrelated native balance and rights.

### W3. Convert booked OldDetf into Dtf at MIG

```text
MIG -> OldDetf.approve(OldDetf, q)
MIG -> OldDetf.exchangeIn(OldDetf, q, Dtf, minimumDtf, MIG, false, deadline)
    -> actualDtf
MIG -> OldDetf.approve(OldDetf, 0)
```

Input is native 9-decimal weighted OldDetf; output/minimum is native
18-decimal Dtf. There is no constant decimal-scaled 1:1 rate.
`q > 0` must not exceed booked OldDetf inventory. The source pulls q
from msg.sender using transferFrom, so **MIG approves OldDetf as spender
on the OldDetf token**. Use an operation-local exact allowance and clear
it on success. Do not approve the NFT, receipt, source facet or an operator.
Any later failure in the same selected transaction must revert the approval
and all preceding work.

X `UniswapV4DetfExchangeTarget.sol:10-19` and
`UniswapV4DetfTarget.sol:204-234,429-487` establish the caller graph.
The source chooses its existing burn or swap fallback based on the token
burn gate; it is not a route chosen by Migration. The proportional burn
uses `floor(q * protocolLp / supply)`, rejects zero LP, exits the reserve
and converts the selected leg. A swap fallback transfers existing DETF into
the reserve rather than burning it. Both remain exact-input consumption
of MIG's q and must satisfy nonzero output/minimum. Do not require total
supply to drop as proof that every admitted conversion succeeded.

The reserve hook is owner-restricted, but this route reaches it through
**OldDetf**, its legitimate owner; Migration does not call the owner-only
LP exit itself. Internal calls use fixed source custody and finally pay
the explicitly supplied MIG recipient. Nested approvals are scoped and
cleared by the source (X `UniswapV4DetfTarget.sol:490-495,516-534`,
`UniswapV4DetfCommon.sol:77-100,413-427`). This is why a failed standalone
LP exit from a new custodian does not invalidate the proven DETF route.

### W4. Hand off booked proceeds to the same new DETF reserve

W1-W3 may stop with proceeds at MIG. Their eventual donation destination
is that same Migration DETF's reserve/custody graph, never an owner-selected
wallet, another DETF or an ordinary bond purchase. Recovery pays no personal
principal and makes no compensation issuance.

This lane admits no new legacy donation selector. The current
`donateMigrationCapital` surface measures external donor pulls and uses
operation budgets; a self-call is not proof that staged inventory was
newly received. Implementation must bridge only the selected, booked
recovery inventory into the existing protected reserve-budget flow, debit
what is actually donated and retain actual residuals. It must not release
older donation budgets, unsolicited assets, new-bond backing, user packets,
self-leg inventory, other legacy custody or existing funded reward rights.
Real successful donation and failing-donation rollback through the new
recovery surface remain mandatory downstream proof.

## 5. Operation-local accounting, including receipt synchronization

Maintain explicit per-token undonated inventory, distinct from token
balances, configuration and entitlement consumption:

```text
inventoryAfter[token] = inventoryBefore[token]
                      + newlyReceivedClaims[token]
                      + actualConversionOutputs[token]
                      - actualConversionInputs[token]
                      - actualDonations[token]
```

W1 credits only newly transferred Receipt. W2 debits q Receipt and credits
the observed q OldDetf. W3 debits q OldDetf and credits the observed Dtf
delta, matching the one-word source return/minimum. Donation debits only
the selected actual contribution. These are successive representations
of one recovery, not separate recovered-economic-value totals.

**Do not use the unsynchronized Receipt balance delta blindly.** W1 and
W2 synchronize legacy rewards. A changed divisor can increase the displayed
balance of receipts MIG already held without a new transfer. This follows
from S `StakedDETFTarget.sol:34-37,97-98,230-236`,
`DETFFundedStakingRepo.sol:81-88,147-156`, and
X `UniswapV4DetfCommon.sol:352-388`.

For W1, read MIG's gons G0 before the call and G1/k1 after. The source
transfer adds an integer amount times the synchronized divisor; rebase
does not itself add gons to an ordinary holder:

```text
A = principalPaid + rewardsPaid
require G1 - G0 == A * k1
newClaimNative = floor(G1 / k1) - floor(G0 / k1) = A
```

This is an operation-local receipt delta valued at one index, not a sweep
of MIG's total balance. Require actual Receipt custody to corroborate the
typed return. The raw `balanceAfter - balanceBefore` can additionally
contain revaluation of G0; it is not all A. Previously held or unsolicited
gons cannot be booked as another NFT claim. Track sufficient gons/index
evidence to reconcile native inventory and exact partial/full debits;
unbooked revaluation is not permission to enlarge the selected recovery
budget. No new policy to distribute it is authorized here.

For W2, actual OldDetf output is nonrebasing and can use its before/after
delta directly. Verify Receipt gons consumption using the synchronized
index and the full-account remainder rule, not an assumption that the
pre-call balance/index is unchanged. Returned q is not proof of spending
only admitted inventory without the wrapper's budget checks.

Recovery batches must index selected surrendered identities directly;
do not scan every configured/held position. Work is proportional to the
selected set plus fixed route work. Final implementation must measure
small/large unrelated-custody populations and honest operational gas
bounds; phase01 receipt gas is not a target-chain batch limit.

## 6. Registry, activation and failure contract

The three admitted source entrypoints have no Migration activation gate.
Legacy claims/receipt unstake have no direct local `_requireNotDisabled`
check in the cited bodies; their synchronization and backing dependencies
still execute. The selected OldDetf exit does not run the mint path's
`_requireNotDisabled`, but requires a live reserve, a configured output route,
valid deadline, liquidity and successful nested operations. The name
`_requireActive` here means amount/deadline checks, not Migration activation
(X `UniswapV4DetfCommon.sol:59-74`,
`UniswapV4DetfTarget.sol:204-234,264-274,429-487`).

Do not generalize this to every forced registry-disable state: phase01 did
not execute that matrix. It did prove the weighted Dtf route at the pin,
while weighted WETH-leg SE `0x999Dae02d22E5feE1c4508430D5196d31D631009`
and the earlier SE have preserved disabled-exit evidence. No WETH leg,
registry policy change, enable call or alternative source is admitted here.
Actual dependency failures propagate; prior successful claim inventory
remains available for a later permitted retry.

The new recovery wrapper must be retained after activation, follow actual
current Crane ownership, guard the full legacy synchronization/callback graph,
and preserve the shared new-child accounting protections. It must not reuse
the removable Stage1 administration modifier. Registry behavior is
route-specific: preserve exit availability and the current new-reserve
donation disable checks rather than adding a blanket activation/disable
barrier to every stage or bypassing a nested registry rejection.

One selected transaction is all-or-nothing. A failed middle ID, wrong live
owner, unsupported identity, expired conversion, minimum failure, backing
failure, callback/reentry failure or donation failure reverts every source
and local state change in that transaction. Do not catch and skip an item.
Smaller retry is allowed. If W1 committed in transaction A and W3 fails in
later transaction B, A's actual custody/inventory remains; B cannot erase
it. Repeating a live W1 can add genuinely new payout only; repeating W2/W3
cannot consume previously debited inventory. A burned W1 repeat is a real
rejection, not an always-successful fallback.

These atomicity requirements come from P/MIG-P14 and section 5.6 and the
source's reverting calls. Phase01 snapshot restoration is not represented
as an executed failing-middle-item Migration batch test. Integrated
atomicity, current/former owner, postactivation operation, malicious callback,
approval cleanup, protected backing, residuals and donation proof remain
the implementation/verifier lane's work.

## 7. Existing executed witnesses and exact limits

The following are **local fork** transactions in E4, not public-chain
transaction claims. The caller/receiver is EOA custodian
`0x000000000000000000000000000000000000c057`; there is no parent-owner
impersonation in these positive calls.

| Witness | Transaction / actual result |
| --- | --- |
| ID 3 approved whole custody | `0x0f344ce9310c30f5a50be14b9f69a7ba2110deb33254a612ff6a3f92b1fc043e`, status 1, owner becomes custodian |
| ID 3 `claimBond(3,custodian)` | `0x40049b8b180aaf28d770b96a0b607bce5cd181b3efa5489b00cfa60db9c27cb8`, status 1; **3,772,281,649 principal + 536,524,556 reward = 4,308,806,205 Receipt**, corroborated by actual Transfer and BondClaimed |
| Burned ID 3 repeat | `0xf0fdd29fd4e84f962ba8640d132a5ebb42c6fb3b15452fb42d8431e79c0d9eb9`, status 0; zero owner and nonexistent-position rejection |
| Direct W2 unstake | `0xc5fdef1e066063b549f98c2f9d4508726f3e20b6f65303f42dc0de89eebac6eb`, status 1; **4,308,806,205 Receipt -> 4,308,806,205 OldDetf**, recipient custodian, false pretransfer |
| W3 conversion | `0x8e20f225db3d277f59b1950224f075c2b8ba1198d475d2308297cb283d9caffc`, status 1; input **4,308,806,205 OldDetf**, actual **24,312,424,763,253,115,621,623 Dtf** to custodian |
| Principal-only leaves reward-only NFT | `0x4f1b70c3cf0b3392db950f428d63dd6897b5362bb7358f367d4a44706f033d78`, status 1; principal equals claimedPrincipal, owner persists and reward gons remain |
| Approved operator redirection | `0xcadefebefd78638594f2c8a2434c08d6baf16e832708bc877a5387a960fafbce`, status 1; pays a stranger, retained as adverse source evidence |

The W3 fixture used zero minimum and a very large deadline to establish
source execution; those inputs are not a recommended operational slippage
policy. Its exact call input, self-token approval, nested Dtf transfers and
final receiver are decoded in the audit. Fixture output is not a promised
future quote. N2 independently established the genuine Migration custody
precondition and kept six removed administration selectors absent after
activation; it did not execute W1-W4 from that proxy.

## 8. Prerequisites, remaining gates and cleanup

**Source prerequisite result:** W1-W3 need actual surrendered custody,
sufficient booked input and successful live source dependencies. No additional
legacy operator/parent permission is required. Partial/mature/repeated
semantics and return/recipient/rounding facts are specified from the exact
archive, with executed witnesses distinguished above.

**Concrete implementation prerequisite:** the pinned baseline has custody and
consumption records but no admitted installed owner-only weighted recovery
surface or recovery inventory/donation bridge. Implement and prove that
surface through the real registry proxy, including index-isolated Receipt
measurement. Do not impersonate MIG to manufacture that proof. Fresh source
binding, actual final reserve routes and operational minimums remain inputs
to execution, not permission to alter source policy.

This contract closes no all-source task8 claim. Earlier NFT disabled mature
conversion/receipt exits and masked wrong-owner close remain separate;
fungible E2 attribution, TokenStaking caller composition, restricted LP exits,
all remaining source/harvest/donation rows, complete-product payout/surface
checks, reviewed operational allocations, operator/resume rehearsal and final
release gates remain open. Harvest creates no personal credit, ordinary bond
or change to a delivered migration bond. No category is silently removed.

This lane authored only this file and `source-evidence.json`. It ran no
Forge compiler/test, RPC request, new fork transaction, public operation,
commit, dependency/config edit or delegation. No node, port 18555 or owned
temporary runtime root was started, so no owned runtime cleanup remains.
The available JSON LSP reports missing `biome`; no clean LSP result or
installation is claimed. Resident JSON parsing and the recorded offline
checks are the evidence validation. Prior phase01/04/05 evidence is unchanged.
