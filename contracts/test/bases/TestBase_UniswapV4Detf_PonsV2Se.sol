// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4HookDiamondPackageCallBackFactory
} from "contracts/hooks/uniswap/v4/factory/interfaces/IUniswapV4HookDiamondPackageCallBackFactory.sol";
import {
    UniswapV4HookDiamondPackageCallBackFactory_FactoryService as HookFactoryService
} from "contracts/hooks/uniswap/v4/factory/UniswapV4HookDiamondPackageCallBackFactory_FactoryService.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as CpHookFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_Facet_FactoryService} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Facet_FactoryService.sol";
import {UniswapV4Detf_Pkg_FactoryService} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol";
import {
    TestBase_UniswapV4StandardExchange_PonsV2
} from "contracts/test/bases/TestBase_UniswapV4StandardExchange_PonsV2.sol";

/**
 * @title TestBase_UniswapV4Detf_PonsV2Se
 * @notice Unified UniswapV4DetfDFPkg whose bound SE is the pons v2 graduated Uni V4 vault.
 *         Same PoolManager. Hook pair / mintToken is the pons v2 launch token (R-5).
 */
abstract contract TestBase_UniswapV4Detf_PonsV2Se is TestBase_UniswapV4StandardExchange_PonsV2 {
    using BetterEfficientHashLib for bytes;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;
    uint256 internal constant DEFAULT_CREATION_PAIR_PER_DETF = 1e18;

    IUniswapV4HookDiamondPackageCallBackFactory internal hookFactory;
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage internal hookPkg;
    address internal reserveHook;

    IFacet internal detfProductFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721FacetDetf;
    IUniswapV4DetfBondNFTVaultDFPkg internal bondNftVaultPkg;
    IRebasingClaimTokenDFPkg internal rebasingClaimTokenPkg;
    IUniswapV4DetfDFPkg internal detfPkg;

    address internal detf;
    IUniswapV4Detf internal detfInfo;
    IStandardExchangeIn internal detfExchangeIn;
    address internal detfUser = address(0xD37F);

    function setUp() public virtual override {
        TestBase_UniswapV4StandardExchange_PonsV2.setUp();

        _deployHookFactoryAndCpPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployHookThenDetf(_defaultDetfArgs());
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        _wrapWeth(detfUser, 10_000 ether);
        uint256 launchBal_ = IERC20(launchToken).balanceOf(address(this));
        if (launchBal_ > 1 ether) {
            IERC20(launchToken).transfer(detfUser, launchBal_ / 2);
        }
        vm.startPrank(detfUser);
        IERC20(launchToken).approve(detf, type(uint256).max);
        IERC20(launchToken).approve(address(ponsSe), type(uint256).max);
        IERC20(address(weth)).approve(detf, type(uint256).max);
        IERC20(address(weth)).approve(address(ponsSe), type(uint256).max);
        IERC20(address(ponsSe)).approve(detf, type(uint256).max);
        vm.stopPrank();
    }

    function _deployHookFactoryAndCpPkg() internal {
        IFacet hookFlagsFacet = HookFactoryService.deployUniswapV4HookFlagsFacet(create3Factory);
        IFacetRegistry facetReg = IFacetRegistry(address(create3Factory));
        hookFactory = HookFactoryService.deployUniswapV4HookDiamondPackageCallBackFactory(
            create3Factory,
            IUniswapV4HookDiamondPackageCallBackFactory.InitArgs({
                erc165Facet: facetReg.canonicalFacet(type(IERC165).interfaceId),
                diamondLoupeFacet: facetReg.canonicalFacet(type(IDiamondLoupe).interfaceId),
                erc8109IntrospectionFacet: facetReg.canonicalFacet(type(IERC8109Introspection).interfaceId),
                postDeployHookFacet: facetReg.canonicalFacet(type(IPostDeployAccountHook).interfaceId),
                hookFlagsFacet: hookFlagsFacet
            })
        );
        vm.prank(owner);
        IVaultRegistryDeployment(address(indexedexManager)).setHookDiamondPackageFactory(address(hookFactory));

        IFacet seFacet = CpHookFactory.deploySeFacet(create3Factory);
        IFacet depositFacet = CpHookFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = CpHookFactory.deployWithdrawFacet(create3Factory);
        hookPkg = CpHookFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                seFacet: seFacet,
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(type(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage).name, "pons")._hash()
        );
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployUniswapV4DetfBondNFTVaultFacet();
        erc721FacetDetf = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("PonsUv4Detf_ERC721Facet"))
        );
        IUniswapV4DetfBondNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService
            .buildUniswapV4DetfBondNFTVaultPkgInit(
            erc721FacetDetf,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );
        vm.startPrank(owner);
        bondNftVaultPkg = IVaultRegistryDeployment(address(indexedexManager))
            .deployUniswapV4DetfBondNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();
    }

    function _deployRebasingClaimTokenPkg() internal {
        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        rebasingClaimTokenPkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );
    }

    function _deployDetfPkg() internal {
        detfProductFacet = UniswapV4Detf_Facet_FactoryService.deployUniswapV4DetfFacet(create3Factory);
        IUniswapV4DetfDFPkg.PkgInit memory pkgInit = IUniswapV4DetfDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            productFacet: detfProductFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg
        });
        vm.startPrank(owner);
        detfPkg = UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
    }

    function _defaultDetfArgs() internal view returns (IUniswapV4Detf.PkgArgs memory args) {
        uint256[] memory creation_ = new uint256[](1);
        creation_[0] = DEFAULT_CREATION_PAIR_PER_DETF;
        args = IUniswapV4Detf.PkgArgs({
            name: "Pons V2 SE UniV4 DETF",
            symbol: "ponsUv4DETF",
            hook: address(0),
            creationPairPerDetfWad: creation_,
            openingPairPerDetfWad: new uint256[](0),
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Open,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            creator: address(0),
            claimName: "",
            claimSymbol: "",
            bondName: "",
            bondSymbol: "",
            mintRouteMode: IUniswapV4Detf.RouteTableMode.Default,
            mintRoutes: new IUniswapV4Detf.IoRoute[](0),
            burnRouteMode: IUniswapV4Detf.RouteTableMode.Default,
            burnRoutes: new IUniswapV4Detf.IoRoute[](0),
            bondRouteMode: IUniswapV4Detf.RouteTableMode.Default,
            bondRoutes: new IUniswapV4Detf.IoRoute[](0),
            closeRouteMode: IUniswapV4Detf.RouteTableMode.Default,
            closeRoutes: new IUniswapV4Detf.IoRoute[](0),
            donateRouteMode: IUniswapV4Detf.RouteTableMode.Default,
            donateRoutes: new IUniswapV4Detf.IoRoute[](0)
        });
    }

    function _predictDetf(IUniswapV4Detf.PkgArgs memory args) internal view returns (address) {
        IUniswapV4Detf.PkgArgs memory saltArgs_ = args;
        saltArgs_.hook = address(0);
        return diamondPackageFactory.calcAddress(
            IDiamondFactoryPackage(address(detfPkg)), abi.encode(saltArgs_)
        );
    }

    function _deployHookThenDetf(IUniswapV4Detf.PkgArgs memory args) internal returns (address detf_) {
        address predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(weth).code);
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(poolManager),
                feeOracle: address(indexedexManager),
                standardExchange: address(ponsSe),
                pairToken: launchToken,
                rawToken: predicted_,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
        reserveHook = CpHookFactory.deployHook(hookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(predicted_, launchToken);
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted_, "");
        args.hook = reserveHook;
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
        vm.label(reserveHook, "ponsReserveHook");
    }

    function _setDefaultBondTerms(uint256 minLock_, uint256 maxLock_) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager)).setDefaultBondTerms(
            BondTerms({
                minLockDuration: minLock_,
                maxLockDuration: maxLock_,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
        vm.stopPrank();
    }

    function _setBondTerms(uint256 minLock_, uint256 maxLock_) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(
            detf,
            BondTerms({
                minLockDuration: minLock_,
                maxLockDuration: maxLock_,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
        vm.stopPrank();
    }

    function _firstBond(uint256 pairAmount_) internal returns (uint256 tokenId, uint256 shares) {
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(launchToken),
            pairAmount_,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _boundSe() internal view returns (address) {
        return IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(launchToken);
    }

    /// @dev First non-DETF `hook.tokens()` entry after finalize (pons v2 launch token).
    function _mintToken() internal view returns (address t) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) return toks[i];
        }
        revert("no mintToken");
    }

    function _assertSeAllowancesZero() internal view {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            address se_ = IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(toks[i]);
            if (se_ != address(0)) {
                assertEq(IERC20(se_).allowance(reserveHook, se_), 0, "SE allowance(hook, se)==0");
            }
        }
    }

    function _assertR19() internal {
        address hook_ = detfInfo.hook();
        address[] memory toks = IUniswapV4SeBufferHook(hook_).tokens();
        bool needSweep = IERC20(hook_).balanceOf(detf) > 0;
        for (uint256 i; i < toks.length; ++i) {
            if (IERC20(toks[i]).balanceOf(detf) > 0) needSweep = true;
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(toks[i]);
            if (se_ != address(0) && IERC20(se_).balanceOf(detf) > 0) needSweep = true;
        }
        if (needSweep) detfInfo.sweepDust();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "R19 hook LP");
        for (uint256 i; i < toks.length; ++i) {
            uint256 bal = IERC20(toks[i]).balanceOf(detf);
            if (bal > 10) {
                _logR19JoinFailure(hook_, toks[i], bal);
                assertLe(bal, 10, string.concat("R19 token after sweep ", vm.toString(toks[i])));
            }
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(toks[i]);
            if (se_ != address(0)) {
                uint256 seBal = IERC20(se_).balanceOf(detf);
                if (seBal > 10) {
                    emit log_named_address("R19 leftover SE", se_);
                    emit log_named_uint("R19 leftover SE bal", seBal);
                }
                assertLe(seBal, 10, "R19 SE share");
            }
        }
    }

    function _logR19JoinFailure(address hook_, address token_, uint256 bal_) internal {
        emit log_named_address("R19 leftover token", token_);
        emit log_named_uint("R19 leftover is DETF", token_ == detf ? 1 : 0);
        emit log_named_uint("R19 leftover is WETH", token_ == address(weth) ? 1 : 0);
        emit log_named_uint("R19 leftover bal", bal_);
        try IUniswapV4SeBufferHook(hook_).previewJoinSingleAssetExactIn(token_, bal_) returns (uint256 p) {
            emit log_named_uint("R19 previewJoin", p);
        } catch (bytes memory err) {
            if (err.length >= 4) emit log_named_bytes32("R19 join revert", bytes32(err));
        }
        address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(token_);
        if (se_ != address(0)) {
            try IStandardExchangeIn(se_).previewExchangeIn(IERC20(token_), bal_, IERC20(se_)) returns (uint256 w) {
                emit log_named_uint("R19 sePreview wrap", w);
            } catch (bytes memory err2) {
                if (err2.length >= 4) emit log_named_bytes32("R19 wrap revert", bytes32(err2));
            }
        }
    }
}
