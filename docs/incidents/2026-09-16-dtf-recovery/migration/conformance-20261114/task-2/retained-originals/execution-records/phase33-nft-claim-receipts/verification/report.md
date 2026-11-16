# Phase33 independent named NFT claim receipt verification

Date: November 13, 2026.

**Verdict: confirmed for the complete bounded 23-record stopped handoff.
No needs-fix producer evidence or reconciliation defect was established.**
The independent live collector acquired exactly the 16 missing transactions,
reused seven authenticated phase30 receipts without recollecting them, and
stopped with exit 0. The independent raw proof and its final read-only
reproduction both exited 0. All 23 actual BondClaimed events establish separate
principal/reward amounts and match one exact sDETF payout each. Seven are
reward-only claims. Actual Transfer-to-zero logs prove retirement of NFTs 25
and 42. Their unavailable current position fields remain unknown.

This verdict does not establish complete claim history, source admission,
original economic contributions, financial authority, eligibility, descendant
control, C0 or any migration deduction.

## 1. Subject, authority and exact input identities

Subject is the stopped `source/` sibling of this `verification/` directory.
Only this verification directory was written. The complete phase33 brief,
actual producer report, scripts, source/event schemas, raw capture structures,
input/source manifests, command failures, cleanup and seal were inspected.
The current migration plan r5 sections 1 and 5 and PRD r22 establish the
original-wallet/configuration, native-unit, separate-reward and no-double-credit
boundaries. Historical frozen policy prose does not override those rules.

The current reader worktree is
`/Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-30-recovery-receipts`.
Its HEAD/packed branch references identify
`1694e68a4bd66dd67d3b5e3f145f1da23074ff48`; they were read without Git commands.
Actual current `candidate-input.ts`, `receipt-association.ts`,
`receipt-rpc.ts`, `provenance.ts` and `schema.ts` bodies are hash-bound,
not represented by a base hash alone. No clean-worktree claim is made.

The recovered original root is:

`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`

The independent intake authenticates sources.json against manifest.json before
using its declarations, then authenticates every one of the 36 declarations,
including complete Markdown and sibling bodies. There are 28 physical bodies
including manifest.json. These are hash-authenticated recovered bodies, not
newly located original captures. No frozen field or identity was rewritten.
S008 is the complete `evidence/weighted-bonds.csv`, 12,283 bytes, SHA-256
`f1f63c97dee2d6fbaa0f0148b3e602a312af79d018e3b8b56967764d9e3a24e9`.

An independently written CSV tokenizer derives all 43 rows, every original
field including blanks, and all 23 individual `claim_transactions` occurrences
on the actual `|` delimiter. There are 23 unique transaction hashes across
17 NFTs. Every occurrence retains logical row locator, collection, token ID
and one-based occurrence. No orientation reconciliation supplied that list.
Seven hashes occur in the accepted phase30 archive; 16 do not. None occurs in
the phase28 purchase archive.

The intake authenticates every producer manifest entry and direct seal binding,
the complete sealed file inventory, all 5,035 external binding occurrences,
and the accepted phase28/30, phase31 and joined-flow verification manifests and
direct seal bindings. Duplicate bindings are not additional independent sources.
The acquired `inputs.json` records all initial actual identities; final
`preservation.json` reauthenticates them with zero changes.

| Bound body | Bytes | SHA-256 |
| --- | ---: | --- |
| Producer report.md | 24850 | `26a34556d1f878da998fcc6d9aefe580b11ba25b5bc6a31338f922d524b09ece` |
| Producer seal.json | 2131 | `77b99347dcf36a228e845dbcea61ed2a34aa6e2dbb58c3e665784f47962315d3` |
| Producer manifest.json | 124315 | `798336e0f7ab521067e6b6342f3fb65493c3c290bb69db69f5ea5861657b03af` |
| Producer cleanup.json | 14590 | `015c002eb405c5831f31fcd8d5002650e844c189ce444b93f39df3d259f65c76` |
| Accepted phase28 actual/archive.json | 3848804 | `e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b` |
| Accepted phase30 actual/archive.json | 5917231 | `67a8cd97a26d0bfe4fc118469db605a9b0424e7b40c17fb977f6bd6990dfefc0` |
| Joined observed-recipient worksheet | 902872 | `ed8474ac3454453697308ce82adffebb8bbfe9d346050973e0753a46cf6af39e` |
| Archived weighted probe.sources.json | 6447942 | `1ed706355a0238847dba503c6c4b590812f9fb3fbe583fff04d15d32de920f4d` |
| Phase31 verification observations.json | 871902 | `31f957fb0821c63aaa7db8b8bcb404698b5294c0ca555b0bac37e420effbc956` |

