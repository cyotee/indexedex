# Complete ArbOS 61 method inventory

All 191 Solidity ABI methods from the exact pinned interface tree appear below.
190 are version-enabled. O = ordinary potentially successful (109); R = ordinary
dispatch always reverts (5); P = role-restricted (68); D = debug-config-only (7);
Z = zero-caller-only (1); I = inactive at61 (1). State/input conditions still apply
to O. No row authenticates the required executing prefix at source. None of
these labels attests the deployed native handler. Full inputs/outputs, fields,
body, exact gates and deployment observations are in inventory.json.

Source locators below are relative to sources/. Fields and producer update
points for each flow key are fully spelled out in dataflows.json and below.
Addresses are zero-padded to20 bytes in inventory.json.

| Family/address | ABI method | Selector | Versions min..max | Mutability | Access | Dataflows | Handler source lines |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ArbInfo / 0x0000000000000000000000000000000000000065 | `getBalance(address)` | `0xf8b2cb4f` | 0..unbounded | view | O | account | nitro/precompiles/ArbInfo.go:19-24 |
| ArbInfo / 0x0000000000000000000000000000000000000065 | `getCode(address)` | `0x7e105ce2` | 0..unbounded | view | O | account | nitro/precompiles/ArbInfo.go:27-37 |
| ArbAddressTable / 0x0000000000000000000000000000000000000066 | `addressExists(address)` | `0xa5025222` | 0..unbounded | view | O | addressTable | nitro/precompiles/ArbAddressTable.go:17-19 |
| ArbAddressTable / 0x0000000000000000000000000000000000000066 | `compress(address)` | `0xf6a455a2` | 0..unbounded | nonpayable | O | addressTable | nitro/precompiles/ArbAddressTable.go:22-24 |
| ArbAddressTable / 0x0000000000000000000000000000000000000066 | `decompress(bytes,uint256)` | `0x31862ada` | 0..unbounded | view | O | addressTable | nitro/precompiles/ArbAddressTable.go:27-37 |
| ArbAddressTable / 0x0000000000000000000000000000000000000066 | `lookup(address)` | `0xd4b6b5da` | 0..unbounded | view | O | addressTable | nitro/precompiles/ArbAddressTable.go:40-49 |
| ArbAddressTable / 0x0000000000000000000000000000000000000066 | `lookupIndex(uint256)` | `0x8a186788` | 0..unbounded | view | O | addressTable | nitro/precompiles/ArbAddressTable.go:52-64 |
| ArbAddressTable / 0x0000000000000000000000000000000000000066 | `register(address)` | `0x4420e486` | 0..unbounded | nonpayable | O | addressTable | nitro/precompiles/ArbAddressTable.go:67-70 |
| ArbAddressTable / 0x0000000000000000000000000000000000000066 | `size()` | `0x949d225d` | 0..unbounded | view | O | addressTable | nitro/precompiles/ArbAddressTable.go:73-76 |
| ArbFunctionTable / 0x0000000000000000000000000000000000000068 | `upload(bytes)` | `0xce2ae159` | 0..unbounded | nonpayable | O | legacy | nitro/precompiles/ArbFunctionTable.go:19-21 |
| ArbFunctionTable / 0x0000000000000000000000000000000000000068 | `size(address)` | `0x88987068` | 0..unbounded | view | O | legacy | nitro/precompiles/ArbFunctionTable.go:24-26 |
| ArbFunctionTable / 0x0000000000000000000000000000000000000068 | `get(address,uint256)` | `0xb464631b` | 0..unbounded | view | R | legacy | nitro/precompiles/ArbFunctionTable.go:29-31 |
| ArbosTest / 0x0000000000000000000000000000000000000069 | `burnArbGas(uint256)` | `0xbb3480f9` | 0..unbounded | pure | O | legacy | nitro/precompiles/ArbosTest.go:18-25 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getPricesInWeiWithAggregator(address)` | `0xba9c916e` | 0..unbounded | view | O | l1Pricing, l2Pricing | nitro/precompiles/ArbGasInfo.go:28-67 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getPricesInWei()` | `0x41b247a8` | 0..unbounded | view | O | l1Pricing, l2Pricing | nitro/precompiles/ArbGasInfo.go:101-103 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getPricesInArbGasWithAggregator(address)` | `0x7a1ea732` | 0..unbounded | view | O | l1Pricing, l2Pricing | nitro/precompiles/ArbGasInfo.go:106-131 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getPricesInArbGas()` | `0x02199f34` | 0..unbounded | view | O | l1Pricing, l2Pricing | nitro/precompiles/ArbGasInfo.go:156-158 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getGasAccountingParams()` | `0x612af178` | 0..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:161-166 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getMaxTxGasLimit()` | `0xaae1cd4c` | 50..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:169-173 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getMinimumGasPrice()` | `0xf918379a` | 0..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:176-178 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1BaseFeeEstimate()` | `0xf5d6ded7` | 0..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:181-183 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1BaseFeeEstimateInertia()` | `0x29eb31ee` | 0..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:186-188 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1RewardRate()` | `0x8a5b1d28` | 11..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:191-193 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1RewardRecipient()` | `0x9e6d7e31` | 11..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:196-198 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1GasPriceEstimate()` | `0x055f362f` | 0..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:201-203 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getCurrentTxL1GasFees()` | `0xc6f7de0e` | 0..unbounded | view | O | posterFee | nitro/precompiles/ArbGasInfo.go:206-208 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getGasBacklog()` | `0x1d5b5c20` | 0..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:211-213 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getPricingInertia()` | `0x3dfb45b9` | 0..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:216-218 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getGasBacklogTolerance()` | `0x25754f91` | 0..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:221-223 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1PricingSurplus()` | `0x520acdd7` | 0..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:226-232 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getPerBatchGasCharge()` | `0x6ecca45a` | 0..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:250-252 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getAmortizedCostCapBips()` | `0x7a7d6beb` | 0..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:255-257 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1FeesAvailable()` | `0x5b39d23c` | 10..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:260-262 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1PricingEquilibrationUnits()` | `0xad26ce90` | 20..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:265-267 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getLastL1PricingUpdateTime()` | `0x138b47b4` | 20..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:270-272 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1PricingFundsDueForRewards()` | `0x963d6002` | 20..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:275-277 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getL1PricingUnitsSinceUpdate()` | `0xeff01306` | 20..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:280-282 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getLastL1PricingSurplus()` | `0x2987d027` | 20..unbounded | view | O | l1Pricing | nitro/precompiles/ArbGasInfo.go:285-287 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getMaxBlockGasLimit()` | `0x0371fdb4` | 50..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:290-292 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getGasPricingConstraints()` | `0x232027d1` | 50..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:295-324 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getMultiGasPricingConstraints()` | `0xbbfc0a72` | 60..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:327-378 |
| ArbGasInfo / 0x000000000000000000000000000000000000006c | `getMultiGasBaseFee()` | `0xc0e10bbb` | 60..unbounded | view | O | l2Pricing | nitro/precompiles/ArbGasInfo.go:381-390 |
| ArbAggregator / 0x000000000000000000000000000000000000006d | `getPreferredAggregator(address)` | `0x52f10740` | 0..unbounded | view | O | legacy | nitro/precompiles/ArbAggregator.go:25-27 |
| ArbAggregator / 0x000000000000000000000000000000000000006d | `getDefaultAggregator()` | `0x875883f2` | 0..unbounded | view | O | legacy | nitro/precompiles/ArbAggregator.go:32-34 |
| ArbAggregator / 0x000000000000000000000000000000000000006d | `getBatchPosters()` | `0xe10573a3` | 0..unbounded | view | O | posters | nitro/precompiles/ArbAggregator.go:37-39 |
| ArbAggregator / 0x000000000000000000000000000000000000006d | `addBatchPoster(address)` | `0xdf41e1e2` | 0..unbounded | nonpayable | P | posters | nitro/precompiles/ArbAggregator.go:42-62 |
| ArbAggregator / 0x000000000000000000000000000000000000006d | `getFeeCollector(address)` | `0x9c2c5bb5` | 0..unbounded | view | O | posters | nitro/precompiles/ArbAggregator.go:65-71 |
| ArbAggregator / 0x000000000000000000000000000000000000006d | `setFeeCollector(address,address)` | `0x29149799` | 0..unbounded | nonpayable | P | posters | nitro/precompiles/ArbAggregator.go:74-93 |
| ArbAggregator / 0x000000000000000000000000000000000000006d | `getTxBaseFee(address)` | `0x049764af` | 0..unbounded | view | O | legacy | nitro/precompiles/ArbAggregator.go:98-101 |
| ArbAggregator / 0x000000000000000000000000000000000000006d | `setTxBaseFee(address,uint256)` | `0x5be6888b` | 0..unbounded | nonpayable | O | legacy | nitro/precompiles/ArbAggregator.go:106-109 |
| ArbStatistics / 0x000000000000000000000000000000000000006f | `getStats()` | `0xc59d4847` | 0..unbounded | view | O | legacy | nitro/precompiles/ArbStatistics.go:18-26 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `isChainOwner(address)` | `0x26ef7f68` | 0..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:35-37 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `rectifyChainOwner(address)` | `0x6fe86373` | 11..unbounded | nonpayable | O | config | nitro/precompiles/ArbOwnerPublic.go:26-32 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getAllChainOwners()` | `0x516b4e0f` | 0..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:21-23 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getNativeTokenManagementFrom()` | `0x3fecbab0` | 50..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:51-53 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `isNativeTokenOwner(address)` | `0xc686f4db` | 41..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:40-42 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getAllNativeTokenOwners()` | `0x3f8601e4` | 41..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:45-47 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getTransactionFilteringFrom()` | `0xc1d355b8` | 60..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:57-59 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `isTransactionFilterer(address)` | `0xb32352c3` | 60..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:62-64 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getAllTransactionFilterers()` | `0x595fbb5a` | 60..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:67-69 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getFilteredFundsRecipient()` | `0x3caa5f12` | 60..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:73-75 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getNetworkFeeAccount()` | `0x2d9125e9` | 0..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:78-80 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getInfraFeeAccount()` | `0xee95a824` | 5..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:83-88 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getBrotliCompressionLevel()` | `0x22d499c7` | 20..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:91-93 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getParentGasFloorPerToken()` | `0x49ccdaff` | 50..unbounded | view | O | l1Pricing | nitro/precompiles/ArbOwnerPublic.go:115-117 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getScheduledUpgrade()` | `0x81ef944c` | 20..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:97-106 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `isCalldataPriceIncreaseEnabled()` | `0x2aa9551e` | 40..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:110-112 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getCollectTips()` | `0x8e34a64d` | 60..unbounded | view | O | config | nitro/precompiles/ArbOwnerPublic.go:120-122 |
| ArbOwnerPublic / 0x000000000000000000000000000000000000006b | `getMaxStylusContractFragments()` | `0xe5a7f893` | 60..unbounded | view | O | stylusParams | nitro/precompiles/ArbOwnerPublic.go:124-130 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `activateProgram(address)` | `0x58c780c2` | 30..unbounded | payable | O | stylusProgram | nitro/precompiles/ArbWasm.go:36-65 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `stylusVersion()` | `0xa996e0c2` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:104-107 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `codehashVersion(bytes32)` | `0xd70c0ca7` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasm.go:186-192 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `codehashKeepalive(bytes32)` | `0xc689bad5` | 30..unbounded | payable | O | stylusProgram | nitro/precompiles/ArbWasm.go:68-81 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `codehashAsmSize(bytes32)` | `0x4089267f` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasm.go:195-201 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `programVersion(address)` | `0xcc8f4e88` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasm.go:204-210 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `programInitGas(address)` | `0x62b688aa` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasm.go:213-219 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `programMemoryFootprint(address)` | `0xaef36be3` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasm.go:222-228 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `programTimeLeft(address)` | `0xc775a62a` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasm.go:231-237 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `inkPrice()` | `0xd1c17abc` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:110-113 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `maxStackDepth()` | `0x8ccfaa70` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:116-119 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `freePages()` | `0x4490c19d` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:122-125 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `pageGas()` | `0x7af4ba49` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:128-131 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `pageRamp()` | `0x11c82ae8` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:134-137 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `pageLimit()` | `0x9786f96e` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:140-143 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `minInitGas()` | `0x99d0b38d` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:146-154 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `initCostScalar()` | `0x5fc94c0b` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:157-160 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `expiryDays()` | `0x309f6555` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:163-166 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `keepaliveDays()` | `0x0a936455` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:169-172 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `blockCacheSize()` | `0x7af6e819` | 30..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:175-178 |
| ArbWasm / 0x0000000000000000000000000000000000000071 | `activationGas()` | `0x2278c278` | 59..unbounded | view | O | stylusParams | nitro/precompiles/ArbWasm.go:181-183 |
| ArbWasmCache / 0x0000000000000000000000000000000000000072 | `isCacheManager(address)` | `0x85e2de85` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasmCache.go:16-18 |
| ArbWasmCache / 0x0000000000000000000000000000000000000072 | `allCacheManagers()` | `0x0ec1d773` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasmCache.go:21-23 |
| ArbWasmCache / 0x0000000000000000000000000000000000000072 | `cacheCodehash(bytes32)` | `0x4ceac817` | 30..30 | nonpayable | I | stylusProgram | nitro/precompiles/ArbWasmCache.go:26-28 |
| ArbWasmCache / 0x0000000000000000000000000000000000000072 | `cacheProgram(address)` | `0xe73ac9f2` | 31..unbounded | nonpayable | P | stylusProgram | nitro/precompiles/ArbWasmCache.go:31-37 |
| ArbWasmCache / 0x0000000000000000000000000000000000000072 | `evictCodehash(bytes32)` | `0xce972013` | 30..unbounded | nonpayable | P | stylusProgram | nitro/precompiles/ArbWasmCache.go:40-42 |
| ArbWasmCache / 0x0000000000000000000000000000000000000072 | `codehashIsCached(bytes32)` | `0xa72f179b` | 30..unbounded | view | O | stylusProgram | nitro/precompiles/ArbWasmCache.go:45-47 |
| ArbRetryableTx / 0x000000000000000000000000000000000000006e | `redeem(bytes32)` | `0xeda1122c` | 0..unbounded | nonpayable | O | retryable | nitro/precompiles/ArbRetryableTx.go:50-159 |
| ArbRetryableTx / 0x000000000000000000000000000000000000006e | `getLifetime()` | `0x81e6e083` | 0..unbounded | view | O | retryable | nitro/precompiles/ArbRetryableTx.go:162-164 |
| ArbRetryableTx / 0x000000000000000000000000000000000000006e | `getTimeout(bytes32)` | `0x9f1025c6` | 0..unbounded | view | O | retryable | nitro/precompiles/ArbRetryableTx.go:167-181 |
| ArbRetryableTx / 0x000000000000000000000000000000000000006e | `keepalive(bytes32)` | `0xf0b21a41` | 0..unbounded | nonpayable | O | retryable | nitro/precompiles/ArbRetryableTx.go:184-209 |
| ArbRetryableTx / 0x000000000000000000000000000000000000006e | `getBeneficiary(bytes32)` | `0xba20dda4` | 0..unbounded | view | O | retryable | nitro/precompiles/ArbRetryableTx.go:212-222 |
| ArbRetryableTx / 0x000000000000000000000000000000000000006e | `cancel(bytes32)` | `0xc4d252f5` | 0..unbounded | nonpayable | O | retryable | nitro/precompiles/ArbRetryableTx.go:225-251 |
| ArbRetryableTx / 0x000000000000000000000000000000000000006e | `getCurrentRedeemer()` | `0xde4ba2b3` | 0..unbounded | view | O | retryable | nitro/precompiles/ArbRetryableTx.go:256-261 |
| ArbRetryableTx / 0x000000000000000000000000000000000000006e | `submitRetryable(bytes32,uint256,uint256,uint256,uint256,uint64,uint256,address,address,address,bytes)` | `0xc9f95d32` | 0..unbounded | nonpayable | R | retryable | nitro/precompiles/ArbRetryableTx.go:264-271 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `arbBlockNumber()` | `0xa3b1b31d` | 0..unbounded | view | O | sysContext | nitro/precompiles/ArbSys.go:36-38 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `arbBlockHash(uint256)` | `0x2b407a82` | 0..unbounded | view | O | l2History | nitro/precompiles/ArbSys.go:41-59 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `arbChainID()` | `0xd127f54a` | 0..unbounded | view | O | sysContext | nitro/precompiles/ArbSys.go:62-64 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `arbOSVersion()` | `0x051038f2` | 0..unbounded | view | O | sysContext | nitro/precompiles/ArbSys.go:67-70 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `getStorageGasAvailable()` | `0xa94597ff` | 0..unbounded | view | O | sysContext | nitro/precompiles/ArbSys.go:73-75 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `isTopLevelCall()` | `0x08bd624c` | 0..unbounded | view | O | sysContext | nitro/precompiles/ArbSys.go:78-80 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `mapL1SenderContractAddressToL2Alias(address,address)` | `0x4dbbd506` | 0..unbounded | pure | O | sysContext | nitro/precompiles/ArbSys.go:83-85 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `wasMyCallersAddressAliased()` | `0x175a260b` | 0..unbounded | view | O | sysContext | nitro/precompiles/ArbSys.go:88-95 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `myCallersAddressWithoutAliasing()` | `0xd74523b3` | 0..unbounded | view | O | sysContext | nitro/precompiles/ArbSys.go:98-110 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `withdrawEth(address)` | `0x25e16063` | 0..unbounded | payable | O | outbox | nitro/precompiles/ArbSys.go:239-241 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `sendTxToL1(address,bytes)` | `0x928c169a` | 0..unbounded | payable | O | outbox | nitro/precompiles/ArbSys.go:113-220 |
| ArbSys / 0x0000000000000000000000000000000000000064 | `sendMerkleTreeState()` | `0x7aeecd2a` | 0..unbounded | view | Z | outbox | nitro/precompiles/ArbSys.go:223-236 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `addChainOwner(address)` | `0x481f8dbf` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:65-73 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `removeChainOwner(address)` | `0x8792701a` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:76-88 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `isChainOwner(address)` | `0x26ef7f68` | 0..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:91-93 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `getAllChainOwners()` | `0x516b4e0f` | 0..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:96-98 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setNativeTokenManagementFrom(uint64)` | `0xbdb8f707` | 41..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:132-134 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setTransactionFilteringFrom(uint64)` | `0x46066e45` | 60..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:137-139 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `addNativeTokenOwner(address)` | `0xaeb3a464` | 41..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:142-157 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `removeNativeTokenOwner(address)` | `0x96a3751d` | 41..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:160-172 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `isNativeTokenOwner(address)` | `0xc686f4db` | 41..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:175-177 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `getAllNativeTokenOwners()` | `0x3f8601e4` | 41..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:180-182 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `addTransactionFilterer(address)` | `0x59c87acc` | 60..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:185-198 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `removeTransactionFilterer(address)` | `0x67ada089` | 60..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:201-214 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `isTransactionFilterer(address)` | `0xb32352c3` | 60..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:217-219 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `getAllTransactionFilterers()` | `0x595fbb5a` | 60..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:222-224 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setFilteredFundsRecipient(address)` | `0xb79da0e9` | 60..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:228-233 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `getFilteredFundsRecipient()` | `0x3caa5f12` | 60..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:237-239 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL1BaseFeeEstimateInertia(uint64)` | `0x718f7805` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:242-244 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL2BaseFee(uint256)` | `0xd99bc80e` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:247-249 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setMinimumL2BaseFee(uint256)` | `0xa0188cdb` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:252-257 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setSpeedLimit(uint64)` | `0x4d7a060d` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:260-265 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setMaxTxGasLimit(uint64)` | `0x39673611` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:268-273 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setMaxBlockGasLimit(uint64)` | `0xae105c80` | 50..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:276-278 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL2GasPricingInertia(uint64)` | `0x3fd62a29` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:281-286 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL2GasBacklogTolerance(uint64)` | `0x198e7157` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:289-291 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `getNetworkFeeAccount()` | `0x2d9125e9` | 0..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:294-296 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `getInfraFeeAccount()` | `0xee95a824` | 5..unbounded | view | P | owner | nitro/precompiles/ArbOwner.go:299-301 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setNetworkFeeAccount(address)` | `0xfcdde2b4` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:304-306 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setInfraFeeAccount(address)` | `0x57f585db` | 5..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:309-311 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `scheduleArbOSUpgrade(uint64,uint64)` | `0xe388b381` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:314-316 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL1PricingEquilibrationUnits(uint256)` | `0x152db696` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:319-321 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL1PricingInertia(uint64)` | `0x775a82e9` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:324-326 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL1PricingRewardRecipient(address)` | `0x934be07d` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:329-331 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL1PricingRewardRate(uint64)` | `0xf6739500` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:334-336 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setL1PricePerUnit(uint256)` | `0x2b352fae` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:339-341 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setParentGasFloorPerToken(uint64)` | `0x3a930b0b` | 50..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:344-346 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setPerBatchGasCharge(int64)` | `0xfad7f20b` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:349-351 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setBrotliCompressionLevel(uint64)` | `0x5399126f` | 20..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:360-362 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setAmortizedCostCapBips(uint64)` | `0x56191cc3` | 0..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:354-356 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `releaseL1PricerSurplusFunds(uint256)` | `0x314bcf05` | 10..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:365-383 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setInkPrice(uint32)` | `0x8c1d4fda` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:386-397 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmMaxStackDepth(uint32)` | `0x4567cc8e` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:400-407 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmFreePages(uint16)` | `0x3f37a846` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:410-417 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmPageGas(uint16)` | `0xaaa619e0` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:420-427 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmPageLimit(uint16)` | `0x6595381a` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:430-437 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmMaxSize(uint32)` | `0x455ec2eb` | 40..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:492-499 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmMinInitGas(uint8,uint16)` | `0x8293405e` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:440-448 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmInitCostScalar(uint64)` | `0x67e0718f` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:451-458 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmExpiryDays(uint16)` | `0xaac68018` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:461-468 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmKeepaliveDays(uint16)` | `0x2a9cbe3e` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:471-478 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmBlockCacheSize(uint16)` | `0x380f1457` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:481-488 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `addWasmCacheManager(address)` | `0xffdca515` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:502-504 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `removeWasmCacheManager(address)` | `0xbf197322` | 30..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:507-517 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setChainConfig(string)` | `0xeda73212` | 11..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:520-566 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setCalldataPriceIncrease(bool)` | `0x8eb911d9` | 40..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:570-572 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setGasBacklog(uint64)` | `0x68fc808a` | 50..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:575-577 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setGasPricingConstraints(uint64[3][])` | `0xcc0d556a` | 50..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:580-609 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setMultiGasPricingConstraints(((uint8,uint64)[],uint32,uint64,uint64)[])` | `0x2b05bb39` | 60..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:612-661 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setCollectTips(bool)` | `0xa858dbe2` | 60..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:666-668 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setMaxStylusContractFragments(uint8)` | `0xf1fe1a70` | 60..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:670-677 |
| ArbOwner / 0x0000000000000000000000000000000000000070 | `setWasmActivationGas(uint64)` | `0xa0a32497` | 59..unbounded | nonpayable | P | owner | nitro/precompiles/ArbOwner.go:682-684 |
| ArbDebug / 0x00000000000000000000000000000000000000ff | `becomeChainOwner()` | `0x0e5bbc11` | 0..unbounded | nonpayable | D | debug | nitro/precompiles/ArbDebug.go:59-61 |
| ArbDebug / 0x00000000000000000000000000000000000000ff | `overwriteContractCode(address,bytes)` | `0x1be250d6` | 0..unbounded | nonpayable | D | debug | nitro/precompiles/ArbDebug.go:64-66 |
| ArbDebug / 0x00000000000000000000000000000000000000ff | `events(bool,bytes32)` | `0x7b9963ef` | 0..unbounded | payable | D | debug | nitro/precompiles/ArbDebug.go:29-45 |
| ArbDebug / 0x00000000000000000000000000000000000000ff | `eventsView()` | `0x8e5f30ab` | 0..unbounded | view | D | debug | nitro/precompiles/ArbDebug.go:48-51 |
| ArbDebug / 0x00000000000000000000000000000000000000ff | `customRevert(uint64)` | `0x7ea89f8b` | 0..unbounded | pure | D | debug | nitro/precompiles/ArbDebug.go:54-56 |
| ArbDebug / 0x00000000000000000000000000000000000000ff | `panic()` | `0x4700d305` | 30..unbounded | nonpayable | D | debug | nitro/precompiles/ArbDebug.go:69-71 |
| ArbDebug / 0x00000000000000000000000000000000000000ff | `legacyError()` | `0x1e48fe82` | 0..unbounded | pure | D | debug | nitro/precompiles/ArbDebug.go:74-76 |
| ArbosActs / 0x00000000000000000000000000000000000a4b05 | `startBlock(uint256,uint64,uint64,uint64)` | `0x6bf6a42d` | 0..unbounded | nonpayable | R | internal | nitro/precompiles/ArbosActs.go:16-18 |
| ArbosActs / 0x00000000000000000000000000000000000a4b05 | `batchPostingReport(uint256,address,uint64,uint64,uint256)` | `0xb6693771` | 0..unbounded | nonpayable | R | internal | nitro/precompiles/ArbosActs.go:20-22 |
| ArbosActs / 0x00000000000000000000000000000000000a4b05 | `batchPostingReportV2(uint256,address,uint64,uint64,uint64,uint64,uint256)` | `0x9998269e` | 0..unbounded | nonpayable | R | internal | nitro/precompiles/ArbosActs.go:24-26 |
| ArbNativeTokenManager / 0x0000000000000000000000000000000000000073 | `mintNativeToken(uint256)` | `0xa6f0f7c7` | 41..unbounded | nonpayable | P | nativeToken | nitro/precompiles/ArbNativeTokenManager.go:29-40 |
| ArbNativeTokenManager / 0x0000000000000000000000000000000000000073 | `burnNativeToken(uint256)` | `0x1c679a3c` | 41..unbounded | nonpayable | P | nativeToken | nitro/precompiles/ArbNativeTokenManager.go:43-58 |
| ArbFilteredTransactionsManager / 0x0000000000000000000000000000000000000074 | `addFilteredTransaction(bytes32)` | `0xcb470491` | 60..unbounded | nonpayable | P | filter | nitro/precompiles/ArbFilteredTransactionsManager.go:26-37 |
| ArbFilteredTransactionsManager / 0x0000000000000000000000000000000000000074 | `deleteFilteredTransaction(bytes32)` | `0xd26374b1` | 60..unbounded | nonpayable | P | filter | nitro/precompiles/ArbFilteredTransactionsManager.go:40-51 |
| ArbFilteredTransactionsManager / 0x0000000000000000000000000000000000000074 | `isTransactionFiltered(bytes32)` | `0x85c733a4` | 60..unbounded | view | O | filter | nitro/precompiles/ArbFilteredTransactionsManager.go:54-57 |

