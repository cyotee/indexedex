// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IDiamond} from "@crane/contracts/interfaces/IDiamond.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {Behavior_IFacet} from "@crane/contracts/factories/diamondPkg/Behavior_IFacet.sol";
import {TestBase_IFacet} from "@crane/contracts/factories/diamondPkg/TestBase_IFacet.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {
    TestBase_UniswapV4MultiPoolTwapOracle
} from "contracts/test/bases/TestBase_UniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracle
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracle.sol";
import {
    IUniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/interfaces/IUniswapV4MultiPoolTwapOracleDFPkg.sol";
import {
    UniswapV4MultiPoolTwapOracleFacet
} from "contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleFacet.sol";
import {
    UniswapV4MultiPoolTwapOracleDFPkg
} from "contracts/oracles/uniswap/v4/twap/UniswapV4MultiPoolTwapOracleDFPkg.sol";

/**
 * @title UniswapV4MultiPoolTwapOracle_Declaration
 * @notice H20, H22–H26, H23, H24, H30, J1–J3, F1. Behavior_IFacet + IDiamondFactoryPackage declaration.
 */
contract UniswapV4MultiPoolTwapOracle_Declaration is TestBase_UniswapV4MultiPoolTwapOracle, TestBase_IFacet {
    bytes4 internal constant UPDATE_ONE_SELECTOR =
        bytes4(keccak256("update((address,address,uint24,int24,address))"));
    bytes4 internal constant UPDATE_MANY_SELECTOR =
        bytes4(keccak256("update((address,address,uint24,int24,address)[])"));

    function setUp() public override(TestBase_UniswapV4MultiPoolTwapOracle, TestBase_IFacet) {
        TestBase_UniswapV4MultiPoolTwapOracle.setUp();
        testFacet = facetTestInstance();
    }

    function facetTestInstance() public view override returns (IFacet) {
        return twapOracleFacet;
    }

    function controlFacetName() public pure override returns (string memory) {
        return type(UniswapV4MultiPoolTwapOracleFacet).name;
    }

    function controlFacetInterfaces() public pure override returns (bytes4[] memory controlInterfaces) {
        controlInterfaces = new bytes4[](1);
        controlInterfaces[0] = type(IUniswapV4MultiPoolTwapOracle).interfaceId;
    }

    function controlFacetFuncs() public pure override returns (bytes4[] memory controlFuncs) {
        controlFuncs = new bytes4[](11);
        controlFuncs[0] = IUniswapV4MultiPoolTwapOracle.poolManager.selector;
        controlFuncs[1] = IUniswapV4MultiPoolTwapOracle.MAX_ABS_TICK_MOVE.selector;
        controlFuncs[2] = UPDATE_ONE_SELECTOR;
        controlFuncs[3] = UPDATE_MANY_SELECTOR;
        controlFuncs[4] = IUniswapV4MultiPoolTwapOracle.increaseCardinalityNext.selector;
        controlFuncs[5] = IUniswapV4MultiPoolTwapOracle.observe.selector;
        controlFuncs[6] = IUniswapV4MultiPoolTwapOracle.consult.selector;
        controlFuncs[7] = IUniswapV4MultiPoolTwapOracle.getPoolKey.selector;
        controlFuncs[8] = IUniswapV4MultiPoolTwapOracle.getState.selector;
        controlFuncs[9] = IUniswapV4MultiPoolTwapOracle.getObservation.selector;
        controlFuncs[10] = IUniswapV4MultiPoolTwapOracle.writeAge.selector;
    }

    function test_H20_noNewOnHappyPath() public view {
        assertTrue(address(twapOracleFacet).code.length > 0, "facet deployed");
        assertTrue(address(twapOraclePkg).code.length > 0, "pkg deployed");
        assertTrue(address(twapOracle).code.length > 0, "instance deployed");
        assertEq(twapOracle.poolManager(), address(poolManager));
    }

    function test_H22_deployOracleIdempotent() public {
        IUniswapV4MultiPoolTwapOracle second = twapOraclePkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(poolManager)})
        );
        assertEq(address(second), address(twapOracle), "same args same instance");
    }

    function test_H23_zeroPoolManagerReverts() public {
        vm.expectRevert(IUniswapV4MultiPoolTwapOracle.ZeroPoolManager.selector);
        twapOraclePkg.deployOracle(IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(0)}));
    }

    function test_H24_F1_unownedDiamondCutReverts() public {
        assertEq(
            IDiamondLoupe(address(twapOracle)).facetAddress(IDiamondCut.diamondCut.selector),
            address(0),
            "diamondCut not cut"
        );
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](0);
        vm.expectRevert();
        IDiamondCut(address(twapOracle)).diamondCut(cuts, address(0), "");
    }

    function test_H25_IDiamondFactoryPackage_packageName() public view {
        assertEq(twapOraclePkg.packageName(), type(UniswapV4MultiPoolTwapOracleDFPkg).name);
    }

    function test_H25_IDiamondFactoryPackage_facetAddresses() public view {
        address[] memory addrs = twapOraclePkg.facetAddresses();
        assertEq(addrs.length, 1);
        assertEq(addrs[0], address(twapOracleFacet));
    }

    function test_H25_IDiamondFactoryPackage_facetCuts() public view {
        IDiamond.FacetCut[] memory cuts = twapOraclePkg.facetCuts();
        assertEq(cuts.length, 1);
        assertEq(cuts[0].facetAddress, address(twapOracleFacet));
        assertEq(uint8(cuts[0].action), uint8(IDiamond.FacetCutAction.Add));
        assertEq(cuts[0].functionSelectors.length, controlFacetFuncs().length);
    }

    function test_H25_IDiamondFactoryPackage_diamondConfig() public view {
        IDiamondFactoryPackage.DiamondConfig memory cfg = twapOraclePkg.diamondConfig();
        assertEq(cfg.facetCuts.length, 1);
        assertEq(cfg.interfaces.length, 1);
        assertEq(cfg.interfaces[0], type(IUniswapV4MultiPoolTwapOracle).interfaceId);
    }

    function test_H25_IDiamondFactoryPackage_calcSalt_determinism() public view {
        bytes memory argsA =
            abi.encode(IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(poolManager)}));
        bytes memory argsB = abi.encode(IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(1)}));
        assertEq(twapOraclePkg.calcSalt(argsA), twapOraclePkg.calcSalt(argsA));
        assertTrue(twapOraclePkg.calcSalt(argsA) != twapOraclePkg.calcSalt(argsB));
        assertEq(twapOraclePkg.calcSalt(argsA), keccak256(abi.encode(address(poolManager))));
    }

    function test_H26_J1_J2_J3_targetSelectorsOnProxy() public {
        bytes4[] memory selectors = controlFacetFuncs();
        bytes4[] memory facetFuncs_ = twapOracleFacet.facetFuncs();
        assertTrue(Behavior_IFacet.areValid_IFacet_facetFuncs(twapOracleFacet, selectors, facetFuncs_));

        IDiamond.FacetCut[] memory cuts = twapOraclePkg.facetCuts();
        assertEq(cuts[0].functionSelectors.length, selectors.length);
        for (uint256 i; i < selectors.length; ++i) {
            bool inCut;
            for (uint256 j; j < cuts[0].functionSelectors.length; ++j) {
                if (cuts[0].functionSelectors[j] == selectors[i]) {
                    inCut = true;
                    break;
                }
            }
            assertTrue(inCut, "selector missing from cuts");
            address facetOnProxy = IDiamondLoupe(address(twapOracle)).facetAddress(selectors[i]);
            assertEq(facetOnProxy, address(twapOracleFacet), "loupe missing selector");
        }

        assertEq(twapOracle.poolManager(), address(poolManager));
        assertEq(twapOracle.MAX_ABS_TICK_MOVE(), 9116);
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(twapOracle.update(poolKey));
        uint32[] memory agos = new uint32[](1);
        agos[0] = 0;
        int56[] memory cumulatives = twapOracle.observe(poolKey.toId(), agos);
        assertEq(cumulatives.length, 1);
        _warp(10);
        twapOracle.consult(poolKey.toId(), 5);
        twapOracle.getPoolKey(poolKey.toId());
        twapOracle.getState(poolKey.toId());
        twapOracle.getObservation(poolKey.toId(), 0);
        twapOracle.writeAge(poolKey.toId());
        PoolKey[] memory keys = new PoolKey[](1);
        keys[0] = poolKey;
        twapOracle.update(keys);
        twapOracle.increaseCardinalityNext(poolKey.toId(), 4);
    }

    function test_H30_permissionlessDeployOracle() public {
        PoolManager otherPm = new PoolManager(address(this));
        address eoa = makeAddr("eoaDeployer");
        vm.prank(eoa);
        IUniswapV4MultiPoolTwapOracle other = twapOraclePkg.deployOracle(
            IUniswapV4MultiPoolTwapOracleDFPkg.PkgArgs({poolManager: address(otherPm)})
        );
        assertTrue(address(other).code.length > 0);
        assertEq(other.poolManager(), address(otherPm));
        assertTrue(address(other) != address(twapOracle));
    }

    function test_H21_twoManagersIsolatedRings() public {
        PoolManager pmB = new PoolManager(address(this));
        IUniswapV4MultiPoolTwapOracle oracleB = _deployOracle(pmB);
        _initPool(poolManager, poolKey, TickMath.getSqrtPriceAtTick(0));
        assertTrue(twapOracle.update(poolKey));
        (, uint16 cardA,,,) = twapOracle.getState(poolKey.toId());
        assertEq(cardA, 1);
        (, uint16 cardB,,,) = oracleB.getState(poolKey.toId());
        assertEq(cardB, 0);
    }
}
