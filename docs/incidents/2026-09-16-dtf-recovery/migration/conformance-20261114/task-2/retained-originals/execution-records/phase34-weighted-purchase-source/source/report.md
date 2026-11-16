# Phase34 recovered weighted purchase source: stopped producer handoff

Date: November 13, 2026.

**Complete bounded G1 source-supported observation review of all 39 direct weighted purchases.** The actual purchase facet package is recovered and authenticated against all 99 metadata source declarations and all 39 retained historical runtime bodies. Each complete call/receipt supports a gross caller-paid token disposition: 40 positive WETH18/DTF18 components and 38 affirmative other-token zeros. **These are proposed gross purchase-time ERC20 payments, not approved original NFT cost, E0/D0/C0, eligibility or an allocation.** NFT3's extra DTF payment is explicitly nonzero protocol/reserve capital; its approved original-cost treatment remains unknown.

Only this source/ directory was written. The four G2 indirect rows and all sixteen earlier proposals remain unchanged in their sealed originals and in untouched-context.json. No source/configuration/production edit, commit, compiler, old gate, signing, trace, range scan, provider workaround or phase29/G2 retry occurred. All interpretation and authentication were offline: zero new network requests.

## 1. Authorities and exact capture

The complete phase34 brief and exact phase32 producer and independent handoffs/proofs were inspected, together with the current migration plan r5 and PRD r22, accepted phase28 canonical receipts, joined-flow qualifications, phase31 same-pin state and phase33 claim/retirement evidence relevant to the retained limits. Plan sections 1.3-1.5 and 5.2 govern: actual original wallet/control and configuration are separate, original inputs are not reduced and requoted, and routed intermediates, mint inventory, duration bonus, LP self-leg, old rewards and current redemption value are not extra C_i inputs. Historical policy text and matching gross debits do not approve financial inputs.

references.json binds the admitted bodies before parsing. The proof authenticates all 36 recovered-input declarations, complete source tables, accepted sealed manifests and both phase32 handoffs. The frozen bodies are hash-authenticated recovered historical bodies, not newly located original captures. S008 is 12,283 bytes / SHA-256 f1f63c97dee2d6fbaa0f0148b3e602a312af79d018e3b8b56967764d9e3a24e9. All 43 original rows are derived from that complete authenticated CSV; actual direct callers/callees yield 39 G1 and four G2 rows. S009's sixteen rows remain context only.

The supplied capture is ../../weighted-bond-facet-source-capture-20261113.json (absolute path is bound in references.json). Its 533 base64 chunks decode to exactly **1,636,793 UTF-8 bytes**, SHA-256 **adb0729a4d782cef809684171914caa90e8dcc4357446dfef18741f3d7256e27**. Fatal UTF-8 decoding and the pinned byte identity pass before JSON interpretation. Its URL, HTTP 200, headers, capture time and qualifications remain in the untouched capture. The entity is received UTF-8 response text, not HTTP framing or independently retained compressed wire bytes. It was not refetched.

recovered-package.json is a lossless parsed representation, not falsely labelled the original raw entity. Every source is the exact UTF-8 string at sources[originalPath].content; source-index.json records each string's byte length, SHA-256, actual Keccak and metadata declaration. All **99/99** match, and all contents separately equal stdJsonInput.sources[path].content. The source set equals the metadata source set. The owned ABI/runtime/creation/metadata JSONs deep-equal their decoded package members. JSON formatting outside those strings does not redefine source bytes.

## 2. Runtime, ABI and source binding

- Actual purchase facet: **0xaaf47ef19c9b932b6d00bca3683b000fc6208661**, chain 4663.
- Complete runtime: **13,997 bytes**, Keccak-256 **0x2676830f3b489088787c4ecc21803326a7909fbaaf9fd72994ec62b111bf62f8**.
- Published onchain/recompiled runtime strings are byte-for-byte identical; published creation strings are also identical. Both transformation lists are empty. These facts are recomputed, not accepted from the capture's checks booleans.
- ABI: nonpayable bond(address,uint256,uint256,address,bool,uint256), selector **0x7a3b1181**. Metadata ABI and published compiler-output ABI equal the recovered ABI. All five published function-signature hashes/selectors recompute correctly.
- Package deployment claim: transaction **0xca059d130f3f6aa9ebc069ec1dd0943b89e4b8ec5086121b878a0ff2e8ddafa4**, block **62116727**, transaction index 12. This is a published claim, not a newly reacquired creation transaction. Published compilation identifies solc 0.8.35+commit.47b9dedd, optimizer runs 1, viaIR=false; no compiler was invoked here.

