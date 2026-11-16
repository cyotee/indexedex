# Weighted NFT adapter contract

Date: 2026-11-11. **Disposition: ADMITTED for the weighted NFT source
adapter described here. No unresolved source fact prevents this NFT
surrender implementation.** Admission is not a claim that integrated
Migration surrender, receiver handling, issuance or recovery has been
implemented or tested. Those are the implementation lane's work, not
circular source prerequisites.

This is a behavioral/ABI contract, not Solidity production source. The
verified worktree is
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05`, branch
`work/dtf-migration-phase-05`, HEAD
`5021e8d4a62bcbddc555f580ef98f8666d993aab`. Initial
`git status --porcelain --ignore-submodules=all` was empty. Ignoring
submodules avoids Git's error on the existing warm-seed Crane symlink;
the symlink was not changed. The caller supplies the warm-seed exit-0
receipt; this lane independently verified branch, HEAD and clean status.

## 1. Evidence and exact code domain

The historical source domain is Robinhood **chain 4663**, block
**108944663** (`0x67e5d17`), hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
This is not the Migration funded pricing snapshot.

Evidence prefix **E** means the absolute directory
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/`.
These existing artifacts remain read-only:

| Reference | Artifact and use |
| --- | --- |
| E1 | `E/phase01-verification.md`, especially sections 1, 3 and 6: independent qualification of the old source matrix; missing future integration is not a source blocker. |
| E2 | `E/weighted/probe.results.json`: raw `rpc[]`, `selectors.nft[]`, `identity`, `reads.positions[]`, `history` and mined source transactions. |
| E3 | `E/weighted/probe.sources.json`: address-keyed archived ABI, source contents, on-chain runtime bytes and published recompiled bytes. |
| E4 | `E/weighted/deployed-source-extracts.json`, `source-state-summary.json`, `source-comparison.json`, `probe.historical-receipts.json` and `report.md`: source lines, original receipt joins, units and current/deployed differences. |
| E5 | `E/verification/weighted-replay.results.json`, `.sources.json` and `.exit.json`: independent pinned replay, actual receipts, exit 0, 34 PASS / 1 FAIL / 2 UNPROVEN. The FAIL is successful approved-operator redirection, not failed custody. |
| E6 | `E/earlier-cp/report.md`: the other collection uses LP accounting shares and must not use this fixed-principal adapter. |

