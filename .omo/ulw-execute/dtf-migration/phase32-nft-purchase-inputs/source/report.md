# Phase32 historical NFT purchase inputs: stopped producer handoff

Date: November 13, 2026.

**Complete bounded reconciliation of all 59 named purchases.** Sixteen earlier-CP purchases have source-specific proposed native18 token inputs: 16 nonzero paid components and 16 affirmative other-component zeros. The 43 weighted purchases retain 86 unknown components: 39 direct calls lack an authenticated source/ABI for their actual purchase facet, and four indirect calls remain deliberately unresolved. All 19 purchase flags and both NFT/protocol-conversion pairs remain. This is not an allocation or financial approval.

The producer proof passed **4,915 checks** across every purchase and every one of the **363** retained historical read requests. It is producer-side proof, not the separate independent verification verdict. The workflow's downstream verifier owns verification/; this producer neither writes there nor claims its result.

## Scope, authorities and original evidence

Only this source/ directory was written. The complete brief, current plan r5 and PRD r22, provenance report, accepted phase27 R2 preparation/review, phase28 and phase30 verification reports/archives/reconciliations, joined worksheet and its independent review, and phase31 same-pin source and verification reports were read. Current plan sections 1.3-1.5 and 5.2 govern. Historical policy, equal NFT counts, original input observations and current control remain separate.

The frozen root is /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase27-frozen-input-recovery/input-tree/2026-09-16-dtf-recovery. All 36 declarations over 27 paths authenticate before table parsing; adding manifest.json gives 28 physical bodies. These are hash-authenticated recovered historical bodies, not located original captures. The owned intake independently enumerates complete S008 and S009 tables as 43+16 rows, preserves every original field and blank, and joins canonical receipts individually. S006 and S011 witnesses remain on every applicable weighted record, including their exact logical row locators. Earlier purchases retain S009's original LP-accounting basis and its direct/routed fields; canonical phase28 receipts supply their mint/event witnesses.

Accepted phase28/30 canonical verification is reused, not recollected. Their full sealed manifests, and the flow-review and phase31 verifier manifests, are authenticated on intake. The worksheet SHA-256 remains ed8474ac3454453697308ce82adffebb8bbfe9d346050973e0753a46cf6af39e. No earlier all-unknown worksheet or evidence was edited. inputs.json records actual input identities; source-manifest.json binds owned code and failed executed snapshots. The evidence manifest binds all new raw and derived bodies.

## Actual entrypoints and historical deployment bindings

All 55 direct records have exactly 196 calldata bytes: selector **0x7a3b1181** and six static words. They reencode byte-for-byte as bond(address,uint256,uint256,address,bool,uint256). Sender equals historical acquiring/mint recipient; recipient word resolves to that recipient; pretransferred=false; outer value=0. The actual source-bound ABI name is established for earlier CP only. Weighted calls are explicitly labelled bond-shaped until their actual facet body is authenticated; a matching selector or local interface is not that authentication.

One bounded acquisition used existing robinhood_mainnet_alchemy and authenticated chain 4663. At each direct transaction's numeric historical block it captured the canonical header, proxy runtime, facetAddress's own routing/runtime, purchase-selector routing/runtime, and, for earlier CP, the pairToken getter route/value. Every header matches the accepted transaction block/hash and membership. Every proxy and loupe runtime matches the archive. No receipt collector, transaction/receipt request, trace, range scan, storage RPC, state override, alternate provider or phase29 operation ran.

The retained successful observer ran 11:06:38.650Z-11:07:15.039Z, exit 0. Its 363 calls are 1 chainId, 55 block-by-number, 165 code and 142 eth_call. All return safe raw entities, matching IDs, HTTP 200 and no failure. http02/ contains exact request and response entities plus capture records. observe-02.stdout retains full runtime bytes, parameters/results and per-purchase request IDs; http-manifest.json adds lengths/hashes and paths. No credential was redacted in this successful run. These are RPC response entities, not signed transactions, trustless proofs or consensus finality.

These historical getter observations are **block-end state**, not an execution-prefix trace or proof against an arbitrary intra-block routing change. They are source-specific bounded historical bindings, not all-history authenticated build pedigree. No execution-prefix prerequisite or reconstruction was introduced.

