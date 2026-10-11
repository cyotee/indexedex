// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
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

    function test_review_singleCpJoinAndShareExit() public { _roundTrip(Amm.Family.SingleCp); }
    function test_review_dualCpJoinAndShareExit() public { _roundTrip(Amm.Family.Dual); }
    function test_review_orbitalJoinAndShareExit() public { _roundTrip(Amm.Family.Orbital); }
    function test_review_curveQuadJoinAndShareExit() public { _roundTrip(Amm.Family.CurveQuad); }
    function test_review_balancerQuadJoinAndShareExit() public { _roundTrip(Amm.Family.BalancerQuad); }

    function _roundTrip(Amm.Family family) private {
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, SEED, IERC20(address(wings0)), SEED, address(this), false, block.timestamp);
        Rebalance(address(wings0)).rebalance(0, block.timestamp);
        Amm.Fixture memory f = _deploy(family);
        uint256 shares = IERC20(address(wings0)).balanceOf(address(this)) / 2;
        for (uint256 i; i < f.tokens.length; ++i) if (f.tokens[i] != address(token0)) {
            f.amounts[i] = 1_000 * 10 ** _decimals(f.tokens[i]);
            Amm.fundInventory(f, f.tokens[i], address(this), f.amounts[i]);
            IERC20(f.tokens[i]).approve(f.hook, type(uint256).max);
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
        uint256 holderSharesBeforeExit = IERC20(address(wings0)).balanceOf(address(this));
        uint256 totalSupply = IERC20(address(wings0)).totalSupply();
        uint256 opposingBeforeExit = token1.balanceOf(f.hook);
        uint256 holderOpposingBeforeExit = token1.balanceOf(address(this));
        _exit(family, f, lp / 2);
        assertLt(IERC20(address(wings0)).balanceOf(f.hook), hookShares, "exit returned Wings shares");
        uint256 returned = IERC20(address(wings0)).balanceOf(address(this)) - holderSharesBeforeExit;
        assertGt(returned, 0, "actual Wings shares received");
        assertEq(hookShares - IERC20(address(wings0)).balanceOf(f.hook), returned, "share exit conserves Wings shares");
        assertEq(IERC20(address(wings0)).totalSupply(), totalSupply, "share exit does not redeem Wings");
        assertEq(token1.balanceOf(f.hook), opposingBeforeExit, "opposing vault currency does not leak into consumer");
        assertEq(token1.balanceOf(address(this)), holderOpposingBeforeExit, "share exit does not pay opposing vault currency");
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

    function _exit(Amm.Family family, Amm.Fixture memory f, uint256 lp) private {
        if (family == Amm.Family.SingleCp) {
            CpHook(f.hook).withdrawSeShares(lp, address(this), 0, 0, block.timestamp);
        } else if (family == Amm.Family.Dual) {
            bool first = f.tokens[0] == address(token0);
            DualHook(f.hook).withdrawFlexible(lp, address(this), first, !first, 0, 0, block.timestamp);
        } else if (family == Amm.Family.Orbital) {
            bool a = f.tokens[0] == address(token0);
            bool b = f.tokens[1] == address(token0);
            OrbitalHook(f.hook).withdrawFlexible(lp, address(this), a, b, !a && !b, 0, 0, 0, block.timestamp);
        } else {
            bool[] memory shares = new bool[](f.tokens.length);
            uint256[] memory minimums = new uint256[](f.tokens.length);
            for (uint256 i; i < shares.length; ++i) shares[i] = f.tokens[i] == address(token0);
            if (family == Amm.Family.CurveQuad) CurveHook(f.hook).exitProportionalFlexible(lp, address(this), shares, minimums, block.timestamp);
            else IUniswapV4BalancerStableLiquidityUnits(f.hook).exitProportionalFlexible(lp, address(this), shares, minimums, block.timestamp);
        }
    }

    function _decimals(address token) private view returns (uint256) {
        (bool ok, bytes memory data) = token.staticcall(abi.encodeWithSignature("decimals()"));
        return ok && data.length >= 32 ? abi.decode(data, (uint8)) : 18;
    }
}

