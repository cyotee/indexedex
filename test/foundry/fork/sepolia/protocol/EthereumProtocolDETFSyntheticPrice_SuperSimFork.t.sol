// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity ^0.8.0;

// import {Test, console} from "forge-std/Test.sol";

// import {UNISWAPV2_FEE_PERCENT} from "@crane/contracts/constants/Constants.sol";
// import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
// import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
// import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
// import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
// import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
// import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
// import {AerodromeUtils} from "@crane/contracts/utils/math/AerodromeUtils.sol";
// import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";

// import {IProtocolDETF} from "contracts/interfaces/IProtocolDETF.sol";
// import {IProtocolDETFErrors} from "contracts/interfaces/IProtocolDETFErrors.sol";
// import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";

// contract TestBase_SupersimEthereumFork is Test {
//     uint256 internal constant ETHEREUM_SEPOLIA_CHAIN_ID = 11155111;
//     string internal constant DEFAULT_SUPERSIM_ETHEREUM_RPC_URL = "http://127.0.0.1:8545";

//     uint256 internal supersimEthereumForkId;
//     uint256 internal forkBlock;

//     function setUp() public virtual {
//         string memory rpcUrl = _supersimEthereumRpcUrl();
//         uint256 requestedBlock = _forkBlock();

//         if (requestedBlock > 0) {
//             supersimEthereumForkId = vm.createSelectFork(rpcUrl, requestedBlock);
//             forkBlock = requestedBlock;
//         } else {
//             supersimEthereumForkId = vm.createSelectFork(rpcUrl);
//             forkBlock = block.number;
//         }

//         assertEq(block.chainid, ETHEREUM_SEPOLIA_CHAIN_ID, "Fork should be on Supersim Ethereum Sepolia");
//     }

//     function _supersimEthereumRpcUrl() internal view returns (string memory rpcUrl) {
//         try vm.envString("SUPERSIM_ETHEREUM_RPC_URL") returns (string memory envUrl) {
//             return envUrl;
//         } catch {
//             return DEFAULT_SUPERSIM_ETHEREUM_RPC_URL;
//         }
//     }

//     function _forkBlock() internal view returns (uint256 blockNumber) {
//         try vm.envUint("SUPERSIM_ETHEREUM_FORK_BLOCK") returns (uint256 envBlock) {
//             return envBlock;
//         } catch {
//             return 0;
//         }
//     }
// }

// contract EthereumProtocolDETFSyntheticPrice_SuperSimFork_Test is TestBase_SupersimEthereumFork {
//     using BetterMath for uint256;

//     address internal constant SUPERSIM_ETHEREUM_PROTOCOL_DETF = 0x607Eb93ab1868A8B5Ae904bA063380505E4764F7;
//     string internal constant EXPECTED_SYNTHETIC_PRICE_FACET_NAME = "EthereumProtocolDETFBondingQueryFacet";

//     struct SyntheticPriceDebugState {
//         address detf;
//         address rich;
//         address richir;
//         address chirWethVault;
//         address richChirVault;
//         address reservePool;
//         address chirWethPair;
//         address richChirPair;
//         uint256 chirWethVaultIndex;
//         uint256 richChirVaultIndex;
//         uint256 chirWethVaultWeight;
//         uint256 richChirVaultWeight;
//         uint256 chirWethLpTotalSupply;
//         uint256 richChirLpTotalSupply;
//         uint256 chirInWethPool;
//         uint256 wethReserve;
//         uint256 richReserve;
//         uint256 chirInRichPool;
//         uint256 chirTotalSupply;
//         uint256 chirTotalInPools;
//         uint256 chirSynthWc;
//         uint256 chirSynthRc;
//         uint256 syntheticWethValue;
//         uint256 syntheticRichValue;
//     }

//     function test_sanity_supersimProtocolDetfDeploymentExists() public view {
//         assertEq(block.chainid, ETHEREUM_SEPOLIA_CHAIN_ID, "Should be on Ethereum Sepolia chain id");
//         assertGt(forkBlock, 0, "Fork block should be set");
//         assertTrue(SUPERSIM_ETHEREUM_PROTOCOL_DETF.code.length > 0, "Protocol DETF should have code");
//     }

//     function test_checkSyntheticPrice_selectorFacetMapping_liveSupersimFork() public view {
//         IDiamondLoupe loupe = IDiamondLoupe(SUPERSIM_ETHEREUM_PROTOCOL_DETF);
//         bytes4 selector = IProtocolDETF.syntheticPrice.selector;
//         address ownerFacet = loupe.facetAddress(selector);

//         assertTrue(ownerFacet != address(0), "syntheticPrice selector should resolve to a facet");

//         string memory facetName = IFacet(ownerFacet).facetName();
//         bytes4[] memory facetSelectors = loupe.facetFunctionSelectors(ownerFacet);