The original plan was read completely at
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`,
revision `migration-detf-implementation-plan-r1`, including MIG-P01-P15,
sections 5.3-5.6 and 6, and all remaining full-plan gates.

[`archive-audit.json`](archive-audit.json) is the only new supporting
artifact. It records SHA-256 fingerprints of consumed archive files,
exact deployed source excerpts with original line numbers/source hashes,
all 14 archived NFT selector bindings, raw RPC journal indexes, selected
position fixtures and independent receipt identities. Its **385/385**
offline checks recompute selectors, compare archived ABI entries, hash
actual recorded code, compare published execution bodies after terminal
CBOR removal, decode all 47 owner/position/preview rows, and cross-check
the independent replay's source bytes and bindings. No existing successful
fork probe was repeated.

| Identity | Address | Runtime Keccak-256 |
| --- | --- | --- |
| Weighted collection | `0xFe4Cc6D5FaaFdF210AF4E728F4108FCaad9bb65E` | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |
| Generic ERC721 facet, G | `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279` | `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8` |
| Funded bond facet, B | `0x3a07364eabA092472d40F0e6788b8891A31faD4D` | `0x325a3b9bf3e616386e03d2a14d0a1fb29820f104a5f433d0b08a88dbdd0bef52` |

Collection code alone is insufficient: this proxy delegates through a
selector map. E2 raw historical `facetAddress(bytes4)` calls
(`0xcdffacc6`, address return) bind each selector below to G or B;
the corresponding pinned `eth_getCode` bytes equal E3's archived
`runtimeBytecode.onchainBytecode`. G is a Sourcify `match`, not a
full metadata `exact_match`; B is `exact_match`. Published recompiled
execution bodies match after removing their terminal CBOR metadata.
No compiler was invoked here and no independent recompilation is claimed.
Neither today's source file nor another proxy with the same code hash
may substitute for these bindings. Execution evidence for implementation
must retain this chain/header/collection/route/facet-code binding.

## 2. Exact legacy callable contract

All calls go to the **collection proxy**, never directly to a facet.
The adapter's required surrender calls are `ownerOf`, `positionOf` and
the **three-argument** `safeTransferFrom`. The approval calls belong to
the holder's setup; preview and claim calls are separately typed reads
and recovery operations, not steps that pay the surrendering user.

| Signature | Selector | Route | Exact ABI return |
| --- | --- | --- | --- |
| `ownerOf(uint256)` | `0x6352211e` | G | `address` |
| `positionOf(uint256)` | `0x46f96023` | B | One static tuple `(uint256 principal,uint256 claimedPrincipal,uint256 stakingGons,uint256 startTimestamp,uint256 vestingDuration)` |
| `previewClaim(uint256)` | `0xae648e90` | B | One static tuple `(uint256 vestedPrincipal,uint256 principalRemaining,uint256 principalDue,uint256 rewardsDue)` |
| `approve(address,uint256)` | `0x095ea7b3` | G | No return data |
| `getApproved(uint256)` | `0x081812fc` | G | `address` |
| `setApprovalForAll(address,bool)` | `0xa22cb465` | G | No return data |
| `isApprovedForAll(address,address)` | `0xe985e9c5` | G | `bool` |
| `safeTransferFrom(address,address,uint256)` | `0x42842e0e` | B | No return data |
| `transferFrom(address,address,uint256)` | `0x23b872dd` | B | No return data; source-supported alternative, not the selected safe custody call |
| `claimPrincipal(uint256,address)` | `0xf400c743` | B | `uint256 principal_` |
| `claimRewards(uint256,address)` | `0x6c7b69cb` | B | `uint256 rewards_` |
| `claimBond(uint256,address)` | `0x084c59ae` | B | Two separate outputs `(uint256 principal_,uint256 rewards_)` |

The two read tuples occupy **160 bytes** and **128 bytes** respectively:
all fields are static, with no leading dynamic offset. A typed local
legacy interface must preserve the field order and widths. Do not import
a current interface on the assumption that its return layout matches.
No four-argument safe-transfer selector is required by this contract.
The audit also retains `detf()` and `lpToken()` bindings for provenance;
neither is needed to compute eligible units or pull the NFT.

Source anchors refer to E3's **unescaped source content**, not current
repository lines:

* B `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol`
  lines 127-140: reads; 142-200: claims, authorization and retirement;
  210-243: actual guarded transfers, existence and recipient checks.
* B `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol`
  lines 28-43: tuple declarations; 96-117: principal/reward arithmetic.
* B `lib/crane/contracts/tokens/ERC721/ERC721Repo.sol`
  lines 153-170 and 199-215: receiver order/data; 229-254:
  authorization, approval deletion and ownership update; 281-291:
  approval authorization and zero-operator rejection.
* G flattened `ERC721Facet.sol` lines 2754-2756, 2813-2815,
  2827-2829, 2840-2842 and 2854-2856: owner and approval reads/writes.

These exact excerpts and hashes are in `archive-audit.json.sourceRanges`.

## 3. Units and remaining-principal admission

`principal` is the **original fixed DETF principal**, in native
**9-decimal** legacy DETF-equivalent units. `claimedPrincipal` is actual
principal already paid, in the same units. `stakingGons` is internal
ownership inventory, not principal and not an 18-decimal contribution.
Timestamps/durations are seconds. Claim principal and rewards are paid
in native 9-decimal legacy **sDETF**, not directly in DTF.
The observed legacy DETF and sDETF identities are respectively
`0x4a5cFDC2b07016FCf917f4eD5A51C52111A0fcC7` and
`0x4Fa4974a8a09660258B8edD430B51C1620eBFE5c`
(E2/E5 token reads and actual claim receipt).

For a configured original entitlement:

```text
P0 = verified original principal, matching positionOf(id).principal
Pc = positionOf(id).claimedPrincipal at surrender
Pr = P0 - Pc
C0 = stored frozen quote(original ETH) + frozen quote(original DTF)