The prior report bodies and their limitations are retained. Weighted purchase
IDs 19, 20, 23 and 42 keep their indirect-caller qualifications. The joined
review's separate indirect raw-claim and routed-comparison qualifications are
not erased by this claim-output match. Matching a purchase recipient is not
proof of the original economic payer.

## 2. Actual independent acquisition and wire proof

The sole successful live collector child ran from
**2026-11-13T11:30:48.791Z to 2026-11-13T11:30:55.699Z**, PID 82402,
exit 0, empty stderr. `acquire-01.command.json` records exact executable,
argv, CWD, source snapshots, actual close and stream identities.

Only the existing `robinhood_mainnet_alchemy` alias was used. Its exact
foundry.toml template is checked before the selected ALCHEMY_KEY is resolved.
No wallet keys, credential-bearing argv, alternate endpoint/provider,
redirect, retry, trace, range/log scan, storage query, override, signing or
transaction submission was used. Direct HTTPS is sequential, bounded by
20 seconds per request and a strict 67-request cap.

Before named requests, the collector authenticated chain 4663 and block
108944663 / `0x67e5d17`, hash
`0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733`.
Its ending request returns the entire same header, which also equals the
producer's retained ending header.

| Newly performed method | Requests |
| --- | ---: |
| eth_chainId | 1 |
| eth_getTransactionByHash | 16 |
| eth_getTransactionReceipt | 16 |
| eth_getBlockByHash | 16 |
| eth_getBlockByNumber, including both anchor reads | 18 |
| Total | 67 |

All 67 request and 67 safe raw response entities are retained in `http/`.
`http-manifest.json` binds ID, exact method/params, start/finish, status, entity
length, SHA-256, raw qualification and complete parsed result. There are zero
actual transport, HTTP, RPC, null-result, envelope or redaction failures in
this acquisition. Empty failure lists are explicit. Every HTTP file is
accounted for; each missing transaction has a standalone hash-named capture.
The final credential scan checks literal and URL-encoded selected-key values
without printing them.

For each of all 23 combined receipts the independent proof verifies exact
transaction/receipt hashes, sender/callee, block hash/number, transaction index,
canonical quantities, successful status, unique membership at that exact
full-block index, complete block-by-hash versus block-by-number equality and
the historical cutoff. All **96** claim-receipt logs pass exact transaction,
block and index associations, removed=false, address/topics/data shape and
strict unique log order.

The seven retained phase30 observations are authenticated against their
actual old raw requests/responses and prior chain/anchor, using 30 prior
captures including chain/anchor. Their archive result indices, conversion
references, raw root and old IDs remain explicit. They are not new RPC calls.
All 43 original purchase receipts are separately authenticated against 174
selected phase28 raw captures, with canonical checks on all **1,746** logs,
exact mint and BondPurchased terms. No old proof or full gate was replayed.

The 16 new independent complete normalized observations equal the producer's
corresponding observations; all seven reused observations and provenance also
match. The proof checks every producer claim/payout/retirement locator, all
native9 output logs, original mint/purchase locators and per-original totals.
Producer reconciliation is compared only after independent raw derivation.

This is same-provider observation, not independent-provider consensus,
signed-transaction reconstruction, HTTP framing capture, a receipt-root proof
or transaction-prefix execution authentication.

## 3. Actual deployed schema and bounded source meaning

Weighted NFT collection:
`0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e`.
Funded bond facet:
`0x3a07364eaba092472d40f0e6788b8891a31fad4d`.
sDETF:
`0x4fa4974a8a09660258b8edd430b51c1620ebfe5c`.
Staking facet:
`0xb7581fe833a2b2380dd786b345d61ffb734d36eb`.
Loupe:
`0x343590ed92498739225e351c27133bc2c11b91b9`.

