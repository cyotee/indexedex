# Earlier LP-lock NFT: admitted adapter contract

Date: 2026-11-11. Scope: source contract for the earlier NFT lane only.

**Admit the current-holder/original-LP-share read and whole-NFT custody
primitives for implementation.** A live purchased user lock retains its full
original accounting shares after reward claims and transfers. Successful sale
removes those shares and burns the user identity. Consequently the admitted
fraction is **one for a live, nonempty, authenticated original user lock; no
award for a sold, burned, absent, reserved or zero-original-share identity**.
There is no earlier-NFT `claimedPrincipal` field to subtract.

This is not full source acceptance, successful harvest, or integrated Migration
acceptance. The next node implements and proves the actual registry-deployed
Migration receiver, consumption and funded-bond path. Their absence here is not
a source blocker.

## 1. Provenance and authentication boundary

Worktree: `/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-05`.
Independently observed branch `work/dtf-migration-phase-05` and HEAD
`5021e8d4a62bcbddc555f580ef98f8666d993aab`; the named commit resolves to that
same object. Initial status was clean with submodule inspection excluded.
Plain status first failed on the already-linked `lib/crane`; nothing was
changed to repair or replace that warm dependency. Root reported warm-seed exit
0; this lane did not seed or compile.

The execution-evidence pin is Robinhood **chain 4663, block 108944663**
(`0x67e5d17`), hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`,
state root
`0xb1f528ad90e54a44bcde0886f181c790b65647d9256d743596f2f9623a6b2071`.
Both reused historical runs have `freshFallback=false`. This is not the new
instance's funded quote snapshot.

The retained input root, abbreviated **P1**, is:

`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/`

Authoritative inputs are `P1/phase01-verification.md`,
`P1/earlier-cp/report.md`, `P1/earlier-cp/probe-alchemy-retry.source.json`,
`P1/earlier-cp/probe-alchemy-retry.json`, and the independent
`P1/verification/cp-replay.json` plus `cp-replay.exit.json`.
The complete original implementation plan was read at
`/Users/cyotee/Projects/indexedex/docs/incidents/2026-09-16-dtf-recovery/MIGRATION_DETF_IMPLEMENTATION_AND_TEST_PLAN.md`.
Its MIG-P01 through MIG-P15 remain binding. Phase01 weighted evidence was read
to distinguish its fixed-principal model; phase04 corrected-core evidence was
read without changing it or the accepted phase03 r3 accounting.

[source-evidence.json](source-evidence.json) records input SHA-256 fingerprints,
exact ABI entries, loupe bindings, recomputed runtime identities, verbatim
source extracts, selected position/purchase observations, mined transaction
locators and the 50-check local archive audit. Source line references below
mean the **unescaped flattened `sources[file].content`**, not JSON line numbers
and not current repository Solidity.

| Identity | Address | Runtime Keccak-256 |
| --- | --- | --- |
| Earlier NFT proxy | `0x15666F0b4C8D09d046d2Aa9048aFcAF49e8cB391` | `0x2393ee3dc4d7877a9bfb7b59c272f2b9b0d1df92f2dc82ee67df076a99836601` |
| Position and transfer facet, `DETFNFTVaultFacet` | `0x3AB85813785b43B864F9C171F7ac97d6B76c459b` | `0xe44c05ff19808e8e7096c7e470cb1d40ddaf057f4e53818f1e749621d3632027` |
| Owner/approval facet, `ERC721Facet` | `0xde5a691CEFE1830e8Ff2b65F6657738b0d9B9279` | `0xf709b5311471ef0b02cf7ddaa8f48b9da30647ab9958a3efde1813e5ac4337b8` |

For both consumed facets the archived observed runtime equals Sourcify's
on-chain bytes; the runtime hash was recomputed here. Archived recompiled
execution bodies equal observed bodies after removing terminal CBOR metadata.
Sourcify labels both **`match`, not `exact_match`**. This uses the archived
service recompilation; no compiler was run here. The shared proxy hash alone
does not authenticate any selector, tuple or transitive dependency.

## 2. Exact consumed ABI and units

The minimal surrender adapter consumes the following three calls on the fixed
earlier collection, not on a caller-selected contract:

```solidity
struct EarlierPosition {
    uint256 originalShares;
    uint256 effectiveShares;
    uint256 bonusMultiplier;
    uint256 unlockTime;
    uint256 rewardDebt;
}

function ownerOf(uint256 tokenId) external view returns (address);
function getPosition(uint256 tokenId)
    external view returns (EarlierPosition memory);