### S1: earlier-CP source-specific inputs

All 16 historical purchases route bond to **0x8333749cc7b1f66b5be568257d362aa749497cf0**, runtime Keccak-256 **0x5b5f12902a0baeb235ec2dc91794c425a0c60a439a7d9070cb1abb17b094389d**. Each exact historical runtime equals the archived onchain bytes. The historical pairToken getter routes to that same facet and returns DTF 0xee5576fa1bcaa380e591d01245f406f3f384eb01. Archived source-service match/metadata qualifications are retained, not upgraded to exact_match.

Source: /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/earlier-cp/probe-alchemy-retry.source.json, member contracts[0x8333749cc7b1f66b5be568257d362aa749497cf0].sources[UniswapV4SingleStandardExchangeDETFFacet.sol].content. Line numbers below address that unescaped historical source, not current checkout code:

- **25352-25403:** nonpayable bond checks the route, normalizes recipient, settles one token input, joins protocol liquidity, opens the LP-accounting NFT, accounts reward/inventory legs and synchronizes reserves.
- **25021-25035:** _pullToken(false) pulls amountIn from msg.sender into the parent and measures the delta. The true branch instead credits existing unbooked surplus and does not establish who paid; none of these direct calls selects it.
- **25105-25124:** direct pairToken settles the single pull unchanged; WETH/other allowed inputs are pulled once and routed through the SE.
- **25046-25060:** nested exchange pushes already held capital to the SE and calls exchangeIn with pretransferred=true and recipient=this parent. It does not pull another original wallet contribution.
- **24832-24844:** reserve join approves the parent's protocol DETF and pair assets, then deposits with the protocol LP holder as recipient. Reserve settlement is not another user payment.
- **24946-24995:** protocol reward compounding uses protocol-held positions and joins; it is not another caller purchase input.

For every earlier purchase the exact calldata primary amount equals exactly one matching caller-to-parent Transfer. Complete receipts show no incoming DTF/WETH to the acquiring wallet, no other DTF/WETH wallet debit, and no token refund offset. The source-bound one-pull path (including its first-bond branch) supplies the affirmative restriction supporting the other token component's zero; the zero is not inferred merely from missing logs. The parent has no native-value/wrapping input branch on this path. No native ETH amount, gas charge, missing WETH Deposit/Withdrawal event or hypothetical native refund is substituted for these observed ERC20 amounts.

These are proposed **purchase-time caller-paid WETH and DTF components**, not a lifetime net cash-flow claim, prior-compensation proof, ETH/WETH equivalence at every route, approved E0/D0, or eligibility. Internal native refunds remain explicitly unknown. Original contributions are not reduced for later principal claims, enlarged for rewards, or requoted here.

Fifteen routed-dtf flags survive. Their saved field measures SE-only routed DTF; the broader old comparison also includes reserve-LP settlement. That scope difference does not make S009 erroneous. In particular earlier NFT 3's paid WETH 2000000000000000000 is not added to its routed DTF 1778859964387451305574664. Earlier NFT 9 similarly has WETH 100000000000000 and separate SE-routed DTF 41454674363068691516. All exact routed and other-parent events are retained with endpoint/log classification.

### G1: 39 direct weighted calls, exact remaining gap

Every direct weighted purchase routes selector 0x7a3b1181 to **0xaaf47ef19c9b932b6d00bca3683b000fc6208661**, runtime Keccak-256 **0x2676830f3b489088787c4ecc21803326a7909fbaaf9fd72994ec62b111bf62f8**. Full actual bytes and each historical binding are retained. **That facet has no verified source/ABI body in the inspected weighted/earlier archives.** The missing fact is the actual purchase implementation's binding to its payment, first-bond multi-input, refund/native and transitive-routing semantics, not another receipt or a current NFT balance.