//         bool selectorPresent;
//         for (uint256 i = 0; i < facetSelectors.length; i++) {
//             if (facetSelectors[i] == selector) {
//                 selectorPresent = true;
//                 break;
//             }
//         }

//         assertTrue(selectorPresent, "selector owner facet should report syntheticPrice selector");
//         assertEq(
//             keccak256(bytes(facetName)),
//             keccak256(bytes(EXPECTED_SYNTHETIC_PRICE_FACET_NAME)),
//             "syntheticPrice selector is mapped to the wrong facet"
//         );
//     }

//     function test_debugSyntheticPrice_liveSupersimFork() public {
//         SyntheticPriceDebugState memory state = _loadDebugState();
//         (address syntheticPriceFacet, string memory syntheticPriceFacetName) = _syntheticPriceFacetInfo();

//         console.log("=== Supersim Ethereum Protocol DETF syntheticPrice debug ===");
//         console.log("forkBlock:", forkBlock);
//         console.log("detf:", state.detf);
//         console.log("syntheticPriceFacet:", syntheticPriceFacet);
//         console.log("syntheticPriceFacetName:", syntheticPriceFacetName);
//         console.log("rich:", state.rich);
//         console.log("richir:", state.richir);
//         console.log("chirWethVault:", state.chirWethVault);
//         console.log("richChirVault:", state.richChirVault);
//         console.log("reservePool:", state.reservePool);
//         console.log("chirWethPair:", state.chirWethPair);
//         console.log("richChirPair:", state.richChirPair);

//         emit log_named_uint("chirWethVaultIndex", state.chirWethVaultIndex);
//         emit log_named_uint("richChirVaultIndex", state.richChirVaultIndex);
//         emit log_named_uint("chirWethVaultWeight", state.chirWethVaultWeight);
//         emit log_named_uint("richChirVaultWeight", state.richChirVaultWeight);
//         emit log_named_uint("chirWethLpTotalSupply", state.chirWethLpTotalSupply);
//         emit log_named_uint("richChirLpTotalSupply", state.richChirLpTotalSupply);
//         emit log_named_uint("chirInWethPool", state.chirInWethPool);
//         emit log_named_uint("wethReserve", state.wethReserve);
//         emit log_named_uint("richReserve", state.richReserve);
//         emit log_named_uint("chirInRichPool", state.chirInRichPool);
//         emit log_named_uint("chirTotalSupply", state.chirTotalSupply);
//         emit log_named_uint("chirTotalInPools", state.chirTotalInPools);
//         emit log_named_uint("chirSynth_WC", state.chirSynthWc);
//         emit log_named_uint("chirSynth_RC", state.chirSynthRc);
//         emit log_named_uint("syntheticWethValue", state.syntheticWethValue);
//         emit log_named_uint("syntheticRichValue", state.syntheticRichValue);

//         IProtocolDETF detf = IProtocolDETF(state.detf);

//         try detf.syntheticPrice() returns (uint256 syntheticPrice_) {
//             emit log_named_uint("syntheticPrice", syntheticPrice_);
//             assertGt(syntheticPrice_, 0, "syntheticPrice returned zero");
//         } catch (bytes memory reason) {
//             bytes4 selector = _selector(reason);
//             if (selector == IProtocolDETFErrors.PoolImbalanced.selector) {
//                 (uint256 syntheticWethValue_, uint256 syntheticRichValue_) = _decodePoolImbalanced(reason);
//                 emit log_named_uint("decodedSyntheticWethValue", syntheticWethValue_);
//                 emit log_named_uint("decodedSyntheticRichValue", syntheticRichValue_);
//             }

//             fail("syntheticPrice() reverted on live Supersim fork; inspect logs for reserve state");
//         }
//     }

//     function _loadDebugState() internal view returns (SyntheticPriceDebugState memory state) {
//         IProtocolDETF detf = IProtocolDETF(SUPERSIM_ETHEREUM_PROTOCOL_DETF);
//         IStandardExchange chirWethVault = detf.chirWethVault();
//         IStandardExchange richChirVault = detf.richChirVault();
//         IWeightedPool reservePool = IWeightedPool(detf.reservePool());

//         state.detf = address(detf);
//         state.rich = address(detf.richToken());
//         state.richir = address(detf.richirToken());
//         state.chirWethVault = address(chirWethVault);
//         state.richChirVault = address(richChirVault);
//         state.reservePool = address(reservePool);

//         _loadReservePoolWeights(state, reservePool, address(chirWethVault), address(richChirVault));

//         IUniswapV2Pair chirWethPair = IUniswapV2Pair(address(IERC4626(address(chirWethVault)).asset()));
//         state.chirWethPair = address(chirWethPair);
//         state.chirWethLpTotalSupply = IERC20(address(chirWethPair)).totalSupply();