ArbBLS at0x67 is an explicitly inventoried empty ABI/empty exported-handler set,
not an omitted family. Every nonempty ABI has exactly the same exported Go
handler-name set. The dispatcher has no fallback exposing additional methods.

## Dataflow and update-point closure

### account

Selected account balance or code, not account/storage trie root or ordered effects.

StateDB AddBalance/SubBalance/SetBalance, SetCode and creation/selfdestruct update selected account fields. Ordinary token transfers can change unrelated storage without changing a selected balance/code. No global-root return.

Readers: `nitro/precompiles/ArbInfo.go:18-37`.

Writers: `go-ethereum/core/state/statedb.go`.

### addressTable

Address-to-index registry and RLP supplied-data codec, not transaction register.

Register alone appends an explicitly supplied address and increments numItems; repeat registration returns existing slot. Compress only reads lookup or encodes address (despite nonpayable ABI); Decompress decodes supplied bytes or supplied index. Size counts registrations, not transfers.

Readers: `nitro/precompiles/ArbAddressTable.go:17-77`.

Writers: `nitro/arbos/addressTable/addressTable.go:34-55`, `nitro/arbos/addressTable/addressTable.go:58-126`.

### legacy

Constant, empty-table error, or no-op.

No history producer. burnArbGas consumes caller-chosen gas; getStats returns current L2 number plus five zeros; aggregator defaults are BatchPosterAddress; deprecated tx base fee is zero/no-op.

