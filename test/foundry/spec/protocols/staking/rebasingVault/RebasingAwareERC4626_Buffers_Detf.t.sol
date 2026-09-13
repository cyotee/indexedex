// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage} from
    "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4StandardExchangeWeightedBufferHookPackage as IWeightedPkg} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WeightedFactory
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {HookPkgArgsDecimalsLib} from "contracts/test/libs/HookPkgArgsDecimalsLib.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";
import {RebasingAwareERC4626_Component_FactoryService} from
    "contracts/protocols/staking/rebasingVault/RebasingAwareERC4626_Component_FactoryService.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {RebasingERC20Harness} from "contracts/test/stubs/RebasingERC20Harness.sol";

abstract contract TestBase_RebasingAwareDetfComposition is TestBase_UniswapV4Detf {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    function _fundWrap(IERC4626 w, uint256 assets) internal {
        RebasingERC20Harness(w.asset()).mint(detfUser, assets * 2);
        vm.startPrank(detfUser);
        IERC20(w.asset()).approve(address(w), type(uint256).max);
        w.deposit(assets, detfUser);
        vm.stopPrank();
    }

    function _deployCpWrapperDetf(IERC4626 w) internal returns (address wDetf) {
        IUniswapV4Detf.PkgArgs memory args = _defaultDetfArgs();
        args.name = "Wrap CP DETF";
        args.symbol = "wCPDETF";
        address predicted = _predictDetf(args);
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: address(w),
                pairToken: address(w),
                rawToken: predicted,
                pairTokenDecimals: IERC20Metadata(address(w)).decimals(),
                rawTokenDecimals: 9,
                ownerOnlyLiquidity: args.ownerOnlyLiquidity,
                owner: predicted
            });
        uint256 mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
        address wHook = CpHookFactory.deployHook(hookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(wHook);
        init.deployPair(predicted, address(w));
        require(init.finalizeInitialization(), "finalize");
        args.hook = wHook;
        vm.prank(owner);
        wDetf = detfPkg.deployVault(args);
        require(wDetf == predicted, "detf != predicted");
    }

    function _bondOnly(IERC4626 w, address wDetf) internal returns (uint256 bondId) {
        IUniswapV4Detf info = IUniswapV4Detf(wDetf);
        uint8 d = IERC20Metadata(address(w)).decimals();
        vm.startPrank(detfUser);
        IERC20(address(w)).approve(wDetf, type(uint256).max);
        (uint256 tokenId, uint256 shares) =
            info.bond(IERC20(address(w)), 100 * (10 ** d), DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        bondId = tokenId;
        assertGt(tokenId, 0, "bond id");
        assertGt(shares, 0, "bond lp");
        assertTrue(info.isReserveLive(), "reserve live");
    }

    function _mintRedeem(IERC4626 w, address wDetf) internal {
        uint8 d = IERC20Metadata(address(w)).decimals();
        vm.startPrank(detfUser);
        uint256 minted = IStandardExchangeIn(wDetf).exchangeIn(
            IERC20(address(w)), 10 * (10 ** d), IERC20(wDetf), 0, detfUser, false, block.timestamp + 1 hours
        );
        assertGt(minted, 0, "minted");
        IERC20(wDetf).approve(wDetf, minted);
        uint256 redeemed = IStandardExchangeIn(wDetf).exchangeIn(
            IERC20(wDetf), minted, IERC20(address(w)), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(redeemed, 0, "redeemed");
    }

    function _deployWrapper(bytes32 salt) internal returns (IERC4626) {
        IFacet erc4626F = create3Factory.deployRebasingAwareERC4626Facet();
        IFacet seF = create3Factory.deployRebasingAwareStandardExchangeFacet();
        IFacet syF = create3Factory.deployRebasingAwareStandardYieldFacet();
        IFacet metaF = create3Factory.deployRebasingAwareVaultMetadataFacet();
        IFacet quoteF = create3Factory.deployRebasingAwareStandardExchangeQuoteFacet();
        vm.prank(owner);
        IRebasingAwareERC4626DFPkg wpkg = RebasingAwareERC4626_Component_FactoryService
            .deployRebasingAwareERC4626DFPkg(
            indexedexManager,
            IRebasingAwareERC4626DFPkg.PkgInit({
                erc20Facet: erc20Facet,
                rebasingAwareErc4626Facet: erc4626F,
                diamondFactory: diamondPackageFactory,
                standardExchangeFacet: seF,
                standardYieldFacet: syF,
                vaultMetadataFacet: metaF,
                transitionQuoteFacet: quoteF,
                vaultRegistry: IVaultRegistryDeployment(address(indexedexManager))
            })
        );
        RebasingERC20Harness underlying = new RebasingERC20Harness("Rebase", "RBS", 18);
        return wpkg.deployVault(IERC20Metadata(address(underlying)), 10, salt);
    }
}

contract RebasingAwareERC4626_Buffers_Detf is TestBase_RebasingAwareDetfComposition {
    function test_F16_cpDetfMintRedeemWrapperShareReserve() public {
        IERC4626 w = _deployWrapper(bytes32(uint256(41)));
        _fundWrap(w, 1_000e18);
        address wDetf = _deployCpWrapperDetf(w);
        _bondOnly(w, wDetf);
        _mintRedeem(w, wDetf);
    }

}

contract RebasingAwareERC4626_Buffers_Detf_Weighted is TestBase_UniswapV4Detf_Weighted {
    using RebasingAwareERC4626_Component_FactoryService for ICreate3FactoryProxy;

    function test_F16_weightedDetfMintRedeemWrapperShareLeg() public {
        IERC4626 w = _deployWeightedWrapper();
        address wDetf = _deployWeightedWrapperDetf(w);
        _weightedBondMintRedeem(w, wDetf);
    }

    function _deployWeightedWrapper() internal returns (IERC4626 w) {
        IFacet erc4626F = create3Factory.deployRebasingAwareERC4626Facet();
        IFacet seF = create3Factory.deployRebasingAwareStandardExchangeFacet();
        IFacet syF = create3Factory.deployRebasingAwareStandardYieldFacet();
        IFacet metaF = create3Factory.deployRebasingAwareVaultMetadataFacet();
        IFacet quoteF = create3Factory.deployRebasingAwareStandardExchangeQuoteFacet();
        vm.prank(owner);
        IRebasingAwareERC4626DFPkg wpkg = RebasingAwareERC4626_Component_FactoryService
            .deployRebasingAwareERC4626DFPkg(
            indexedexManager,
            IRebasingAwareERC4626DFPkg.PkgInit({
                erc20Facet: erc20Facet,
                rebasingAwareErc4626Facet: erc4626F,
                diamondFactory: diamondPackageFactory,
                standardExchangeFacet: seF,
                standardYieldFacet: syF,
                vaultMetadataFacet: metaF,
                transitionQuoteFacet: quoteF,
                vaultRegistry: IVaultRegistryDeployment(address(indexedexManager))
            })
        );
        RebasingERC20Harness underlying = new RebasingERC20Harness("Rebase", "RBS", 18);
        w = wpkg.deployVault(IERC20Metadata(address(underlying)), 10, bytes32(uint256(42)));
        underlying.mint(detfUser, 2_000e18);
        vm.startPrank(detfUser);
        underlying.approve(address(w), type(uint256).max);
        w.deposit(1_000e18, detfUser);
        vm.stopPrank();
    }

    function _deployWeightedWrapperDetf(IERC4626 w) internal returns (address wDetf) {
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        args.name = "Wrap W DETF";
        args.symbol = "wWDETF";
        address predicted = _predictDetf(args);
        address[] memory toks = new address[](3);
        toks[0] = predicted;
        toks[1] = address(w);
        toks[2] = address(pair1);
        _sortInPlace(toks);
        uint256[] memory weights = new uint256[](3);
        weights[0] = 4e17;
        weights[1] = 3e17;
        weights[2] = 3e17;
        address[] memory ses = new address[](3);
        address[] memory rps = new address[](3);
        for (uint256 i; i < 3; ++i) {
            if (toks[i] == predicted) ses[i] = address(0);
            else if (toks[i] == address(w)) ses[i] = address(w);
            else ses[i] = se1;
        }
        IWeightedPkg.PkgArgs memory hArgs = IWeightedPkg.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            n: 3,
            tokens: toks,
            weights: weights,
            standardExchanges: ses,
            rateProviders: rps,
            tokenDecimals: HookPkgArgsDecimalsLib.tokenDecimals(toks, predicted),
            seDecimals: HookPkgArgsDecimalsLib.seDecimals(ses),
            ownerOnlyLiquidity: args.ownerOnlyLiquidity,
            owner: predicted
        });
        uint256 mineNonce = WeightedFactory.findMineNonce(hookFactory, weightedHookPkg, hArgs);
        address wHook = WeightedFactory.deployHook(weightedHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(wHook);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[1], toks[2]);
        require(init.finalizeInitialization(), "finalize");
        args.hook = wHook;
        vm.prank(owner);
        wDetf = detfPkg.deployVault(args);
        require(wDetf == predicted, "detf != predicted");
    }

    function _weightedBondMintRedeem(IERC4626 w, address wDetf) internal {
        IUniswapV4Detf info = IUniswapV4Detf(wDetf);
        uint8 d = IERC20Metadata(address(w)).decimals();
        pair1.mint(detfUser, 10_000 ether);
        vm.startPrank(detfUser);
        IERC20(address(w)).approve(wDetf, type(uint256).max);
        pair1.approve(wDetf, type(uint256).max);
        (uint256 tokenId, uint256 lp) =
            info.bond(IERC20(address(w)), 100 * (10 ** d), DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertGt(tokenId, 0);
        assertGt(lp, 0);
        assertTrue(info.isReserveLive());

        vm.startPrank(detfUser);
        uint256 minted = IStandardExchangeIn(wDetf).exchangeIn(
            IERC20(address(w)), 10 * (10 ** d), IERC20(wDetf), 0, detfUser, false, block.timestamp + 1 hours
        );
        assertGt(minted, 0);
        IERC20(wDetf).approve(wDetf, minted);
        uint256 redeemed = IStandardExchangeIn(wDetf).exchangeIn(
            IERC20(wDetf), minted, IERC20(address(w)), 0, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(redeemed, 0);
    }
}