The actual ABI and seven complete unescaped relevant archived source bodies
were inspected and independently bound to the original weighted source archive.
`schema-proof.json` retains their bodies, content hashes, ABI and each selected
historical source binding. It independently decodes the producer's actual
source-binding raw captures: **115** full runtime comparisons and **161**
selected facet/loupe route comparisons, five runtimes and seven routes at
each exact named canonical claim block. All match the inspected archives.
The verifier did not repeat those 276 code/view calls or broaden acquisition.

ClaimBond, claimPrincipal and claimRewards resolve to the funded bond facet;
sDETF transfer/decimals resolve to the staking facet; both facetAddress
self-routes match the archived loupe. These are end-of-block selected-surface
bindings, not proof of arbitrary inner execution or every historical route.
Current checkout source is not substituted for the deployed source.

The actual event is:

```solidity
event BondClaimed(
    uint256 indexed tokenId,
    address indexed recipient,
    uint256 principal,
    uint256 rewards
);
```

Topic:
`0xc9ce1fda0c77561624626cb96a2d6d13038d1873f8999d5401c3e48f858dbc05`.
The proof requires three topics, exact padded recipient, the named token ID,
and precisely two data words. Those words establish P/R independently;
partitioning a total Transfer is not the oracle.

The following line references are inside the authenticated unescaped archived
source bodies, not current checkout line numbers:

- `contracts/interfaces/IDetfBondNFT.sol:29-34` defines purchase/claim event ABI.
- `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:163-187`
  authorizes the owner/operator, resolves a zero recipient, computes separate
  principal/reward selections, increments claimedPrincipal, debits their
  combined gons, transfers P+R as sDETF, and emits BondClaimed.
- The same target `:190-199` deletes and burns only when all fixed principal
  is paid and residual gons are below one native-unit divisor. A getter
  revert is not the proof of that burn.
- `contracts/vaults/detf/common/bondNft/DETFFundedBondRepo.sol:47-55`
  initializes claimedPrincipal to zero.
- `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:29-43,97-116`
  separates fixed principal, claimedPrincipal, gons, total remaining principal,
  currently due principal and funded rewards.
- `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:91-92,111-115`
  fixes nine decimals and delegates transfer to the funded ledger.
- `contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol:147-156`
  debits/credits the exact requested native amount in gons and emits Transfer.

Observation: this inspected lifecycle opens Pc at zero and adds nonnegative
principal payouts while the position survives; retirement deletes it.
Inference: Pc is nondecreasing under that lifecycle, not because snapshots
happen to be equal. Selected end-block routes and two snapshots do not prove
all historical transitions or turn this named list into a history census.

## 4. Every named claim, split, payout and capture

All rows are confirmed for actual claim split and exact payout. P and R are
native9 integers; each payout is exactly P+R. For NFT N, the original logical
locator is `evidence/weighted-bonds.csv#row=N-1`. Occurrence is one-based.
Full block hashes, transaction indices, complete logs, receipt-array indices,
emitted recipients and exact new/prior request identities are in
`proof.json/entries`; nothing is sampled.

`new` means an independent verifier capture. `old[i]` means accepted phase30
`actual/archive.json/results[i]`, not a new capture. Log indices below are
decimal claim / payout / retirement. A dash means no retirement event in
that named receipt, not a general absence proof.

