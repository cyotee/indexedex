// SPDX-License-Identifier: BUSL-1.1
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
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeDETDFPkg,
    IUniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETF_Component_FactoryService.sol";

/**
 * @title TestBase_UniswapV4SingleStandardExchangeDETF
 * @notice Gold TestBase: production DFPkg via manager registry + real hook + ERC-4626 wrapper SE.
 *
 * Consumed hook ABI surface (frozen — do not invent methods):
 * - deposit / depositSingle / withdraw / withdrawSingle
 * - previewDeposit / previewDepositSingle / previewWithdraw / previewWithdrawSingle
 * - rawReserve / reserveCurrency0/1 / currency0/1 / pairToken / rawToken / isLive
 * - IERC20 LP on hook diamond
 *
 * SE validation pattern (DFPkg postDeploy): pair ∈ SE.vaultTokens(); DETF ∉ SE.vaultTokens().
 */
abstract contract TestBase_UniswapV4SingleStandardExchangeDETF is
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook
{
    using BetterEfficientHashLib for bytes;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using UniswapV4SingleStandardExchangeDETF_Component_FactoryService for ICreate3FactoryProxy;
    using UniswapV4SingleStandardExchangeDETF_Component_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;
    /// @dev 1 pair per 1 DETF at 1e18 scale (creation mid).
    uint256 internal constant DEFAULT_CREATION_PAIR_PER_DETF = 1e18;

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal detfExchangeInFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721FacetDetf;

    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    IRebasingClaimTokenDFPkg internal rebasingClaimTokenPkg;
    IUniswapV4SingleStandardExchangeDETDFPkg internal detfPkg;

    address internal detf;
    IUniswapV4SingleStandardExchangeDETF internal detfInfo;
    IStandardExchangeIn internal detfExchangeIn;

    address internal detfUser = address(0xD37F);

    function setUp() public virtual override {
        // Hook base: SE, PM, hook factory, hookPkg.
        TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.setUp();

        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        // Uni V4 CP DETF facet (not Balancer Single SE facet).
        detfExchangeInFacet =
            UniswapV4SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);

        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();

        // Global bond terms BEFORE instance deploy so postDeploy fee-recipient NFT + lock validation succeed.
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployDetfInstance(_defaultDetfArgs());

        detfInfo = IUniswapV4SingleStandardExchangeDETF(detf);
        detfExchangeIn = IStandardExchangeIn(detf);

        // Fund DETF user with pair
        pairToken.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        vm.stopPrank();

        // Also pin vault-specific terms (hermetic assert feeRecipientNftId != 0 after deploy).
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
    }

    function _deployRebasingClaimTokenPkg() internal {
        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        rebasingClaimTokenPkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );
        vm.label(address(rebasingClaimTokenPkg), "Uv4CpDetf_RebasingClaimTokenPkg");
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721FacetDetf = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("Uv4CpDetf_ERC721Facet"))
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
        vm.label(address(bondNftVaultPkg), "Uv4CpDetf_BondNftVaultPkg");
    }

    function _deployDetfPkg() internal {
        IUniswapV4SingleStandardExchangeDETDFPkg.PkgInit memory pkgInit = IUniswapV4SingleStandardExchangeDETDFPkg
            .PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: detfExchangeInFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            poolManager: pm,
            hookPkg: hookPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        detfPkg = UniswapV4SingleStandardExchangeDETF_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
        vm.label(address(detfPkg), "UniswapV4SingleStandardExchangeDETDFPkg");
    }

    function _defaultDetfArgs()
        internal
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory)
    {
        return IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs({
            name: "UniV4 SE CP DETF",
            symbol: "uv4cpDETF",
            standardExchangeVault: IStandardExchangeProxy(se),
            standardExchangeVaultShare: IERC20(address(0)),
            pairToken: IERC20(address(pairToken)),
            creationPairPerDetfWad: DEFAULT_CREATION_PAIR_PER_DETF,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Policy,
            expansionEpochLength: 0,
            expansionClosureRatePerYearWad: 0,
            expansionMaxCatchUpEpochs: 0,
            hookMineNonce: 0
        });
    }

    /// @notice Gentle expansion: epoch 8h (default), R=10%/yr (default).
    function _gentleArgs()
        internal
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "Gentle UniV4 DETF";
        args.symbol = "gDETF";
    }

    /// @notice Launch-rich: R=4.4e18 (~1y walk from S≈5 narrative).
    function _launchRichArgs()
        internal
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "LaunchRich UniV4 DETF";
        args.symbol = "lrDETF";
        args.expansionClosureRatePerYearWad = 4.4e18;
    }

    /// @notice Open threshold mode — never expands.
    function _openArgs()
        internal
        view
        returns (IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
    {
        args = _defaultDetfArgs();
        args.name = "Open UniV4 DETF";
        args.symbol = "oDETF";
        args.thresholdMode = ThresholdMode.Open;
    }

    function _deployDetfInstance(IUniswapV4SingleStandardExchangeDETDFPkg.PkgArgs memory args)
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

    function _firstBond(uint256 pairAmount_) internal returns (uint256 tokenId, uint256 shares) {
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(address(pairToken)),
            pairAmount_,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _mintPair(uint256 pairAmount_) internal returns (uint256 userDetf) {
        vm.startPrank(detfUser);
        userDetf = detfExchangeIn.exchangeIn(
            IERC20(address(pairToken)),
            pairAmount_,
            IERC20(detf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _burnToPair(uint256 detfAmount_) internal returns (uint256 pairOut) {
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, type(uint256).max);
        pairOut = detfExchangeIn.exchangeIn(
            IERC20(detf),
            detfAmount_,
            IERC20(address(pairToken)),
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

    function _assertLive() internal view {
        assertTrue(detfInfo.isReserveLive(), "expected reserve live");
        assertTrue(detfInfo.reserveHook() != address(0), "reserve hook missing");
        assertTrue(detfInfo.bondNftVault() != address(0), "bond nft vault missing");
    }
}