For each direct original, the proof decodes the exact six retained phase32 raw request/response pairs: numeric-block header, proxy code, loupe self-route/code, purchase route and facet code. Each header matches the accepted purchase block hash and exact transaction-index membership. Requests really name the recorded addresses/selectors/numeric tags. Proxy/loupe identities match accepted bytes. The purchase route really returns the facet above. Each **complete historical facet runtime** equals the published runtime string, not merely its hash or an executable prefix. All 234 selected historical captures are reused offline. Full request locators and expected/actual associations remain on each row.

These are selected **end-of-block** bindings. They do not establish arbitrary transaction-prefix routing, universal transitive dependency equivalence, trustless chain proof, local compilation reproducibility or a common repository revision for all dependencies. Exact-match is the verification service's pedigree claim, supported here by source/hash/body checks, not independently regenerated compiler output. The two current local facet/BondTarget bodies equal the recovered strings; that narrow equality does not authenticate every local dependency. No Git history query or repository-lead expansion was necessary.

## 3. Inspected source meaning

All line numbers below refer to unescaped recovered sources[path].content inside recovered-package.json, **not current checkout line numbers**. The directory prefix for the first four files is contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/.

| Recovered source and lines | Observed mechanism and attribution consequence |
| --- | --- |
| UniswapV4DetfBondFacet.sol:11-21 | Inherits the actual BondTarget and advertises only the bond purchase selector. This is the recovered purchase body, not the unrelated exchange facet used as compatible context in phase32. |
| UniswapV4DetfBondTarget.sol:8-20 | External nonpayable bond forwards the six arguments to _entryBond. |
| UniswapV4DetfTarget.sol:548-578 | nonReentrant entry; active/deadline/disabled checks, resolved recipient, live versus first branch. Hook-LP input has its own live path; all 39 actual leads are WETH/DTF, not that LP. |
| UniswapV4DetfTarget.sol:618-638; UniswapV4DetfCommon.sol:391-403 | Leading false-pretransfer payment pulls from msg.sender to parent and measures actual delta. True would use unbooked parent surplus, but none of the direct calls selects it. |
| UniswapV4DetfTarget.sol:597-616,640-684,836-842 | Principal quote uses the lead seat's pair equivalent and duration. The unboosted G is separately minted for reserve liquidity. An empty full-book branch pulls every other required non-self/non-lead leg from msg.sender at opening/creation-price size. It is not the ordinary one-payment branch. |
| UniswapV4DetfCommon.sol:267-298; contracts/vaults/detf/common/core/DETFMintSplitLib.sol:37-53 | Lead payment sizes G and duration-adjusted purchased principal separately; funded reward/inventory split is not caller-paid DTF18. The extra first-book leg is not passed back into the lead-priced principal quote. |
| UniswapV4DetfCommon.sol:413-460 | Nested exchange approves/spends the parent's already received token amount, recipient=parent in _toShare; join approves parent assets and directs LP to _bondLpHolder. A nested false-pretransfer flag does not mean another pull from the original wallet: the external caller there is the parent. |
| UniswapV4DetfTarget.sol:699-709; UniswapV4DetfCommon.sol:91-100,381-389 | Principal is separately minted/approved into the NFT funding path; rewards are separately minted/funded. Protocol LP, DETF9 self-leg and sDETF9 custody are not another DTF18 original contribution. |
| UniswapV4DetfCommon.sol:481-547,551-682 | Dust uses guarded parent self-calls, parent-held balances, residual joins and parking. Internal join refunds may recirculate into protocol assets. There is no inspected direct caller-refund assignment on this purchase path; this is not proof of zero native/internal refund across arbitrary downstream code. |
| lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:21-29 | The nonReentrant modifier checks, locks, runs and unlocks the entry. The static ABI has no arbitrary action list. This narrows the selected purchase, not every external contract's possible behavior. |