Readers: `nitro/precompiles/ArbFunctionTable.go:18-31`, `nitro/precompiles/ArbosTest.go:18-25`, `nitro/precompiles/ArbStatistics.go:17-25`, `nitro/precompiles/ArbAggregator.go:23-36`, `nitro/precompiles/ArbAggregator.go:95-109`.

Writers: none.

### l1Pricing

Pricing/configuration values and aggregate fee accounting, not an ordered commitment.

PricePerUnit, inertia, reward payee/rate, equilibration, batch charge, cap and floor have owner setters. unitsSinceUpdate += compressed calldata units before EVM; batch report allocates/subtracts units, adjusts rewards/refunds, update time, last surplus and price with integer arithmetic. L1FeesAvailable receives PosterFee after transaction and loses batch payments. GetL1PricingSurplus = feesAvailable - totalFundsDue - rewardDebt at v61. No transaction content, transfer log list or order hash is accumulated.

Readers: `nitro/precompiles/ArbGasInfo.go:27-287`.

Writers: `nitro/arbos/l1pricing/l1pricing.go:119-316`, `nitro/arbos/l1pricing/l1pricing.go:320-515`, `nitro/arbos/internal_tx.go:115-200`, `nitro/arbos/tx_processor.go:603-646`, `nitro/arbos/tx_processor.go:875-883`, `nitro/precompiles/ArbOwner.go:241-243`, `nitro/precompiles/ArbOwner.go:318-383`.

