// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    UniswapV4DetfHookPremineLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookPremineLib.sol";
import {
    UniswapV4DetfHookStagedInitLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/UniswapV4DetfHookStagedInitLib.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";

import {
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETDFPkg,
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";

/**
 * @title TestBase_UniswapV4StandardExchangeOrbitalDETF
 * @notice Gold TestBase: production DFPkg via manager registry + real orbital hook via deployHookVault + SEs.
 *
 * Hook ABI checklist (frozen — do not invent methods):
 * - addLiquidity / removeLiquidity / previewAddLiquidity / previewRemoveLiquidity
 * - depositSingle / previewDepositSingle / isZapEligible
 * - effectiveReserve(i) / token0/1/2 / standardExchange(i)
 * - previewSwapExactIn / exchangeIn (SE facet)
 * - IERC20 LP on hook diamond
 *
 * Default config: 1 SE + bare (SE on pair0, bare pair1), DETF binding index 2.
 * Matrix helpers: free binding index, 2 SE, gentle/launch-rich expansion.
 */
abstract contract TestBase_UniswapV4StandardExchangeOrbitalDETF is
    TestBase_UniswapV4StandardExchangeOrbitalBufferHook
{
    using BetterEfficientHashLib for bytes;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;
    uint256 internal constant DEFAULT_CREATION = 1e18;

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal detfExchangeInFacet;
    IFacet internal detfBondingFacet;
    IFacet internal detfInfoFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721FacetDetf;

    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    IRebasingClaimTokenDFPkg internal rebasingClaimTokenPkg;
    IUniswapV4StandardExchangeOrbitalDETDFPkg internal detfPkg;

    address internal detf;
    IUniswapV4StandardExchangeOrbitalDETF internal detfInfo;
    IStandardExchangeIn internal detfExchangeIn;

    address internal detfUser = address(0xD37F);

    // Product legs after default deploy: pair0 = token0 (SE), pair1 = token1 (bare), DETF binding = 2
    address internal pair0;
    address internal pair1;

    function setUp() public virtual override {
        _setUpPlatform();
        detf = _deployDetfInstance(_defaultDetfArgs());
        UniswapV4DetfHookStagedInitLib.ensureReserveReadyOrbital(IUniswapV4StandardExchangeOrbitalDETF(detf));
        _bindDetfPointers();
    }

    function _setUpPlatform() internal {
        // Hook base: tokens, SEs, PM, hook factory, hookPkg, default raw-only hook.
        TestBase_UniswapV4StandardExchangeOrbitalBufferHook.setUp();

        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        detfExchangeInFacet =
            UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);
        detfBondingFacet =
            UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.deployBondingFacet(create3Factory);
        detfInfoFacet =
            UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.deployInfoFacet(create3Factory);

        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();

        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
    }

    function _bindDetfPointers() internal {
        detfInfo = IUniswapV4StandardExchangeOrbitalDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        pair0 = detfInfo.pairToken0();
        pair1 = detfInfo.pairToken1();

        // Fund user on both pair tokens
        SimpleMintableERC20(pair0).mint(detfUser, 10_000_000 ether);
        SimpleMintableERC20(pair1).mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        IERC20(pair0).approve(detf, type(uint256).max);
        IERC20(pair1).approve(detf, type(uint256).max);
        if (detfInfo.standardExchange0() != address(0)) {
            IERC20(pair0).approve(detfInfo.standardExchange0(), type(uint256).max);
        }
        if (detfInfo.standardExchange1() != address(0)) {
            IERC20(pair1).approve(detfInfo.standardExchange1(), type(uint256).max);
        }
        vm.stopPrank();

        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
    }

    function _deployRebasingClaimTokenPkg() internal {
        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        rebasingClaimTokenPkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );
        vm.label(address(rebasingClaimTokenPkg), "Uv4OrbDetf_RebasingClaimTokenPkg");
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721FacetDetf = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("Uv4OrbDetf_ERC721Facet"))
        );

        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721FacetDetf,
            erc4626BasicVaultFacet,
            erc4626StandardVaultFacet,
            detfNFTVaultFacet,
            IVaultFeeOracleQuery(address(indexedexManager)),
            IVaultRegistryDeployment(address(indexedexManager))
        );

        vm.startPrank(owner);
        bondNftVaultPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployDETFNFTVaultDFPkg(nftPkgInit);
        vm.stopPrank();
        vm.label(address(bondNftVaultPkg), "Uv4OrbDetf_BondNftVaultPkg");
    }

    function _deployDetfPkg() internal {
        IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgInit memory pkgInit = IUniswapV4StandardExchangeOrbitalDETDFPkg
            .PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: detfExchangeInFacet,
            bondingFacet: detfBondingFacet,
            infoFacet: detfInfoFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            poolManager: pm,
            hookPkg: hookPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        detfPkg = UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(detfPkg), "UniswapV4StandardExchangeOrbitalDETDFPkg");
    }

    /// @notice Default: 1 SE + bare; DETF binding index 2; pair0=token0+se0, pair1=token1 bare.
    function _defaultDetfArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory)
    {
        return IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs({
            name: "UniV4 Orbital SE DETF",
            symbol: "uv4orbDETF",
            pairToken0: IERC20(address(token0)),
            pairToken1: IERC20(address(token1)),
            standardExchange0: IStandardExchangeProxy(se0),
            standardExchange1: IStandardExchangeProxy(address(0)),
            vaultShare0: IERC20(address(0)),
            vaultShare1: IERC20(address(0)),
            rateProvider0: address(0),
            rateProvider1: address(0),
            rateAsset: IERC20(address(0)), // → pair0
            detfBindingIndex: 2,
            creationPair0PerDetfWad: DEFAULT_CREATION,
            creationPair1PerDetfWad: DEFAULT_CREATION,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            creator: address(0)
        });
    }

    function _gentleArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "Gentle Orb DETF";
        args.symbol = "gOrbDETF";
    }

    function _launchRichArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "LaunchRich Orb DETF";
        args.symbol = "lrOrbDETF";
        args.expansionClosureRatePerYearWad = 4.4e18;
    }

    function _openArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "Open Orb DETF";
        args.symbol = "oOrbDETF";
        args.thresholdMode = ThresholdMode.Open;
    }

    /// @dev Fresh CREATE3 salt per call — never redeploy the same PkgArgs name/symbol in one suite.
    function _openArgsUnique(string memory tag_)
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args = _openArgs();
        args.name = string(abi.encodePacked("Open Orb DETF ", tag_));
        args.symbol = string(abi.encodePacked("oO", tag_));
    }

    function _gentleArgsUnique(string memory tag_)
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args = _gentleArgs();
        args.name = string(abi.encodePacked("Gentle Orb DETF ", tag_));
        args.symbol = string(abi.encodePacked("gO", tag_));
    }

    function _twoSeArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "2SE Orb DETF";
        args.symbol = "2seOrb";
        args.standardExchange1 = IStandardExchangeProxy(se1);
    }

    function _freeBindingArgs(uint8 detfIdx_)
        internal
        view
        returns (IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "FreeBind Orb DETF";
        args.symbol = "fbOrb";
        args.detfBindingIndex = detfIdx_;
    }

    function _deployDetfInstance(IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
        internal
        returns (address detf_)
    {
        (address predicted_, uint256 nonce_) = UniswapV4DetfHookPremineLib.premineOrbital(
            diamondPackageFactory,
            hookFactory,
            detfPkg,
            hookPkg,
            args,
            address(pm),
            address(indexedexManager)
        );
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args, nonce_);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
    }

    function _deployDetfBootstrapOnly(IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
        internal
        returns (address)
    {
        return _deployDetfInstance(args);
    }

    function _deployDetfWired(IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
        internal
        returns (address detf_)
    {
        detf_ = _deployDetfInstance(args);
        UniswapV4DetfHookStagedInitLib.ensureReserveReadyOrbital(IUniswapV4StandardExchangeOrbitalDETF(detf_));
    }

    function _premineNonce(IUniswapV4StandardExchangeOrbitalDETDFPkg.PkgArgs memory args)
        internal
        view
        returns (uint256 nonce)
    {
        (, nonce) = UniswapV4DetfHookPremineLib.premineOrbital(
            diamondPackageFactory,
            hookFactory,
            detfPkg,
            hookPkg,
            args,
            address(pm),
            address(indexedexManager)
        );
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

    function _firstBondBothPairs(uint256 amount0_, uint256 amount1_)
        internal
        returns (uint256 tokenId, uint256 shares)
    {
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(pair0),
            amount0_,
            IERC20(pair1),
            amount1_,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _mintPair(address pair_, uint256 amount_) internal returns (uint256 userDetf) {
        vm.startPrank(detfUser);
        userDetf = detfExchangeIn.exchangeIn(
            IERC20(pair_),
            amount_,
            IERC20(detf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _burnToPair(address pairOut_, uint256 detfAmount_) internal returns (uint256 pairOutAmt) {
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, type(uint256).max);
        pairOutAmt = detfExchangeIn.exchangeIn(
            IERC20(detf),
            detfAmount_,
            IERC20(pairOut_),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _assertInert() internal view {
        assertFalse(detfInfo.isReserveLive(), "expected inert (not live)");
    }

    function _assertWired() internal view {
        assertTrue(detfInfo.isReserveWired(), "expected reserve wired");
        assertTrue(detfInfo.isReserveHookFinalized(), "expected hook finalized");
        assertTrue(detfInfo.bondNftVault() != address(0), "bond nft vault missing");
        assertTrue(detfInfo.rebasingClaimToken() != address(0), "claim token missing");
        assertFalse(detfInfo.isReserveLive(), "wired must still be inert");
    }

    function _assertLive() internal view {
        assertTrue(detfInfo.isReserveLive(), "expected reserve live");
        assertTrue(detfInfo.reserveHook() != address(0), "reserve hook missing");
        assertTrue(detfInfo.bondNftVault() != address(0), "bond nft vault missing");
    }

    /* ----------------------------- policy / book helpers ----------------------------- */

    function _dl() internal view returns (uint256) {
        return block.timestamp + 30 days;
    }

    /// @dev Fund + approve pair tokens for `who` against `detf_`.
    function _fundPairs(address detf_, address who, uint256 amt0, uint256 amt1) internal {
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(detf_);
        address p0 = info.pairToken0();
        address p1 = info.pairToken1();
        SimpleMintableERC20(p0).mint(who, amt0);
        SimpleMintableERC20(p1).mint(who, amt1);
        vm.startPrank(who);
        IERC20(p0).approve(detf_, type(uint256).max);
        IERC20(p1).approve(detf_, type(uint256).max);
        vm.stopPrank();
    }

    function _firstBondOn(address detf_, uint256 a0, uint256 a1)
        internal
        returns (uint256 tokenId, uint256 shares)
    {
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(detf_);
        _fundPairs(detf_, detfUser, a0 * 2, a1 * 2);
        vm.startPrank(detfUser);
        (tokenId, shares) = info.bond(
            IERC20(info.pairToken0()),
            a0,
            IERC20(info.pairToken1()),
            a1,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            _dl()
        );
        vm.stopPrank();
    }

    function _mintOn(address detf_, address pair_, uint256 amount_) internal returns (uint256 out_) {
        vm.startPrank(detfUser);
        IERC20(pair_).approve(detf_, type(uint256).max);
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            IERC20(pair_), amount_, IERC20(detf_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
    }

    function _burnOn(address detf_, address pairOut_, uint256 detfAmt_) internal returns (uint256 out_) {
        vm.startPrank(detfUser);
        IERC20(detf_).approve(detf_, type(uint256).max);
        out_ = IStandardExchangeIn(detf_).exchangeIn(
            IERC20(detf_), detfAmt_, IERC20(pairOut_), 0, detfUser, false, _dl()
        );
        vm.stopPrank();
    }

    /// @dev Donate pair0 capital into protocol LP holder via hook depositSingle (no DETF mint).
    function _donatePair0ToProtocolLp(IUniswapV4StandardExchangeOrbitalDETF info_, uint256 pairAmt_)
        internal
        returns (bool ok_)
    {
        address hook = info_.reserveHook();
        address p0 = info_.pairToken0();
        address holder = info_.bondNftVault() != address(0) ? info_.bondNftVault() : address(info_);
        if (!IUniswapV4StandardExchangeOrbitalBufferHook(hook).isZapEligible()) return false;
        SimpleMintableERC20(p0).mint(address(info_), pairAmt_);
        vm.startPrank(address(info_));
        IERC20(p0).approve(hook, type(uint256).max);
        try IUniswapV4StandardExchangeOrbitalBufferHook(hook).depositSingle(
            p0, pairAmt_, holder, 0, block.timestamp + 1 days, ""
        ) {
            ok_ = true;
        } catch {
            try IUniswapV4StandardExchangeOrbitalBufferHook(hook).depositSingle(
                p0, pairAmt_ / 20, holder, 0, block.timestamp + 1 days, ""
            ) {
                ok_ = true;
            } catch {
                ok_ = false;
            }
        }
        vm.stopPrank();
    }

    /// @dev Hard precondition: Policy mint is **blocked** (deadband or burn side: S ≤ mintThreshold).
    ///      After live first bond at ~peg this should already hold. If mint is open, dilute via free DETF
    ///      (mint while allowed + dual-bond free legs) until blocked. Never soft-skips.
    function _requireMintBlocked(IUniswapV4StandardExchangeOrbitalDETF info_) internal {
        require(info_.isReserveLive(), "live");
        require(uint8(info_.thresholdMode()) == uint8(ThresholdMode.Policy), "Policy only");

        if (info_.isMintingAllowed()) {
            address d = address(info_);
            address p0 = info_.pairToken0();
            // Dilute S: free DETF mint while mint-allowed, then dual-bond free legs.
            for (uint256 i; i < 40 && info_.isMintingAllowed(); ++i) {
                SimpleMintableERC20(p0).mint(detfUser, 50 ether);
                try this.mintExternal(d, p0, 50 ether) {} catch {
                    break;
                }
            }
            for (uint256 j; j < 25 && info_.isMintingAllowed(); ++j) {
                try this.bondDualExternal(d, 40 ether, 40 ether) {} catch {
                    break;
                }
            }
        }

        assertFalse(info_.isMintingAllowed(), "mint must be blocked (deadband or burn side)");
        assertLe(info_.syntheticPrice(), info_.mintThreshold(), "S <= mintThreshold");
    }

    /// @dev Drive debt-inclusive synthetic above mint threshold under Policy via donations (+ burns if allowed).
    function _pushSyntheticMintAllowed(IUniswapV4StandardExchangeOrbitalDETF info_) internal {
        require(info_.isReserveLive(), "live");
        if (info_.isMintingAllowed()) return;
        address d = address(info_);
        address p0 = info_.pairToken0();

        // Phase A: burn free DETF while burn-allowed (raises S by cutting supply).
        for (uint256 r; r < 12 && !info_.isMintingAllowed() && info_.isBurningAllowed(); ++r) {
            uint256 bal = IERC20(d).balanceOf(detfUser);
            if (bal == 0) break;
            uint256 burnAmt = bal / 5;
            if (burnAmt == 0) burnAmt = bal;
            try this.burnExternal(d, p0, burnAmt) {} catch {
                break;
            }
        }
        if (info_.isMintingAllowed()) return;

        // Phase B: donate pair capital into protocol LP (raises FD without supply).
        for (uint256 i; i < 40 && !info_.isMintingAllowed(); ++i) {
            bool ok = _donatePair0ToProtocolLp(info_, 20 ether * (i + 1));
            if (!ok) {
                ok = _donatePair0ToProtocolLp(info_, 5 ether);
            }
            if (!ok) break;
        }
        require(info_.isMintingAllowed(), "could not open Policy mint (S > mintThreshold)");
    }

    /// @dev Drive synthetic below burn threshold under Policy (dilute via free DETF if mintable, else first-bond free legs).
    function _pushSyntheticBurnAllowed(IUniswapV4StandardExchangeOrbitalDETF info_) internal {
        require(info_.isReserveLive(), "live");
        if (info_.isBurningAllowed()) return;
        address d = address(info_);
        address p0 = info_.pairToken0();

        // Mint free DETF while mint-allowed (dilutes S).
        for (uint256 i; i < 30 && !info_.isBurningAllowed() && info_.isMintingAllowed(); ++i) {
            SimpleMintableERC20(p0).mint(detfUser, 50 ether);
            try this.mintExternal(d, p0, 50 ether) {} catch {
                break;
            }
        }
        if (info_.isBurningAllowed()) return;

        // More dual bonds mint free legs outside pool (dilution).
        for (uint256 j; j < 10 && !info_.isBurningAllowed(); ++j) {
            try this.bondDualExternal(d, 30 ether, 30 ether) {} catch {
                break;
            }
        }
        require(info_.isBurningAllowed(), "could not open Policy burn (S < burnThreshold)");
    }

    /// @dev External wrappers for try/catch from helpers.
    function mintExternal(address d, address pair_, uint256 amt) external returns (uint256) {
        return _mintOn(d, pair_, amt);
    }

    function burnExternal(address d, address pairOut_, uint256 amt) external returns (uint256) {
        return _burnOn(d, pairOut_, amt);
    }

    function bondDualExternal(address d, uint256 a0, uint256 a1) external returns (uint256 tokenId, uint256 shares) {
        IUniswapV4StandardExchangeOrbitalDETF info = IUniswapV4StandardExchangeOrbitalDETF(d);
        if (!info.isReserveLive()) {
            return _firstBondOn(d, a0, a1);
        }
        _fundPairs(d, detfUser, a0 * 2, a1 * 2);
        vm.startPrank(detfUser);
        (tokenId, shares) = info.bond(
            IERC20(info.pairToken0()),
            a0,
            IERC20(info.pairToken1()),
            a1,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            _dl()
        );
        vm.stopPrank();
    }

    /// @dev Drain redeemable hook LP so only MINIMUM_LIQUIDITY remains → isZapEligible=false.
    ///      Requires a **unique** Open instance (no shared CREATE3 salt with other deploys).
    function _drainToMinLiquidityOnly(IUniswapV4StandardExchangeOrbitalDETF info_, uint256 bondTokenId)
        internal
    {
        address hook = info_.reserveHook();
        address d = address(info_);
        address p0 = info_.pairToken0();
        address p1 = info_.pairToken1();
        address bond = info_.bondNftVault();

        // Mature-close user bond (pulls this position's LP, removes, redeposits DETF → protocol LP).
        uint256 unlock = IDETFNFTVault(bond).unlockTimeOf(bondTokenId);
        if (block.timestamp < unlock) vm.warp(unlock + 1);
        uint256 principal = IDETFNFTVault(bond).originalSharesOf(bondTokenId);
        uint256 bondLpBefore = IERC20(hook).balanceOf(bond);
        vm.prank(detfUser);
        info_.closeBondMature(bondTokenId, _minOut3(), detfUser, block.timestamp + 1 hours);
        // Position principal must leave the bond vault (unique instance: full drain).
        uint256 bondLpAfter = IERC20(hook).balanceOf(bond);
        assertLe(bondLpAfter, bondLpBefore - principal, "bond principal not pulled on close");
        // Unique first-bond-only instance: no other positions → bond empty of this hook LP.
        if (bondLpBefore == principal) {
            assertEq(bondLpAfter, 0, "bond LP drained after close (sole position)");
        }

        // Burn free DETF to drain protocol LP toward MINIMUM_LIQUIDITY.
        // Redeposit returns DETF as LP but pair capital leaves → net supply shrinks each burn.
        for (uint256 i; i < 100; ++i) {
            if (!IUniswapV4StandardExchangeOrbitalBufferHook(hook).isZapEligible()) break;
            uint256 supply = IERC20(hook).totalSupply();
            if (supply <= 1000 + 1e12) break;
            uint256 proto = IERC20(hook).balanceOf(bond);
            if (proto == 0) break;
            if (!info_.isBurningAllowed() && info_.thresholdMode() == ThresholdMode.Policy) break;

            uint256 bal = IERC20(d).balanceOf(detfUser);
            if (bal == 0) {
                // Seed free DETF (Open burn is ungated) so we can keep draining protocol LP.
                // deal free DETF is a test harness control — burn still hits production path.
                deal(d, detfUser, proto > 1e18 ? proto : 10 ether);
                bal = IERC20(d).balanceOf(detfUser);
                if (bal == 0) break;
            }
            uint256 burnAmt = bal;
            try this.burnExternal(d, p1, burnAmt) {} catch {
                try this.burnExternal(d, p0, burnAmt) {} catch {
                    burnAmt = bal / 4;
                    if (burnAmt == 0) break;
                    try this.burnExternal(d, p1, burnAmt) {} catch {
                        break;
                    }
                }
            }
        }
        // Hard surface: if still zap-eligible, force one reserve-empty path is not available in v1;
        // require drain succeeded for NotZap tests.
        if (IUniswapV4StandardExchangeOrbitalBufferHook(hook).isZapEligible()) {
            // Final attempt: burn entire free DETF supply-sized chunks until empty protocol or revert.
            for (uint256 k; k < 30 && IUniswapV4StandardExchangeOrbitalBufferHook(hook).isZapEligible(); ++k) {
                uint256 proto2 = IERC20(hook).balanceOf(bond);
                if (proto2 == 0) break;
                deal(d, detfUser, proto2 + 1 ether);
                try this.burnExternal(d, p1, IERC20(d).balanceOf(detfUser)) {} catch {
                    try this.burnExternal(d, p0, IERC20(d).balanceOf(detfUser) / 2) {} catch {
                        break;
                    }
                }
            }
        }
    }

    function _minOut3() internal pure returns (uint256[] memory m_) {
        m_ = new uint256[](3);
    }

    function _bondNftVault(address instance_) internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(IUniswapV4StandardExchangeOrbitalDETF(instance_).bondNftVault());
    }

    function _feeTo() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _weightsFC(address instance_) internal view returns (uint256 f_, uint256 c_) {
        (, f_, c_) = IVaultFeeOracleQuery(address(indexedexManager)).seigniorageSplitOfVault(instance_);
    }

    function _claim(uint256 tokenId_, address to_) internal returns (uint256 claimed_) {
        IDETFNFTVault vault_ = _bondNftVault(detf);
        vm.prank(to_);
        claimed_ = vault_.claimRewards(tokenId_, to_);
    }

    function _potBalance() internal view returns (uint256) {
        return IERC20(detf).balanceOf(address(_bondNftVault(detf)));
    }
}