Source observation and receipt observation are separate from inference. Every direct call is exactly 196 bytes, reencodes identically with the actual recovered ABI, has pretransferred=false, zero outer value and the original acquiring wallet as caller/resolved recipient. Every complete receipt has one correct purchased NFT mint and one BondPurchased event matching original principal/start/duration. The proof inspects all 1,746 receipt logs across the 43 weighted context transactions, including **1,582** logs in the 39 direct receipts; no witness is sampled. All 498 direct-row S011 witnesses and 23 S006 witnesses are independently joined and checked.

For the **38 live ordinary rows**, the successful source-defined first branch would emit ReserveLive after opening the NFT. Complete receipts contain no such parent event, while the call is a non-LP bond and the ordinary path has one leading caller pull. Nested settlement spends parent assets. Every other-token component separately has no original-wallet debit **and no original-wallet inflow/refund** in its complete receipt. That affirmative source/call restriction plus complete receipt corroboration supports the table's other-token **gross-payment zero**. Missing logs alone, a zero outer value, current ownership or an arbitrary empty sum would not support it. No statement here turns that zero into zero gas/native cost, lifetime economic exposure or approved E0/D0.

Callbacks and multi-action limits remain layered. The exact outer call is one static bond, and all actual logs are retained, including non-payment protocol activity. No multiple-purchase action is assigned a whole-transaction total. Reentrancy protection and the inspected parent call graph explain the bounded roles; unauthenticated transitive native behavior, arbitrary historical routing changes and the four outer bundles remain outside that proof.

## 4. NFT3: actual first-full-book extra DTF

Original S008 row2, transaction **0x140c83d7c5a5170424fe13788194f21d1f30694bc166134ae486681a1fa3c624**, accepted phase28 results[7]. Actual payer/original acquiring wallet is **0x72bea6fa3e68ef18c87d045aac7c4aa5249d933b**; payment recipient is parent **0x4a5cfdc2b07016fcf917f4ed5a51c52111a0fcc7**.

| Receipt offset / logIndex | Actual observation | Source-supported role |
| --- | --- | --- |
| 1 / 6 | caller -> parent WETH **999999000000000** | Leading false-pretransfer bond payment. |
| 2 / 7 | zero -> parent DETF **3628938576 native9** | Separately minted G self-leg; not WETH18/DTF18 payment. |
| 3 / 8 | caller -> parent DTF **362893857600000000000** | Actual extra caller-paid first-full-book other-leg reserve/protocol capital. **Not zero.** |
| 8 / 13; 10 / 15; 11 / 16 | parent -> 0x46e068c2393e189fbc86632f67210af253a42aa8: leading WETH, G DETF9 and extra DTF respectively | Reserve join funding, not three more original contributions. |
| 23 / 28 | reserve endpoint -> 0x2e9c1f705ab967c5af59249203d7495bdabb223b: same DTF amount | Observed downstream movement of the extra capital; not a second caller payment or a refund to the caller. No blanket historical implementation claim for that endpoint is added. |
| 28 / 33 | reserve LP mint to NFT protocol **1725248455310066742** | Protocol-held liquidity, not original asset payment or personal LP entitlement. |
| 33 / 38; 36 / 41; 39 / 44; 40 / 45 | principal DETF9 mint and funding into NFT/staking custody, with sDETF9 to NFT | Purchased principal **3772281649**; these assets/units are not DTF18 purchase cost. |
| 43 / 48; 44 / 49; 46 / 51 | NFT3 mint, BondPurchased and parent ReserveLive(3,1725248455310066742) | The actual first-purchase branch, consistent with the full-book other-leg pull and ordering above. |
| 47 / 52; 50 / 55 | separate DETF9 reward mint/funding **74393240** | Inventory/reward capital; excluded from original contribution. |

