# Phase33 named weighted-NFT claims: complete bounded producer evidence

Date: November 13, 2026.

**All 23 named claim occurrences have an actual canonical BondClaimed split and
one exact native9 sDETF payout.** Seven accepted phase30 receipts were reused;
only the 16 missing transaction/receipt pairs were acquired. Seven claims have
zero principal and nonzero rewards. NFTs 25 and 42 have explicit canonical
Transfer-to-zero retirement events. Every independently summed named principal
and reward amount equals its frozen S008 counter. All 41 available phase31
current principal counters equal the frozen counters. The two absent NFTs'
current position fields remain unknown.

This is complete bounded producer evidence, with a separate raw-data proof.
It is not the independent live-verifier role described in the brief, a history
census, source admission, financial configuration, or migration approval.
Only this `source/` directory was written. No phase32 output was read.

## 1. Authenticated inputs and complete derivation

The complete phase33 brief, repository router and assistant rules, current
implementation plan r5 and PRD r22, accepted phase28/30 reports and archives,
joined recipient-flow verification, and phase31 source-schema/state evidence
were read before acquisition. Current plan sections 1 and 5 govern the original
wallet, actual remaining principal, separate rewards and compensation rules.
Historical frozen prose does not override those requirements.

Frozen root:

`/Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery`

The existing input loader authenticates sources.json from manifest.json before
using any source declarations, then reads and authenticates every declaration:
36 declarations, 28 physical bodies including manifest.json. These are
hash-authenticated recovered bodies, not located original captures.

The entire S008 weighted-bonds.csv independently yields 43 original rows and
23 individual claim_transactions occurrences, separated on the actual `|`
delimiter. There are 23 distinct hashes across 17 NFTs. Each occurrence retains
its original logical CSV locator, collection, token ID and one-based occurrence.
No root reconciliation/orientation file supplied the claim list. An independent
CSV state machine in raw.mjs reconstructs the list again from complete raw S008.

The accepted phase31 producer seal authenticates the archived source/schema
roots and phase28/30 acceptance bindings. The intake checks all direct seal
bindings and every manifest body in phase28 verification, phase30 verification,
phase31 producer/verification, and joined-flow verification. It also authenticates
the external source bindings from the phase31 source manifest. The resulting
source-manifest.json has 5,035 binding occurrences, including duplicates; it is
not a claim of 5,035 unique sources or independent source histories.

The current operator reader base is 1694e68a4bd66dd67d3b5e3f145f1da23074ff48.
The inspected current candidate-input and receipt-association schemas are reused
without changes. Actual old deployed schemas come from the authenticated
weighted probe.sources.json and the earlier archive containing the loupe.
Current local contracts are not substituted for historical deployed source.

Main historical archive identities:

| Body | SHA-256 |
| --- | --- |
| phase28 verification actual/archive.json | e390e13162b566cd4c138a4342e4e1186dc3053526e9743454db3d92d637839b |
| phase30 verification actual/archive.json | 67a8cd97a26d0bfe4fc118469db605a9b0424e7b40c17fb977f6bd6990dfefc0 |
| joined observed-recipient worksheet | ed8474ac3454453697308ce82adffebb8bbfe9d346050973e0753a46cf6af39e |
| archived weighted probe.sources.json | 1ed706355a0238847dba503c6c4b590812f9fb3fbe583fff04d15d32de920f4d |
| phase31 independent observations.json | 31f957fb0821c63aaa7db8b8bcb404698b5294c0ca555b0bac37e420effbc956 |

inputs.json binds every frozen body and declaration. source-manifest.json
retains absolute paths, lengths and hashes for all authenticated prior bindings.
Neither an old collector nor an old proof/test suite was executed.

## 2. Actual acquisition and exact canonical checks

The sole live collector ran November 13, 2026, from 11:16:00.868Z to
11:16:34.696Z and exited 0. It authenticated chain 4663 and historical block
108944663 / 0x67e5d17 / hash
0xc497433dd691a40cb85959cfeba2e3fff85a975ae060612d984998e1d5765733
before named reads. The complete ending header equals the initial header.