The weighted archive at /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-01/docs/incidents/2026-09-16-dtf-recovery/migration/evidence/weighted/probe.sources.json contains source imported by exchange facet 0x4886f86cd0dfff8b8a836f858925ed4de3a2b291. UniswapV4DetfExchangeFacet.sol exposes exchangeIn only. Its shared UniswapV4DetfTarget.sol:548-638,645-709 contains internal bond logic, including **first-bond other-leg caller pulls at 662-684**. UniswapV4DetfCommon.sol:391-403 defines pull versus reserve-surplus semantics, :413-460 nested approvals/joins, :481-547 protocol dust settlement. Those bodies are relevant compatible source, **not proof the actual purchase facet executes them**. The actual weighted facet is not the authenticated exchange facet.

Both weighted components therefore remain unknown for every G1 row, even when a lead word and caller debit agree. Weighted NFT 3's receipt includes separate DTF 362893857600000000000 and WETH 999999000000000 observations; treating only its lead token as paid, or forcing the other component to zero, would ignore the documented possible first-bond multi-leg mechanism. Current local names, calldata amount, gross transfers and later source state cannot fill the missing implementation fact. No new source fetch or compilation was attempted outside the allowed provider methods.

### G2: four indirect weighted purchases

Weighted NFTs 19/20/23/42 remain flagged indirect-purchase-or-different-caller, with complete already-authenticated mint/token/event observations retained. The outer callee is 0x5ff137d4b0fdcd49dca30c7cf57e578a026d2789 with selector 0x1fad948c. The outer bundle is not decoded; no inner invocation, payer authority or delegation is authenticated or retried. Both components stay unknown. No outer-bundle total is assigned to a purchase.

## All 59 dispositions

Amounts in proposed columns are exact native18 integer strings. **unknown is not zero.** Lead calldata is a raw call observation, not a proposed financial amount, especially for G1. S1/G1/G2 mean the source-supported result or precise gap above. Every original field, full call/receipt, mint/source event, raw/log locator, input/source identity, historical getter binding, original acquiring wallet and separate current-state row is in reconcile-01.stdout, a JSON document.