The extra DTF matches S006 logical row2 and S011 logical row6; leading WETH matches S011 logical row5. Both full raw payment logs and all subsequent movements are retained. Exact openingOfPair/creationOfPair values and arbitrary downstream execution are not independently recovered. No historical getter is necessary to observe the two actual debits or their source-consistent roles.

**Financial boundary:** the gross DTF362893857600000000000 is real caller payment, but the source prices the purchased principal from the leading seat and sends the additional leg to the protocol's initial full book. Neither a leading-word-only rule nor a sum-of-all-debits rule establishes approved original NFT cost. Plan5.2's exclusions remain. originalCostDtf18, approvedOriginalCapitalRaw and approvedD0 stay **unknown**, not zero and not this gross amount. WETH18 also remains a proposed token payment rather than approved ETH E0. This handoff makes no owner/policy decision to include the extra protocol capital in compensation.

## 5. All 39 direct-row dispositions

Values are exact **native18 integer strings**. These columns mean proposed **gross caller-paid token quantities**, not approved original NFT cost. F is the source-supported first-full-book role above. L is the live one-pull path with the separately justified other-token zero. The original logical locator is evidence/weighted-bonds.csv#row=N as shown. Full payer/recipient addresses, calldata, complete receipts, offsets, source locators, accepted raw request IDs and exact historical bindings are in direct-attribution.json/rows and proof.json/direct. Original fields/blanks and all old flags/qualifications survive.