Only the existing robinhood_mainnet_alchemy alias and its selected ALCHEMY_KEY
were used. The alias template is checked exactly. The key never enters argv,
request bodies or retained evidence. Direct HTTPS is sequential, bounded at
20 seconds per request and 350 total, with no middleware, redirect, retry,
alternate provider or method escalation.

| Method | New calls |
| --- | ---: |
| eth_chainId | 1 |
| eth_getTransactionByHash | 16 |
| eth_getTransactionReceipt | 16 |
| eth_getBlockByHash | 16 |
| eth_getBlockByNumber, including start/end anchor | 18 |
| eth_getCode | 115 |
| eth_call, facetAddress view only | 161 |
| Total | 343 |

The 276 source-binding calls are five exact runtime byte strings and seven
selected loupe bindings at each of the 23 actual named claim blocks. Reading
the source binding for a reused receipt is not reacquiring that receipt.
There is no storage query, trace, range/log scan, state override, arbitrary
inner invocation or claim simulation.

All 343 safe request and response entities are retained in http/, with IDs,
method/params, start/finish, status, entity lengths, SHA-256 and raw qualification
in http-manifest.json. There are no actual transport, HTTP, RPC, null, envelope,
schema or redaction failures. These are RPC HTTP entities, not HTTP framing,
signed-transaction verification, trustless proofs or independent-provider
consensus.

For all 23 receipts, the proof verifies exact transaction/receipt hashes,
block hash and number, successful receipt status, sender/callee association,
canonical quantities, transaction index, unique full-block membership at that
index, and complete block-by-hash versus block-by-number equality. Every one
of the 96 combined receipt logs passes exact transaction/block/index binding,
removed=false, address/topics/data shape and strictly increasing unique log
indices. Every transaction is at or before the authenticated historical anchor.
Every new request is accounted for; the HTTP directory has no orphan entities.

The seven retained prior bodies additionally authenticate against their
accepted raw requests/responses and prior chain/anchor. Their prior request IDs
are not relabelled as new capture IDs.

## 3. Actual deployed source meaning

schema-bindings.json retains the exact ABI and seven complete relevant
unescaped source bodies with their hashes. Source locators in this section
are lines inside authenticated `sources[path].content`, not current checkout
line numbers.

Weighted NFT: 0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e.
Funded facet: 0x3a07364eaba092472d40f0e6788b8891a31fad4d.
sDETF: 0x4fa4974a8a09660258b8edd430b51c1620ebfe5c.
Staking facet: 0xb7581fe833a2b2380dd786b345d61ffb734d36eb.
Loupe: 0x343590ed92498739225e351c27133bc2c11b91b9.

All 115 runtime comparisons and 161 selected historical routes match the
inspected archived implementations. The NFT's claimBond, claimPrincipal and
claimRewards selectors resolve to the funded facet. sDETF transfer and decimals
resolve to the staking facet. Both proxies' facetAddress routes resolve to the
matching loupe. Each numeric tag comes from that named canonical receipt block.
This binds selected historical surfaces, not every possible route in every
block or transaction-prefix execution.

Actual event ABI:

```solidity
event BondClaimed(
    uint256 indexed tokenId,
    address indexed recipient,
    uint256 principal,
    uint256 rewards
);
```

Its topic is
0xc9ce1fda0c77561624626cb96a2d6d13038d1873f8999d5401c3e48f858dbc05.
There are exactly three topics and two static data words. The split comes
from this actual emitted source event, not from partitioning a total Transfer.

`contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:163-187`
authorizes the owner/operator, resolves a zero recipient to owner, selects
principal/rewards, increments claimedPrincipal, debits gons and transfers their
sum as sDETF, then emits BondClaimed. Lines 190-199 retire only a fully paid
principal position with less than one native unit of residual gons, delete
the position and burn the NFT. A revert is not the evidence for that burn.

`contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:29-43,97-116`
defines fixed principal, claimedPrincipal and staking gons, separately computes
remaining principal versus currently due principal, and computes funded rewards.
`contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:91-92,111-115`
fixes decimals at nine and delegates transfer to the funded ledger.
`contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol:147-156`
debits/credits equal native-unit gons and emits the exact Transfer amount.
The amounts below are native9 integers, not ETH, native18 DTF, LP shares or gons.

The inspected lifecycle opens claimedPrincipal at zero
(`DETFFundedBondRepo.sol:47-55`) and increases it by nonnegative principalDue
(`DETFFundedBondTarget.sol:175-187`); retirement deletes the position. This is
the source invariant behind conditional nondecrease for a surviving position.
Equal snapshots alone are not a monotonicity proof. This bounded read does not
prove every historical state transition used only these routes, so it does not
upgrade the named list into an exhaustive history census.

## 4. All 23 dispositions and capture provenance

Every row below has disposition **claim-split-and-exact-payout-confirmed**.
The first column is NFT ID and one-based occurrence in S008 claim_transactions.
The full original locator is retained on every JSON row; for this actual
table, NFT ID N is `evidence/weighted-bonds.csv#row=N-1`.

P and R are the separately emitted native9 principal and rewards. Each exact
sDETF payout is P+R. The final column lists decimal canonical logIndex values:
claim / payout / retirement. A dash means no retirement event in that named
receipt, not proof that retirement is impossible elsewhere.

`phase30[i]` means zero-based results[i] in the accepted phase30 verification
actual/archive.json. `new` means this phase33 raw capture. Full block hashes,
transaction indices, receipt-array indices and complete logs are retained in
reconciliation.json and proof.json.

| NFT.occurrence | Transaction | Capture | P | R | Claim / payout / retirement log |
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
| 25.1 | `0x5912c8beef25c63604f3b1a4545307e2e20cf752f34fd84a03f4c32e312a4e83` | phase30[105] | 53274997 | 2865189 | 30 / 28 / 29 |
| 32.1 | `0x8ec4c3be22e3226dd695cfdbeb8da03fd0b3adde63996b094fd9238f6c91946b` | phase30[160] | 8071216 | 2716673 | 10 / 9 / - |
| 34.1 | `0x76179386f800116488db19c7164a076f887dd533822a32d055c05d395f52296f` | phase30[138] | 7942358 | 1540843 | 1 / 0 / - |
| 36.1 | `0xf7325a1194157d76db83360914d405799cb041165bd63522a5f8f6be0ebd7f0a` | new | 3247321 | 14090243 | 20 / 19 / - |
| 42.1 | `0xcbd779f65dc55f8838fdbe1776d1c008383e885f9ef78ae9dc8c9cfc9267db04` | phase30[254] | 5129740381 | 162562490 | 16 / 14 / 15 |
| 44.1 | `0xe5cef98c943aee410e44370dbf2abdfd0df3f6df906a49786133a1596a9025fd` | phase30[283] | 73745125 | 1262696 | 6 / 5 / - |
| 45.1 | `0xb54fc2bc5865af3326f1f934d41c29274a825ffa7c96b848294bfebe71d2ae52` | phase30[216] | 802706343 | 54999359 | 36 / 35 / - |
| 45.2 | `0xf7a553d8d377f46c8f827de6f00f865d30142f3d0a87a9f37978d0f13412a289` | phase30[306] | 10658259319 | 130642693 | 16 / 15 / - |

All seven prior provenance records preserve the accepted archive and HTTP
manifest paths, previous conversion references, result index, exact old raw
directory and request IDs:

| NFT.occurrence | Prior request IDs |
| --- | --- |
| 25.1 | 423,424,425,426 |
| 32.1 | 643,644,645,646 |
| 34.1 | 555,556,557,558 |
| 42.1 | 1019,1020,1021,1022 |
| 44.1 | 1135,1136,1137,1138 |
| 45.1 | 867,868,869,870 |
| 45.2 | 1227,1228,1229,1230 |

Each of the 16 new rows has its own four canonical request IDs in
archive.json/results[].provenance and a standalone hash-named JSON file.
Their request/response bodies are never substituted from the prior archive.