### l2Pricing

Gas limits, min price, model parameters, resource backlogs and base fees.

EndTxHook grows active scalar/resource backlogs by gas usage, not ordered transaction bytes; retryable redeem shrinks donated-gas backlog. StartBlock decays backlogs by elapsed time and computes fees. Owner changes limits/constraints/backlogs. Current per-resource fees rotate from next before block execution; v61 SingleDim uses actual block base fee. Saturating arithmetic, weighted sums and decay discard information/order; not cryptographic commitments.

Readers: `nitro/precompiles/ArbGasInfo.go:160-223`, `nitro/precompiles/ArbGasInfo.go:289-389`.

Writers: `nitro/arbos/l2pricing/l2pricing.go:237-331`, `nitro/arbos/l2pricing/model.go`, `nitro/arbos/l2pricing/gas_constraint.go`, `nitro/arbos/l2pricing/multi_gas_constraint.go`, `nitro/arbos/l2pricing/multi_gas_fees.go:38-68`, `nitro/arbos/tx_processor.go:834-920`, `nitro/arbos/internal_tx.go:106-114`, `nitro/arbos/block_processor.go:372-381`, `nitro/precompiles/ArbOwner.go:246-290`, `nitro/precompiles/ArbOwner.go:574-677`.

### posterFee

