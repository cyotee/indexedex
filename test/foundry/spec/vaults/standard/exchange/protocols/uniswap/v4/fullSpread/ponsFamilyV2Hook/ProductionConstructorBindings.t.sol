// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch as Launch} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Launch.sol";
import {IUniswapV4FullSpreadPonsFamilyHookDFPkg as Package} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/IUniswapV4FullSpreadPonsFamilyHookDFPkg.sol";
import {UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService as Factory} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHook_Component_FactoryService.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {ROBINHOOD_MAIN} from "@crane/contracts/constants/networks/ROBINHOOD_MAIN.sol";
import {Bytecode} from "@crane/contracts/utils/Bytecode.sol";
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";

/// @dev Production-chain test proves local binding cannot bypass the fixed singleton.
/// It does not claim isolation of the later manager-address pin: production validates
/// canonical hook code/identity first. That isolated branch needs a coordinated fixture.
contract UniswapV4FullSpreadPonsFamilyHookProductionConstructorBindingsTest is Launch {
    function _probeInit() private view returns (Package.PkgInit memory init) {
        init = Factory.buildArgsUniswapV4FullSpreadPonsFamilyHookPkgInit(_univ4SePkgInitCore());
        init = Factory.attachTwapOracle(init, twapOracle);
        init.positionManager = ponsPositionManager; init.expectedHook = address(ponsHook);
        return Factory.attachUniswapV4FullSpreadPonsFamilyHookMultiFacets(init,
            uniswapV4StandardExchangeInMultiFacet, uniswapV4StandardExchangeInMultiQueryFacet,
            uniswapV4StandardExchangeOutMultiFacet, uniswapV4StandardExchangeOutMultiQueryFacet);
    }

    function test_chain4663RejectsLocalLaunchHookAndManagerConstructorBindings() public {
        Package.PkgInit memory init = _probeInit();
        uint256 chain = block.chainid;
        assertTrue(init.expectedHook != ROBINHOOD_MAIN.PONS_V2_MEME_HOOK);
        assertTrue(address(init.poolManager) != ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER);
        _rejectThenAccept(init, init, ROBINHOOD_MAIN.CHAIN_ID, chain);
    }

    function test_realLaunchHookRejectsDifferentRealManagerBeforeRegistration() public {
        Package.PkgInit memory good = _probeInit();
        Package.PkgInit memory wrong = abi.decode(abi.encode(good), (Package.PkgInit));
        wrong.poolManager = IPoolManager(create3Factory.create3WithArgs(
            ArtifactCreationCode.creationCode(create3Factory, "PoolManager.sol:PoolManager"),
            abi.encode(address(this)), keccak256(abi.encode("PoolManager"))));
        assertTrue(address(wrong.poolManager) != address(ponsHook.poolManager()));
        _rejectThenAccept(wrong, good, block.chainid, block.chainid);
    }

    function _rejectThenAccept(Package.PkgInit memory bad_, Package.PkgInit memory good_, uint256 rejectChain_, uint256 acceptChain_) private {
        bytes memory code = ArtifactCreationCode.creationCode(create3Factory,
            "UniswapV4FullSpreadPonsFamilyHookProductionBindingProbe.sol:UniswapV4FullSpreadPonsFamilyHookProductionBindingProbe");
        bytes32 salt = keccak256(abi.encode("UniswapV4FullSpreadPonsFamilyHookProductionBindingProbe"));
        uint256 count = indexedexManager.vaultPackages().length;
        vm.chainId(rejectChain_);
        vm.prank(owner);
        vm.expectRevert(Bytecode.ErrorCreatingContract.selector);
        indexedexManager.deployPkg(code, abi.encode(bad_), salt);
        assertEq(indexedexManager.vaultPackages().length, count);
        vm.chainId(acceptChain_);
        vm.prank(owner);
        address deployed = indexedexManager.deployPkg(code, abi.encode(good_), salt);
        assertGt(deployed.code.length, 0); assertTrue(indexedexManager.isPackage(deployed));
        assertEq(indexedexManager.vaultPackages().length, count + 1);
        assertEq(Package(deployed).bindingHash(), keccak256(abi.encode(good_)));
    }
}