The total named principal is **16780565667**, rewards **883066406**, payout
**17663632073**, all native9. These are observed old-claim amounts, not approved
new migration amounts. Reward-only IDs 4,6,7,8,9,10,24 remain represented.

All 23 emitted recipients equal their original purchase recipients, but the
complete address is retained independently on each event row. This equality
does not identify an original economic payer or approve any entitlement.
NFT42's outer caller is 0xf22e13f4fecf19c17cd142b58a3ed3fbfc361ff5 and
callee is 0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789 with selector 0x1fad948c.
Its emitted recipient is 0x26acc4c07cac494d49054eaad406ef108a074a66.
The indirect outer calldata is retained only as context, not decoded or
authenticated as an inner source claim. The other 22 have the NFT as outer
callee; no stronger transaction-prefix claim is made for them.

## 5. Frozen and accepted current comparisons for every original

Every P/R sum below exactly equals the corresponding frozen
claimed_principal_detf_raw/rewards_claimed_sdetf_raw. Both frozen-minus-named
differences are explicitly zero in all 43 originals. A zero-claim row means
the declared list contributes no observed claim, not an exhaustive zero-history
assertion.

Current means the accepted phase31 numeric pin 113279837, hash
0x78f23110692ee71a64dfea3463f7df0f9687ffa5d5f951fabb22c239921c4113,
timestamp 1794565137. It was not refreshed by this unit. Current Pc is the
actual positionOf claimedPrincipal, not CSV substitution. Current remaining
is the actual position's principal minus Pc; actual principal equals the
original P0 in every available position. Current-minus-frozen and
current-minus-named Pc are both zero for all 41 available positions.

| NFT | Named claims | Named/frozen P | Named/frozen R | Current Pc | Current remaining |
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

The deployed position has no cumulative claimed-rewards getter. Current
previewClaim.rewardsDue is unpaid funded rewards, not cumulative rewards paid.
Therefore current cumulative rewards remain unknown for all 43; equality
against frozen rewards uses actual historical events, not a fabricated current
counter. NFT26's current owner differs from its purchase recipient; ownership
and configuration do not follow from the payout comparisons. IDs44/45 retain
pre_attack=false; matching their counters is not an eligibility ruling.

## 6. Retirement, descendants and precise remaining gaps

NFT25: accepted phase30 results[105], transaction
0x5912c8beef25c63604f3b1a4545307e2e20cf752f34fd84a03f4c32e312a4e83,
block 89377134, transaction index 6, receipt-array index 10, logIndex 29
(0x1d), collection W, ID25, from
0xf0f80dd7e46ee7c3e7bd68f806bab1875f069530 to zero.

NFT42: accepted phase30 results[254], transaction
0xcbd779f65dc55f8838fdbe1776d1c008383e885f9ef78ae9dc8c9cfc9267db04,
block 103485779, transaction index 5, receipt-array index 12, logIndex 15
(0xf), collection W, ID42, from
0x26acc4c07cac494d49054eaad406ef108a074a66 to zero.

Those are specific proved retirement events, with full canonical hashes/logs
in both proof and reconciliation. The accepted current owner reads are zero
and current position/preview reads are exact ERC721NonexistentToken errors.
The errors remain errors. Current principal, claimedPrincipal, gons and remaining
fields for 25/42 are not filled with their historical fully-paid CSV values.

For all originals, the report keeps purchase recipient, purchase outer caller,
unknown original economic payer, claim recipient, current owner, remaining NFT
principal and transferred sDETF/gon claims separate. A historical sDETF payout
is a descendant observation, not proof of current descendant control or a
second full original entitlement. Later wrapping, transfers, unstaking and
claims remain outside this finite list.

No split is missing for these 23 actual events and there is no numerical
frozen-counter mismatch. Remaining unknowns are complete history beyond the
declared list, current descendant ownership/balances, original E0/D0 and
original-payer attribution, original-wallet financial authority/eligibility,
prior migration delivery, C0 and approved compensation deductions. None is
zero by default. Rewards are not new original contributions; legacy principal
payouts are not migration-compensation deductions. No source admission or
executable allocation is produced.