Fee for the current top-level message only.

GasChargingHook computes PosterDataCost from message transaction/compressed calldata and configured prices, converts to posterGas and stores PosterFee. It is no receipt prefix, execution position or prior-transfer content.

Readers: `nitro/precompiles/ArbGasInfo.go:205-208`.

Writers: `nitro/arbos/tx_processor.go:603-646`, `nitro/arbos/l1pricing/l1pricing.go:518-617`.

### posters

Poster membership and per-poster fee-recipient configuration.

Owner addBatchPoster or internal batch-spending report adds poster. SetFeeCollector writes PayTo after caller-role check. TotalFundsDue is an arithmetic debt sum. Enumeration bounded to 65536; no log/transaction commitment.

Readers: `nitro/precompiles/ArbAggregator.go:38-93`.

Writers: `nitro/arbos/l1pricing/batchPoster.go:57-141`, `nitro/precompiles/ArbAggregator.go:43-61`, `nitro/precompiles/ArbAggregator.go:74-93`, `nitro/arbos/l1pricing/l1pricing.go:334-336`.

### config

Chain configuration, membership and scheduled parameters.

Owner changes member sets, fee accounts, flags and enable timestamps; ArbOS initializes/upgrades defaults. rectifyChainOwner is public but repairs an already-member corrupt mapping, not arbitrary admission. Membership enumeration caps at 65536. ScheduledUpgrade reads version/time, suppresses already-applied schedule. These are current configuration facts, not history commitments.