| Source / NFT | Original logical locator | Purchase transaction | Lead calldata observation | Proposed WETH18 | Proposed DTF18 | Retained purchase flags | Reason |
| --- | --- | --- | --- | ---: | ---: | --- | --- |
| S008 / 3 | evidence/weighted-bonds.csv#row=2 | 0x140c83d7c5a5170424fe13788194f21d1f30694bc166134ae486681a1fa3c624 | WETH:999999000000000 | unknown | unknown | none | G1 |
| S008 / 4 | evidence/weighted-bonds.csv#row=3 | 0x2595bbc003c11cf938ea4da468676ca5eb46241b6bdc4e3cc0ae108df7211bfe | WETH:30000000000000000 | unknown | unknown | none | G1 |
| S008 / 5 | evidence/weighted-bonds.csv#row=4 | 0x1812ec8bd64c0629707c30da87cf59d786426271065b0f653501862339947293 | WETH:50000000000000000 | unknown | unknown | none | G1 |
| S008 / 6 | evidence/weighted-bonds.csv#row=5 | 0xeefb57d4fd369c08c6050f125d93f19c7171c557f0280270049ed4c6e613a917 | WETH:80000000000000000 | unknown | unknown | none | G1 |
| S008 / 7 | evidence/weighted-bonds.csv#row=6 | 0xa19407e27f675728c094c6ee0c0f40a37d5be24baaa99b0b68dd58191a25d296 | WETH:130000000000000000 | unknown | unknown | none | G1 |
| S008 / 8 | evidence/weighted-bonds.csv#row=7 | 0xce2e18987a6cd3644b52702fb9ac47fb34e34916ed7c27355c183a72414bb8cb | WETH:220000000000000000 | unknown | unknown | none | G1 |
| S008 / 9 | evidence/weighted-bonds.csv#row=8 | 0x70fb38227e885c80057c384a0ffad1a31912220b7c47d6e29957960849f11d2a | WETH:150000000000000000 | unknown | unknown | none | G1 |
| S008 / 10 | evidence/weighted-bonds.csv#row=9 | 0xf84c55aaee2784b0334e2af96ba6700242060ef5dd33844d4b18d3106f648651 | WETH:180000000000000000 | unknown | unknown | none | G1 |
| S008 / 11 | evidence/weighted-bonds.csv#row=10 | 0xb86e32336704974be5a4c3973269bf2a7256acdb4e262badd13409e4ba174c0b | DTF:117620151493077568323998 | unknown | unknown | none | G1 |
| S008 / 12 | evidence/weighted-bonds.csv#row=11 | 0xbab7b6801334d28cc2805a716aac0b3d08f7d531ab888a1bbddfb8030826aec1 | DTF:1000000000000000000000000 | unknown | unknown | none | G1 |
| S008 / 13 | evidence/weighted-bonds.csv#row=12 | 0x61b92972e5c140d2f79db2e8990ca8cd6d4b0590f43eeaa4abd9bfc36fdf61bb | DTF:1000000000000000000 | unknown | unknown | none | G1 |
| S008 / 14 | evidence/weighted-bonds.csv#row=13 | 0xf9698195b5d4497e0b9b719808697cf1449f3a1ccbbcbaa8cb786a55717ad2cd | DTF:100000000000000000000 | unknown | unknown | none | G1 |
| S008 / 15 | evidence/weighted-bonds.csv#row=14 | 0x1d01114d19123fc4672351935617087af66ffbf7150878d5ece34558bd25bc27 | DTF:1000000000000000000 | unknown | unknown | none | G1 |
| S008 / 16 | evidence/weighted-bonds.csv#row=15 | 0xb2bef901e7b6ff58446a79a6de19a4536b7892f14fd7160d2ae4408c23ae90c1 | DTF:84207000000000000000000 | unknown | unknown | none | G1 |
| S008 / 17 | evidence/weighted-bonds.csv#row=16 | 0x95495a3c68397d245175693240a7f37889e55ca1d0431e6b2b7e47162479878b | DTF:100000000000000000000 | unknown | unknown | none | G1 |
| S008 / 18 | evidence/weighted-bonds.csv#row=17 | 0xe213477237aca92a72461478bb797b2208f79eb872fac28dfeb1130e18d5b1bd | DTF:28722838050154716955768 | unknown | unknown | none | G1 |
| S008 / 19 | evidence/weighted-bonds.csv#row=18 | 0x514ce8099216a62d16f6c1d84829a8c71e49e6d02359266486a055dd5fae77a9 | not decoded | unknown | unknown | indirect-purchase-or-different-caller | G2 |
| S008 / 20 | evidence/weighted-bonds.csv#row=19 | 0xb3778e6b5b6cb914fc9c99dd258034e949b3eea9be8ad7c3888b1d63bd2e3a71 | not decoded | unknown | unknown | indirect-purchase-or-different-caller | G2 |
| S008 / 21 | evidence/weighted-bonds.csv#row=20 | 0x4f337590de70440aff4716fdd44abd1fb1dd678a211443b8eb3c1a938a93ad0d | DTF:13638592554139803593186 | unknown | unknown | none | G1 |
| S008 / 22 | evidence/weighted-bonds.csv#row=21 | 0x412965ee1ae9b6c8e23939f443f080ee62f5204c1a40319ba23b6a78091cf4ac | DTF:1010505832294964975193008 | unknown | unknown | none | G1 |
| S008 / 23 | evidence/weighted-bonds.csv#row=22 | 0x3763ac1015d74655c52e84357ffcfef4cc59938fcfd6d77dafb0a0bc0d7efd3a | not decoded | unknown | unknown | indirect-purchase-or-different-caller | G2 |
| S008 / 24 | evidence/weighted-bonds.csv#row=23 | 0xcce46effe1c0877581ab82bcd32f5690b09dd9eaa782bf653c8545ff9f608352 | WETH:2000000000000000000 | unknown | unknown | none | G1 |
| S008 / 25 | evidence/weighted-bonds.csv#row=24 | 0xbaf5a8671bb876febd555fdfc95ad53289598eb90e0cdb535c5d54a6bb533970 | DTF:50000000000000000000000 | unknown | unknown | none | G1 |
| S008 / 26 | evidence/weighted-bonds.csv#row=25 | 0x03a24910340df937a7597382909e015284f60432f266e63ffc163dc559255e0d | DTF:50000000000000000000 | unknown | unknown | none | G1 |
| S008 / 27 | evidence/weighted-bonds.csv#row=26 | 0x343e2e392a180d5d7b325ad655b26c0af8d6e10ef393c8a63cae9afd33ead0a0 | DTF:3638287394965303325165504 | unknown | unknown | none | G1 |
| S008 / 28 | evidence/weighted-bonds.csv#row=27 | 0x3c4d60f7662423e28bb9701d0d0cc86fba5f1f0a72b657bbab43c86a23ae8737 | DTF:4646962928061246692056443 | unknown | unknown | none | G1 |
| S008 / 29 | evidence/weighted-bonds.csv#row=28 | 0x4657b3a4dc9d185528850a3c348328e2731f1130087464370e9963d0a41c57f1 | DTF:2000000000000000000000000 | unknown | unknown | none | G1 |
| S008 / 30 | evidence/weighted-bonds.csv#row=29 | 0x0b710505696fd871c01a6a671eaf7899bddc3c506972d8ebe88a44f2e46f71d9 | DTF:500000000000000000000000 | unknown | unknown | none | G1 |
| S008 / 31 | evidence/weighted-bonds.csv#row=30 | 0x7bdfad0304c2c6b95a966cb524aa266e20c042dab687376982ae5da4b615da04 | WETH:6190000000000000000 | unknown | unknown | none | G1 |
| S008 / 32 | evidence/weighted-bonds.csv#row=31 | 0x66c1011955675c6927bf67fd64935a147dec659a1791e8ee86ea5cacfdd70914 | DTF:56017714220190058289217 | unknown | unknown | none | G1 |
| S008 / 33 | evidence/weighted-bonds.csv#row=32 | 0x3a1ffa3810f9995a53c474c6a1843543802c82ba23374b21a8356f9d96362cfc | DTF:15063801572703677690083241 | unknown | unknown | none | G1 |
| S008 / 34 | evidence/weighted-bonds.csv#row=33 | 0xd9562354a472f6db7ee553586602a4d96f8340b7d70ecaca49e7f0e1d6283e92 | DTF:6412108793936732436515 | unknown | unknown | none | G1 |
| S008 / 35 | evidence/weighted-bonds.csv#row=34 | 0xaf50932dd1887a0b040b9f3ebe56e41a816438d7bd1a9c60ba9ed2165698032b | DTF:14069000000000000000000 | unknown | unknown | none | G1 |
| S008 / 36 | evidence/weighted-bonds.csv#row=35 | 0x50027e2f28032e2984df2f0d3edf38d9c883505df137aad51a3850e51c0800cb | DTF:126626591392013828699598 | unknown | unknown | none | G1 |
| S008 / 37 | evidence/weighted-bonds.csv#row=36 | 0x542ef3e006d0c2abdffe8de50be1276a715b53001ff8d53a9965314635124ec6 | WETH:3929803780631121610 | unknown | unknown | none | G1 |
| S008 / 38 | evidence/weighted-bonds.csv#row=37 | 0xa8fa821dee294b5c50201e7f42c8edec6b2f1d868156b93757b3589f42678b0f | WETH:2000000000000000000 | unknown | unknown | none | G1 |
| S008 / 39 | evidence/weighted-bonds.csv#row=38 | 0x265781359b86c99ca1df38ea2132430dbc0d96369411e6e6d748d8980c3ecd47 | WETH:6000000000000000000 | unknown | unknown | none | G1 |
| S008 / 40 | evidence/weighted-bonds.csv#row=39 | 0xcb03d5db72ad067fad5199f33e1c6877d68e263ee506ba623ec5c20f3ed272e9 | WETH:1000000000000000000 | unknown | unknown | none | G1 |
| S008 / 41 | evidence/weighted-bonds.csv#row=40 | 0x81d091be8e2fac3b579a6d3dcd99b8ba5656c86002679dbece0e4c00e26e3ab4 | WETH:50000000000000000 | unknown | unknown | none | G1 |
| S008 / 42 | evidence/weighted-bonds.csv#row=41 | 0x3334bd0e091f8d9f869709c6333b5e6e491dc15cd0e1a35c0283aaf3fa3739ba | not decoded | unknown | unknown | indirect-purchase-or-different-caller | G2 |
| S008 / 43 | evidence/weighted-bonds.csv#row=42 | 0xab95cc263000f9305cdde269920706aac5e7a8bfd177993e9bc9cb3f79ec0b27 | DTF:100000000000000000000000 | unknown | unknown | none | G1 |
| S008 / 44 | evidence/weighted-bonds.csv#row=43 | 0x8175991424ff423b7e184076fbba7e2a3c6172c7b39d7993492b6d64edbaa7bd | DTF:1000000000000000000000 | unknown | unknown | none | G1 |
| S008 / 45 | evidence/weighted-bonds.csv#row=44 | 0xd70fc904c7b3c6889eb2d3caad6417965674f4b2250a8d20a6649be3cae2e731 | DTF:100000000000000000000000 | unknown | unknown | none | G1 |
| S009 / 3 | evidence/earlier-cp-bonds.csv#row=2 | 0xc0a74f69a4a58540168c070968bb8f2d13759195e4ccabfe469ba3ad3d3d1c75 | WETH:2000000000000000000 | 2000000000000000000 | 0 | none | S1 |
| S009 / 4 | evidence/earlier-cp-bonds.csv#row=3 | 0x0fc1a71638d581251317d0d83a248e1cc3317af73b07205120083ab32eaf8fc4 | DTF:7215852540309913726431 | 0 | 7215852540309913726431 | routed-dtf | S1 |
| S009 / 5 | evidence/earlier-cp-bonds.csv#row=4 | 0x80a7af214d8aafe95e2b62b6c67a28b98ef1601f417a5c07b942e44e717f8fa1 | DTF:14939945008882434692090 | 0 | 14939945008882434692090 | routed-dtf | S1 |
| S009 / 6 | evidence/earlier-cp-bonds.csv#row=5 | 0x68cf362d094e28799bb02943c0fa5d8b7a4577d40d701e360c791bc715ed7535 | DTF:55026060195080703684401 | 0 | 55026060195080703684401 | routed-dtf | S1 |
| S009 / 7 | evidence/earlier-cp-bonds.csv#row=6 | 0x90ad17355e01e23c01e80ab93b246a61c0e791a7d85066c6341fcbf44b963067 | DTF:320000000000000000000000 | 0 | 320000000000000000000000 | routed-dtf | S1 |
| S009 / 8 | evidence/earlier-cp-bonds.csv#row=7 | 0x176e169d8d7add51dce9f3f5009f6322f93264fc7cfdc17a5d2c969066a4a88f | DTF:10000000000000000000000 | 0 | 10000000000000000000000 | routed-dtf | S1 |
| S009 / 9 | evidence/earlier-cp-bonds.csv#row=8 | 0xf504bc3b5ec0452769f18c7c53f759dd4579afe9622ea72db6736bddb83d6e55 | WETH:100000000000000 | 100000000000000 | 0 | routed-dtf | S1 |
| S009 / 10 | evidence/earlier-cp-bonds.csv#row=9 | 0x8ec17aa049770ee9c2d525d5e6e1c707ee42f2c039532526de56a132c9f5876f | DTF:1000000000000000000000 | 0 | 1000000000000000000000 | routed-dtf | S1 |
| S009 / 11 | evidence/earlier-cp-bonds.csv#row=10 | 0xb6292353395922bd69b073664afb0188d47cbdbfcc4d13cd185ac37d4cb4ad73 | DTF:100000000000000000000 | 0 | 100000000000000000000 | routed-dtf | S1 |
| S009 / 12 | evidence/earlier-cp-bonds.csv#row=11 | 0x75555879247aa52ce308f86f50f9f3330ccdef438072726a63d55d5ca915ab24 | DTF:75081277576132719227716 | 0 | 75081277576132719227716 | routed-dtf | S1 |
| S009 / 13 | evidence/earlier-cp-bonds.csv#row=12 | 0xa18c5713d0e7f67099072b20ecca3418c89dc9bf61af2f503f9fa04f97f5625b | DTF:22000000000000000000 | 0 | 22000000000000000000 | routed-dtf | S1 |
| S009 / 14 | evidence/earlier-cp-bonds.csv#row=13 | 0x1b17aaa9a895121a4b496bb5c74ba00e4ed445951f2ed1a6cc7ba3b1dc77a829 | DTF:100000000000000000000 | 0 | 100000000000000000000 | routed-dtf | S1 |
| S009 / 15 | evidence/earlier-cp-bonds.csv#row=14 | 0xa45445505ce0d5c5f8011d49bef9344f883a245d6a86a0752a610376c6bb5287 | DTF:600000000000000000000 | 0 | 600000000000000000000 | routed-dtf | S1 |
| S009 / 16 | evidence/earlier-cp-bonds.csv#row=15 | 0x0a902f1d04b7da358cc37504cb976901597febc12f72d13cf9d2db660190ec8a | DTF:1063674247110000000000 | 0 | 1063674247110000000000 | routed-dtf | S1 |
| S009 / 17 | evidence/earlier-cp-bonds.csv#row=16 | 0xb525bd3a74304840614be0fd894afd6f24b93f022be6b2c8d6be5df04d7314b6 | DTF:117496434189960639589934 | 0 | 117496434189960639589934 | routed-dtf | S1 |
| S009 / 18 | evidence/earlier-cp-bonds.csv#row=17 | 0x46b804fa90b141eb7ec105162f11d9b70238f5cdd44284caffefab1c01574e1d | DTF:1000000000000000000 | 0 | 1000000000000000000 | routed-dtf | S1 |

