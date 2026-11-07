// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {Vm} from "forge-std/Vm.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4BalancerStableLiquidityUnits} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4BalancerStableLiquidityUnits.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {FullSpreadSameManagerAmmFixture as Amm} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/FullSpreadSameManagerAmmFixture.sol";
import {IUniswapV4HookDiamondPackageCallBackFactory as HookFactory} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHook as CpHook} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHook as DualHook} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {IUniswapV4StandardExchangeOrbitalBufferHook as OrbitalHook} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {IUniswapV4StandardExchangeCurveQuadStableBufferHook as CurveHook} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance as Rebalance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultRebalance.sol";

/// @notice Real Orbital, quad and constant-product consumers bound to a Wings vault. Not an exhaustive mask.
contract WingsApexRecurrenceConsumerConservationTest is Fixture {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    uint256 internal constant SEED = 1e12;

    struct ExitSnapshot {
        uint256 hookShares;
        uint256 holderShares;
        uint256 supply;
        uint256 local;
        uint256 lpSupply;
        uint256 opposing;
        uint256 holderOpposing;
    }

    function test_review_singleCpJoinAndShareExit() public { _roundTrip(Amm.Family.SingleCp); }
    function test_review_dualCpJoinAndShareExit() public { _roundTrip(Amm.Family.Dual); }
    function test_review_orbitalJoinAndShareExit() public { _roundTrip(Amm.Family.Orbital); }
    function test_review_curveQuadJoinAndShareExit() public { _roundTrip(Amm.Family.CurveQuad); }
    function test_review_balancerQuadJoinAndShareExit() public { _roundTrip(Amm.Family.BalancerQuad); }

    function _roundTrip(Amm.Family family) private {IStandardExchangeIn(address(wings0)).exchangeIn(token0, SEED, IERC20(address(wings0)), SEED, address(this), false, block.timestamp);
        Rebalance(address(wings0)).rebalance(0, block.timestamp);
        Amm.Fixture memory f = _deploy(family);
        uint256 shares = IERC20(address(wings0)).balanceOf(address(this)) / 2;
        for (uint256 i; i < f.tokens.length; ++i) if (f.tokens[i] != address(token0)) {
            address input = family == Amm.Family.Dual ? f.output : f.tokens[i];
            f.amounts[i] = 1_000 * 10 ** _decimals(input);
            Amm.fundInventory(f, input, address(this), f.amounts[i]);
            IERC20(input).approve(f.hook, type(uint256).max);
        }
        IERC20(address(wings0)).approve(f.hook, shares);
        uint256 wingsBefore = IERC20(address(wings0)).balanceOf(address(this));
        (bool ok, bytes memory result) = f.hook.call(Amm.shareSeedCall(family, f, address(token0), shares, address(this)));
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        uint256 lp = IERC20(f.hook).balanceOf(address(this));
        assertGt(lp, 0, "consumer minted");
        assertLt(IERC20(address(wings0)).balanceOf(address(this)), wingsBefore, "Wings shares left the holder");
        uint256 hookShares = IERC20(address(wings0)).balanceOf(f.hook);
        assertGt(hookShares, 0, "consumer holds Wings shares");
        _assertShareExit(family, f, lp / 2);
    }

    /// @dev FS-HOOK-08: allocate both components, then convert only the exiting local claim.
    function _assertShareExit(Amm.Family family, Amm.Fixture memory f, uint256 burned) private {
        IERC20 se = IERC20(address(wings0));
        ExitSnapshot memory beforeExit = ExitSnapshot(se.balanceOf(f.hook), se.balanceOf(address(this)),
            se.totalSupply(), token0.balanceOf(f.hook), IERC20(f.hook).totalSupply(),
            token1.balanceOf(f.hook), token1.balanceOf(address(this)));
        // This fixture stages no donations: its held shares and local tokens are the funded book.
        uint256 allocatedShares = Math.mulDiv(burned, beforeExit.hookShares, beforeExit.lpSupply);
        uint256 allocatedLocal = Math.mulDiv(burned, beforeExit.local, beforeExit.lpSupply);
        assertGt(allocatedLocal, 0, "bootstrap seeded the exiting local claim");
        vm.recordLogs();
        uint256 paid = _exit(family, f, burned);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 minted;
        uint256 spent;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 3 || logs[i].topics[0] != keccak256("Transfer(address,address,uint256)")) continue;
            address from = address(uint160(uint256(logs[i].topics[1])));
            address to = address(uint160(uint256(logs[i].topics[2])));
            if (logs[i].emitter == address(se) && from == address(0) && to == f.hook) minted += abi.decode(logs[i].data, (uint256));
            if (logs[i].emitter == address(token0) && from == f.hook && to == address(se)) spent += abi.decode(logs[i].data, (uint256));
        }
        assertGt(minted, 0, "allocated local claim minted actual Wings shares");
        assertEq(spent, allocatedLocal, "only allocated local claim converted");
        assertEq(paid, allocatedShares + minted, "exit receipt includes held and newly minted shares");
        assertEq(se.balanceOf(address(this)) - beforeExit.holderShares, paid, "exit receipt matches shares received");
        assertEq(se.balanceOf(f.hook), beforeExit.hookShares - allocatedShares, "remaining share component conserved");
        assertEq(token0.balanceOf(f.hook), beforeExit.local - allocatedLocal, "remaining local component conserved");
        assertEq(se.totalSupply(), beforeExit.supply + minted, "SE supply includes local claim conversion");
        assertEq(IERC20(f.hook).totalSupply(), beforeExit.lpSupply - burned, "exit only burns requested LP");
        assertEq(token1.balanceOf(f.hook), beforeExit.opposing, "opposing vault currency does not leak into consumer");
        assertEq(token1.balanceOf(address(this)), beforeExit.holderOpposing, "share exit does not pay opposing vault currency");
    }

    function _deploy(Amm.Family family) private returns (Amm.Fixture memory) {
        SeMatrixFixture.Ctx memory c;
        c.create3Factory = create3Factory;
        c.indexedexManager = indexedexManager;
        c.owner = owner;
        c.permit2 = IPermit2(deployPermit2());
        c.erc20Facet = create3Factory.deployERC20Facet();
        c.erc2612Facet = create3Factory.deployERC2612Facet();
        c.erc5267Facet = create3Factory.deployERC5267Facet();
        c.erc4626Facet = create3Factory.deployERC4626Facet();
        c.erc4626StandardVaultFacet = create3Factory.deployERC4626StandardVaultFacet();
        c.multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        c.multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        IFacetRegistry registry = IFacetRegistry(address(create3Factory));
        HookFactory factory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(create3Factory,
            HookFactory.InitArgs(registry.canonicalFacet(type(IERC165).interfaceId), registry.canonicalFacet(type(IDiamondLoupe).interfaceId),
                registry.canonicalFacet(type(IERC8109Introspection).interfaceId), registry.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory)));
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(factory));
        Amm.Request memory request;
        request.c = c; request.factory = factory; request.manager = address(pool);
        request.vault = address(wings0); request.face = address(token0); request.owner = address(this);
        request.identityAssetDecimals = 6;
        return Amm.deploy(family, request);
    }

    function _exit(Amm.Family family, Amm.Fixture memory f, uint256 lp) private returns (uint256 paid) {
        if (family == Amm.Family.SingleCp) {
            (, paid) = CpHook(f.hook).withdrawSeShares(lp, address(this), 0, 0, block.timestamp);
        } else if (family == Amm.Family.Dual) {
            bool first = f.tokens[0] == address(token0);
            (uint256 a, uint256 b) = DualHook(f.hook).withdrawFlexible(lp, address(this), first, !first, 0, 0, block.timestamp);
            paid = first ? a : b;
        } else if (family == Amm.Family.Orbital) {
            bool a = f.tokens[0] == address(token0);
            bool b = f.tokens[1] == address(token0);
            (uint256 x, uint256 y, uint256 z) = OrbitalHook(f.hook).withdrawFlexible(lp, address(this), a, b, !a && !b, 0, 0, 0, block.timestamp);
            paid = a ? x : b ? y : z;
        } else {
            bool[] memory shares = new bool[](f.tokens.length);
            uint256[] memory minimums = new uint256[](f.tokens.length);
            for (uint256 i; i < shares.length; ++i) shares[i] = f.tokens[i] == address(token0);
            uint256[] memory amounts;
            if (family == Amm.Family.CurveQuad) amounts = CurveHook(f.hook).exitProportionalFlexible(lp, address(this), shares, minimums, block.timestamp);
            else amounts = IUniswapV4BalancerStableLiquidityUnits(f.hook).exitProportionalFlexible(lp, address(this), shares, minimums, block.timestamp);
            for (uint256 i; i < shares.length; ++i) if (shares[i]) paid = amounts[i];
        }
    }

    function _decimals(address token) private view returns (uint256) {
        (bool ok, bytes memory data) = token.staticcall(abi.encodeWithSignature("decimals()"));
        return ok && data.length >= 32 ? abi.decode(data, (uint8)) : 18;
    }
}