Readers: `nitro/precompiles/ArbOwnerPublic.go:20-130`.

Writers: `nitro/precompiles/ArbOwner.go:64-383`, `nitro/precompiles/ArbOwner.go:501-677`, `nitro/arbos/addressSet/addressSet.go:108-201`, `nitro/arbos/arbosState/arbosstate.go:393-590`, `nitro/arbos/arbosState/arbosstate.go:611-736`, `nitro/arbos/features/features.go`.

### stylusParams

Stylus metering/version/lifetime configuration, no execution-history value.

Params decodes packed fields; Save writes owner-specified parameters only when executed onchain, otherwise charges equivalent gas; init/upgrades also set fields. PageRamp is an initialized constant in Params, not live activity. ActivationGas is separate stored uint64. MinInitGas body rejects versions <32, admitted at61.

Readers: `nitro/precompiles/ArbWasm.go:103-183`, `nitro/precompiles/ArbOwnerPublic.go:124-129`.

Writers: `nitro/arbos/programs/params.go:45-258`, `nitro/precompiles/ArbOwner.go:385-498`, `nitro/precompiles/ArbOwner.go:670-684`, `nitro/arbos/programs/programs.go:92-102`.

### stylusProgram

Selected codehash activation/version/size/init-cost/expiry/cache metadata, not global state root.