| NFT.occurrence | Transaction | Capture | P | R | Log indices |
| --- | --- | --- | ---: | ---: | --- |
| 4.1 | `0x98c198c8c25946098971110ac701ac1891036d573232db84788f7c3f665d19cf` | new | 0 | 15414315 | 32 / 31 / - |
| 6.1 | `0x25bcdec5ebd3f1a1b5223f30c7a4a5be7b1c7b732fa7fb36a8a2cbdc45e803bc` | new | 0 | 38281206 | 1 / 0 / - |
| 7.1 | `0x8af05d894ccb05f0a57eb5bea4838f3267726b41033609a1007ea744a5f406ff` | new | 0 | 58561139 | 29 / 28 / - |
| 8.1 | `0x1db62f8a403bb8e6c1e2ff44853a105cfd033d8fc70902e51795bb483b9bf3ed` | new | 0 | 86294368 | 5 / 4 / - |
| 9.1 | `0xeea4d604f7178e4caa89c36898574e34ebb484404985ab12662670c96e9b51f5` | new | 0 | 120399548 | 67 / 66 / - |
| 10.1 | `0x5e92e5978d3c22ec6e00fb9bc2feeb6a251fd9ccc2e3274f7be7c96ab6470d19` | new | 0 | 153046829 | 110 / 109 / - |
| 14.1 | `0x6168c6e2a65335b24d93f294064207d50b41931cd738aaab9c1b868a27f1a8c1` | new | 39 | 1 | 2 / 1 / - |
| 14.2 | `0x1878ba4049d26b08a81843edbeb2a936edbd8e8d8be9dfb2ec26531ef0b580d4` | new | 5247 | 3070 | 1 / 0 / - |
| 21.1 | `0xb973e4523b957f950800308b0327eab13782f54309bec9ffb5a5ed3d8c0fe076` | new | 592850 | 519358 | 76 / 75 / - |
| 21.2 | `0x0db6934c05928ca3f3a88b0c6be21071dcae4f873dda3f6992dea75b4b670954` | new | 191 | 0 | 16 / 15 / - |
| 21.3 | `0x08c32381c229242054fbb3b1f5e66cbae181e678b9c5b4b0cb37a42854f8e029` | new | 110390 | 14657 | 3 / 2 / - |
| 22.1 | `0xb76c35b8cbcf976712dac07d1816b2df06fb5258b6bd844ae9352d02c0d37077` | new | 3751798 | 395154 | 83 / 82 / - |
| 22.2 | `0x2a94d0afa94e43d4d261baf0bb4c37e0d98d32051aa924a2ddfa3320867fb572` | new | 18851422 | 3475244 | 5 / 4 / - |
| 22.3 | `0x6997764082b1c00f01956a7c576c9aeb1f9c47e4f0356327e22b0f520f0c1578` | new | 20266670 | 33302823 | 1 / 0 / - |
| 24.1 | `0x9f1ed965eeaa9c52248ce937443ba29ff34f5a350c8b1915d1132e6459719d0f` | new | 0 | 2678508 | 9 / 8 / - |
| 25.1 | `0x5912c8beef25c63604f3b1a4545307e2e20cf752f34fd84a03f4c32e312a4e83` | old[105] | 53274997 | 2865189 | 30 / 28 / 29 |
| 32.1 | `0x8ec4c3be22e3226dd695cfdbeb8da03fd0b3adde63996b094fd9238f6c91946b` | old[160] | 8071216 | 2716673 | 10 / 9 / - |
| 34.1 | `0x76179386f800116488db19c7164a076f887dd533822a32d055c05d395f52296f` | old[138] | 7942358 | 1540843 | 1 / 0 / - |
| 36.1 | `0xf7325a1194157d76db83360914d405799cb041165bd63522a5f8f6be0ebd7f0a` | new | 3247321 | 14090243 | 20 / 19 / - |
| 42.1 | `0xcbd779f65dc55f8838fdbe1776d1c008383e885f9ef78ae9dc8c9cfc9267db04` | old[254] | 5129740381 | 162562490 | 16 / 14 / 15 |
| 44.1 | `0xe5cef98c943aee410e44370dbf2abdfd0df3f6df906a49786133a1596a9025fd` | old[283] | 73745125 | 1262696 | 6 / 5 / - |
| 45.1 | `0xb54fc2bc5865af3326f1f934d41c29274a825ffa7c96b848294bfebe71d2ae52` | old[216] | 802706343 | 54999359 | 36 / 35 / - |
| 45.2 | `0xf7a553d8d377f46c8f827de6f00f865d30142f3d0a87a9f37978d0f13412a289` | old[306] | 10658259319 | 130642693 | 16 / 15 / - |

Exact summed P = **16780565667**, R = **883066406**, payout =
**17663632073**, all native9. Reward-only IDs 4, 6, 7, 8, 9, 10 and 24
are retained, not discarded as zero-principal records.

The seven prior capture ID sets, in the old-row order above, are
423-426, 643-646, 555-558, 1019-1022, 1135-1138, 867-870 and 1227-1230.
Every old conversion reference is preserved alongside its new S008 occurrence.
New IDs are 3-66 in four-call groups following new-row order; IDs 1/2/67 are
chain/start-anchor/end-anchor. The exact retained raw body identities, not
only these shorthand ranges, govern.

