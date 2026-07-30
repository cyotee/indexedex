// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/reusable/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/reusable/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/reusable/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/reusable/nft/IDetfSelfNftInventoryDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {ThresholdMode} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {
    IUniswapV4StandardExchangeDFPkg
} from "contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol";
import {UniswapV4_Component_FactoryService} from "contracts/protocols/dexes/uniswap/v4/UniswapV4_Component_FactoryService.sol";

/// @notice Phase 5 matrix: outer SingleStandardExchangeDETF over production Uni V4 SE vault (Base fork).
contract SingleStandardExchangeDETF_UniswapV4Matrix_Test is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    uint256 internal constant MIN_LOCK = 30 days;

    address internal uniV4SeVault;
    address internal outerDetf;
    ISingleStandardExchangeDETFInfo internal outerInfo;
    ISingleStandardExchangeDETFBonding internal outerBonding;
    IStandardExchangeIn internal outerExchangeIn;
    ISingleStandardExchangeDETDFPkg internal outerPkg;
    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    IStandardExchangeRateProviderDFPkg internal outerRateProviderPkg;

    function setUp() public virtual override {
        super.setUp();

        // Deploy a production Uni V4 Standard Exchange vault (common/tokenA market already seeded).
        PoolKey memory key_ = _poolKey(commonToken, tokenA);
        vm.prank(owner);
        uniV4SeVault = address(
            IUniswapV4StandardExchangeDFPkg(address(v4VaultPkg)).deployVault(key_, WIDTH_MULTIPLIER)
        );
        // Seed some shares into this vault for bonding.
        _fund(commonToken, address(this), 5_000e18);
        _fund(tokenA, address(this), 5_000e18);
        commonToken.approve(uniV4SeVault, type(uint256).max);
        tokenA.approve(uniV4SeVault, type(uint256).max);
        // Prefer single-sided deposit via exchangeIn when available.
        try IStandardExchangeIn(uniV4SeVault).exchangeIn(
            commonToken, 1_000e18, IERC20(uniV4SeVault), 0, address(this), false, block.timestamp
        ) returns (uint256) {} catch {
            // Some V4 SE vaults require both tokens or position path — fund via deposit if present.
            try IERC20(uniV4SeVault).balanceOf(address(this)) returns (uint256) {} catch {}
        }

        _deployOuterStack();
        outerDetf = _deployOuter();
        outerInfo = ISingleStandardExchangeDETFInfo(outerDetf);
        outerBonding = ISingleStandardExchangeDETFBonding(outerDetf);
        outerExchangeIn = IStandardExchangeIn(outerDetf);
    }

    function _deployOuterStack() internal {
        IFacet multiBasic_ = VaultComponentFactoryService.deployMultiAssetBasicVaultFacet(create3Factory);
        IFacet multiStd_ = VaultComponentFactoryService.deployMultiAssetStandardVaultFacet(create3Factory);
        IFacet exchangeInFacet_ =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);
        IFacet rateFacet_ = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode, keccak256("SSE_DETF_V4_RP")
            )
        );
        outerRateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateFacet_, diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("SSE_DETF_V4_RP_PKG")
                )
            )
        );
        IFacet nftFacet_ = DetfFacetFactoryService.deployDETFNFTVaultFacet(create3Factory);
        IFacet erc721_ =
            IFacet(create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SSE_DETF_V4_721")));
        IFacet erc4626Basic_ = VaultComponentFactoryService.deployERC4626BasedBasicVaultFacet(create3Factory);
        IFacet erc4626Std_ = VaultComponentFactoryService.deployERC4626StandardVaultFacet(create3Factory);

        vm.startPrank(owner);
        bondNftVaultPkg = DetfPkgFactoryService.deployDETFNFTVaultDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
                erc721_,
                erc4626Basic_,
                erc4626Std_,
                nftFacet_,
                IVaultFeeOracleQuery(address(indexedexManager)),
                IVaultRegistryDeployment(address(indexedexManager))
            )
        );
        outerPkg = SingleStandardExchangeDETF_Component_FactoryService.deployPkg(
            IVaultRegistryDeployment(address(indexedexManager)),
            ISingleStandardExchangeDETDFPkg.PkgInit({
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiBasic_,
                multiAssetStandardVaultFacet: multiStd_,
                exchangeInFacet: exchangeInFacet_,
                feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
                balancerV3Vault: vault,
                weightedPoolFactory: weightedPoolFactory,
                rateProviderPkg: outerRateProviderPkg,
                bondNftVaultPkg: bondNftVaultPkg,
                diamondFactory: diamondPackageFactory
            })
        );
        vm.stopPrank();
    }

    function _deployOuter() internal returns (address detf_) {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Outer DETF over Uniswap V4 SE",
            symbol: "oV4DETF",
            standardExchangeVault: IStandardExchangeProxy(uniV4SeVault),
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: commonToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Open,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(IStandardVaultPkg(address(outerPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_matrix_uniV4_deployInert() public view {
        assertFalse(outerInfo.isReserveLive());
        assertEq(outerInfo.standardExchangeVault(), uniV4SeVault);
        assertTrue(outerInfo.reservePool() != address(0));
    }

    function _assertOuterNoFreeInventory() internal view {
        assertEq(IERC20(uniV4SeVault).balanceOf(outerDetf), 0, "residual uni v4 se shares");
        assertEq(IERC20(outerDetf).balanceOf(outerDetf), 0, "residual free outer detf");
        assertEq(commonToken.balanceOf(outerDetf), 0, "residual common");
    }

    function _acquireUniV4Shares(uint256 commonIn_) internal returns (uint256 shares_) {
        _fund(commonToken, address(this), commonIn_);
        commonToken.approve(uniV4SeVault, commonIn_);
        shares_ = IStandardExchangeIn(uniV4SeVault).exchangeIn(
            commonToken, commonIn_, IERC20(uniV4SeVault), 0, address(this), false, block.timestamp
        );
        require(shares_ > 0, "uni v4 se shares");
    }

    function test_matrix_uniV4_firstBondMintBurn() public {
        uint256 seShares_ = IERC20(uniV4SeVault).balanceOf(address(this));
        if (seShares_ == 0) {
            seShares_ = _acquireUniV4Shares(500e18);
        }
        uint256 bondIn_ = seShares_ > 20e18 ? 20e18 : seShares_;
        IERC20(uniV4SeVault).approve(outerDetf, bondIn_);
        (uint256 tokenId_,) =
            outerBonding.bond(IERC20(uniV4SeVault), bondIn_, MIN_LOCK, address(this), false, block.timestamp + 1 hours);
        assertTrue(tokenId_ > 0);
        assertTrue(outerInfo.isReserveLive());
        _assertOuterNoFreeInventory();

        // Hard mint (open mintThreshold=1).
        assertTrue(outerInfo.isMintingAllowed(), "mint gate open");
        uint256 mintIn_ = _acquireUniV4Shares(30e18);
        if (mintIn_ > 3e18) mintIn_ = 3e18;
        IERC20(uniV4SeVault).approve(outerDetf, mintIn_);
        uint256 mintOut_ = outerExchangeIn.exchangeIn(
            IERC20(uniV4SeVault), mintIn_, IERC20(outerDetf), 0, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(mintOut_ > 0, "outer mint from uni v4 se shares");
        _assertOuterNoFreeInventory();

        // Hard burn (burnThreshold=max).
        assertTrue(outerInfo.isBurningAllowed(), "burn gate open");
        uint256 burnIn_ = mintOut_ / 2;
        require(burnIn_ > 0, "burn amount");
        IERC20(outerDetf).approve(outerDetf, burnIn_);
        uint256 burnOut_ = outerExchangeIn.exchangeIn(
            IERC20(outerDetf), burnIn_, IERC20(uniV4SeVault), 0, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(burnOut_ > 0, "outer burn to uni v4 se shares");
        _assertOuterNoFreeInventory();
    }
}
