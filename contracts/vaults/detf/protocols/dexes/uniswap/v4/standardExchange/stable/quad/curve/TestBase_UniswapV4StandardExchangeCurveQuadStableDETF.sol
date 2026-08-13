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
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
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
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg,
    IUniswapV4StandardExchangeCurveQuadStableDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";

/**
 * @title TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
 * @notice Production-first TestBase: DFPkg via manager registry + real Curve Quad hook via deployHookVault.
 *
 * Phase 0 decisions (recorded):
 * - Exact-out mint/burn: InvalidRoute (burn invert not closed-form).
 * - joinUnbalanced DETF-only + zeros: hook skips zero legs after first mint / full book.
 *
 * Default: 1 SE + 2 bare, Policy, creation 1e18, baseAmp=100.
 */
abstract contract TestBase_UniswapV4StandardExchangeCurveQuadStableDETF is
    TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook
{
    using BetterEfficientHashLib for bytes;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;
    uint256 internal constant DEFAULT_CREATION = 1e18;

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal detfExchangeInFacet;
    IFacet internal detfBondingFacet;
    IFacet internal detfCompoundFacet;
    IFacet internal detfInfoFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721FacetDetf;

    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    IRebasingClaimTokenDFPkg internal rebasingClaimTokenPkg;
    IUniswapV4StandardExchangeCurveQuadStableDETDFPkg internal detfPkg;

    address internal detf;
    IUniswapV4StandardExchangeCurveQuadStableDETF internal detfInfo;
    IStandardExchangeIn internal detfExchangeIn;

    address internal detfUser = address(0xD37F);
    address internal pair0;
    address internal pair1;
    address internal pair2;

    function setUp() public virtual override {
        TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.setUp();

        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        detfExchangeInFacet =
            UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);
        detfBondingFacet =
            UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.deployBondingFacet(create3Factory);
        detfCompoundFacet =
            UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.deployCompoundFacet(create3Factory);
        detfInfoFacet =
            UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.deployInfoFacet(create3Factory);

        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();

        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployDetfInstance(_defaultDetfArgs());
        detfInfo = IUniswapV4StandardExchangeCurveQuadStableDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        pair0 = detfInfo.pairToken(0);
        pair1 = detfInfo.pairToken(1);
        pair2 = detfInfo.pairToken(2);

        SimpleMintableERC20(pair0).mint(detfUser, 10_000_000 ether);
        SimpleMintableERC20(pair1).mint(detfUser, 10_000_000 ether);
        SimpleMintableERC20(pair2).mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        IERC20(pair0).approve(detf, type(uint256).max);
        IERC20(pair1).approve(detf, type(uint256).max);
        IERC20(pair2).approve(detf, type(uint256).max);
        if (detfInfo.standardExchange(0) != address(0)) {
            IERC20(pair0).approve(detfInfo.standardExchange(0), type(uint256).max);
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
        vm.label(address(rebasingClaimTokenPkg), "Uv4QuadDetf_RebasingClaimTokenPkg");
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721FacetDetf = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("Uv4QuadDetf_ERC721Facet"))
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
        vm.label(address(bondNftVaultPkg), "Uv4QuadDetf_BondNftVaultPkg");
    }

    function _deployDetfPkg() internal {
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgInit memory pkgInit =
        IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: detfExchangeInFacet,
            bondingFacet: detfBondingFacet,
            compoundFacet: detfCompoundFacet,
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
        detfPkg = UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(detfPkg), "UniswapV4StandardExchangeCurveQuadStableDETDFPkg");
    }

    /// @notice Default: 1 SE + 2 bare, Policy, baseAmp=100.
    function _defaultDetfArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory)
    {
        return _argsSeMask(1);
    }

    function _argsSeMask(uint8 seCount)
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        IERC20[] memory pairs_ = new IERC20[](3);
        pairs_[0] = IERC20(address(token0));
        pairs_[1] = IERC20(address(token1));
        pairs_[2] = IERC20(address(token2));
        IStandardExchangeProxy[] memory ses_ = new IStandardExchangeProxy[](3);
        address[] memory sesAll = new address[](3);
        sesAll[0] = se0;
        sesAll[1] = se1;
        sesAll[2] = se2;
        for (uint8 i; i < seCount && i < 3; ++i) {
            ses_[i] = IStandardExchangeProxy(sesAll[i]);
        }
        IERC20[] memory shares_ = new IERC20[](3);
        address[] memory rps_ = new address[](3);
        uint256[] memory rates_ = new uint256[](3);
        rates_[0] = DEFAULT_CREATION;
        rates_[1] = DEFAULT_CREATION;
        rates_[2] = DEFAULT_CREATION;

        args = IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs({
            name: "UniV4 Quad Stable DETF",
            symbol: "uv4qDETF",
            pairTokens: pairs_,
            standardExchanges: ses_,
            vaultShares: shares_,
            rateProviders: rps_,
            creationPairPerDetfWad: rates_,
            baseAmp: DEFAULT_BASE_AMP,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            hookMineNonce: 0
        });
    }

    function _args1Se2Bare()
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory)
    {
        return _argsSeMask(1);
    }

    function _args2Se1Bare()
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args = _argsSeMask(2);
        args.name = "Quad 2SE";
        args.symbol = "q2se";
    }

    function _args3Se()
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args = _argsSeMask(3);
        args.name = "Quad 3SE";
        args.symbol = "q3se";
    }

    function _argsAllBare()
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args = _argsSeMask(0);
        args.name = "AllBare";
        args.symbol = "bare";
    }

    function _openArgs()
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "Open Quad DETF";
        args.symbol = "oQDETF";
        args.thresholdMode = ThresholdMode.Open;
    }

    function _openArgsUnique(string memory tag_)
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args = _openArgs();
        args.name = string(abi.encodePacked("Open Quad DETF ", tag_));
        args.symbol = string(abi.encodePacked("oQ", tag_));
    }

    function _gentleArgsUnique(string memory tag_)
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = string(abi.encodePacked("Gentle Quad DETF ", tag_));
        args.symbol = string(abi.encodePacked("gQ", tag_));
    }

    function _launchRichArgsUnique(string memory tag_)
        internal
        view
        returns (IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
    {
        args = _gentleArgsUnique(tag_);
        args.name = string(abi.encodePacked("LaunchRich Quad ", tag_));
        args.symbol = string(abi.encodePacked("lrQ", tag_));
        args.expansionClosureRatePerYearWad = 4.4e18;
    }

    function _deployDetfInstance(IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.PkgArgs memory args)
        internal
        returns (address detf_)
    {
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args));
        vm.stopPrank();
        vm.label(detf_, args.symbol);
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

    function _setBondTermsFor(address vault_) internal {
        vm.startPrank(owner);
        try IVaultFeeOracleManager(address(indexedexManager)).setVaultBondTerms(
            vault_,
            BondTerms({
                minLockDuration: DEFAULT_MIN_LOCK,
                maxLockDuration: DEFAULT_MAX_LOCK,
                minBonusPercentage: 0,
                maxBonusPercentage: 0.5e18
            })
        ) {} catch {}
        vm.stopPrank();
    }

    function _dl() internal view returns (uint256) {
        return block.timestamp + 30 days;
    }

    function _fundPair(address detf_, address pair_, address who, uint256 amt) internal {
        SimpleMintableERC20(pair_).mint(who, amt);
        vm.startPrank(who);
        IERC20(pair_).approve(detf_, type(uint256).max);
        vm.stopPrank();
    }

    function _firstBondDefault(uint256 amount_)
        internal
        returns (uint256 tokenId, uint256 shares)
    {
        uint256[] memory amts = new uint256[](3);
        amts[0] = amount_;
        amts[1] = amount_;
        amts[2] = amount_;
        return _firstBondOn(detf, amts, pair0);
    }

    function _firstBondOn(address detf_, uint256[] memory amounts_, address capitalToken_)
        internal
        returns (uint256 tokenId, uint256 shares)
    {
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(detf_);
        uint8 m_ = info.m();
        IERC20[] memory ins = new IERC20[](m_);
        for (uint8 i; i < m_; ++i) {
            address p = info.pairToken(i);
            ins[i] = IERC20(p);
            _fundPair(detf_, p, detfUser, amounts_[i] * 2);
        }
        vm.startPrank(detfUser);
        (tokenId, shares) =
            info.bond(ins, amounts_, capitalToken_, DEFAULT_MIN_LOCK, detfUser, false, _dl());
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

    function _assertInert() internal view {
        assertFalse(detfInfo.isReserveLive(), "expected inert (not live)");
    }

    function _assertLive() internal view {
        assertTrue(detfInfo.isReserveLive(), "expected reserve live");
        assertTrue(detfInfo.reserveHook() != address(0), "reserve hook missing");
        assertTrue(detfInfo.bondNftVault() != address(0), "bond nft vault missing");
    }

    function _donatePairToProtocolLp(
        IUniswapV4StandardExchangeCurveQuadStableDETF info_,
        address pair_,
        uint256 pairAmt_
    ) internal returns (bool ok_) {
        address hook = info_.reserveHook();
        address holder =
            info_.rebasingClaimToken() != address(0) ? info_.rebasingClaimToken() : address(info_);
        if (!IUniswapV4StandardExchangeCurveQuadStableBufferHook(hook).isFullBook()) return false;
        SimpleMintableERC20(pair_).mint(detfUser, pairAmt_);
        vm.startPrank(detfUser);
        IERC20(pair_).approve(hook, type(uint256).max);
        try IUniswapV4StandardExchangeCurveQuadStableBufferHook(hook).depositSingle(
            pair_, pairAmt_, holder, 0, block.timestamp + 1 days
        ) {
            ok_ = true;
        } catch {
            try IUniswapV4StandardExchangeCurveQuadStableBufferHook(hook).depositSingle(
                pair_, pairAmt_ / 20, holder, 0, block.timestamp + 1 days
            ) {
                ok_ = true;
            } catch {
                ok_ = false;
            }
        }
        vm.stopPrank();
    }

    function _pushSyntheticMintAllowed(IUniswapV4StandardExchangeCurveQuadStableDETF info_) internal {
        require(info_.isReserveLive(), "live");
        address p0 = info_.pairToken(0);
        if (info_.isMintingAllowed(p0)) return;

        for (uint256 r; r < 12 && !info_.isMintingAllowed(p0) && info_.isBurningAllowed(p0); ++r) {
            uint256 bal = IERC20(address(info_)).balanceOf(detfUser);
            if (bal == 0) break;
            uint256 burnAmt = bal / 5;
            if (burnAmt == 0) burnAmt = bal;
            try this.burnExternal(address(info_), p0, burnAmt) {} catch {
                break;
            }
        }
        if (info_.isMintingAllowed(p0)) return;

        for (uint256 i; i < 40 && !info_.isMintingAllowed(p0); ++i) {
            bool ok = _donatePairToProtocolLp(info_, p0, 20 ether * (i + 1));
            if (!ok) ok = _donatePairToProtocolLp(info_, p0, 5 ether);
            if (!ok) break;
            uint8 m_ = info_.m();
            for (uint8 j = 1; j < m_; ++j) {
                _donatePairToProtocolLp(info_, info_.pairToken(j), 10 ether * (i + 1));
            }
        }
        require(info_.isMintingAllowed(p0), "could not open Policy mint (S > mintThreshold)");
    }

    function _pushSyntheticBurnAllowed(IUniswapV4StandardExchangeCurveQuadStableDETF info_) internal {
        require(info_.isReserveLive(), "live");
        address p0 = info_.pairToken(0);
        if (info_.isBurningAllowed(p0)) return;
        address d = address(info_);

        for (uint256 i; i < 30 && !info_.isBurningAllowed(p0) && info_.isMintingAllowed(p0); ++i) {
            SimpleMintableERC20(p0).mint(detfUser, 50 ether);
            try this.mintExternal(d, p0, 50 ether) {} catch {
                break;
            }
        }
        if (info_.isBurningAllowed(p0)) return;

        for (uint256 j; j < 15 && !info_.isBurningAllowed(p0); ++j) {
            try this.bondSingleExternal(d, p0, 30 ether) {} catch {
                break;
            }
        }
        require(info_.isBurningAllowed(p0), "could not open Policy burn (S < burnThreshold)");
    }

    function mintExternal(address d, address pair_, uint256 amt) external returns (uint256) {
        return _mintOn(d, pair_, amt);
    }

    function burnExternal(address d, address pairOut_, uint256 amt) external returns (uint256) {
        return _burnOn(d, pairOut_, amt);
    }

    function bondSingleExternal(address d, address pair_, uint256 amt)
        external
        returns (uint256 tokenId, uint256 shares)
    {
        IUniswapV4StandardExchangeCurveQuadStableDETF info =
            IUniswapV4StandardExchangeCurveQuadStableDETF(d);
        _fundPair(d, pair_, detfUser, amt * 2);
        vm.startPrank(detfUser);
        (tokenId, shares) = info.bond(IERC20(pair_), amt, DEFAULT_MIN_LOCK, detfUser, false, _dl());
        vm.stopPrank();
    }
}