require configured and original contributions known
require id >= 3 and P0 > 0 and Pc <= P0 and 0 < Pr <= P0
deliveredCredit = fullPrecisionMulDiv(C0, Pr, P0), rounding down
require deliveredCredit > 0 and deliveredCredit >= caller minimum
```

The new credit is native **9-decimal new DETF**. Original ETH/DTF quote
inputs remain native 18-decimal integers. Do not scale the principal
fraction by `1e9` or `1e18`; numerator and denominator already share a
unit. Do not re-quote reduced contributions, use current redemption
value, add rewards, or use `principalDue` as `Pr`.

E2 `history.purchases[]` and E4 historical receipts bind 43 purchased
IDs 3-45 to `BondPurchased` original principals; seven post-incident
claim receipts distinguish principal from reward. Configuration supplies
verified original contributions, not user-selected surrender quantities.
The source does not expose original ETH/DTF contribution amounts through
`positionOf`. An unknown contribution must reject configuration rather
than become zero. IDs 44-45 are post-incident purchases: their existence
is a source fixture, not authorization for a compensation allocation.

Pinned examples, redecoded from E2's raw historical return bytes:

| ID | Original P0 | Claimed Pc | Remaining Pr | Due now |
| --- | ---: | ---: | ---: | ---: |
| 4 | 281387179 | 0 | 281387179 | 86292556 |
| 26 | 56299 | 0 | 56299 | 16976 |
| 32 | 54436459 | 8071216 | 46365243 | 8249343 |
| 34 | 59081498 | 7942358 | 51139140 | 51139140 |
| 36 | 1642192630 | 3247321 | 1638945309 | 488108181 |

Thus locked principal remains eligible. ID 26's pinned holder is
`0x2e69E40C4a4Ab5CA6826850F347acf8076a8063e`, not its original purchaser.
Use **current** ownership at surrender, not that historical address.

Reserved IDs 0-2 have no purchased principal. IDs 25 and 42 are burned
at the pin; 46 is nonexistent. Their `ownerOf` returns zero, whereas
their position/preview calls revert `ERC721NonexistentToken(uint256)`
(`0x7e273289`). Treat both outcomes as ineligible; do not assume
OpenZeppelin-style `ownerOf` reverting. E5's
`reward_only_source_persists_after_principal` pays ID 3's principal and
leaves an extant NFT with `principal == claimedPrincipal == 3772281649`
and nonzero reward gons. That NFT receives **no** migration credit.
Existence, rewards or approved configuration alone cannot prove eligibility.

## 4. Current holder, safe custody and callback order

The persistent Migration entrypoint is holder-initiated. In one guarded
operation it must perform the following:

1. Check deadline, admitted collection/source, complete configuration and
   unused `(collection,id)` identity. Read live `ownerOf`; require nonzero
   and **equal to the entrypoint caller**. Bind the new bond beneficiary
   to that holder, with no arbitrary recipient argument.
2. Read the exact position, match P0 to the verified configured original,
   validate Pc/Pr and compute the stored-quote fraction above. Reject
   zero credit before committing custody or consumption.
3. Establish a one-operation expected receiver context, then call
   `safeTransferFrom(holder,address(this),id)` from the actual Migration
   proxy. The holder must previously have approved **that proxy**, either
   per-token or as its operator. Approval is pull authority, not authority
   to choose a different migration beneficiary.
4. Accept exactly the expected collection, ID and holder callback, once.
   For this selected call its `operator` is the Migration proxy,
   `from` is the holder and `data` is empty. The receiver returns
   `0x150b7a02` for
   `onERC721Received(address,address,uint256,bytes)`. It only records
   acceptance; it does not issue, harvest, activate, configure, redirect
   or recursively surrender.
5. After the transfer returns, require callback acceptance, then verify
   `ownerOf(id) == address(this)` and unchanged position terms/claimed
   principal/gons. Only now treat custody as complete. Clear the expected
   receiver context and record permanent consumption plus custody and
   delivered-credit facts under the same guard.
6. Use the genuine Migration exact-funded issuance path to create one
   fresh bond for that bound holder, with deliveredCredit as principal
   and a new 90-day cliff starting at its actual creation. Complete all
   operation-local bookkeeping atomically. Any failed transfer,
   postcondition, funding, child operation or receiver callback reverts
   the complete transaction, including consumption and custody.

**Source-specific receiver order:** E3 B's `ERC721Repo.sol:153-170`
calls the receiver **before** `_transferFrom`. Ownership still belongs
to `from` during the callback, and transfer authorization is also checked
after that callback (`:229-254`). Therefore a receiver that requires
`ownerOf(id) == Migration` inside the callback will reject valid custody.
A callback alone cannot prove a completed or authorized transfer.
Validate the expected context there and ownership after return.
This rule is established by archived code; no new fork is needed to
rediscover it. The new production receiver still needs integrated proof.

The routed B transfers are `synchronized nonReentrant`, not the generic
G transfer bodies. `synchronized` first calls the **legacy** DETF's
`synchronizeRewards` (`DETFFundedBondTarget.sol:45-48`), so external
legacy work precedes the receiver. The Migration guard and expected
context must cover the entire external call. Despite the transfer
comment, its body does not call per-position `_claim`; the real custody
receipt and before/after five-field position establish unchanged
principal/claimedPrincipal/gons. Do not claim a transfer pays the
holder's bond rewards.

Safe transfer deletes the per-token approval (`ERC721Repo.sol:249`).
Old owner-wide approvals remain keyed to the **old owner**, not the
new custodian. Migration must never grant legacy operators approval
over recovery NFTs. Do not add an `approve(address(0),id)` cleanup call:
this deployed approval implementation rejects a zero operator
(`:281-291`); transfer itself clears the token approval.
Reject unsolicited safe callbacks outside an expected operation.
An unsolicited unsafe transfer creates no consumption or compensation.

## 5. Operator redirection and recovery identity

E3 B `_claim:163-187` authorizes current owner **or** token approval
**or** owner-wide operator, accepts an arbitrary permitted nonzero
recipient, increments only principal paid and debits principal plus
reward gons. E5's actual operator transaction
`0xcadefebefd78638594f2c8a2434c08d6baf16e832708bc877a5387a960fafbce`
succeeds and pays `4308806205` raw sDETF to a stranger.
Legacy approval therefore cannot authenticate a Migration beneficiary.
An approved operator whose address differs from `ownerOf` must fail
the Migration entrypoint, even if it can make legacy calls.
This does not revoke the authority the legacy owner already granted:
an authorized legacy transfer can change who the current holder is.

The immutable recovery record binds chain/source kind/collection/ID,
original configuration/evidence identity, surrendering holder, measured
P0/Pc/Pr, delivered credit, new bond ID and **Migration proxy custody**.
Keep this distinct from replaceable loading configuration. Within one
instance the key is collection plus ID, never ID alone; external evidence
and any commitments also bind chain, Migration proxy and snapshot.
Full replacement after consumption cannot reopen credit, resize a
delivered bond or redirect the already-held NFT.

Holding the NFT conveys all its remaining principal and reward rights.
Recovery later calls the typed legacy claim from Migration as current
owner, always fixing its recipient to **Migration custody**, not to
the former holder, caller, fee recipient or legacy operator.
`claimBond(id,address(this))` returns principal and rewards separately,
and can leave a partially vested NFT alive. `claimPrincipal` and
`claimRewards` have the distinct outputs in section 2. E3
`_checkRecipient:239-242` rejects zero, the legacy DETF and the legacy
collection itself; a distinct Migration proxy is not one of those
forbidden identities. E5 proves claims after new-owner custody.
The zero-recipient owner-default behavior must not become a caller
option in the recovery API.

Recovery is current-Migration-owner-only, bounded and separately
accounted. Measure newly received legacy sDETF, distinguish claimed
principal from reward, and retain staged assets and operation-local
deltas. Legacy burn after complete payout does not erase the persistent
consumed identity. Do not attempt another position read as if the NFT
must survive a full claim. Legacy receipt/DETF/DTF conversion remains
a separate typed route, not a second award or an arbitrary executor.
This NFT contract adds no new conversion ABI; existing conversion proofs
do not close the remaining full recovery implementation.

Whole surrender consumes the whole original NFT entitlement once.
`C0 - deliveredCredit` is **not** a residual claim on that NFT.
Previously withdrawn principal, its liquid/receipt/SY descendants and
overlapping independent allocations acquire no new credit from this
adapter. Configuration must keep distinct original exposure disjoint;
the adapter does not manufacture an authenticated fungible-history
verifier or silently pay descendants. Harvested amounts likewise do
not resize the new bond.

## 6. Admission evidence and implementation obligations

Selected E5 mined receipts, all retained in the audit:

| Observation | Transaction | Result |
| --- | --- | --- |
| Approved whole-NFT custody, ID 3 | `0x0f344ce9310c30f5a50be14b9f69a7ba2110deb33254a612ff6a3f92b1fc043e` | Status 1; new owner is custodian; all five position fields unchanged. |
| Custodied ID 3 claim | `0x40049b8b180aaf28d770b96a0b607bce5cd181b3efa5489b00cfa60db9c27cb8` | Status 1; sDETF delta 4308806205; burn and later position rejection. |
| Failed nonreceiver transfer | `0xc91c76fb89632f6b8fc60c311d47fbee4b4246a58f0c1454aa9385af4fa04baf` | Status 0; owner unchanged. |
| Principal-only claim leaving reward-only NFT | `0x4f1b70c3cf0b3392db950f428d63dd6897b5362bb7358f367d4a44706f033d78` | Status 1; remaining principal zero, owner persists. |

These are historical **local fork** transactions, not public-chain
transaction claims and not a deployed Migration receiver demonstration.
They establish the usable source primitives. The implementer must still
prove real pinned-legacy-to-registry-Migration custody, callback ordering,
partial-principal credit, holder changes, operator rejection, once-only
identity consumption, fresh exact-funded bonds, zero-credit/burned/
reward-only rejection, full rollback, configuration replacement and
persistent postactivation surrender. Remove all new loading selectors
through actual activation cuts; do not add postactivation transfer approval.

All non-NFT full-plan gates remain open. In particular this admission
does not close fungible E2 attribution, TokenStaking caller composition,
LP liquidation/harvest, complete recovery/donation, real operational
configuration, operator resume/rehearsal or full release verification.
The earlier NFT remains a separate required adapter; its mature exit's
disabled-SE failure is neither repaired nor hidden by weighted admission.
No category, original entitlement rule, source policy, phase03 r3
accounting or phase04 core evidence is changed.

## 7. Validation and cleanup

This lane performed only local archived-byte/source inspection and the
385 passing offline checks recorded above. There were **zero RPC
requests, zero new fork transactions and no Forge compiler**. Existing
source probes were not repeated. It started no node, used no port 18549,
and created no owned temporary runtime root, so no runtime cleanup
remains. E5's existing cleanup records base-snapshot restoration,
Anvil exit 0, PID gone, port closed and run-root removed.

Only this file and `archive-audit.json` are authored by this lane.
JSON structural validation is performed with the resident parser;
Biome diagnostics are unavailable because the configured Biome server
is not installed. No dependency/configuration installation or edit is
needed for this evidence-only artifact. Production, test, source-policy
and earlier evidence files remain untouched. No commit, delegation,
public transaction or main/integration operation was performed.
