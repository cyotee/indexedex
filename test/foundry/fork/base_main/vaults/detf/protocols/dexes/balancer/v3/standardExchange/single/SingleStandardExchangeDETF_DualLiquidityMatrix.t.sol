// SPDX-License-Identifier: BSL-1.1
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
} from "test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";

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
        IFacet claimFacet_ = DetfFacetFactoryService.deployRebasingClaimTokenFacet(create3Factory);
        IRebasingClaimTokenDFPkg claimPkg_ = DetfPkgFactoryService.deployRebasingClaimTokenDFPkg(
            create3Factory,
            DetfComponentFactoryService.buildRebasingClaimTokenPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
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
                rebasingClaimTokenPkg: claimPkg_,
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
            thresholdMode: ThresholdMode.Open,
        expansionClosureRatePerSecond: 0,
        expansionCatchUpMaxSeconds: 0,
        expansionCatchUpCapBps: 0
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
        // Bootstrap outer with dual-liquidity shares already on this contract from _bootstrapReserve.
        // Outer SingleSE mint is a **single-sided** vault-share join; Balancer MaxInRatio ≈ 30% of that
        // leg's pool balance. Cap mint well under first-bond vault-share amount.
        // Dual-liq *inner* joins also hit MaxInRatio — keep `_acquireDualShares` tiny vs LEG_SEED.
        uint256 seShares_ = IERC20(linkedVault).balanceOf(address(this));
        if (seShares_ == 0) {
            seShares_ = _acquireDualShares(1e16);
        }
        // First bond bootstraps outer reserve (both legs). Keep principal small and MaxInRatio-safe
        // for a later single-sided vault-share join (mint ≤ ~10% of bonded vault-share leg).
        uint256 bondIn_ = seShares_ / 50;
        if (bondIn_ == 0) bondIn_ = seShares_;
        if (bondIn_ > 1e17) bondIn_ = 1e17; // 0.1 dual shares max for first bond

        IERC20(linkedVault).approve(outerDetf, bondIn_);
        (uint256 tokenId_,) = outerBonding.bond(
            IERC20(linkedVault), bondIn_, MIN_LOCK, address(this), false, block.timestamp + 1 hours
        );
        assertTrue(tokenId_ > 0);
        assertTrue(outerInfo.isReserveLive());
        assertTrue(IERC20(outerDetf).totalSupply() > 0, "outer detf supply");
        _assertOuterNoFreeInventory();

        // Hard mint: ≤5% of bonded vault-share leg (<< MaxInRatio 30%).
        assertTrue(outerInfo.isMintingAllowed(), "mint gate open");
        uint256 mintIn_ = bondIn_ / 20;
        if (mintIn_ == 0) mintIn_ = 1;
        uint256 held_ = IERC20(linkedVault).balanceOf(address(this));
        if (held_ < mintIn_) {
            uint256 acquired_ = _acquireDualShares(1e15);
            held_ = IERC20(linkedVault).balanceOf(address(this));
            require(held_ > 0 || acquired_ > 0, "need dual shares for mint");
            if (held_ < mintIn_) mintIn_ = held_ / 20;
            if (mintIn_ == 0) mintIn_ = held_;
        }
        if (mintIn_ > bondIn_ / 20 && bondIn_ / 20 > 0) mintIn_ = bondIn_ / 20;

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
        uint256 innerOut_ = _acquireDualShares(1e15);
        assertTrue(innerOut_ > 0, "inner still serves");
    }
}