## Economic origins and current ownership

The two shared transactions are linked to one purchase origin each, never two contributions:

| NFT / purchase locator | Transaction | Protocol conversion locator | Protocol-held sDETF output |
| --- | --- | --- | ---: |
| Weighted NFT 44 / weighted-bonds row43 | 0x8175991424ff423b7e184076fbba7e2a3c6172c7b39d7993492b6d64edbaa7bd | conversions.csv#row=94 | 81035885 native9 |
| Weighted NFT 45 / weighted-bonds row44 | 0xd70fc904c7b3c6889eb2d3caad6417965674f4b2250a8d20a6649be3cae2e731 | conversions.csv#row=100 | 12596732131 native9 |

Both original wallet contexts are 0xd221eea1c0ca823f57a96fdfe1d392a367384fdd; both conversion recipients are weighted NFT protocol 0xfe4cc6d5faafdf210af4e728f4108fcaad9bb65e. Full original conversion fields, exact phase30 output review and saved Transfer locators remain on each economicOriginLinks entry. Caller DTF outflows go to the weighted DETF, not another personal contribution assigned to the NFT protocol. Conversion/native9 funding is neither input DTF18 nor another award.

All phase31 pin 113279837 observations remain separate: 57 present, weighted NFTs 25/42 absent after historical mint, weighted NFT 26 held by a different wallet. Absence does not erase purchase history or approve descendant compensation. A transfer does not move configured compensation; future surrender requires the configured original wallet's actual control. Weighted NFTs 44/45 retain pre_attack=false without approval or exclusion. No current principal, LP accounting, share, gon, reward or receipt quantity is substituted for purchase inputs.

