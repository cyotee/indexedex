// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {TestBase_FundedBalancerDETF} from "contracts/test/bases/TestBase_FundedBalancerDETF.sol";
import {FundedBondLifecycleAssertions} from "contracts/test/bases/FundedBondLifecycleAssertions.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {
    IComposedStableCommonDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfInfo.sol";
import {
    IComposedStableCommonDetfBonding as IFundedComposedBonding
} from "contracts/interfaces/IComposedStableCommonDetfBonding.sol";

import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {
    CastingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20MintBurn} from "@crane/contracts/interfaces/IERC20MintBurn.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IStablePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol";
import {IRouter} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol";
import {IStablePoolFactory} from "contracts/interfaces/IStablePoolFactory.sol";
import {IWeightedPoolFactory} from "contracts/interfaces/IWeightedPoolFactory.sol";
import {IOperable} from "@crane/contracts/interfaces/IOperable.sol";

import {IERC20MintBurnOwnableOperableDFPkg} from "@crane/contracts/tokens/ERC20/IERC20MintBurnOwnableOperableDFPkg.sol";

import {TokenConfig, PoolRoleAccounts} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {IWeightedPool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol";

import {IDETF} from "contracts/interfaces/IDETF.sol";
import {IComposedStableCommonDetfBondNFTVault} from "contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol";
import {ILegacyComposedStableCommonDetfBonding as IComposedStableCommonDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ILegacyComposedStableCommonDetfBonding.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultRegistryVaultQuery} from "contracts/interfaces/IVaultRegistryVaultQuery.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";

import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    ComposedStableCommonDetfRepo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfRepo.sol";
import {
    ComposedStableCommonDetf_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol";
import {IComposedStableCommonDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfDFPkg.sol";
import {
    ComposedStableCommonDetf_Facet_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Facet_FactoryService.sol";
import {
    ComposedStableCommonDetf_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetf_Pkg_FactoryService.sol";
import {IComposedStableCommonDetfBondNFTVaultDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IComposedStableCommonDetfBondNFTVaultDFPkg.sol";
import {
    ComposedStableCommonDetfBondNFTVault_Facet_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVault_Facet_FactoryService.sol";
import {
    ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService.sol";
import {IRebasingDETFTokenDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/IRebasingDETFTokenDFPkg.sol";
import {
    RebasingDETFToken_Facet_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFToken_Facet_FactoryService.sol";
import {
    RebasingDETFToken_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/RebasingDETFToken_Pkg_FactoryService.sol";

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IDetf} from "contracts/interfaces/detf/IDetf.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

interface IRebasingLeftoverMinter {
    function renounceLeftoverMinter() external;
}

contract ComposedStableCommonDetf_IntegratedDeploy_Test is TestBase_FundedBalancerDETF, FundedBondLifecycleAssertions {
    using CastingHelpers for address[];
    using ComposedStableCommonDetf_Facet_FactoryService for ICreate3FactoryProxy;
    using ComposedStableCommonDetf_Pkg_FactoryService for IVaultRegistryDeployment;
    using ComposedStableCommonDetfBondNFTVault_Facet_FactoryService for ICreate3FactoryProxy;
    using ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService for IVaultRegistryDeployment;
    using RebasingDETFToken_Facet_FactoryService for ICreate3FactoryProxy;
    using RebasingDETFToken_Pkg_FactoryService for ICreate3FactoryProxy;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    IFacet internal bondingFacet;
    IFacet internal exchangeInFacet;
    IFacet internal exchangeOutQueryFacet;
    IFacet internal pricingFacet;
    IFacet internal multiAssetBasicVaultFacet;
    IFacet internal multiAssetStandardVaultFacet;
    IFacet internal erc20MintBurnOwnableFacet;
    IFacet internal operableFacet;
    IFacet internal bondNFTVaultFacet;
    IFacet internal rebasingDetfTokenFacet;
    IComposedStableCommonDetfDFPkg internal detfPkg;
    IERC20MintBurnOwnableOperableDFPkg internal detfTokenPkg;
    IComposedStableCommonDetfBondNFTVaultDFPkg internal bondNFTVaultPkg;
    IRebasingDETFTokenDFPkg internal rebasingDetfTokenPkg;

    IERC20 internal detfToken;
    IDETFNFTVault internal bondNFTVault;
    IRebasingClaimToken internal rebasingDetfToken;
    IDetf internal detf;

    IStablePoolFactory internal stablePoolFactory;
    IStablePoolFactory internal commonPoolFactory;
    IStablePool internal stablePool;
    IStablePool internal commonPool;
    IWeightedPool internal reservePool;
    IStandardExchangeIn internal stablePoolAdapter;
    IStandardExchangeIn internal commonPoolAdapter;
    IStandardExchangeIn internal reservePoolAdapter;
    uint256 internal detfIndex;
    uint256 internal stablePoolBptIndex;
    uint256 internal commonPoolBptIndex;

    address internal deployedDetfVault;

    function _warpPastUnlock(uint256 id_) internal {
        uint256 end_ = IDetfBondNFT(address(bondNFTVault)).positionOf(id_).startTimestamp
            + IDetfBondNFT(address(bondNFTVault)).positionOf(id_).vestingDuration;
        if (block.timestamp <= end_) vm.warp(end_ + 1);
    }

    function _feeTo() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    function _reserveTokenBudget(address pool_, IERC20 token_) internal view returns (uint256) {
        (IERC20[] memory tokens_,, uint256[] memory balances_,) = vault.getPoolTokenInfo(pool_);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == token_) return balances_[i_] / 10;
        }
        revert("reserve token missing");
    }

    function _potBalance() internal view returns (uint256) {
        return IERC20(address(detfToken)).balanceOf(address(bondNFTVault));
    }

    function _claim(uint256 tokenId_, address to_) internal returns (uint256 claimed_) {
        vm.prank(to_);
        claimed_ = bondNFTVault.claimRewards(tokenId_, to_);
    }

    function _wireReservedBondNfts() internal {
        if (bondNFTVault.reservedBondNftsWired()) return;
        address feeTo_ = _feeTo();
        vm.prank(deployedDetfVault);
        bondNFTVault.initializeReservedBondNfts(feeTo_, address(0));
    }

    function _liveMint(address who_, uint256 daiIn_) internal returns (uint256 detfOut_) {
        deal(address(dai), who_, daiIn_, true);
        vm.startPrank(who_);
        dai.approve(deployedDetfVault, daiIn_);
        detfOut_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(dai, daiIn_, IERC20(address(detfToken)), 0, who_, false, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    struct StablePoolSpec {
        string name;
        string symbol;
        address poolCreator;
        string label;
    }

    /// @dev Overridable so nested matrix fixtures can open burn for rate-provider quotes.
    /// @notice After resolve, `0` → defaults; never means Open. Policy `1e18`/`0` → `1e18`/`0.95e18`
    ///         so near-peg integrated mints remain allowed without product Open.
    function _composedMintThreshold() internal pure virtual returns (uint256) {
        return 1e18;
    }

    function _composedBurnThreshold() internal pure virtual returns (uint256) {
        return 0;
    }

    /// @dev Default Policy. Nested matrix / dual-path may override to product Open.
    function _composedThresholdMode() internal pure virtual returns (ThresholdMode) {
        return ThresholdMode.Policy;
    }

    function _primaryRoutes() internal virtual returns (ComposedStableCommonDetfRepo.RouteConfig[] memory routes) {
        routes = new ComposedStableCommonDetfRepo.RouteConfig[](1);
        routes[0] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: dai,
            vaultToken: IERC20(address(daiUsdcVault)),
            underlyingVault: daiUsdcVault,
            stablePoolRouter: stablePoolAdapter,
            commonPoolRouter: commonPoolAdapter,
            stablePoolTokenIndex: 0,
            commonPoolTokenIndex: 0
        });
    }

    /// @dev Product Open: mode Open + thresholds 0,0 (resolved defaults stored; gates ignore thresholds).
    function _deployOpenModeDetf() internal returns (address vault_) {
        vault_ = _deployDetfWithThresholds(0, 0, ThresholdMode.Open);
    }

    /// @dev Extreme legal Policy pair (mint > burn). Not product Open.
    function _deployExtremePolicyDetf() internal returns (address vault_) {
        vault_ = _deployDetfWithThresholds(2, 1, ThresholdMode.Policy);
    }

    function _deployDetfWithThresholds(uint256 mintTh_, uint256 burnTh_, ThresholdMode mode_)
        internal
        returns (address vault_)
    {
        ComposedStableCommonDetfRepo.RouteConfig[] memory routes = new ComposedStableCommonDetfRepo.RouteConfig[](1);
        routes[0] = ComposedStableCommonDetfRepo.RouteConfig({
            baseToken: dai,
            vaultToken: IERC20(address(daiUsdcVault)),
            underlyingVault: daiUsdcVault,
            stablePoolRouter: stablePoolAdapter,
            commonPoolRouter: commonPoolAdapter,
            stablePoolTokenIndex: 0,
            commonPoolTokenIndex: 0
        });
        return _deployDetfWithRoutes(routes, mintTh_, burnTh_, mode_);
    }

    function _deployDetfWithRoutes(
        ComposedStableCommonDetfRepo.RouteConfig[] memory routes,
        uint256 mintTh_,
        uint256 burnTh_,
        ThresholdMode
    ) internal returns (address vault_) {
        IComposedStableCommonDetfDFPkg.PkgArgs memory args_;
        args_.name = "Composed Stable DETF";
        args_.symbol = "csDETF";
        args_.stablePool = stablePool;
        args_.commonPool = commonPool;
        args_.rateAsset = weth;
        args_.stablePoolExitPricer = stablePoolAdapter;
        args_.commonPoolExitPricer = commonPoolAdapter;
        args_.reserveWeights = [uint256(0.5e18), uint256(0.25e18), uint256(0.25e18)];
        args_.openingDetfPrices = [uint256(1e18), uint256(1e18)];
        args_.reserveSeedAmounts = [uint256(2_000e9), uint256(1_000e18), uint256(1_000e18)];
        args_.mintThreshold = mintTh_;
        args_.burnThreshold = burnTh_;
        // Derive route indices from the registered, sorted pool tokens.
        (IERC20[] memory stable_,,,) = vault.getPoolTokenInfo(address(stablePool));
        for (uint256 r_; r_ < routes.length; ++r_) {
            for (uint256 i_; i_ < stable_.length; ++i_) {
                if (stable_[i_] == routes[r_].vaultToken) {
                    routes[r_].stablePoolTokenIndex = i_;
                    routes[r_].commonPoolTokenIndex = i_;
                }
            }
        }
        args_.routes = routes;
        vm.prank(owner);
        vault_ = IVaultRegistryDeployment(address(indexedexManager))
            .deployVault(IStandardVaultPkg(address(detfPkg)), abi.encode(args_));
    }

    function setUp() public virtual override {
        super.setUp();
        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();
        _deployPricingPools();
        _seedPricingPools();
        bondingFacet = create3Factory.deployComposedStableCommonDetfBondingFacet();
        exchangeInFacet = create3Factory.deployComposedStableCommonDetfExchangeInFacet();
        exchangeOutQueryFacet = create3Factory.deployComposedStableCommonDetfExchangeOutQueryFacet();
        pricingFacet = create3Factory.deployRebasingDetfTokenPricingFacet();
        IComposedStableCommonDetfDFPkg.PkgInit memory init_;
        init_.erc20Facet = erc20Facet;
        init_.erc5267Facet = erc5267Facet;
        init_.erc2612Facet = erc2612Facet;
        init_.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        init_.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        init_.composedStableCommonDetfBondingFacet = bondingFacet;
        init_.composedStableCommonDetfExchangeInFacet = exchangeInFacet;
        init_.composedStableCommonDetfExchangeOutQueryFacet = exchangeOutQueryFacet;
        init_.rebasingDetfTokenPricingFacet = pricingFacet;
        init_.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        init_.feeOracle = IVaultFeeOracleQuery(address(indexedexManager));
        init_.balancerV3Router = IBalancerV3StandardExchangeRouterProxy(address(seRouter));
        init_.balancerV3Vault = IVault(address(vault));
        init_.weightedPoolFactory = IWeightedPoolFactory(testPoolFactory);
        init_.bondNftVaultPkg = bondNftVaultPkg;
        init_.rebasingClaimTokenPkg = rebasingClaimTokenPkg;
        init_.syPkg = syPkg;
        vm.prank(owner);
        detfPkg = IVaultRegistryDeployment(address(indexedexManager)).deployComposedStableCommonDetfDFPkg(init_);
        _useFundedComposed(
            _deployDetfWithRoutes(
                _primaryRoutes(), _composedMintThreshold(), _composedBurnThreshold(), _composedThresholdMode()
            )
        );
    }

    function test_deployVault_surfacesRealCompanionReferences() public view {
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(deployedDetfVault));
        IComposedStableCommonDetfInfo info_ = IComposedStableCommonDetfInfo(deployedDetfVault);
        assertEq(info_.bondNftVault(), address(bondNFTVault));
        assertEq(info_.rebasingClaimToken(), address(rebasingDetfToken));
        assertEq(info_.reservePool(), address(reservePool));
    }

    function test_deployVault_exposesBondAndExchangeEntryPoints() public view {
        IFundedComposedBonding bonds_ = IFundedComposedBonding(deployedDetfVault);
        assertTrue(bonds_.isAcceptedBondToken(IERC20(address(dai))));
        assertTrue(bonds_.isAcceptedBondToken(IERC20(address(stablePool))));
        assertTrue(bonds_.isAcceptedBondToken(IERC20(address(commonPool))));
        assertEq(
            IStandardExchangeIn(deployedDetfVault).previewExchangeIn(detfToken, 0, IERC20(address(rebasingDetfToken))),
            0
        );
        assertEq(
            IStandardExchangeOut(deployedDetfVault)
                .previewExchangeOut(detfToken, IERC20(address(rebasingDetfToken)), 0),
            0
        );
    }

    function test_deployVault_preservesCompanionSpecialPositionState() public view {
        IDetfBondNFT nft_ = IDetfBondNFT(address(bondNFTVault));
        assertTrue(nft_.reservedBondNftsWired());
        assertEq(nft_.detf(), deployedDetfVault);
        assertEq(address(nft_.lpToken()), address(reservePool));
        assertEq(nft_.positionOf(1).principal, 0, "fee position has no purchased principal");
        assertEq(nft_.positionOf(2).principal, 0, "creator position has no purchased principal");
        assertEq(IERC20Metadata(address(rebasingDetfToken)).decimals(), 9);
        assertEq(IERC20Metadata(deployedDetfVault).decimals(), 9);
        assertEq(IStakedDETF(address(rebasingDetfToken)).detf(), deployedDetfVault);
    }

    function test_deployVault_zeroAmountPricingQueriesShortCircuitSafely() public view {
        IComposedStableCommonDetfInfo info_ = IComposedStableCommonDetfInfo(deployedDetfVault);
        (uint256 self_, uint256 stable_, uint256 common_) = info_.previewReservePoolDecomposition(0);
        assertEq(self_, 0);
        assertEq(stable_, 0);
        assertEq(common_, 0);
        assertEq(info_.previewStablePoolBptEthValue(0), 0);
        assertEq(info_.previewCommonPoolBptEthValue(0), 0);
    }

    function test_exchangeIn_fundedReserveRoute_previewEqualsPayment() public {
        _bootstrapReserveGraph();
        IERC20 payment_ = IERC20(address(stablePool));
        vm.prank(owner);
        payment_.transfer(alice, 1e18);
        uint256 preview_ = IStandardExchangeIn(deployedDetfVault).previewExchangeIn(payment_, 1e18, detfToken);
        assertGt(preview_, 0, "funded route quote");
        uint256 before_ = detfToken.balanceOf(alice);
        vm.startPrank(alice);
        payment_.approve(deployedDetfVault, 1e18);
        uint256 out_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(payment_, 1e18, detfToken, preview_, alice, false, block.timestamp);
        vm.stopPrank();
        assertEq(out_, preview_);
        assertEq(detfToken.balanceOf(alice), before_ + out_);
        assertEq(payment_.balanceOf(alice), 0);
        assertEq(IERC20(address(reservePool)).balanceOf(deployedDetfVault), 0, "protocol LP held by NFT vault");
        assertGt(IERC20(address(reservePool)).balanceOf(address(bondNFTVault)), 0);
    }

    function test_bond_vestsFundedStaking_andUnstakes_onProductionGraph() public {
        _bootstrapReserveGraph();
        IERC20 payment_ = IERC20(address(stablePool));
        vm.prank(owner);
        payment_.transfer(alice, 10e18);
        (uint256 expected_,,) = IFundedComposedBonding(deployedDetfVault).previewBond(payment_, 10e18, 30 days);
        vm.startPrank(alice);
        payment_.approve(deployedDetfVault, 10e18);
        (uint256 id_, uint256 principal_) =
            IFundedComposedBonding(deployedDetfVault).bond(payment_, 10e18, 30 days, alice, block.timestamp);
        vm.stopPrank();
        assertEq(principal_, expected_);
        IDetfBondNFT nft_ = IDetfBondNFT(address(bondNFTVault));
        _assertBondPrincipalIsFunded(deployedDetfVault, id_, alice);
        _assertBondPrincipalStillLocked(deployedDetfVault, id_, alice);
        _assertBondMaturePreviewEqualsPayment(deployedDetfVault, id_, alice);
        uint256 paid_ = _fundedBondStaking(deployedDetfVault).balanceOf(alice);
        _assertFundedUnstake(deployedDetfVault, alice, paid_);
    }

    /// @dev Same as `_bootstrapReserveGraph` but caps vault-share init legs to the WETH scale so
    ///      empty-SE virtual-offset first mints cannot trip StableMath MaxImbalanceRatioExceeded.
    function _bootstrapReserveGraphBalanced() internal {
        _bootstrapReserveGraphWithShareCap(true);
    }

    function _bootstrapReserveGraph() internal {
        _bootstrapReserveGraphWithShareCap(false);
    }

    function _bootstrapReserveGraphWithShareCap(bool) internal {
        if (IComposedStableCommonDetfInfo(deployedDetfVault).isReserveLive()) return;
        vm.startPrank(owner);
        IERC20(address(stablePool)).approve(deployedDetfVault, 1_000e18);
        IERC20(address(commonPool)).approve(deployedDetfVault, 1_000e18);
        IFundedComposedBonding(deployedDetfVault).initializeReserve(1_000e18, 1_000e18, 30 days, owner, block.timestamp);
        vm.stopPrank();
    }

    function _approvePermit2ToRouter(address token_) internal {
        IERC20(token_).approve(address(permit2), type(uint256).max);
        permit2.approve(token_, address(router), type(uint160).max, type(uint48).max);
    }

    function _deployCompanions() internal {
        erc721Facet = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/tokens/ERC721/ERC721Facet.sol:ERC721Facet"), keccak256("ComposedStableCommonDetf_Integrated_ERC721Facet")
            )
        );
        bondNFTVaultFacet = create3Factory.deployComposedStableCommonDetfBondNFTVaultFacet();
        rebasingDetfTokenFacet = create3Factory.deployRebasingDETFTokenFacet();

        vm.startPrank(owner);
        bondNFTVaultPkg = IVaultRegistryDeployment(address(indexedexManager))
            .deployComposedStableCommonDetfBondNFTVaultDFPkg(
                ComposedStableCommonDetf_Component_FactoryService.buildBondNFTVaultPkgInit(
                        ComposedStableCommonDetf_Component_FactoryService.BondNFTVaultFacets({
                            erc721Facet: erc721Facet,
                            erc4626BasicVaultFacet: erc4626BasicVaultFacet,
                            erc4626StandardVaultFacet: erc4626StandardVaultFacet,
                            bondNFTVaultFacet: bondNFTVaultFacet,
                            multiStepOwnableFacet: multiStepOwnableFacet
                        }),
                        ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfInfra({
                                vaultRegistryDeployment: indexedexManager
                            })
                    )
            );
        vm.stopPrank();

        rebasingDetfTokenPkg = create3Factory.deployRebasingDETFTokenDFPkg(
            ComposedStableCommonDetf_Component_FactoryService.buildRebasingDetfTokenPkgInit(
                ComposedStableCommonDetf_Component_FactoryService.RebasingDetfTokenFacets({
                    erc20Facet: erc20Facet,
                    erc5267Facet: erc5267Facet,
                    erc2612Facet: erc2612Facet,
                    multiStepOwnableFacet: multiStepOwnableFacet,
                    rebasingDetfTokenFacet: rebasingDetfTokenFacet
                }),
                diamondPackageFactory
            )
        );

        vm.startPrank(owner);
        bondNFTVault = IDETFNFTVault(
            bondNFTVaultPkg.deployVault(
                "Composed Stable Bond NFT Vault",
                "csBOND",
                detf,
                IERC20(address(reservePool)),
                IERC20(address(detfToken)),
                0,
                owner
            )
        );
        bondNFTVault.initializeDETFNFT();
        vm.stopPrank();

        vm.startPrank(owner);
        rebasingDetfToken = IRebasingClaimToken(
            rebasingDetfTokenPkg.deployToken(IDETF(address(detf)), bondNFTVault, weth, bondNFTVault.detfNFTId(), owner)
        );
        vm.stopPrank();
    }

    function _transferBondVaultOwnership(address newOwner_) internal {
        vm.startPrank(owner);
        IMultiStepOwnable(address(bondNFTVault)).initiateOwnershipTransfer(newOwner_);
        vm.warp(block.timestamp + IMultiStepOwnable(address(bondNFTVault)).getOwnershipTransferBuffer());
        IMultiStepOwnable(address(bondNFTVault)).confirmOwnershipTransfer(newOwner_);
        vm.stopPrank();

        vm.prank(newOwner_);
        IMultiStepOwnable(address(bondNFTVault)).acceptOwnershipTransfer();
    }

    function _transferDetfTokenOwnership(address newOwner_) internal {
        vm.startPrank(owner);
        IMultiStepOwnable(address(detfToken)).initiateOwnershipTransfer(newOwner_);
        vm.warp(block.timestamp + IMultiStepOwnable(address(detfToken)).getOwnershipTransferBuffer());
        IMultiStepOwnable(address(detfToken)).confirmOwnershipTransfer(newOwner_);
        vm.stopPrank();

        vm.prank(newOwner_);
        IMultiStepOwnable(address(detfToken)).acceptOwnershipTransfer();
    }

    function _transferRebasingDetfTokenOwnership(address newOwner_) internal {
        vm.startPrank(owner);
        IMultiStepOwnable(address(rebasingDetfToken)).initiateOwnershipTransfer(newOwner_);
        vm.warp(block.timestamp + IMultiStepOwnable(address(rebasingDetfToken)).getOwnershipTransferBuffer());
        IMultiStepOwnable(address(rebasingDetfToken)).confirmOwnershipTransfer(newOwner_);
        vm.stopPrank();

        vm.prank(newOwner_);
        IMultiStepOwnable(address(rebasingDetfToken)).acceptOwnershipTransfer();
    }

    function _deployDetfToken() internal {
        operableFacet = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/access/operable/OperableFacet.sol:OperableFacet"), keccak256("ComposedStableCommonDetf_Integrated_OperableFacet")
            )
        );
        erc20MintBurnOwnableFacet = IFacet(
            create3Factory.deployFacet(
                ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol:ERC20MintBurnOwnableFacet"),
                keccak256("ComposedStableCommonDetf_Integrated_ERC20MintBurnOwnableFacet")
            )
        );

        IERC20MintBurnOwnableOperableDFPkg.PkgInit memory pkgInit = IERC20MintBurnOwnableOperableDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            erc20MintBurnOwnableFacet: erc20MintBurnOwnableFacet,
            mutiStepOwnableFacet: multiStepOwnableFacet,
            operableFacet: operableFacet,
            diamondFactory: diamondPackageFactory
        });

        detfTokenPkg = IERC20MintBurnOwnableOperableDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol:ERC20MintBurnOwnableOperableDFPkg"),
                    abi.encode(pkgInit),
                    keccak256("ComposedStableCommonDetf_Integrated_DETFTokenPkg")
                )
            )
        );

        detfToken = IERC20(
            detfTokenPkg.deployToken(
                "DETF Token", "DETF", 18, owner, keccak256("ComposedStableCommonDetf_Integrated_DETFToken")
            )
        );
    }

    function _authorizeDetfTokenOperator(address operator_) internal {
        vm.prank(owner);
        IOperable(address(detfToken)).setOperator(operator_, true);
    }

    function _deployPricingPools() internal {
        stablePoolFactory = _deployStablePoolFactory("ComposedStableCommonDetfStableFactory");
        commonPoolFactory = _deployStablePoolFactory("ComposedStableCommonDetfCommonFactory");

        address[] memory composedPoolTokens = new address[](2);
        composedPoolTokens[0] = address(daiUsdcVault);
        composedPoolTokens[1] = address(weth);
        TokenConfig[] memory composedPoolTokenConfigs = vault.buildTokenConfig(composedPoolTokens.asIERC20());
        IERC20[] memory sortedComposedPoolTokens = _tokenAddresses(composedPoolTokenConfigs).asIERC20();

        stablePool = IStablePool(
            _createStablePool(
                stablePoolFactory,
                StablePoolSpec({
                    name: "Stable DETF Pool", symbol: "sDETF", poolCreator: owner, label: "StableDetfPool"
                }),
                composedPoolTokenConfigs
            )
        );
        commonPool = IStablePool(
            _createStablePool(
                commonPoolFactory,
                StablePoolSpec({
                    name: "Common DETF Pool", symbol: "cDETF", poolCreator: owner, label: "CommonDetfPool"
                }),
                composedPoolTokenConfigs
            )
        );

        stablePoolAdapter = _deployPoolAdapter(
            address(stablePool), IERC20(address(stablePool)), sortedComposedPoolTokens, "StablePoolAdapter"
        );
        commonPoolAdapter = _deployPoolAdapter(
            address(commonPool), IERC20(address(commonPool)), sortedComposedPoolTokens, "CommonPoolAdapter"
        );
    }

    function _createReservePool(TokenConfig[] memory tokenConfigs_) internal returns (address poolAddress_) {
        uint256[] memory weights = new uint256[](3);
        weights[0] = 333333333333333333;
        weights[1] = 333333333333333333;
        weights[2] = 1000000000000000000 - weights[0] - weights[1];

        PoolRoleAccounts memory roleAccounts;
        roleAccounts.poolCreator = owner;

        poolAddress_ = IWeightedPoolFactory(testPoolFactory)
            .create(
                "Reserve DETF Pool",
                "rDETF",
                tokenConfigs_,
                weights,
                roleAccounts,
                0.003e18,
                address(0),
                false,
                false,
                keccak256("Reserve DETF Pool_rDETF")
            );
        vm.label(poolAddress_, "ReserveDetfPool");
    }

    function _deployStablePoolFactory(string memory saltLabel_) internal returns (IStablePoolFactory factory_) {
        factory_ = IStablePoolFactory(
            create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(create3Factory, "lib/crane/contracts/external/balancer/v3/pool-stable/contracts/StablePoolFactory.sol:StablePoolFactory"),
                abi.encode(vault, uint32(365 days), "Factory v1", "Pool v1"),
                keccak256(bytes(saltLabel_))
            )
        );
    }

    function _createStablePool(
        IStablePoolFactory factory_,
        StablePoolSpec memory spec_,
        TokenConfig[] memory tokenConfigs_
    ) internal returns (address poolAddress_) {
        PoolRoleAccounts memory roleAccounts;
        roleAccounts.poolCreator = spec_.poolCreator;

        poolAddress_ = factory_.create(
            spec_.name,
            spec_.symbol,
            tokenConfigs_,
            200,
            roleAccounts,
            0.003e18,
            address(0),
            false,
            false,
            _stablePoolSalt(spec_)
        );
        vm.label(poolAddress_, spec_.label);
    }

    function _stablePoolSalt(StablePoolSpec memory spec_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(spec_.name, spec_.symbol, spec_.poolCreator));
    }

    function _tokenAddresses(TokenConfig[] memory tokenConfigs_) internal pure returns (address[] memory tokens_) {
        tokens_ = new address[](tokenConfigs_.length);
        for (uint256 index = 0; index < tokenConfigs_.length; index++) {
            tokens_[index] = address(tokenConfigs_[index].token);
        }
    }

    function _indexOf(address[] memory tokens_, address token_) internal pure returns (uint256 index_) {
        for (uint256 index = 0; index < tokens_.length; index++) {
            if (tokens_[index] == token_) {
                return index;
            }
        }
        revert("token not found");
    }

    function _deployPoolAdapter(address pool_, IERC20 bptToken_, IERC20[] memory poolTokens_, string memory saltLabel_)
        internal
        returns (IStandardExchangeIn adapter_)
    {
        adapter_ = IStandardExchangeIn(
            create3Factory.create3WithArgs(
                ArtifactCreationCode.creationCode(create3Factory, "contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol:BalancerV3SinglePoolStandardExchange"),
                abi.encode(IRouter(address(router)), pool_, bptToken_, poolTokens_),
                keccak256(bytes(saltLabel_))
            )
        );
    }

    function _useFundedComposed(address instance_) internal {
        deployedDetfVault = instance_;
        detfToken = IERC20(instance_);
        detf = IDetf(instance_);
        IComposedStableCommonDetfInfo info_ = IComposedStableCommonDetfInfo(instance_);
        bondNFTVault = IDETFNFTVault(info_.bondNftVault());
        rebasingDetfToken = IRebasingClaimToken(info_.rebasingClaimToken());
        reservePool = IWeightedPool(info_.reservePool());
        (IERC20[] memory tokens_,,,) = vault.getPoolTokenInfo(address(reservePool));
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == detfToken) detfIndex = i_;
            else if (tokens_[i_] == IERC20(address(stablePool))) stablePoolBptIndex = i_;
            else commonPoolBptIndex = i_;
        }
    }

    function _seedPricingPools() internal {
        IERC20 payment_ = IERC20(address(dai));
        uint256 native_ = 200_000 * 10 ** IERC20Metadata(address(payment_)).decimals();
        deal(address(payment_), owner, native_, true);
        deal(address(weth), owner, 100_000e18, true);
        vm.startPrank(owner);
        payment_.approve(address(daiUsdcVault), native_);
        uint256 shares_ = IStandardExchangeIn(address(daiUsdcVault))
            .exchangeIn(payment_, native_, IERC20(address(daiUsdcVault)), 0, owner, false, block.timestamp);
        (IERC20[] memory tokens_,,,) = vault.getPoolTokenInfo(address(stablePool));
        uint256[] memory amounts_ = new uint256[](2);
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            amounts_[i_] = address(tokens_[i_]) == address(daiUsdcVault) ? shares_ / 2 : 50_000e18;
            _approvePermit2ToRouter(address(tokens_[i_]));
        }
        router.initialize(address(stablePool), tokens_, amounts_, 0, false, "");
        router.initialize(address(commonPool), tokens_, amounts_, 0, false, "");
        vm.stopPrank();
        assertGe(IERC20(address(stablePool)).balanceOf(owner), 10_000e18, "funded stable seeds");
        assertGe(IERC20(address(commonPool)).balanceOf(owner), 10_000e18, "funded common seeds");
    }

    function _buyFixtureBond(address who_) internal returns (uint256 id_) {
        _bootstrapReserveGraph();
        IERC20 input_ = IERC20(address(stablePool));
        uint256 amount_ = 10e18;
        vm.prank(owner);
        input_.transfer(who_, amount_);
        vm.startPrank(who_);
        input_.approve(deployedDetfVault, amount_);
        (id_,) = IFundedComposedBonding(deployedDetfVault).bond(input_, amount_, 30 days, who_, block.timestamp);
        vm.stopPrank();
        _assertBondPrincipalIsFunded(deployedDetfVault, id_, who_);
    }

    function _buyFixtureRaw(address who_) internal returns (uint256 paid_) {
        _bootstrapReserveGraph();
        IERC20 input_ = IERC20(address(stablePool));
        uint256 amount_ = 10e18;
        vm.prank(owner);
        input_.transfer(who_, amount_);
        uint256 quote_ = IStandardExchangeIn(deployedDetfVault).previewExchangeIn(input_, amount_, detfToken);
        assertGt(quote_, 0, "funded raw DETF quote");
        vm.startPrank(who_);
        input_.approve(deployedDetfVault, amount_);
        paid_ = IStandardExchangeIn(deployedDetfVault)
            .exchangeIn(input_, amount_, detfToken, quote_, who_, false, block.timestamp);
        vm.stopPrank();
        assertEq(paid_, quote_);
    }
}
