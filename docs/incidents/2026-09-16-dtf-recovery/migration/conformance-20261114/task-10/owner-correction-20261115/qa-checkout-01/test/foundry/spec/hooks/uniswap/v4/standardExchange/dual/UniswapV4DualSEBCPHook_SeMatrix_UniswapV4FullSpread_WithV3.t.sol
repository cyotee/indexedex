// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IDiamondPackageCallBackFactory} from "@crane/contracts/interfaces/IDiamondPackageCallBackFactory.sol";
import {IIndexedexManagerProxy} from "contracts/interfaces/proxies/IIndexedexManagerProxy.sol";
import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {SeMatrix_FullSpreadV3Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV3Fixture.sol";
import {TestBase_UniswapV4DualSEBCPHook} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHookPackage as IDualPackage} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {RateProviderFixtureLib} from "contracts/test/libs/RateProviderFixtureLib.sol";
import {IUniswapV4DualStandardExchangeBufferConstantProductHook as IDualHook} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";

/// @notice This vault beside the V3 full-spread vault in one dual hook.
contract UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpread_WithV3 is TestBase_UniswapV4DualSEBCPHook {
    function test_withV3FullSpread_bothDirectionsPay() public {
        SeMatrixFixture.Ctx memory ctx_ = SeMatrixFixture.Ctx({
            create3Factory: create3Factory,
            indexedexManager: IIndexedexManagerProxy(address(indexedexManager)),
            owner: owner,
            permit2: permit2,
            erc20Facet: erc20Facet,
            erc2612Facet: erc2612Facet,
            erc5267Facet: erc5267Facet,
            erc4626Facet: erc4626Facet,
            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
        });
        SeMatrix_FullSpreadV4Fixture v4_ = new SeMatrix_FullSpreadV4Fixture(ctx_, address(0));
        SeMatrix_FullSpreadV3Fixture v3_ = new SeMatrix_FullSpreadV3Fixture(ctx_, address(0));
        address face4_ = v4_.faceToken();
        address face3_ = v3_.faceToken();
        address se4_ = v4_.se();
        address se3_ = v3_.se();
        IDiamondPackageCallBackFactory diamond_ = create3Factory.diamondPackageFactory();
        IDualPackage.PkgArgs memory args_ = IDualPackage.PkgArgs({
            poolManager: address(v4_.poolManager()),
            feeOracle: address(indexedexManager),
            standardExchange0: se4_,
            token0: face4_,
            standardExchange1: se3_,
            token1: face3_,
            rateProvider0: RateProviderFixtureLib.providerFor(create3Factory, diamond_, se4_, face4_),
            rateProvider1: RateProviderFixtureLib.providerFor(create3Factory, diamond_, se3_, face3_)
        });
        hookPkg.processArgs(abi.encode(args_));
        uint256 nonce_ = DualFactory.findMineNonce(hookFactory, hookPkg, args_);
        address mixed_ = DualFactory.deployHook(hookPkg, args_, nonce_);
        _ensureProductDoorsAndFinalize(mixed_, face4_, face3_);
        v4_.fund(user, 1_000 ether);
        v3_.fund(user, 1_000 ether);
        vm.startPrank(user);
        IERC20(face4_).approve(mixed_, type(uint256).max);
        IERC20(face3_).approve(mixed_, type(uint256).max);
        IERC20(face4_).approve(se4_, 100 ether);
        IERC20(face3_).approve(se3_, 100 ether);
        (uint256 shares4_,) = IStandardExchangeIn(se4_).exchangeIn(
            IERC20(face4_), 100 ether, IERC20(se4_), 1, user, false, block.timestamp);
        (uint256 shares3_,) = IStandardExchangeIn(se3_).exchangeIn(
            IERC20(face3_), 100 ether, IERC20(se3_), 1, user, false, block.timestamp);
        IERC20(se4_).approve(mixed_, shares4_);
        IERC20(se3_).approve(mixed_, shares3_);
        bool v4First_ = face4_ < face3_;
        IDualHook(mixed_).depositFlexible(v4First_ ? shares4_ : shares3_, true,
            v4First_ ? shares3_ : shares4_, true, user, 1, block.timestamp + 1 hours);
        uint256 before3_ = IERC20(face3_).balanceOf(user);
        IStandardExchangeIn(mixed_).exchangeIn(IERC20(face4_), 1 ether, IERC20(face3_), 0, user, false, block.timestamp);
        assertGt(IERC20(face3_).balanceOf(user), before3_, "V4 face pays the V3 face");
        uint256 before4_ = IERC20(face4_).balanceOf(user);
        IStandardExchangeIn(mixed_).exchangeIn(IERC20(face3_), 1 ether, IERC20(face4_), 0, user, false, block.timestamp);
        assertGt(IERC20(face4_).balanceOf(user), before4_, "V3 face pays the V4 face");
        vm.stopPrank();
    }
}