## Reproduction and actual checks

From any CWD, the owned scripts use absolute admitted input paths and their own module directory:

```sh
/opt/homebrew/Cellar/bun/1.4.2/bin/bun /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase32-nft-purchase-inputs/source/reconcile.mjs
/opt/homebrew/Cellar/bun/1.4.2/bin/bun /Users/cyotee/Projects/indexedex/.omo/ulw-execute/dtf-migration/phase32-nft-purchase-inputs/source/prove.mjs
```

Both commands are offline and emit JSON to stdout. Do not rerun record/observe/finalize into this sealed directory: their output publication is exclusive. A separately authorized reproduction must own fresh output paths. No prior collector or proof was replayed. The producer's new proof independently reconstructs the six ABI words, exact proposed quantities and unknowns, historical request parameters, raw entity hashes/envelopes, code/route equality, membership, all original joins/flags and both origin pairs. It imports no observation or reconciliation algorithm. Its shared authenticated intake is not described as an independent verifier oracle.

reconcile-01, reconcile-repeat and prove-01 all exited 0. The two complete derivation outputs are byte-identical. The final owned syntax check covers all 8 .mjs bodies with Node --check; its exact stopped receipt and per-script output are retained. No strict checked-JavaScript/typecheck or fresh-LSP pass is claimed; fresh LSP requests timed out. No Forge, install, old operator/full gate, signing or deployment ran.