Activation reads selected program codehash/Wasm, compiles it and records version, init/cached cost, footprint, estimated asm KB, activation hour and cache flag keyed by codehash. Keepalive resets activation hour and updates byte-demand fee model. Authorized cache changes only cached flag. Program getters resolve supplied address to codehash. Module hash is compiled-code identity/event data, never an executing-history accumulator.

Readers: `nitro/precompiles/ArbWasm.go:35-101`, `nitro/precompiles/ArbWasm.go:185-245`, `nitro/precompiles/ArbWasmCache.go:15-78`.

Writers: `nitro/arbos/programs/programs.go:112-194`, `nitro/arbos/programs/programs.go:543-744`, `nitro/arbos/programs/data_pricer.go:63-89`, `nitro/precompiles/ArbOwner.go:501-516`.

### retryable

A selected ticket, timeout/beneficiary, scheduled retry hash or current redeemer, not all transactions.

Submit processing creates ticket with submitted from/to/value/data/beneficiary and lifetime. Keepalive increments timeoutWindowsLeft; reap advances/removes expired ticket; success/cancel deletes it. Redeem increments NumTries and constructs a future ArbitrumRetryTx from ticket, chainId, nonce, basefee, donated gas and refund caller; returned Hash commits that scheduled transaction only. CurrentRefundTo is set only for the active retry transaction. submitRetryable ABI always reverts when called normally.