//         (uint256 reserve0, uint256 reserve1,) = chirWethPair.getReserves();
//         if (chirWethPair.token0() == address(detf)) {
//             state.chirInWethPool = reserve0;
//             state.wethReserve = reserve1;
//         } else {
//             state.chirInWethPool = reserve1;
//             state.wethReserve = reserve0;
//         }

//         IUniswapV2Pair richChirPair = IUniswapV2Pair(address(IERC4626(address(richChirVault)).asset()));
//         state.richChirPair = address(richChirPair);
//         state.richChirLpTotalSupply = IERC20(address(richChirPair)).totalSupply();

//         (reserve0, reserve1,) = richChirPair.getReserves();
//         if (richChirPair.token0() == state.rich) {
//             state.richReserve = reserve0;
//             state.chirInRichPool = reserve1;
//         } else {
//             state.richReserve = reserve1;
//             state.chirInRichPool = reserve0;
//         }

//         state.chirTotalSupply = IERC20(address(detf)).totalSupply();
//         state.chirTotalInPools = state.chirInWethPool + state.chirInRichPool;

//         if (state.chirTotalInPools == 0 || state.chirTotalSupply == 0) {
//             return state;
//         }

//         state.chirSynthWc = BetterMath._mulDivDown(state.chirTotalSupply, state.chirInWethPool, state.chirTotalInPools);
//         state.chirSynthRc = BetterMath._mulDivDown(state.chirTotalSupply, state.chirInRichPool, state.chirTotalInPools);

//         state.syntheticWethValue = AerodromeUtils._quoteWithdrawSwapWithFee(
//             state.chirWethLpTotalSupply,
//             state.chirWethLpTotalSupply,
//             state.wethReserve,
//             state.chirSynthWc,
//             UNISWAPV2_FEE_PERCENT
//         );

//         state.syntheticRichValue = AerodromeUtils._quoteWithdrawSwapWithFee(
//             state.richChirLpTotalSupply,
//             state.richChirLpTotalSupply,
//             state.richReserve,
//             state.chirSynthRc,
//             UNISWAPV2_FEE_PERCENT
//         );
//     }

//     function _syntheticPriceFacetInfo() internal view returns (address facetAddress_, string memory facetName_) {
//         facetAddress_ = IDiamondLoupe(SUPERSIM_ETHEREUM_PROTOCOL_DETF).facetAddress(IProtocolDETF.syntheticPrice.selector);
//         if (facetAddress_ == address(0)) {
//             return (address(0), "");
//         }

//         facetName_ = IFacet(facetAddress_).facetName();
//     }

//     function _loadReservePoolWeights(
//         SyntheticPriceDebugState memory state,
//         IWeightedPool reservePool,
//         address chirWethVault,
//         address richChirVault
//     ) internal view {
//         address[] memory tokens = _tokensFromWeightedPool(reservePool);
//         uint256[] memory weights = reservePool.getNormalizedWeights();

//         bool foundChirWeth;
//         bool foundRichChir;

//         for (uint256 i = 0; i < tokens.length; i++) {
//             if (tokens[i] == chirWethVault) {
//                 state.chirWethVaultIndex = i;
//                 state.chirWethVaultWeight = weights[i];
//                 foundChirWeth = true;
//             }
//             if (tokens[i] == richChirVault) {
//                 state.richChirVaultIndex = i;
//                 state.richChirVaultWeight = weights[i];
//                 foundRichChir = true;
//             }
//         }

//         require(foundChirWeth, "chirWethVault missing from reserve pool");
//         require(foundRichChir, "richChirVault missing from reserve pool");
//     }

//     function _tokensFromWeightedPool(IWeightedPool reservePool) internal view returns (address[] memory tokens_) {
//         IERC20[] memory tokens = reservePool.getWeightedPoolImmutableData().tokens;
//         tokens_ = new address[](tokens.length);
//         for (uint256 i = 0; i < tokens.length; i++) {
//             tokens_[i] = address(tokens[i]);
//         }
//     }

//     function _selector(bytes memory reason) internal pure returns (bytes4 selector) {
//         if (reason.length < 4) return bytes4(0);
//         assembly {
//             selector := mload(add(reason, 32))
//         }
//     }

//     function _decodePoolImbalanced(bytes memory reason)
//         internal
//         pure
//         returns (uint256 syntheticWethValue_, uint256 syntheticRichValue_)
//     {
//         if (reason.length < 68) {
//             return (0, 0);
//         }

//         assembly {
//             syntheticWethValue_ := mload(add(reason, 36))
//             syntheticRichValue_ := mload(add(reason, 68))
//         }
//     }
// }