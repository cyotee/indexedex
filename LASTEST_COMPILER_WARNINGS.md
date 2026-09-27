[⠢] Compiling...
[⠊] Compiling 2831 files with Solc 0.8.35
[⠆] Solc 0.8.35 finished in 15098.94s
Compiler run successful with warnings:
Warning (2519): This declaration shadows an existing declaration.
   --> contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:290:33:
    |
290 |     function _pullExactOutInput(IERC20 token, uint256 used, uint256 maxAmountIn, bool pretransferred)
    |                                 ^^^^^^^^^^^^
Note: The shadowed declaration is here:
   --> contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:101:5:
    |
101 |     function token(uint256 index) public view returns (address) {
    |     ^ (Relevant source part starts here and spans across multiple lines).

Warning (2519): This declaration shadows an existing declaration.
   --> contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:465:31:
    |
465 |     function _unbookedBalance(IERC20 token) internal view returns (uint256) {
    |                               ^^^^^^^^^^^^
Note: The shadowed declaration is here:
   --> contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:144:5:
    |
144 |     function token(uint256 index) public view returns (address) {
    |     ^ (Relevant source part starts here and spans across multiple lines).

Warning (2519): This declaration shadows an existing declaration.
   --> contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:475:33:
    |
475 |     function _pullExactOutInput(IERC20 token, uint256 used, uint256 maxAmountIn, bool pretransferred)
    |                                 ^^^^^^^^^^^^
Note: The shadowed declaration is here:
   --> contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:144:5:
    |
144 |     function token(uint256 index) public view returns (address) {
    |     ^ (Relevant source part starts here and spans across multiple lines).

Warning (2519): This declaration shadows an existing declaration.
   --> contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:490:31:
    |
490 |     function _unbookedBalance(IERC20 token) internal view returns (uint256) {
    |                               ^^^^^^^^^^^^
Note: The shadowed declaration is here:
   --> contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:143:5:
    |
143 |     function token(uint256 index) public view returns (address) {
    |     ^ (Relevant source part starts here and spans across multiple lines).

Warning (2519): This declaration shadows an existing declaration.
   --> contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:500:33:
    |
500 |     function _pullExactOutInput(IERC20 token, uint256 used, uint256 maxAmountIn, bool pretransferred)
    |                                 ^^^^^^^^^^^^
Note: The shadowed declaration is here:
   --> contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:143:5:
    |
143 |     function token(uint256 index) public view returns (address) {
    |     ^ (Relevant source part starts here and spans across multiple lines).

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
  --> contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol:23:50:
   |
23 |         if (address(tokenIn) == address(this) && tokenOut == m.tokenA) return _amountForShares(m, amountIn);
   |                                                  ^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
  --> contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol:24:51:
   |
24 |         if (address(tokenOut) != address(this) || tokenIn != m.tokenA) revert ExchangeInNotAvailable();
   |                                                   ^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
  --> contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol:37:50:
   |
37 |         if (address(tokenIn) == address(this) && tokenOut == m.tokenA) {
   |                                                  ^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
  --> contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol:46:51:
   |
46 |         if (address(tokenOut) != address(this) || tokenIn != m.tokenA) revert ExchangeInNotAvailable();
   |                                                   ^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
  --> contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol:37:50:
   |
37 |         if (address(tokenIn) != address(this) || tokenOut != m.tokenA) revert ExchangeOutNotAvailable();
   |                                                  ^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
  --> contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol:52:50:
   |
52 |         if (address(tokenIn) != address(this) || tokenOut != m.tokenA) revert ExchangeOutNotAvailable();
   |                                                  ^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol:184:17:
    |
184 |             if (tokens_[i_] == token_) return balances_[i_] / 10;
    |                 ^^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol:300:21:
    |
300 |                 if (stable_[i_] == routes[r_].vaultToken) {
    |                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol:770:17:
    |
770 |             if (tokens_[i_] == detfToken) detfIndex = i_;
    |                 ^^^^^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol:771:22:
    |
771 |             else if (tokens_[i_] == IERC20(address(stablePool))) stablePoolBptIndex = i_;
    |                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> test/foundry/spec/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/decimals/MixedBufferMultiVaultStable_WalkAndExhaust_Decimals.sol:257:16:
    |
257 |         return tokenIn == bufferToken ? _sharesForAssets(amountIn) : _assetsForShares(amountIn);
    |                ^^^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol:146:17:
    |
146 |             if (tokens_[i_] == token_) return balances_[i_] / 10;
    |                 ^^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol:262:21:
    |
262 |                 if (stable_[i_] == routes[r_].vaultToken) {
    |                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol:699:17:
    |
699 |             if (tokens_[i_] == detfToken) detfIndex = i_;
    |                 ^^^^^^^^^^^^^^^^^^^^^^^^

Warning (9170): Comparison of variables of contract type is deprecated and scheduled for removal. Use an explicit cast to address type and compare the addresses instead.
   --> test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_IntegratedDeploy.t.sol:700:22:
    |
700 |             else if (tokens_[i_] == IERC20(address(stablePool))) stablePoolBptIndex = i_;
    |                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Warning (5740): Unreachable code.
   --> contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:189:9:
    |
189 |         l.reentrancyStatus = Repo.NOT_ENTERED;
    |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Warning (4591): There are more than 256 warnings. Ignoring the rest.
note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeDFPkg.sol:228:16
    |
228 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookDFPkg.sol:252:16
    |
252 |           return keccak256(
    |  ________________^
253 | |             abi.encode(PRODUCT_ID, a.poolManager, a.feeOracle, a.tokens, a.weights, a.rateProviders)
254 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/protocols/staking/etherfi/EtherFiWeETHStandardExchangeDFPkg.sol:208:16
    |
208 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterCommon.sol:76:16
   |
76 |         return keccak256(abi.encode(steps));
   |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol:71:29
   |
71 |         bytes32 stepsHash = keccak256(abi.encode(params.steps));
   |                             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol:73:27
   |
73 |           bytes32 witness = keccak256(
   |  ___________________________^
74 | |             abi.encode(
75 | |                 typehash,
76 | |                 params.recipient,
...  |
86 | |         );
   | |_________^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol:88:40
   |
88 |           bytes32 tokenPermissionsHash = keccak256(
   |  ________________________________________^
89 | |             abi.encode(
90 | |                 keccak256("TokenPermissions(address token,uint256 amount)"),
91 | |                 permit.permitted.token,
...  |
94 | |         );
   | |_________^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol:97:41
    |
 97 |   ...   bytes32 permitWitnessTypehash = keccak256(
    |  _______________________________________^
 98 | | ...       abi.encodePacked(
 99 | | ...           "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Witness witnes...
100 | | ...           "TokenPermissions(address token,uint256 amount)",
...   |
103 | | ...   );
    | |_______^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol:105:30
    |
105 |           bytes32 structHash = keccak256(
    |  ______________________________^
106 | |             abi.encode(
107 | |                 permitWitnessTypehash,
108 | |                 tokenPermissionsHash,
...   |
114 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/routers/balancerV3-uniswapV4/TestBase_BalancerV3UniswapV4CoordinatorRouter.sol:117:26
    |
117 |         bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    |                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol:206:16
    |
206 |         return keccak256(abi.encode(args));
    |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/protocols/staking/lido/LidoWstETHStandardExchangeDFPkg.sol:191:16
    |
191 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeDFPkg.sol:190:16
    |
190 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/oracles/uniswap/v4/twap/UniswapV4TwapAdapterFactory.sol:26:24
   |
26 |         bytes32 salt = keccak256(abi.encode(oracle, key, secondsAgo, collateralIsCurrency0, maxWriteAge));
   |                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/oracles/uniswap/v4/twap/UniswapV4TwapAdapterFactory.sol:52:24
   |
52 |         bytes32 salt = keccak256(abi.encode(oracle, key, secondsAgo, invert, maxWriteAge));
   |                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/oracles/uniswap/v4/twap/UniswapV4TwapAdapterFactory.sol:74:24
   |
74 |         bytes32 salt = keccak256(abi.encode(oracle, key, secondsAgo, collateralIsCurrency0, maxWriteAge));
   |                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/oracles/uniswap/v4/twap/UniswapV4TwapAdapterFactory.sol:89:24
   |
89 |         bytes32 salt = keccak256(abi.encode(oracle, key, secondsAgo, invert, maxWriteAge));
   |                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleDFPkg.sol:82:16
   |
82 |         return keccak256(abi.encode(decoded.poolManager));
   |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol:459:16
    |
459 |         return keccak256(abi.encode(IERC20(d_).totalSupply(), lp_.balanceOf(d_), lp_.balanceOf(info_.bondNftVault())));
    |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_PonsMix.sol:48:28
   |
48 |             bytes32 salt = keccak256(abi.encodePacked("M-QD-P1P2G4-v2", i));
   |                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol:246:16
    |
246 |           return keccak256(
    |  ________________^
247 | |             abi.encode(
248 | |                 PRODUCT_ID,
249 | |                 a.tokens,
...   |
258 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/test/stubs/MintableERC20Decimals.sol:72:26
   |
72 |           bytes32 digest = keccak256(
   |  __________________________^
73 | |             abi.encodePacked(
74 | |                 "\x19\x01",
75 | |                 DOMAIN_SEPARATOR,
...  |
78 | |         );
   | |_________^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/protocols/dexes/uniswap/v3/UniswapV3VaultRepo.sol:72:16
   |
72 |         return keccak256(abi.encodePacked(owner_, tickLower_, tickUpper_));
   |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/protocols/staking/rebasingVault/RebasingAwareVaultMetadataTarget.sol:54:16
   |
54 |         return keccak256(abi.encode(tokens_));
   |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/test/bases/FundedBondCloseAssertions.sol:188:16
    |
188 |           return keccak256(abi.encode(
    |  ________________^
189 | |             IERC20(detf_).totalSupply(), IERC20(detf_).balanceOf(CLAIM_RECIPIENT),
190 | |             IERC20(detf_).balanceOf(address(staking_)), staking_.stakingState().accountedBacking,
191 | |             lp_.balanceOf(detf_), lp_.balanceOf(address(nft_)),
192 | |             staking_.balanceOf(nft_.ownerOf(1)), staking_.balanceOf(nft_.ownerOf(2)), balances_
193 | |         ));
    | |__________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/test/bases/DetfStatefulActions.sol:55:16
   |
55 |           return keccak256(
   |  ________________^
56 | |             abi.encode(
57 | |                 staking_.stakingState(),
58 | |                 IERC20(info_.reservePool()).balanceOf(info_.bondNftVault()),
...  |
62 | |         );
   | |_________^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/test/bases/TestBase_AaveCrossVersionLoop_Decimals.sol:20:25
   |
20 |         bytes32 saltA = keccak256(abi.encode("CLTA", _tokenADecimals(), _tokenBDecimals()));
   |                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/test/bases/TestBase_AaveCrossVersionLoop_Decimals.sol:21:25
   |
21 |         bytes32 saltB = keccak256(abi.encode("CLTB", _tokenADecimals(), _tokenBDecimals()));
   |                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol:21:25
   |
21 |         bytes32 saltA = keccak256(abi.encode("CLTA", _tokenADecimals(), _tokenBDecimals(), "v3m"));
   |                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market_Decimals.sol:22:25
   |
22 |         bytes32 saltB = keccak256(abi.encode("CLTB", _tokenADecimals(), _tokenBDecimals(), "v3m"));
   |                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookDFPkg.sol:246:16
    |
246 |           return keccak256(
    |  ________________^
247 | |             abi.encode(
248 | |                 PRODUCT_ID,
249 | |                 a.tokens,
...   |
256 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_PonsMix_Decimals.sol:48:28
   |
48 |             bytes32 salt = keccak256(abi.encodePacked("M-QD-P1P2G4-v2", i));
   |                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/protocols/dexes/aerodrome/slipstream/test/SlipstreamHermeticClBook.sol:210:23
    |
210 |         bytes32 key = keccak256(abi.encode(recipient, tickLower, tickUpper));
    |                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/protocols/dexes/aerodrome/slipstream/test/SlipstreamHermeticClBook.sol:250:23
    |
250 |         bytes32 key = keccak256(abi.encode(msg.sender, tickLower, tickUpper));
    |                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol:135:27
    |
135 |           bytes32 funded_ = keccak256(
    |  ___________________________^
136 | |             abi.encode(
137 | |                 staking_.stakingState(),
138 | |                 IERC20(d).totalSupply(),
...   |
142 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol:143:16
    |
143 |           return keccak256(
    |  ________________^
144 | |             abi.encode(
145 | |                 funded_,
146 | |                 in_.balanceOf(_fundedPolicyUser()),
...   |
150 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:298:16
    |
298 |           return keccak256(
    |  ________________^
299 | |             abi.encode(
300 | |                 PRODUCT_ID,
301 | |                 a.poolManager,
...   |
312 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Decimals.sol:563:16
    |
563 |         return keccak256(abi.encode(IERC20(d_).totalSupply(), lp_.balanceOf(d_), lp_.balanceOf(info_.bondNftVault())));
    |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol:198:16
    |
198 |         return keccak256(abi.encode(PRODUCT_ID, a.poolManager, a.standardExchange, a.pairToken));
    |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookDFPkg.sol:223:31
    |
223 |         bytes32 contentsId_ = keccak256(abi.encode(PRODUCT_ID, a.standardExchange, a.pairToken));
    |                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetfDFPkg.sol:231:16
    |
231 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
  --> contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultRepo.sol:72:16
   |
72 |         return keccak256(abi.encodePacked(owner_, tickLower_, tickUpper_));
   |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol:246:24
    |
246 |           bytes32 base = keccak256(
    |  ________________________^
247 | |             abi.encode(
248 | |                 PRODUCT_ID,
249 | |                 a.poolManager,
...   |
263 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDFPkg.sol:264:16
    |
264 |         return keccak256(abi.encode(base, a.decimals0, a.decimals1, a.decimals2));
    |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

Warning: AST source not found for /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange.t.sol
note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol:258:16
    |
258 |           return keccak256(
    |  ________________^
259 | |             abi.encode(
260 | |                 PRODUCT_ID,
261 | |                 a.n,
...   |
271 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/TestBase_ComposedStableCommonDetf_Decimals.sol:709:16
    |
709 |         return keccak256(abi.encodePacked(spec_.name, spec_.symbol, spec_.poolCreator));
    |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchangeDFPkg.sol:198:16
    |
198 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol:236:16
    |
236 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol:469:25
    |
469 |         bytes32 salt_ = keccak256(abi.encode(address(this), vaultCount_, block.timestamp));
    |                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/standard/erc4626/ERC4626StandardExchangeDFPkg.sol:191:16
    |
191 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfDFPkg.sol:221:25
    |
221 |         bytes32 salt_ = keccak256(abi.encode(address(this), p_.reserveWeights));
    |                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol:286:16
    |
286 |         return keccak256(abi.encode(PRODUCT_ID, a.poolManager, a.feeOracle, seLo, tLo, seHi, tHi, rpLo, rpHi));
    |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookDFPkg.sol:261:16
    |
261 |           return keccak256(
    |  ________________^
262 | |             abi.encode(
263 | |                 PRODUCT_ID,
264 | |                 a.poolManager,
...   |
273 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol:235:16
    |
235 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookDFPkg.sol:247:16
    |
247 |           return keccak256(
    |  ________________^
248 | |             abi.encode(PRODUCT_ID, a.poolManager, a.feeOracle, a.token0, a.token1, a.token2)
249 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopDFPkg.sol:254:16
    |
254 |         return keccak256(pkgArgs);
    |                ^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

Warning: AST source not found for /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/test/foundry/spec/vaults/detf/DetfNestedPush_ProductionPresence.t.sol
Warning: AST source not found for /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/test/foundry/spec/vaults/detf/common/core/DETFProtocolCompoundLib.t.sol
note[asm-keccak256]: use of inefficient hashing mechanism; consider using inline assembly
   --> contracts/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHookDFPkg.sol:265:16
    |
265 |           return keccak256(
    |  ________________^
266 | |             abi.encode(
267 | |                 PRODUCT_ID,
268 | |                 a.poolManager,
...   |
277 | |         );
    | |_________^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#asm-keccak256

warning[unchecked-call]: Low-level calls should check the success return value
   --> test/foundry/spec/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHook_Factory.t.sol:155:9
    |
155 |         (, bytes memory ret) = h.staticcall(abi.encodeWithSignature("symbol()"));
    |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
   --> test/foundry/spec/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHook_Factory.t.sol:158:9
    |
158 |         (, bytes memory retN) = h.staticcall(abi.encodeWithSignature("name()"));
    |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

Warning: AST source not found for /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/balancer/TestBase_UniswapV4StandardExchangeBalancerQuadStableBufferHook.sol
warning[unchecked-call]: Low-level calls should check the success return value
  --> test/foundry/spec/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHook_Liquidity.t.sol:23:9
   |
23 |         (, bytes memory ret) = hook.staticcall(abi.encodeWithSignature("balanceOf(address)", address(0)));
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

Warning: AST source not found for /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol
warning[unchecked-call]: Low-level calls should check the success return value
  --> test/foundry/spec/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHook_Liquidity.t.sol:26:9
   |
26 |         (, bytes memory retTs) = hook.staticcall(abi.encodeWithSignature("totalSupply()"));
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
  --> test/foundry/spec/hooks/uniswap/v4/stable/quad/curve/decimals/UniswapV4CurveQuadStableSwapHook_Decimals.sol:50:9
   |
50 |         (, bytes memory ret) = hook.staticcall(abi.encodeWithSignature("balanceOf(address)", address(0)));
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
  --> test/foundry/spec/hooks/uniswap/v4/stable/quad/curve/decimals/UniswapV4CurveQuadStableSwapHook_Decimals.sol:53:9
   |
53 |         (, bytes memory retTs) = hook.staticcall(abi.encodeWithSignature("totalSupply()"));
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
  --> test/foundry/spec/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_Liquidity.t.sol:23:9
   |
23 |         (, bytes memory ret) = hook.staticcall(abi.encodeWithSignature("balanceOf(address)", address(0)));
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
  --> test/foundry/spec/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_Liquidity.t.sol:26:9
   |
26 |         (, bytes memory retTs) = hook.staticcall(abi.encodeWithSignature("totalSupply()"));
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
  --> test/foundry/spec/hooks/uniswap/v4/stable/quad/balancer/decimals/UniswapV4BalancerQuadStableSwapHook_Decimals.sol:50:9
   |
50 |         (, bytes memory ret) = hook.staticcall(abi.encodeWithSignature("balanceOf(address)", address(0)));
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
  --> test/foundry/spec/hooks/uniswap/v4/stable/quad/balancer/decimals/UniswapV4BalancerQuadStableSwapHook_Decimals.sol:53:9
   |
53 |         (, bytes memory retTs) = hook.staticcall(abi.encodeWithSignature("totalSupply()"));
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
   --> test/foundry/spec/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_Factory.t.sol:148:9
    |
148 |         (, bytes memory ret) = h.staticcall(abi.encodeWithSignature("symbol()"));
    |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

warning[unchecked-call]: Low-level calls should check the success return value
   --> test/foundry/spec/hooks/uniswap/v4/stable/quad/balancer/UniswapV4BalancerQuadStableSwapHook_Factory.t.sol:151:9
    |
151 |         (, bytes memory retN) = h.staticcall(abi.encodeWithSignature("name()"));
    |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    |
    = help: https://book.getfoundry.sh/reference/forge/forge-lint#unchecked-call

Warning: AST source not found for /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolPkg_Smoke.t.sol
Warning: AST source not found for /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol
Warning: AST source not found for /Users/cyotee/Development/projects-defi/daosys/lib/indexedex/test/foundry/spec/saf/T10_DeadMembers.t.sol