The actual emitted recipients equal the original purchase recipients in all
23 rows, but payer/owner/recipient are not conflated. NFT42's outer caller is
`0xf22e13f4fecf19c17cd142b58a3ed3fbfc361ff5`, callee
`0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789`, selector `0x1fad948c`.
Its emitted recipient is `0x26acc4c07cac494d49054eaad406ef108a074a66`.
That outer calldata is retained as context; no arbitrary inner invocation or
source claim is authenticated from it. The other 22 outer callees are the NFT.

## 5. Every original's frozen/current comparison

The 43 independent sums below equal their respective frozen
`claimed_principal_detf_raw` and `rewards_claimed_sdetf_raw` exactly.
All frozen-minus-named P/R differences are zero. Zero named claims means
zero contribution from this declared list, not a zero-history certificate.

Current is the **accepted phase31 pin**, not a fresh current observation:
113279837 / `0x6c0835d`, hash
`0x78f23110692ee71a64dfea3463f7df0f9687ffa5d5f951fabb22c239921c4113`,
timestamp 1794565137. The proof authenticates all 268 retained phase31
captures and independently decodes each weighted position, owner and preview
from its exact raw numeric-pin request/response. Current principal equals
historical original principal in all 41 available positions. Pc is actual
claimedPrincipal; remaining is actual principal minus Pc, not currently due
principal and not a CSV substitution. All available current-minus-frozen and
current-minus-named Pc differences are zero.

| NFT | Claims | Named/frozen P | Named/frozen R | Current Pc | Current remaining |
| --- | ---: | ---: | ---: | ---: | ---: |
| 3 | 0 | 0 | 0 | 0 | 3772281649 |
| 4 | 1 | 0 | 15414315 | 0 | 281387179 |
| 5 | 0 | 0 | 0 | 0 | 462445599 |
| 6 | 1 | 0 | 38281206 | 0 | 740825635 |
| 7 | 1 | 0 | 58561139 | 0 | 1200103129 |
| 8 | 1 | 0 | 86294368 | 0 | 1937763154 |
| 9 | 1 | 0 | 120399548 | 0 | 3147607863 |
| 10 | 1 | 0 | 153046829 | 0 | 5077481904 |
| 11 | 0 | 0 | 0 | 0 | 44048877 |
| 12 | 0 | 0 | 0 | 0 | 1455956506 |
| 13 | 0 | 0 | 0 | 0 | 1915 |
| 14 | 2 | 5286 | 3071 | 5286 | 186317 |
| 15 | 0 | 0 | 0 | 0 | 1915 |
| 16 | 0 | 0 | 0 | 0 | 153080136 |
| 17 | 0 | 0 | 0 | 0 | 179696 |
| 18 | 0 | 0 | 0 | 0 | 49053117 |
| 19 | 0 | 0 | 0 | 0 | 133006119 |
| 20 | 0 | 0 | 0 | 0 | 266266893 |
| 21 | 3 | 703431 | 534015 | 703431 | 16947058 |
| 22 | 3 | 42869890 | 37173221 | 42869890 | 1245164840 |
| 23 | 0 | 0 | 0 | 0 | 252865083 |
| 24 | 1 | 0 | 2678508 | 0 | 1300890757 |
| 25 | 1 | 53274997 | 2865189 | unknown | unknown |
| 26 | 0 | 0 | 0 | 0 | 56299 |
| 27 | 0 | 0 | 0 | 0 | 3302546215 |
| 28 | 0 | 0 | 0 | 0 | 3726336268 |
| 29 | 0 | 0 | 0 | 0 | 1777911406 |
| 30 | 0 | 0 | 0 | 0 | 457125470 |
| 31 | 0 | 0 | 0 | 0 | 4031493805 |
| 32 | 1 | 8071216 | 2716673 | 8071216 | 46365243 |
| 33 | 0 | 0 | 0 | 0 | 13798634863 |
| 34 | 1 | 7942358 | 1540843 | 7942358 | 51139140 |
| 35 | 0 | 0 | 0 | 0 | 182228084 |
| 36 | 1 | 3247321 | 14090243 | 3247321 | 1638945309 |
| 37 | 0 | 0 | 0 | 0 | 51168348039 |
| 38 | 0 | 0 | 0 | 0 | 28366285153 |
| 39 | 0 | 0 | 0 | 0 | 73833949104 |
| 40 | 0 | 0 | 0 | 0 | 15681307429 |
| 41 | 0 | 0 | 0 | 0 | 746187269 |
| 42 | 1 | 5129740381 | 162562490 | unknown | unknown |
| 43 | 0 | 0 | 0 | 0 | 1564401756 |
| 44 | 1 | 73745125 | 1262696 | 73745125 | 7290760 |
| 45 | 2 | 11460965662 | 185642052 | 11460965662 | 1135766469 |