| NFT / S008 logical row | Purchase transaction | Proposed gross WETH18 | Proposed gross DTF18 | Caller-payment logIndex | Source-supported disposition |
| --- | --- | ---: | ---: | --- | --- |
| 3 / 2 | 0x140c83d7c5a5170424fe13788194f21d1f30694bc166134ae486681a1fa3c624 | 999999000000000 | 362893857600000000000 | WETH:6; DTF:8 | F: lead WETH plus other-leg DTF protocol capital; original-cost DTF unknown |
| 4 / 3 | 0x2595bbc003c11cf938ea4da468676ca5eb46241b6bdc4e3cc0ae108df7211bfe | 30000000000000000 | 0 | WETH:211 | L: one priced caller payment; affirmative other-token zero |
| 5 / 4 | 0x1812ec8bd64c0629707c30da87cf59d786426271065b0f653501862339947293 | 50000000000000000 | 0 | WETH:1 | L: one priced caller payment; affirmative other-token zero |
| 6 / 5 | 0xeefb57d4fd369c08c6050f125d93f19c7171c557f0280270049ed4c6e613a917 | 80000000000000000 | 0 | WETH:155 | L: one priced caller payment; affirmative other-token zero |
| 7 / 6 | 0xa19407e27f675728c094c6ee0c0f40a37d5be24baaa99b0b68dd58191a25d296 | 130000000000000000 | 0 | WETH:58 | L: one priced caller payment; affirmative other-token zero |
| 8 / 7 | 0xce2e18987a6cd3644b52702fb9ac47fb34e34916ed7c27355c183a72414bb8cb | 220000000000000000 | 0 | WETH:1 | L: one priced caller payment; affirmative other-token zero |
| 9 / 8 | 0x70fb38227e885c80057c384a0ffad1a31912220b7c47d6e29957960849f11d2a | 150000000000000000 | 0 | WETH:59 | L: one priced caller payment; affirmative other-token zero |
| 10 / 9 | 0xf84c55aaee2784b0334e2af96ba6700242060ef5dd33844d4b18d3106f648651 | 180000000000000000 | 0 | WETH:71 | L: one priced caller payment; affirmative other-token zero |
| 11 / 10 | 0xb86e32336704974be5a4c3973269bf2a7256acdb4e262badd13409e4ba174c0b | 0 | 117620151493077568323998 | DTF:5 | L: one priced caller payment; affirmative other-token zero |
| 12 / 11 | 0xbab7b6801334d28cc2805a716aac0b3d08f7d531ab888a1bbddfb8030826aec1 | 0 | 1000000000000000000000000 | DTF:85 | L: one priced caller payment; affirmative other-token zero |
| 13 / 12 | 0x61b92972e5c140d2f79db2e8990ca8cd6d4b0590f43eeaa4abd9bfc36fdf61bb | 0 | 1000000000000000000 | DTF:33 | L: one priced caller payment; affirmative other-token zero |
| 14 / 13 | 0xf9698195b5d4497e0b9b719808697cf1449f3a1ccbbcbaa8cb786a55717ad2cd | 0 | 100000000000000000000 | DTF:53 | L: one priced caller payment; affirmative other-token zero |
| 15 / 14 | 0x1d01114d19123fc4672351935617087af66ffbf7150878d5ece34558bd25bc27 | 0 | 1000000000000000000 | DTF:35 | L: one priced caller payment; affirmative other-token zero |
| 16 / 15 | 0xb2bef901e7b6ff58446a79a6de19a4536b7892f14fd7160d2ae4408c23ae90c1 | 0 | 84207000000000000000000 | DTF:39 | L: one priced caller payment; affirmative other-token zero |
| 17 / 16 | 0x95495a3c68397d245175693240a7f37889e55ca1d0431e6b2b7e47162479878b | 0 | 100000000000000000000 | DTF:0 | L: one priced caller payment; affirmative other-token zero |
| 18 / 17 | 0xe213477237aca92a72461478bb797b2208f79eb872fac28dfeb1130e18d5b1bd | 0 | 28722838050154716955768 | DTF:8 | L: one priced caller payment; affirmative other-token zero |
| 21 / 20 | 0x4f337590de70440aff4716fdd44abd1fb1dd678a211443b8eb3c1a938a93ad0d | 0 | 13638592554139803593186 | DTF:80 | L: one priced caller payment; affirmative other-token zero |
| 22 / 21 | 0x412965ee1ae9b6c8e23939f443f080ee62f5204c1a40319ba23b6a78091cf4ac | 0 | 1010505832294964975193008 | DTF:39 | L: one priced caller payment; affirmative other-token zero |
| 24 / 23 | 0xcce46effe1c0877581ab82bcd32f5690b09dd9eaa782bf653c8545ff9f608352 | 2000000000000000000 | 0 | WETH:5 | L: one priced caller payment; affirmative other-token zero |
| 25 / 24 | 0xbaf5a8671bb876febd555fdfc95ad53289598eb90e0cdb535c5d54a6bb533970 | 0 | 50000000000000000000000 | DTF:54 | L: one priced caller payment; affirmative other-token zero |
| 26 / 25 | 0x03a24910340df937a7597382909e015284f60432f266e63ffc163dc559255e0d | 0 | 50000000000000000000 | DTF:117 | L: one priced caller payment; affirmative other-token zero |
| 27 / 26 | 0x343e2e392a180d5d7b325ad655b26c0af8d6e10ef393c8a63cae9afd33ead0a0 | 0 | 3638287394965303325165504 | DTF:70 | L: one priced caller payment; affirmative other-token zero |
| 28 / 27 | 0x3c4d60f7662423e28bb9701d0d0cc86fba5f1f0a72b657bbab43c86a23ae8737 | 0 | 4646962928061246692056443 | DTF:33 | L: one priced caller payment; affirmative other-token zero |
| 29 / 28 | 0x4657b3a4dc9d185528850a3c348328e2731f1130087464370e9963d0a41c57f1 | 0 | 2000000000000000000000000 | DTF:1 | L: one priced caller payment; affirmative other-token zero |
| 30 / 29 | 0x0b710505696fd871c01a6a671eaf7899bddc3c506972d8ebe88a44f2e46f71d9 | 0 | 500000000000000000000000 | DTF:7 | L: one priced caller payment; affirmative other-token zero |
| 31 / 30 | 0x7bdfad0304c2c6b95a966cb524aa266e20c042dab687376982ae5da4b615da04 | 6190000000000000000 | 0 | WETH:6 | L: one priced caller payment; affirmative other-token zero |
| 32 / 31 | 0x66c1011955675c6927bf67fd64935a147dec659a1791e8ee86ea5cacfdd70914 | 0 | 56017714220190058289217 | DTF:0 | L: one priced caller payment; affirmative other-token zero |
| 33 / 32 | 0x3a1ffa3810f9995a53c474c6a1843543802c82ba23374b21a8356f9d96362cfc | 0 | 15063801572703677690083241 | DTF:0 | L: one priced caller payment; affirmative other-token zero |
| 34 / 33 | 0xd9562354a472f6db7ee553586602a4d96f8340b7d70ecaca49e7f0e1d6283e92 | 0 | 6412108793936732436515 | DTF:40 | L: one priced caller payment; affirmative other-token zero |
| 35 / 34 | 0xaf50932dd1887a0b040b9f3ebe56e41a816438d7bd1a9c60ba9ed2165698032b | 0 | 14069000000000000000000 | DTF:22 | L: one priced caller payment; affirmative other-token zero |
| 36 / 35 | 0x50027e2f28032e2984df2f0d3edf38d9c883505df137aad51a3850e51c0800cb | 0 | 126626591392013828699598 | DTF:36 | L: one priced caller payment; affirmative other-token zero |
| 37 / 36 | 0x542ef3e006d0c2abdffe8de50be1276a715b53001ff8d53a9965314635124ec6 | 3929803780631121610 | 0 | WETH:5 | L: one priced caller payment; affirmative other-token zero |
| 38 / 37 | 0xa8fa821dee294b5c50201e7f42c8edec6b2f1d868156b93757b3589f42678b0f | 2000000000000000000 | 0 | WETH:27 | L: one priced caller payment; affirmative other-token zero |
| 39 / 38 | 0x265781359b86c99ca1df38ea2132430dbc0d96369411e6e6d748d8980c3ecd47 | 6000000000000000000 | 0 | WETH:26 | L: one priced caller payment; affirmative other-token zero |
| 40 / 39 | 0xcb03d5db72ad067fad5199f33e1c6877d68e263ee506ba623ec5c20f3ed272e9 | 1000000000000000000 | 0 | WETH:8 | L: one priced caller payment; affirmative other-token zero |
| 41 / 40 | 0x81d091be8e2fac3b579a6d3dcd99b8ba5656c86002679dbece0e4c00e26e3ab4 | 50000000000000000 | 0 | WETH:10 | L: one priced caller payment; affirmative other-token zero |
| 43 / 42 | 0xab95cc263000f9305cdde269920706aac5e7a8bfd177993e9bc9cb3f79ec0b27 | 0 | 100000000000000000000000 | DTF:23 | L: one priced caller payment; affirmative other-token zero |
| 44 / 43 | 0x8175991424ff423b7e184076fbba7e2a3c6172c7b39d7993492b6d64edbaa7bd | 0 | 1000000000000000000000 | DTF:0 | L: one priced caller payment; affirmative other-token zero |
| 45 / 44 | 0xd70fc904c7b3c6889eb2d3caad6417965674f4b2250a8d20a6649be3cae2e731 | 0 | 100000000000000000000000 | DTF:23 | L: one priced caller payment; affirmative other-token zero |