## 7. Reproducible proof and actual checks

Owned scripts have distinct responsibilities: inputs (authentication), rpc
(safe finite transport), collect (bounded acquisition), reconcile (evidence
interpretation), raw (independent wire/CSV/canonical checks), prove (independent
event/comparison proof), record (actual child commands), seal (publication).
They contain 41-159 nonblank/noncomment lines each. No suppression, install,
production seam, new helper in production or source-code modification occurred.

The raw proof does not import the collector, transport, reconciliation or
receipt-association algorithms. It independently parses complete S008, actual
event words, recipients, payouts, retirements, original mint/purchase events,
comparisons and unknown fields, then compares the produced reconciliation.
It reauthenticates all source bodies and prior/new raw captures. This is a
producer-side raw proof, not a separate live verifier.

Actual commands, all from this source directory:

```sh
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs validate
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs validate validate-r2
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs collect
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs reconcile
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs prove
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs validate validate-final
/opt/homebrew/Cellar/bun/1.4.2/bin/bun record.mjs prove prove-final
```

The initial intake failed on the joined-review manifest's `entries` field;
its exact stopped error and command streams remain. The corrected intake,
sole collection, reconciliation and both raw-proof runs exited 0. Final
validation ran eight individual Node syntax checks and complete offline intake,
all nine exits 0. The final strengthened proof additionally checks all original
mint/purchase terms, source bodies, current/frozen/named differences and unknown
fields and reproduces the published proof. No live acquisition was retried.

The actual initial prove command predates the recorder's final --verify
argument; its retained argv shows the actual invocation. The final recorded
proof uses --verify and performs no proof-file overwrite.

Read-only deterministic reproduction, without changing the sealed tree:

```sh
cd /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase33-nft-claim-receipts/source
/opt/homebrew/Cellar/bun/1.4.2/bin/bun prove.mjs --stdout
```

Expected exit 0; stdout is proof.json. This command reads existing evidence
only and performs no RPC. Do not rerun collect against this sealed directory.
For a separate live verifier, independently derive the same 16 missing hashes,
reuse the seven accepted bodies and write only its own authorized verification
directory as specified in the brief.

| Main body | Bytes | SHA-256 |
| --- | ---: | --- |
| archive.json | 371005 | 526241ff35c8f13d82f791eb04ccd258638cd6f74c4696ed0b740f5f528c0b23 |
| reconciliation.json | 352372 | 352a4590726bbcc0b90b26260ba2cb790e58122d66224a59f739725ccd574058 |
| proof.json | 62328 | 9a2c70af6b99867332f101849cb03a8e9ae601eec04c4cfc887502d533c39aee |

Fresh LSP diagnostics timed out for inputs.mjs and record.mjs; no clean LSP or
strict static-type result is claimed. Actual syntax and behavioral proof checks
passed. No unchanged full suite, Forge build/test, full gate, rehearsal, signing,
source changes, provider change, phase29 retry or phase32 read occurred.

## 8. Stopped publication and boundaries

All 23 recorded child commands have actual close timestamps and exits before
publication: 22 exit 0, one retained initial intake exit 1. cleanup.json records
those commands, a stopped process inspection, final source/input reauthentication,
selected-key literal/encoded credential scan, and no pending owned child/RPC.
No temporary runtime, worktree, chain or dependency was created; no deletion is
required. Shared services, production, originals and old evidence are untouched.

The final publisher writes cleanup.json, manifest.json and seal.json last,
then exits. The monitor must observe the publisher's exit 0 before final
handoff. No evidence write follows the seal. The manifest binds all other
owned artifacts and the seal binds the report, complete raw/comparison/proof
outputs, manifests and cleanup.

Complete and stopped for the bounded 23 named claims only. Broader source
coverage, history, financial inputs, deployment/funding, P1, full Task9,
full-source/full-plan and operational acceptance remain separate.