Readers: `nitro/precompiles/ArbRetryableTx.go:49-270`.

Writers: `nitro/arbos/retryables/retryable.go:73-272`, `nitro/arbos/retryables/retryable.go:315-387`, `nitro/arbos/tx_processor.go:403-415`, `nitro/arbos/tx_processor.go:543-568`, `nitro/arbos/tx_processor.go:834-850`.

### sysContext

Block/chain/version or call-frame/alias context only.

BlockContext populated for the block; chain config/ArbOS format state determine domain/version. ArbOSVersion ABI returns 55+format. Depth, TopTxType, Origin and Contracts call stack determine alias booleans/caller. Alias mapping is a pure transform of supplied sender; unused destination ignored. No executing receipt or global root.

Readers: `nitro/precompiles/ArbSys.go:35-109`, `nitro/precompiles/ArbSys.go:243-246`.

Writers: `nitro/arbos/block_processor.go:197-235`, `nitro/arbos/arbosState/arbosstate.go:393-590`, `nitro/gethhook/geth-hook.go:46-67`, `nitro/arbos/tx_processor.go`.

### l2History

Completed-L2 ancestor hash, not current-block or executing-prefix root.

ArbBlockHash explicitly requires n-256<=k<n and reads BlockContext.GetHash(k), backed by ancestor headers. Current transaction/receipt trie roots assembled in NewBlock after execution; header.Root finalized using IntermediateRoot. No current-prefix root exposed.

Readers: `nitro/precompiles/ArbSys.go:40-59`.

Writers: `nitro/arbos/block_processor.go:197-235`, `nitro/arbos/block_processor.go:775-826`, `go-ethereum/core/evm.go`.

### outbox

L2-to-L1 send sequence only, excluding arbitrary ordinary ERC20 transfers.

sendTxToL1 hashes caller,destination,L2/L1 numbers,time,value and supplied data, then Append hashes leaf, increments size and folds partials. Returns new leaf index at61, not root. withdrawEth calls same with empty bytes. export root/size/partials is zero-caller-only; even if accessible it commits sends only, not preceding arbitrary transfers.

Readers: `nitro/precompiles/ArbSys.go:112-240`.

Writers: `nitro/precompiles/ArbSys.go:149-217`, `nitro/arbos/merkleAccumulator/merkleAccumulator.go:133-235`.

### internal

Explorer-facing internal ABI always rejects ordinary calls.

Handlers always CallerNotArbOS, including a nominal ordinary caller equal to system address. Protocol processing intercepts actual ArbitrumInternalTx and executes startBlock/batch reports outside these handlers. StartBlock writes preceding hash and updates pricing/reaping/upgrades; no current prefix getter.

Readers: `nitro/precompiles/ArbosActs.go:16-26`.

Writers: `nitro/arbos/internal_tx.go:62-204`.

### nativeToken

Role-restricted mint/burn of caller native balance, no commitment output.

hasAccess checks NativeTokenOwners membership, then AddBalance/SubBalance(caller, supplied amount) and event. Feature timestamp gates admitting new role members, not a substitute for membership at mint/burn.

Readers: `nitro/precompiles/ArbNativeTokenManager.go:27-62`.

Writers: `nitro/precompiles/ArbNativeTokenManager.go:27-62`, `nitro/precompiles/ArbOwner.go:131-181`.

### filter

Membership of a caller-supplied tx hash in a mutable privileged filter list.

Add stores hash=>1 and Delete clears after TransactionFilterers check; IsTransactionFiltered is PUBLIC, wrapper only varies gas charging. DeleteFree is a defined cleanup entrypoint. Does not authenticate inclusion, order, execution or complete prefix; arbitrary hash can be listed before execution.

Readers: `nitro/precompiles/ArbFilteredTransactionsManager.go:25-61`.

Writers: `nitro/arbos/filteredTransactions/state.go:26-65`, `nitro/precompiles/ArbFilteredTransactionsManager.go:25-48`.

### owner

All 60 methods behind chain-owner wrapper, including view methods.

Caller must be current ChainOwners member. Mutation parameters are owner supplied; releaseL1PricerSurplusFunds returns min(max, poolBalance-recognizedFees) and credits feesAvailable. Other reads expose configuration/membership. No ordinary Migration authority or full executing-prefix output.

Readers: `nitro/precompiles/ArbOwner.go:64-684`, `nitro/precompiles/wrapper.go:84-140`.

Writers: `nitro/precompiles/ArbOwner.go:64-684`.

### debug

Debug-config-only mutators/events/errors, not admitted on advertised production configuration.

Requires ChainConfig.DebugMode; inherited official chain config says false, not attested runtime config. Methods return supplied paid/flag/caller, old selected code, or errors; BecomeChainOwner and Overwrite mutate only when debug enabled. No prefix producer even in debug.

Readers: `nitro/precompiles/ArbDebug.go:28-76`, `nitro/precompiles/wrapper.go:34-51`.

Writers: `nitro/precompiles/ArbDebug.go:58-70`.