Current cumulative rewards remain unknown for every original: the deployed
position has no cumulative claimed-rewards field; preview rewardsDue is unpaid
funded reward, not rewards already paid. The R comparison is historical
event-to-frozen arithmetic, not equality to an invented current reward counter.
ID26's differing current owner and IDs44/45's `pre_attack=false` fields remain
unchanged observations, not eligibility decisions.

## 6. Specific retirement proof and explicit missing semantics

NFT25 retirement is accepted phase30 results[105], transaction
`0x5912c8beef25c63604f3b1a4545307e2e20cf752f34fd84a03f4c32e312a4e83`,
block **89377134**, block hash
`0x59fadcf1fe0bb14585ba1ad32a11bf5550e69d71aff9a53fa0348cdf688814f5`,
transaction index **6**, receipt-array index **10**, logIndex **29** (`0x1d`).
The exact collection Transfer names ID25, from
`0xf0f80dd7e46ee7c3e7bd68f806bab1875f069530` to zero, with empty data.

NFT42 retirement is accepted phase30 results[254], transaction
`0xcbd779f65dc55f8838fdbe1776d1c008383e885f9ef78ae9dc8c9cfc9267db04`,
block **103485779**, block hash
`0x7f31f132b03c28f410cacfbf6a583a72d3cbc10d57f2537dbac3a5d35ee70fbf`,
transaction index **5**, receipt-array index **12**, logIndex **15** (`0xf`).
The exact collection Transfer names ID42, from
`0x26acc4c07cac494d49054eaad406ef108a074a66` to zero, with empty data.

At the accepted current pin both owner calls return zero; position/preview
calls retain exact code 3 / `execution reverted` errors with selector
`0x7e273289` and their requested token ID (25 or 42). These errors remain
failures, not successful zero-valued positions. Current principal, Pc, gons,
start/duration, remaining and preview fields stay unknown. Retirement is proved
by the specific canonical events above, not inferred from those failures.

No principal/reward split is missing for the 23 observed claims; no frozen
numerical mismatch was found. What remains incomplete is history outside the
declared list, transaction-prefix source coverage, current descendant
ownership/balances, original economic payer and complete E0/D0, original-wallet
financial authority/eligibility, exposure uniqueness, prior migration delivery,
C0 and approved deductions. These are unknown, not default zero.

Purchase recipient, purchase outer caller, emitted claim recipient, current
NFT owner, remaining NFT principal and surviving sDETF/gon claims are distinct
fields. A historical payout does not establish current descendant control or
create a second full original entitlement. No holder ancestry, descendant
eligibility, executable allocation or C0 inference is made. **Reward payments
are not new capital; legacy principal payouts are not migration-compensation
deductions.**

## 7. Owned proof, actual checks and retained failures

The six owned modules have separate responsibilities: evidence intake/raw
association, finite acquisition, event meaning, all-record comparison, command
recording and publication. They import no producer collector, CSV parser,
reconciliation or proof program. Only the already installed ethers hash helper
is used for independent event/function signature hashes. Source and output
identities are retained alongside actual command snapshots.

Actual commands ran from this verification directory through `/bin/zsh -lc`:

```sh
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs intake intake-01
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs acquire acquire-01
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs proof proof-01
```

Final scoped syntax uses `/opt/homebrew/bin/node --check` for each of
evidence.mjs, acquire.mjs, record.mjs, semantics.mjs, proof.mjs and publish.mjs;
all six actual Node children exited 0. Their exact recorded commands are
`record.mjs syntax syntax-final-NAME NAME.mjs`. The strengthened final proof
ran `record.mjs proof proof-final --verify`, exited 0, and reproduced both
published proof bodies without RPC or proof-file writes.