| Actual main artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| reconcile-01.stdout (complete JSON dispositions) | 4313971 | 362c9b2d992280533e7c8fa7bf90406e7e64ab67e591ca475be3b31ed6953cd6 |
| observe-02.stdout (complete historical reads) | 5761016 | 26889b527c6179c886d0b1fb6a6c5893f43cfb4165a2b99df9860e773bb574de |
| prove-01.stdout | 32835 | 6f752e27a9a7dc8e1e6b9a2ee6b06abc4e7543e9f95ab7c5a1f1b2ad9fed6b80 |
| validate-01.stdout | 2724 | 115b01d51cb99d445bd11ca6a3f9c0f48fb07805b094c61ccc194edb0b235828 |

The eight small modules separately own authenticated intake, bounded transport,
historical acquisition, reconciliation, raw/amount proof, command recording,
syntax validation and sealing. Each remains below 200 nonblank/noncomment lines.
There are no type suppressions, production seams, new dependencies or test
changes. The earlier recorder body was also recovered byte-for-byte against its
executed SHA-256 and retained as record-executed01.mjs.txt.

## Retained failures and diagnostics

- A report-draft code-fence encoding introduced NUL characters. Text-hunk correction was rejected as binary; the owned draft was replaced through apply_patch with this text-only report before sealing. No evidence value changed.
- The directory listing tool was registered but inactive; native read-only directory enumeration was used instead. A V28 scratch-name lookup failed before any action.
- Offline intake initially assumed a top-level seal.manifest; phase31 instead binds manifest.json inside bindings. The exact format was inspected and corrected before network work. The recovered provenance report is in the current primary incident directory, not the frozen tree.
- The first offline original-field comparison was order-sensitive JSON text and rejected equal objects. Deep object comparison corrected it; no input changed.
- **observe-01 exited 1** at 11:05:27.445Z after first earlier-row source lookup attempted data.wa[earlierCollection].runtimeBytecode. The exact executed observer and transport bodies are retained as observe-executed01.mjs.txt and rpc-executed01.mjs.txt, with the complete stderr/command receipt. The first schedule had settled 243 requests before that local TypeError. Captures existed only in that process's memory and were lost; **their raw bytes and response outcomes are unavailable, not reconstructed or used as proof**. This is a preservation limitation of that failed new attempt, not an accepted receipt archive loss.
- The material correction uses the earlier proxy's actual archived bytes and durably publishes each safe raw entity/capture before the next request. observe-02 is the complete successful 363-request archive. No provider refusal was retried, no accepted receipt collection repeated, and no phase29 lane reopened. First-attempt failure is not hidden by the second result.

## Cleanup, seal and limits

All recorded observer, derivation, proof and syntax children have stopped with actual close events. There is no pending owned provider request, process, monitor command, signer, server, chain or subagent. No temporary runtime or cache was created and no deletion is required. Shared services, original raw declarations, old worksheets and evidence, tracked code/configuration and production sources are untouched. No Git operation or commit occurred.

The final publisher reauthenticates admitted inputs and stopped command streams, checks child PIDs absent, scans literal/encoded selected credential values, writes exact manifests and cleanup, then publishes seal.json **last** and exits. Its externally observed exit completes the producer handoff; no producer write follows it.

The bounded producer deliverable is complete with explicit gaps, not financial/source/operational/full-plan acceptance. Eligibility, original-wallet authority approval, all prior claims/delivery, origin uniqueness beyond the named two pairs, internal native refunds, approved E0/D0, funding and immutable funded snapshot, configuration and C0 remain unapproved/unknown. No nonlinear quote, price/market conversion, allocation or executable loader input is produced. Earlier SE, broader T, disabled exits, selected composition/funding, registration 45,116,678 > 32,000,000 gas and P1 remain separate. Independent verification is the workflow's next owned role, not a pending producer operation or a claimed verdict.