function safeTransferFrom(address from, address to, uint256 tokenId) external;
```

This is an ABI specification, not a new production interface file.

| Signature | Selector | Pinned facet | Return and use |
| --- | --- | --- | --- |
| `ownerOf(uint256)` | `0x6352211e` | ERC721 facet above | One ABI address word. Explicitly reject zero; this source returns zero rather than necessarily reverting for absence. |
| `getPosition(uint256)` | `0xeb02c301` | NFT facet above | One static tuple: five `uint256` words, exactly in the displayed order; 160 bytes. Read the first word as eligible accounting units. |
| `safeTransferFrom(address,address,uint256)` | `0x42842e0e` | NFT facet above | No return value. Migration calls with `from=currentHolder`, `to=Migration`, whole ID, zero native value. Verify ownership after return. |

Corroborating `originalSharesOf(uint256)` is `0x0f3767df`, one `uint256`
from the NFT facet; it reads the same mapping as tuple word zero.
`transferFrom(address,address,uint256)` is `0x23b872dd`, no return, also
on the NFT facet. Its successful historical receipts establish whole-identity
custody; they must not be described as successful receiver-callback executions.
The implementation contract above selects the three-argument safe transfer,
whose contract-receiver success must be exercised by the integrated next node.

Holder preparation uses `approve(address,uint256)` (`0x095ea7b3`) or
`setApprovalForAll(address,bool)` (`0xa22cb465`), routed to the ERC721 facet.
`getApproved(uint256)` is `0x081812fc`; `isApprovedForAll(address,address)`
is `0xe985e9c5`, returning address/bool respectively. These are allowance and
fixture surfaces, not additional eligibility or beneficiary authority.

Source anchors: `DETFNFTVaultFacet.sol:14305-14311` defines the tuple;
`:16135-16143`, `:16556-16558`, `:16643-16669` construct/read it.
`ERC721Facet.sol:2754-2756` reads the owner. NFT
`:16982-17001` supplies the actual transfer overrides. The deployed
`positionOf(uint256)` alias must not be decoded with the weighted collection's
five-field fixed-principal layout merely because its selector matches.

Units are not interchangeable:

| Quantity | Meaning |
| --- | --- |
| `originalShares` | Raw original LP accounting shares; the migration fraction's numerator and authenticated purchase baseline. No decimal rescaling is needed for their ratio. |
| `effectiveShares` | Reward weight, including separate effective base and lock bonus; never eligible principal. |
| `bonusMultiplier` | WAD-scaled reward multiplier, not extra original contribution. |
| `unlockTime` | Unix seconds; governs legacy exits, not eligibility for surrender. |
| `rewardDebt` | Paid reward-per-share checkpoint; not withdrawn principal and not an old-DETF balance to subtract. |
| `convertToAssets(originalShares)` | Current physical LP entitlement, subject to reserve/share conversion and rounding; not the original-share fraction or contribution quote. |

Pinned old liquid DETF/reward token is
`0xaf0E1967c8F755c747615c5427108Bc549CA1122` (18 decimals).
Physical fungible LP is
`0x923877336b14662cFb5B3A60b14e7d716d54A888` (18 decimals).
Receipt is `0x4AC89aD061A531FA62ddceED53520C2750113b01` (18 displayed
decimals, source-specific rebasing share conversions). None is this NFT's
`originalShares`, historical contribution DTF, or the new native 9-decimal
DETF credit. For example, NFT 12 has `47848240999749918187208884` accounting
shares but `47848240999749918187208985` observed LP assets. Do not assume 1:1.
Source conversion anchor: NFT `:15787-15801`.

## 3. Eligibility and remaining-unit fraction

Configuration must identify `(chain 4663, collection, tokenId)` and authenticate
an original **user purchase** with original ETH/DTF components and the original
`NewLock.shares` baseline `S0`. The archived event is
`NewLock(uint256,address,uint256,uint256,uint256)` with indexed ID/recipient;
it is emitted at NFT `:16254`. All 16 receipts, IDs 3-18, match their canonical
block hash and recorded original shares in both reused historical runs.
Recipient-at-purchase is not a permanent holder restriction.

At surrender, read `holder=ownerOf(id)` and `Sr=getPosition(id).originalShares`
inside the protected operation:

```text
require configured authenticated original user purchase, not reserved ID 0/1/2
require holder != 0 and msg.sender == holder
require identity not consumed
require S0 > 0 and Sr > 0
require Sr == S0 for this admitted earlier user-lock source
deliveredCredit = mulDiv(originalFrozenCredit, Sr, S0)
require deliveredCredit > 0 and >= caller minimum; enforce caller deadline
```

Thus an admitted live earlier lock delivers its original frozen credit
(`Sr/S0=1`). Sold/burned/absent/empty identities fail; there is no fractional
award to issue for them. A positive mismatch with authenticated `S0` is an
evidence/source inconsistency to reject, **not** evidence of an undocumented
partial-withdrawal API. Do not clamp it, manufacture `claimedPrincipal`,
substitute a weighted adapter, or interpret changed LP assets as changed units.

**Source observation:** user creation records original and effective units
separately (`:16206-16254`, `:15566-15581`). Rewards do not remove original
shares (`:16413-16425`). Mature retirement and sale delete the entire position
and burn it (`:16377-16404`, `:16500-16546`, `:15593-15601`).
Partial share debit/add methods are restricted to the protocol NFT
(`:16463-16495`); reserve donation credits that protocol ID (`:16922-16929`).
There is no admitted user partial-principal decrement in these paths.
**Inference:** for authenticated user locks in this source, remaining eligible
units are binary original-or-absent, rather than weighted fixed principal
minus withdrawn principal.

| Observed state | Eligibility |
| --- | --- |
| NFT 3: original `562524912595035608166`, effective `843787368892553412249`, unlock `1803205295` | Still locked but full original units remain; custody succeeds. Do not require `isUnlocked`. |
| NFT 4 before/after reward claim: original `2281854312954086546` unchanged; reward received `309005608995105` raw old DETF | Full fraction remains. Neither reward output nor changed reward debt increases/reduces credit. |
| NFT 4 after successful sale | Owner zero and all five fields zero; no NFT credit or second sale. Receipt descendant is not automatically another entitlement. |
| Standing ID 1: original zero, effective `21514144891010951919251332737340123`, positive pending rewards | Reward-only, zero eligible units; reject even though owner and reward weight are nonzero. ID 2 is also zero-original-share. |
| Reserved protocol ID 0 | Positive shares do not make protocol inventory an authenticated user purchase; reject. |
| Absent ID 19; close tested with ID 999999 | Zero owner/position or failed legacy operation is not eligibility; reject before custody. |

Compute original credit once from verified original ETH/DTF on the accepted
frozen book. Never re-quote partial inputs or use live redemption value.
For NFT 3 the original direct input was `2000000000000000000` WETH;
`1778859964387451305574664` routed DTF was intermediate output, not a second
contribution. NFT 4 directly contributed `7215852540309913726431` DTF;
reserve settlement `3703818` was not extra principal.
Unknown input is not zero. Baseline replacement must not alter already
delivered bonds, restore consumption, or redirect held custody.

## 4. Caller, custody and callback contract

The claimant must be the current NFT holder, not merely a legacy approved
operator. The original payer, an administrator or an operator cannot choose
another new-bond recipient. The holder approves the **Migration proxy** to
pull; its external call executes with Migration as source `msg.sender`.
The source accepts owner, token approval or holder-wide approval
(`NFT :13541-13566`), then clears token-specific approval on transfer.
Migration must not approve legacy operators over held NFTs.

The safe-transfer override rejects only transfer to the stored **old DETF
parent**, not every contract recipient (`:16989-16994`). A distinct new
Migration proxy is not that old parent.

**Receiver ordering is significant:** this deployed ERC721 calls
`onERC721Received` **before** `_transferFrom` changes ownership
(`:13465-13482`, `:13525-13527`), unlike an assumption that the receiver already
owns the NFT during its callback. For the selected pull, callback sender is
the collection, operator is Migration, `from` is the captured holder, ID is the
expected ID, and data is empty. Accept only that in-flight expected operation
and return `0x150b7a02`. Do not issue from the callback or require
`ownerOf(id)==Migration` inside it. Keep the shared operation guard active.
After safe transfer returns, require `ownerOf(id)==Migration` and re-read the
same original units; reject unexpected mutation or short custody.

Consume the entire `(collection,id)` identity once, preserve it independently
of replaceable configuration, and create an exactly funded fresh 90-day
Migration bond for the captured holder. Custody, consumption, new issuance,
child funding and any receiver failure must share one transaction's rollback.
No harvest, sale or claim is needed inside surrender. Unsolicited transfers
are not surrender and must not earn a bond. The retained surrender path
must remain usable after activation without discretionary source updates.

These are requirements for the next implementation, not assertions that its
receiver, activation routing or bond integration has already passed.

## 5. Pinned execution coverage and remaining limitations

Both the producer historical retry and the independent historical replay
contain **24 mined local transactions: 10 successful, 14 reverted**.
The independent invocation exited **2**, retaining **18 PASS, 2 FAIL,
4 UNPROVEN**; its whole-source outcome remains UNPROVEN, not green.
Selected producer transaction locators:

| Observation | Transaction hash / result |
| --- | --- |
| NFT 4 whole custody | `0x3e3b2b3d5ad372acb94c7f5b2af467e4aba3a310be6b0fdd06316d909953e398`, status 1 |
| NFT 4 reward claim after custody | `0x5dfa0bfd67a8a62b6db4867245de7a3e2332195d97a75219bc0b6dd6e9ca1d45`, status 1; original units unchanged |
| NFT 4 sale/retirement | `0x3d54621af7e5dff968aed64f3639d0222170d962ead7c80339f39a33ede46042`, status 1; owner/position cleared |
| NFT 3 locked custody | `0x3e722c66a2030af0181fc0fcd4195abff50f3bd832c9b0bbb91c5179910f9056`, status 1; original units/lock unchanged |
| NFT 3 early sale | `0xddaf9a56d8cc5830a56551bd3aa26511e90bad5b7c59fa26f1c58ad5c4e922b8`, status 0 |
| Safe transfer to nonreceiver | `0xc9aef14f6f8caba0b2bb65a13a447c4d72f08e8a4b5c913772b4353a977ee978`, status 0; recorded state/approval rollback |
| NFT 4 mature close | `0x61fb08ec01b576756fa25ae3ab9631613f140471c843576a2eac3774a7ff37a1`, status 0; disabled-SE error |

These are local-fork transactions rooted at the historical pin, not public-chain
transactions at that block. Holder impersonation was fixture setup, not
authority over legacy infrastructure. Positive custodies used holder
`transferFrom` into the local recovery account. Earlier-NFT approved safe pull
into a real Migration contract and successful receiver behavior remain the
next node's integrated proof, not a replay performed here.

The missing-source facet
`0x67ed019eC3f8b77Bc51ED1e6403Fc90E0aBb15bE`, runtime
`0xa289425ebf221bd44551376c3459083a4d53eb30f485b48e783bf8291f7a05d6`,
returned archived Sourcify HTTP 404. It is routed on the **old DETF proxy**,
for selectors `0x6a4d3f12`, `0xf5ee7c5b`, `0x36abf3dc`, `0x7cc34bb4`,
not for the consumed NFT selectors. Owner/position reads are direct NFT storage
reads. Transfer uses the authenticated NFT facet's internal ERC721 code and,
for safe transfer, the selected recipient callback; it does not call that
missing DETF facet. Therefore its missing source **does not block these exact
reads/custody primitives**. This does not authenticate every old DETF route
or transitive harvest dependency.

Mature close and receipt redemption still reach
`VaultDisabled(0xb7D4Bb379d361aD442Cddee53EA71A33957826A7)`,
selector `0x1ba84b43`. Wrong-owner mature-close testing reaches the same
disable check, so authorization is **masked and open**, not PASS. This lane
does not enable the vault, promise harvest proceeds, or authorize recovery
through an unverified alternative. Successful sale to receipt proves a
representation transition; it does not close receipt redemption or create
independent descendant credit.

All non-NFT full-plan gates remain open under their existing dispositions:
fungible attribution/ancestry and nonduplication, TokenStaking composition,
fungible LP and SE recovery, full harvest, complete ordinary/payout/activation
coverage, operators and final integration. No category is omitted, and no
postactivation trusted source/attribution policy is added. Earlier and weighted
NFTs remain separate adapters.

## 6. Verification and runtime disposition

The local archive audit recomputed selectors, both consumed facet hashes,
archived on-chain byte equality and execution-body equality, checked all 16
purchase/share baselines in both historical runs, reward-share preservation,
sale clearing, transaction counts and recorded cleanup: **50 checks, zero
failures**. Verbatim source extracts and exact ABIs are retained alongside
this contract so the consuming source gate need not infer them from prose.

No new RPC request, Anvil, compiler, test suite, production/test source,
configuration/dependency edit, commit, delegation or public action occurred.
Port 18550 was not acquired; no temporary runtime directories were created and
no owned node remains. The initial three read-only Git sessions exited 128, 0
and 0; final branch/status/diff verification exited 0. The first failure was
the linked-submodule status issue described above.
Saved historical runs recorded snapshot restoration, node exit, closed
endpoints and removed runtime roots. Shared caches and evidence were preserved.

JSON language-server diagnostics were unavailable because `biome` is not
installed; no installation or configuration change is authorized. JSON parsed
successfully, and final validation passed 36 checks covering 17 verbatim
extracts, nine selectors, eight unchanged input fingerprints, the evidence
link and exact earlier output filenames. `git diff --check` passed; no tracked
file changed. Only `contract.md` and `source-evidence.json` were written by this
lane. A concurrently appearing `nft/weighted/archive-audit.json` was left
untouched. Final branch and HEAD remain the identities recorded in section 1.
