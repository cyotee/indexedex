// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

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
import {IDETFNFTVaultDFPkg} from "contracts/vaults/protocol/DETFNFTVaultDFPkg.sol";
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

/// @notice Phase 5 matrix: outer SingleStandardExchangeDETF with DualLiquidity as SE vault (Base fork).
/// @dev FOUNDRY_PROFILE=fork. Requires base_mainnet_alchemy (or configured Base RPC).
contract SingleStandardExchangeDETF_DualLiquidityMatrix_Test is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    uint256 internal constant MIN_LOCK = 30 days;

    ISingleStandardExchangeDETDFPkg internal outerPkg;
    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    IStandardExchangeRateProviderDFPkg internal outerRateProviderPkg;

    address internal outerDetf;
    ISingleStandardExchangeDETFInfo internal outerInfo;
    ISingleStandardExchangeDETFBonding internal outerBonding;
    IStandardExchangeIn internal outerExchangeIn;

    function setUp() public virtual override {
        super.setUp();

        // Ensure dual-liquidity has share supply for rate provider + bonding.
        _bootstrapReserve();

        _deployOuterDetfStack();
        outerDetf = _deployOuterDetfInstance();
        outerInfo = ISingleStandardExchangeDETFInfo(outerDetf);
        outerBonding = ISingleStandardExchangeDETFBonding(outerDetf);
        outerExchangeIn = IStandardExchangeIn(outerDetf);
    }

    function _deployOuterDetfStack() internal {
        IFacet multiBasic_ = VaultComponentFactoryService.deployMultiAssetBasicVaultFacet(create3Factory);
        IFacet multiStd_ = VaultComponentFactoryService.deployMultiAssetStandardVaultFacet(create3Factory);
        IFacet exchangeInFacet_ =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);

        IFacet rateFacet_ = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("SSE_DETF_DL_RateProviderFacet")
            )
        );
        outerRateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateFacet_,
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("SSE_DETF_DL_RateProviderDFPkg")
                )
            )
        );

        IFacet nftFacet_ = DetfFacetFactoryService.deployDETFNFTVaultFacet(create3Factory);
        IFacet erc721_ = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("SSE_DETF_DL_ERC721"))
        );
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

    function _deployOuterDetfInstance() internal returns (address detf_) {
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Outer DETF over DualLiquidity",
            symbol: "oDETF",
            standardExchangeVault: IStandardExchangeProxy(linkedVault),
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: commonToken,
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: ThresholdMode.Open
        });
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(IStandardVaultPkg(address(outerPkg)), abi.encode(args));
        vm.stopPrank();
    }

    function test_matrix_dualLiquidity_deployInert() public view {
        assertFalse(outerInfo.isReserveLive());
        assertEq(outerInfo.standardExchangeVault(), linkedVault);
        assertEq(outerInfo.rateTarget(), address(commonToken));
        assertTrue(outerInfo.reservePool() != address(0));
    }

    function _assertOuterNoFreeInventory() internal view {
        assertEq(IERC20(linkedVault).balanceOf(outerDetf), 0, "residual dual-liq shares");
        assertEq(IERC20(outerDetf).balanceOf(outerDetf), 0, "residual free outer detf");
        assertEq(commonToken.balanceOf(outerDetf), 0, "residual common");
    }

    function _acquireDualShares(uint256 commonIn_) internal returns (uint256 shares_) {
        _fund(commonToken, address(this), commonIn_);
        commonToken.approve(linkedVault, commonIn_);
        shares_ = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, commonIn_, IERC20(linkedVault), 0, address(this), false, block.timestamp
        );
        require(shares_ > 0, "dual shares");
    }

    function test_matrix_dualLiquidity_firstBondMintBurn() public {
        // Bootstrap outer with small dual-liquidity share size (MaxInRatio-safe).
        uint256 seShares_ = IERC20(linkedVault).balanceOf(address(this));
        if (seShares_ < 1e18) {
            seShares_ = _acquireDualShares(500e18);
        }
        uint256 bondIn_ = seShares_ > 50e18 ? 50e18 : seShares_ / 2;
        if (bondIn_ == 0) bondIn_ = seShares_;

        IERC20(linkedVault).approve(outerDetf, bondIn_);
        (uint256 tokenId_,) = outerBonding.bond(
            IERC20(linkedVault), bondIn_, MIN_LOCK, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(tokenId_ > 0);
        assertTrue(outerInfo.isReserveLive());
        assertTrue(IERC20(outerDetf).totalSupply() > 0, "outer detf supply");
        _assertOuterNoFreeInventory();

        // Hard mint: open thresholds (mintThreshold=1) must allow mint after bootstrap.
        assertTrue(outerInfo.isMintingAllowed(), "mint gate open");
        uint256 mintIn_ = _acquireDualShares(50e18);
        if (mintIn_ > 5e18) mintIn_ = 5e18;
        IERC20(linkedVault).approve(outerDetf, mintIn_);
        uint256 mintOut_ = outerExchangeIn.exchangeIn(
            IERC20(linkedVault), mintIn_, IERC20(outerDetf), 0, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(mintOut_ > 0, "outer mint");
        _assertOuterNoFreeInventory();

        // Hard burn: burnThreshold=max → always allowed.
        assertTrue(outerInfo.isBurningAllowed(), "burn gate open");
        uint256 burnIn_ = mintOut_ / 2;
        require(burnIn_ > 0, "burn amount");
        IERC20(outerDetf).approve(outerDetf, burnIn_);
        uint256 burnOut_ = outerExchangeIn.exchangeIn(
            IERC20(outerDetf), burnIn_, IERC20(linkedVault), 0, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(burnOut_ > 0, "outer burn to dual shares");
        _assertOuterNoFreeInventory();

        // Inner dual-liquidity still serves direct SE calls after outer composition.
        uint256 innerOut_ = _acquireDualShares(50e18);
        assertTrue(innerOut_ > 0, "inner still serves");
    }
}