Two verifier mistakes are retained rather than hidden:

1. `intake-01` exited 1 because the verifier initially expected a pin object;
   the accepted phase31 observations store the pin as a string. The corrected
   intake completed within the sole successful acquisition and both proofs.
2. The first nominal syntax wave mistakenly passed `--check` to Bun 1.4.2.
   That runtime executed the named modules instead of providing Node syntax
   checking. `syntax-evidence` exited 0 and proves no syntax check;
   `syntax-acquire` exited 1 at exclusive `inputs.json` creation (EEXIST),
   before credential resolution or any RPC. It overwrote no artifact and
   made no additional live call. The corrected actual Node wave is the
   syntax evidence. The original failure/argv/streams remain intact.

The producer's own initial failed intake, later successful commands and
diagnostic limitations also remain bound. Fresh LSP diagnostics timed out on
owned evidence/record scripts; no universal clean-LSP or strict checked-JS
result is claimed. All owned modules are below 200 nonblank/noncomment lines.
Actual raw behavioral execution, deterministic reproduction and actual Node
syntax checks supply the verification. No new production seam, suppression,
test weakening, dependency, install, Forge/build/full-suite/full-gate replay,
source mutation or phase29 retry occurred. No changing phase32 output was read.

Read-only offline reproduction after publication:

```sh
cd /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase33-nft-claim-receipts/verification
/opt/homebrew/Cellar/bun/1.4.2/bin/bun proof.mjs --verify
```

Expected exit 0. This reauthenticates and independently derives the full proof
from retained evidence, then compares the published JSON. It performs no RPC
and writes no files. Do not run acquire.mjs against a sealed directory.

| Independent output | Bytes | SHA-256 |
| --- | ---: | --- |
| proof.json | 540323 | `a8281fd4bd6f3fc7be22629a162e291226faf88ce4e749c2b1a1b2a90f9888c8` |
| archive.json | 173899 | `9dd857ef5c613d70302149f322c2924c9450b1d4915c550b52caecc2f7545820` |
| http-manifest.json | 206250 | `0a818e1f0748a9242b197d7e4200950912883b43d8597125cea4a8fcf095c9f1` |
| inputs.json | 3156877 | `bd00def50868ce24cbb2e5bfd79752d745fcea422328ab677a6a89cbb4b2ff95` |

## 8. Actual stopped cleanup and final seal

Producer cleanup retains 23 actually closed child commands (22 exit 0 and one
initial intake exit 1). Its publisher PID is recorded in its seal. Verifier
command receipts retain actual close events, including both failed attempts,
the sole successful acquisition, both successful proofs and the corrected
syntax group. No failed request or command is converted into a passing result.

The final publisher reauthenticates initial frozen/source/producer identities,
checks actual closed command receipts and final executed script identities,
and runs `/bin/ps -axo pid=,ppid=,comm=` to require all recorded verifier
children, producer children and producer publisher to be absent. It scans all
then-present verifier artifacts for the selected literal/encoded credential.
No temporary runtime, server, chain, worktree or dependency was created; no
deletion is required and no shared service is stopped.

`preservation.json` records zero changed initial bindings.
`cleanup.json` records stopped command evidence, process inspection,
credential scan, zero pending RPC/owned children and no cleanup debt.
`manifest.json` binds every verifier file except itself and seal.json.
The final `seal.json` binds the report, full proof, schema proof, archive,
wire/input manifests, preservation, cleanup and complete manifest.

The publishing command is:

```sh
/bin/zsh -lc 'cd /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase33-nft-claim-receipts/verification && exec /opt/homebrew/Cellar/bun/1.4.2/bin/bun publish.mjs'
```

It writes the seal last and exits. Its external monitored exit is required
before final handoff; the presence of a seal alone is not a promise that a
pending command will finish. No artifact write follows that seal.

**Confirmed only for these complete bounded 23 named claim observations and
their exact stopped evidence.** Broader source coverage, financial
configuration, operational acceptance, P1, full Task9 and full-plan approval
remain separate.