All approved original WETH/DTF-cost fields, net original capital, internal native refunds, prior compensation and E0/D0/C0 remain unknown. The table does not assert 39 financially approved numeric passes. It completes the bounded role/quantity observation review without resolving those independent decisions.

## 6. Preserved context and precise unknowns

G2 NFTs **19/20/23/42** retain both unknown proposed components and indirect-purchase-or-different-caller. Their existing canonical mint/purchase context is retained, but their outer bundle is not decoded, simulated or retried. All sixteen S009 earlier source-specific proposals and fifteen routed-dtf flags remain unchanged; no earlier field is reinterpreted by this new package.

NFT44/45 still pair with conversions.csv rows94/100, with protocol-held sDETF9 outputs **81035885** and **12596732131**. Each is one purchase origin plus its funding/conversion representation, not a second original contribution. Their pre_attack=false flags remain observations, not approval/exclusion. Neither nonlinear original is merged, reduced, or requoted.

Current means accepted phase31 pin **113279837**, not a refreshed state or purchase-era fact. NFT26's original wallet is 0xc379feb4182211abe71a34858265e4bf5ff35e06 while its observed current owner is 0x2e69e40c4a4ab5ca6826850f347acf8076a8063e. Configuration does not transfer with that ownership. Weighted25 and42 have separate accepted retirement evidence and current zero owners plus genuine nonexistent-position errors; those errors remain errors, not zero positions. Historical purchase inputs do not prove current NFT/descendant control or surrender eligibility.

Accepted phase33 splits the 23 named claims into principal/rewards and proves retirement events for25/42. That finite list is not complete lifetime claim history; current cumulative rewards and descendant control remain unknown. Old rewards are not new original contributions, and old principal payouts are not migration-compensation deductions. No new claim arithmetic is promoted into the purchase inputs.

The exact remaining gaps are: financial original-wallet authority and approved original-cost treatment (especially NFT3's additional protocol capital); native/internal refunds and net economic cost; all prior migration delivery/deductions; E0/D0/C0; history beyond the declared claims and current descendant control; universal historical transitive implementation equivalence; G2 inner payer/action authority; eligibility, funding/composition and operational approval. None is default zero. Broader source coverage, earlier SE, disabled exits/conversions, P1 and registration gas45116678>32000000 remain separate.

**Phase32's first243-response loss remains:** observe-01 completed243 scheduled attempts before its local TypeError; those response entities and outcomes were lost from process memory. They are unavailable and were not reconstructed, repaired or called successful by this work. The retained observe-02 historical bodies are the reused accepted successful observations, not replacements for that loss. Historical P1 capture losses also remain.

## 7. Actual proof, reproducibility and diagnostics

The new offline proof ran **2026-11-13T12:05:08.267Z-12:05:08.961Z**, PID1876, exit0 with empty stderr. It passed **41,822 assertions / 7,379 binding checks**; binding counts include repeated occurrences, not that many independent histories. proof.json is the exact captured stdout: **6,336,233 bytes**, SHA-256 **e5a0aafdc3a509e40708c5d4ae6ff565ad40178c059b43972b1bd7705426ea98**. The owned final reproduction ran **12:07:37.343Z-12:07:37.933Z**, PID3394, exit0, and reproduced that complete JSON byte-for-byte before comparing direct attribution, source index and unchanged context. This is producer verification, not the downstream independent verifier's verdict.

All four actual Node --check children exited0 with empty streams. evidence.mjs owns evidence authentication; rows.mjs owns per-original witness reconstruction; prove.mjs owns proof assembly; verify.mjs owns published-output comparison. They have 143, 192, 81 and 26 nonblank/noncomment lines respectively at review, each one responsibility. No type suppression, production seam, test weakening or dependency installation was introduced. This is scoped executable evidence, not a compiler/full-gate replay. Fresh LSP diagnostics were unavailable: biome was not installed and another fresh-diagnostics request timed out. No clean LSP or strict checked-JavaScript result is claimed.

Read-only reproduction from any CWD:

```sh
/opt/homebrew/Cellar/bun/1.4.2/bin/bun /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase34-weighted-purchase-source/source/verify.mjs
```

The command reauthenticates admitted sources and bodies, independently rederives original direct rows from raw S008/calls/receipts, and compares the published owned outputs. It writes no file and opens no network connection. No prior collector, proof program, compiler or old gate is executed.

attempts.md retains local preparation errors and unavailable tooling; no command failure or missing response is concealed. All source-role reasoning is human inspection of the authenticated bodies; counting assertions is not a substitute for that semantic review.

## 8. Stopped cleanup and seal

All proof, reproduction and syntax processes have actual exit receipts. A final read-only process check requires the recorded child PIDs absent; no provider, signer, monitor, server, chain or subagent was started. No temporary runtime/dependency/cache was created and no deletion is required. Shared services, production code, old/source evidence and verification/ were untouched.

Final preservation reauthenticates every admitted body identity. source-manifest.json binds all owned scripts. cleanup.json records actual stopped processes, final preservation and zero pending operations. manifest.json binds every other owned final artifact except itself and seal.json. seal.json is the **last file publication**, binding that manifest, report, proof, source index, source manifest and cleanup; no producer write follows it.

**Complete and stopped for this bounded39-direct-row source-supported observation handoff only. No financial allocation, source-wide approval, operational action or full-plan acceptance follows.**
