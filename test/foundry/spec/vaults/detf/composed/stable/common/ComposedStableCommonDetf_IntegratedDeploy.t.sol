// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ICreate3FactoryProxy} from '@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol';
import {CastingHelpers} from '@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/CastingHelpers.sol';
import {IFacet} from '@crane/contracts/interfaces/IFacet.sol';
import {IERC20} from '@crane/contracts/interfaces/IERC20.sol';
import {IERC20MintBurn} from '@crane/contracts/interfaces/IERC20MintBurn.sol';
import {IPermit2} from '@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol';
import {IStablePool} from '@crane/contracts/external/balancer/v3/interfaces/contracts/pool-stable/IStablePool.sol';
import {IRouter} from '@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IRouter.sol';
import {StablePoolFactory} from '@crane/contracts/external/balancer/v3/pool-stable/contracts/StablePoolFactory.sol';
import {WeightedPoolFactory} from '@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol';
import {IOperable} from '@crane/contracts/interfaces/IOperable.sol';
import {OperableFacet} from '@crane/contracts/access/operable/OperableFacet.sol';
import {
    IERC20MintBurnOwnableOperableDFPkg,
    ERC20MintBurnOwnableOperableDFPkg
} from '@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol';
import {ERC20MintBurnOwnableFacet} from '@crane/contracts/tokens/ERC20/ERC20MintBurnOwnableFacet.sol';
import {TokenConfig, PoolRoleAccounts} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol';
import {IWeightedPool} from '@crane/contracts/interfaces/protocols/dexes/balancer/v3/IWeightedPool.sol';

import {IDETF} from 'contracts/interfaces/IDETF.sol';
import {IComposedStableCommonDetfBondNFTVault} from 'contracts/interfaces/IComposedStableCommonDetfBondNFTVault.sol';
import {IComposedStableCommonDetfBonding} from 'contracts/interfaces/IComposedStableCommonDetfBonding.sol';
import {IRebasingClaimToken} from 'contracts/interfaces/IRebasingClaimToken.sol';
import {IStandardExchangeIn} from 'contracts/interfaces/IStandardExchangeIn.sol';
import {IStandardExchangeOut} from 'contracts/interfaces/IStandardExchangeOut.sol';
import {IStandardVaultPkg} from 'contracts/interfaces/IStandardVaultPkg.sol';
import {IVaultRegistryDeployment} from 'contracts/interfaces/IVaultRegistryDeployment.sol';
import {IVaultRegistryVaultQuery} from 'contracts/interfaces/IVaultRegistryVaultQuery.sol';
import {IBalancerV3StandardExchangeRouterProxy} from 'contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol';
import {TestBase_BalancerV3StandardExchangeRouter} from 'contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol';
import {BalancerV3SinglePoolStandardExchange} from 'contracts/protocols/dexes/balancer/v3/pools/BalancerV3SinglePoolStandardExchange.sol';
import {VaultComponentFactoryService} from 'contracts/vaults/VaultComponentFactoryService.sol';
import {ComposedStableCommonDetfRepo} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfRepo.sol';
import {
    ComposedStableCommonDetf_Component_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetf_Component_FactoryService.sol';
import {
    IComposedStableCommonDetfDFPkg
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfDFPkg.sol';
import {
    ComposedStableCommonDetf_Facet_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetf_Facet_FactoryService.sol';
import {
    ComposedStableCommonDetf_Pkg_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetf_Pkg_FactoryService.sol';
import {
    IComposedStableCommonDetfBondNFTVaultDFPkg
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVaultDFPkg.sol';
import {
    ComposedStableCommonDetfBondNFTVault_Facet_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVault_Facet_FactoryService.sol';
import {
    ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/ComposedStableCommonDetfBondNFTVault_Pkg_FactoryService.sol';
import {
    IRebasingDETFTokenDFPkg
} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFTokenDFPkg.sol';
import {
    RebasingDETFToken_Facet_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFToken_Facet_FactoryService.sol';
import {
    RebasingDETFToken_Pkg_FactoryService
} from 'contracts/vaults/detf/composed/stable/common/RebasingDETFToken_Pkg_FactoryService.sol';
import {ERC721Facet} from '@crane/contracts/tokens/ERC721/ERC721Facet.sol';
import {IMultiStepOwnable} from '@crane/contracts/interfaces/IMultiStepOwnable.sol';
import {IDetf} from 'contracts/interfaces/detf/IDetf.sol';
import {IDETFNFTVault} from 'contracts/interfaces/IDETFNFTVault.sol';
import {ThresholdMode} from 'contracts/vaults/detf/core/DETFThresholdPolicy.sol';

contract ComposedStableCommonDetf_IntegratedDeploy_Test is TestBase_BalancerV3StandardExchangeRouter {
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
    IFacet internal erc721Facet;
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

    StablePoolFactory internal stablePoolFactory;
    StablePoolFactory internal commonPoolFactory;
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

        IComposedStableCommonDetfDFPkg.PkgArgs memory pkgArgs =
            ComposedStableCommonDetf_Component_FactoryService.buildPkgArgs(
                ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfPricingConfig({
                    reservePool: reservePool,
                    bondNftVault: bondNFTVault,
                    rebasingDetfToken: rebasingDetfToken,
                    detfToken: IERC20(address(detfToken)),
                    stablePoolBpt: IERC20(address(stablePool)),
                    commonPoolBpt: IERC20(address(commonPool)),
                    rateAsset: weth,
                    stablePoolExitPricer: stablePoolAdapter,
                    commonPoolExitPricer: commonPoolAdapter,
                    permit2: IPermit2(address(permit2)),
                    balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
                    stablePool: stablePool,
                    commonPool: commonPool,
                    reservePoolEntryRouter: reservePoolAdapter,
                    detfIndex: detfIndex,
                    stablePoolBptIndex: stablePoolBptIndex,
                    commonPoolBptIndex: commonPoolBptIndex,
                    mintThreshold: mintTh_,
                    burnThreshold: burnTh_,
                    routes: routes,
                    thresholdMode: mode_
                })
            );

        vm.startPrank(owner);
        vault_ = IVaultRegistryDeployment(address(indexedexManager)).deployVault(
            IStandardVaultPkg(address(detfPkg)), abi.encode(pkgArgs)
        );
        vm.stopPrank();

        _authorizeDetfTokenOperator(vault_);
        // Secondary instances share bond/rebasing companions already owned by the setUp vault —
        // do not reassign protocol DETF or bond ownership here (NotOwner on rebasing token).
    }

    function setUp() public virtual override {
        super.setUp();

        detf = IDetf(makeAddr('detf'));
        _deployDetfToken();

        multiAssetBasicVaultFacet = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacet = create3Factory.deployMultiAssetStandardVaultFacet();

        _deployPricingPools();
        _deployCompanions();

        bondingFacet = create3Factory.deployComposedStableCommonDetfBondingFacet();
        exchangeInFacet = create3Factory.deployComposedStableCommonDetfExchangeInFacet();
        exchangeOutQueryFacet = create3Factory.deployComposedStableCommonDetfExchangeOutQueryFacet();
        pricingFacet = create3Factory.deployRebasingDetfTokenPricingFacet();

        vm.startPrank(owner);
        detfPkg = IVaultRegistryDeployment(address(indexedexManager)).deployComposedStableCommonDetfDFPkg(
            ComposedStableCommonDetf_Component_FactoryService.buildPkgInit(
                ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfFacets({
                    multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                    multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                    bondingFacet: bondingFacet,
                    exchangeInFacet: exchangeInFacet,
                    exchangeOutQueryFacet: exchangeOutQueryFacet,
                    pricingFacet: pricingFacet
                }),
                ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfInfra({
                    vaultRegistryDeployment: indexedexManager
                })
            )
        );
        vm.stopPrank();

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

        IComposedStableCommonDetfDFPkg.PkgArgs memory pkgArgs =
            ComposedStableCommonDetf_Component_FactoryService.buildPkgArgs(
                ComposedStableCommonDetf_Component_FactoryService.ComposedStableCommonDetfPricingConfig({
                    reservePool: reservePool,
                    bondNftVault: bondNFTVault,
                    rebasingDetfToken: rebasingDetfToken,
                    detfToken: IERC20(address(detfToken)),
                    stablePoolBpt: IERC20(address(stablePool)),
                    commonPoolBpt: IERC20(address(commonPool)),
                    rateAsset: weth,
                    stablePoolExitPricer: stablePoolAdapter,
                    commonPoolExitPricer: commonPoolAdapter,
                    permit2: IPermit2(address(permit2)),
                    balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
                    stablePool: stablePool,
                    commonPool: commonPool,
                    reservePoolEntryRouter: reservePoolAdapter,
                    detfIndex: detfIndex,
                    stablePoolBptIndex: stablePoolBptIndex,
                    commonPoolBptIndex: commonPoolBptIndex,
                    mintThreshold: _composedMintThreshold(),
                    burnThreshold: _composedBurnThreshold(),
                    routes: routes,
                    thresholdMode: _composedThresholdMode()
                })
            );

        vm.startPrank(owner);
        deployedDetfVault = IVaultRegistryDeployment(address(indexedexManager)).deployVault(
            IStandardVaultPkg(address(detfPkg)), abi.encode(pkgArgs)
        );
        vm.stopPrank();

        _authorizeDetfTokenOperator(deployedDetfVault);
        _transferBondVaultOwnership(deployedDetfVault);
        vm.prank(owner);
        rebasingDetfToken.setDetf(deployedDetfVault);
        _transferRebasingDetfTokenOwnership(deployedDetfVault);
    }

    function test_deployVault_surfacesRealCompanionReferences() public view {
        assertTrue(IVaultRegistryVaultQuery(address(indexedexManager)).isVault(deployedDetfVault), 'vault registered');
        assertEq(IDETF(deployedDetfVault).bondNftVault(), address(bondNFTVault), 'bond vault wired');
        assertEq(IDETF(deployedDetfVault).detfNFTId(), bondNFTVault.detfNFTId(), 'protocol nft id surfaced');
        assertEq(IDETF(deployedDetfVault).rebasingDetfToken(), address(rebasingDetfToken), 'rebasing token wired');
        assertEq(IDETF(deployedDetfVault).reservePool(), address(reservePool), 'reserve pool wired');
    }

    function test_deployVault_exposesBondAndExchangeEntryPoints() public view {
        address[] memory acceptedTokens = IComposedStableCommonDetfBonding(deployedDetfVault).acceptedBondTokens();

        assertEq(acceptedTokens.length, 1, 'accepted token count');
        assertEq(acceptedTokens[0], address(dai), 'accepted bond token');
        assertTrue(
            IComposedStableCommonDetfBonding(deployedDetfVault).isAcceptedBondToken(IERC20(address(dai))),
            'bond token accepted'
        );
        assertEq(
            IStandardExchangeIn(deployedDetfVault).previewExchangeIn(IERC20(address(dai)), 0, IERC20(address(detfToken))),
            0,
            'zero amount mint preview'
        );
        assertEq(
            IStandardExchangeOut(deployedDetfVault).previewExchangeOut(IERC20(address(detfToken)), IERC20(address(dai)), 0),
            0,
            'zero amount burn preview'
        );
    }

    function test_deployVault_preservesCompanionSpecialPositionState() public view {
        IComposedStableCommonDetfBondNFTVault deployedBondVault =
            IComposedStableCommonDetfBondNFTVault(IDETF(deployedDetfVault).bondNftVault());
        IRebasingClaimToken deployedRebasingToken = IRebasingClaimToken(IDETF(deployedDetfVault).rebasingDetfToken());
        uint256 detfNftId = deployedBondVault.detfNFTId();
        uint256 feeRecipientNftId = deployedBondVault.feeRecipientNFTId();

        assertEq(deployedBondVault.ownerOf(detfNftId), address(deployedBondVault), 'protocol nft initialized');
        assertTrue(deployedBondVault.ownerOf(feeRecipientNftId) != address(0), 'fee recipient nft minted');
        assertEq(address(deployedBondVault.rewardToken()), address(detfToken), 'bond vault reward token wired');
        assertEq(deployedRebasingToken.detfNFTId(), detfNftId, 'rebasing token protocol nft');
        assertEq(address(deployedRebasingToken.rateAsset()), address(weth), 'rebasing common token wired');
    }

    function test_deployVault_zeroAmountPricingQueriesShortCircuitSafely() public view {
        (uint256 detfAmount, uint256 stableBptAmount, uint256 commonBptAmount) =
            IDETF(deployedDetfVault).previewReservePoolDecomposition(0);

        assertEq(IDETF(deployedDetfVault).previewRebasingDetfTokenReserveBpt(0), 0, 'zero richir reserve bpt');
        assertEq(IDETF(deployedDetfVault).previewRebasingDetfTokenEthValue(0), 0, 'zero reserve bpt value');
        assertEq(detfAmount, 0, 'zero reserve detf leg');
        assertEq(stableBptAmount, 0, 'zero reserve stable leg');
        assertEq(commonBptAmount, 0, 'zero reserve common leg');
    }

    function test_exchangeIn_reserveEntry_mintsRealDetfToken() public {
        _bootstrapReserveGraph();

        uint256 amountIn = 1_000e18;
        uint256 previewOut = IStandardExchangeIn(deployedDetfVault).previewExchangeIn(dai, amountIn, detfToken);
        uint256 supplyBefore = detfToken.totalSupply();
        uint256 reserveBalanceBefore = IERC20(address(reservePool)).balanceOf(deployedDetfVault);

        vm.startPrank(alice);
        dai.approve(deployedDetfVault, amountIn);
        uint256 amountOut = IStandardExchangeIn(deployedDetfVault).exchangeIn(
            dai,
            amountIn,
            detfToken,
            0,
            alice,
            false,
            block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(previewOut, 0, 'preview mint out');
        assertGe(amountOut, previewOut, 'execute respects preview');
        assertEq(detfToken.balanceOf(alice), amountOut, 'alice detf balance');
        assertGe(detfToken.totalSupply() - supplyBefore, amountOut, 'real detf token minted');
        assertGt(IERC20(address(reservePool)).balanceOf(deployedDetfVault), reserveBalanceBefore, 'reserve inventory increased');
    }

    function test_bond_sellNft_and_redeemRichir_onProductionGraph() public {
        _bootstrapReserveGraph();

        uint256 amountIn = 1_000e18;
        uint256 lockDuration = 30 days;
        uint256 protocolSharesBefore = bondNFTVault.originalSharesOf(bondNFTVault.detfNFTId());
        uint256 wethBefore = weth.balanceOf(alice);

        vm.startPrank(alice);
        dai.approve(deployedDetfVault, amountIn);
        (uint256 tokenId, uint256 shares) = IComposedStableCommonDetfBonding(deployedDetfVault).bond(
            dai,
            amountIn,
            lockDuration,
            alice, block.timestamp + 1
        );
        vm.stopPrank();

        assertGt(shares, 0, 'bond shares minted');
        assertEq(bondNFTVault.ownerOf(tokenId), alice, 'bond nft owner');
        assertEq(bondNFTVault.originalSharesOf(tokenId), shares, 'bond position tracked');

        vm.prank(alice);
        uint256 rebasingClaimMinted = IComposedStableCommonDetfBonding(deployedDetfVault).sellNFT(tokenId, alice);

        uint256 redeemPreview = rebasingDetfToken.previewRedeem(rebasingClaimMinted);

        assertGt(rebasingClaimMinted, 0, 'richir minted');
        assertGt(redeemPreview, 0, 'richir redeem preview');
        assertGt(bondNFTVault.originalSharesOf(bondNFTVault.detfNFTId()), protocolSharesBefore, 'protocol nft absorbed principal');
        assertEq(rebasingDetfToken.balanceOf(alice), rebasingClaimMinted, 'alice richir balance');

        vm.prank(alice);
        uint256 wethOut = rebasingDetfToken.redeem(rebasingClaimMinted, alice, false);

        assertGe(wethOut, redeemPreview, 'redeem meets preview');
        assertEq(rebasingDetfToken.balanceOf(alice), 0, 'richir burned on redeem');
        assertEq(weth.balanceOf(alice) - wethBefore, wethOut, 'alice received weth');
    }

    function _bootstrapReserveGraph() internal {
        uint256 vaultAssetIn = 20_000e18;
        uint256 poolWethIn = 10_000e18;
        uint256 detfMintAmount = 2e18;
        uint256 detfReserveIn = 1e18;

        deal(address(dai), owner, vaultAssetIn, true);
        deal(address(weth), owner, poolWethIn * 2, true);

        vm.startPrank(owner);
        dai.approve(address(daiUsdcVault), vaultAssetIn);
        uint256 vaultShares = IStandardExchangeIn(address(daiUsdcVault)).exchangeIn(
            dai,
            vaultAssetIn,
            IERC20(address(daiUsdcVault)),
            0,
            owner,
            false,
            block.timestamp + 1
        );

        (IERC20[] memory composedTokens,,,) = vault.getPoolTokenInfo(address(stablePool));

        uint256 stableVaultShares = vaultShares / 2;
        uint256 commonVaultShares = vaultShares - stableVaultShares;
        uint256[] memory stableInitAmounts = new uint256[](2);
        uint256[] memory commonInitAmounts = new uint256[](2);
        if (address(composedTokens[0]) == address(daiUsdcVault)) {
            stableInitAmounts[0] = stableVaultShares;
            stableInitAmounts[1] = poolWethIn;
            commonInitAmounts[0] = commonVaultShares;
            commonInitAmounts[1] = poolWethIn;
        } else {
            stableInitAmounts[0] = poolWethIn;
            stableInitAmounts[1] = stableVaultShares;
            commonInitAmounts[0] = poolWethIn;
            commonInitAmounts[1] = commonVaultShares;
        }

        _approvePermit2ToRouter(address(daiUsdcVault));
        _approvePermit2ToRouter(address(weth));

        uint256 stableBpt = router.initialize(address(stablePool), composedTokens, stableInitAmounts, 0, false, '');
        uint256 commonBpt = router.initialize(address(commonPool), composedTokens, commonInitAmounts, 0, false, '');

        IERC20MintBurn(address(detfToken)).mint(owner, detfMintAmount);

        _approvePermit2ToRouter(address(detfToken));
        _approvePermit2ToRouter(address(stablePool));
        _approvePermit2ToRouter(address(commonPool));

        (IERC20[] memory reserveTokens,,,) = vault.getPoolTokenInfo(address(reservePool));

        uint256[] memory reserveInitAmounts = new uint256[](reserveTokens.length);
        for (uint256 index = 0; index < reserveTokens.length; index++) {
            if (address(reserveTokens[index]) == address(detfToken)) {
                reserveInitAmounts[index] = detfReserveIn;
            } else if (address(reserveTokens[index]) == address(stablePool)) {
                reserveInitAmounts[index] = stableBpt;
            } else if (address(reserveTokens[index]) == address(commonPool)) {
                reserveInitAmounts[index] = commonBpt;
            }
        }

        uint256 reserveBpt = router.initialize(address(reservePool), reserveTokens, reserveInitAmounts, 0, false, '');
        IERC20(address(reservePool)).transfer(deployedDetfVault, reserveBpt);
        vm.stopPrank();
    }

    function _approvePermit2ToRouter(address token_) internal {
        IERC20(token_).approve(address(permit2), type(uint256).max);
        permit2.approve(token_, address(router), type(uint160).max, type(uint48).max);
    }

    function _deployCompanions() internal {
        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256('ComposedStableCommonDetf_Integrated_ERC721Facet')
            )
        );
        bondNFTVaultFacet = create3Factory.deployComposedStableCommonDetfBondNFTVaultFacet();
        rebasingDetfTokenFacet = create3Factory.deployRebasingDETFTokenFacet();

        vm.startPrank(owner);
        bondNFTVaultPkg = IVaultRegistryDeployment(address(indexedexManager)).deployComposedStableCommonDetfBondNFTVaultDFPkg(
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
                'Composed Stable Bond NFT Vault',
                'csBOND',
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
            rebasingDetfTokenPkg.deployToken(
                IDETF(address(detf)),
                bondNFTVault,
                weth,
                bondNFTVault.detfNFTId(),
                owner
            )
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
                type(OperableFacet).creationCode,
                keccak256('ComposedStableCommonDetf_Integrated_OperableFacet')
            )
        );
        erc20MintBurnOwnableFacet = IFacet(
            create3Factory.deployFacet(
                type(ERC20MintBurnOwnableFacet).creationCode,
                keccak256('ComposedStableCommonDetf_Integrated_ERC20MintBurnOwnableFacet')
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
                    type(ERC20MintBurnOwnableOperableDFPkg).creationCode,
                    abi.encode(pkgInit),
                    keccak256('ComposedStableCommonDetf_Integrated_DETFTokenPkg')
                )
            )
        );

        detfToken = IERC20(
            detfTokenPkg.deployToken(
                'DETF Token',
                'DETF',
                18,
                owner,
                keccak256('ComposedStableCommonDetf_Integrated_DETFToken')
            )
        );
    }

    function _authorizeDetfTokenOperator(address operator_) internal {
        vm.prank(owner);
        IOperable(address(detfToken)).setOperator(operator_, true);
    }

    function _deployPricingPools() internal {
        stablePoolFactory = _deployStablePoolFactory('ComposedStableCommonDetfStableFactory');
        commonPoolFactory = _deployStablePoolFactory('ComposedStableCommonDetfCommonFactory');

        address[] memory composedPoolTokens = new address[](2);
        composedPoolTokens[0] = address(daiUsdcVault);
        composedPoolTokens[1] = address(weth);
        TokenConfig[] memory composedPoolTokenConfigs = vault.buildTokenConfig(composedPoolTokens.asIERC20());
        IERC20[] memory sortedComposedPoolTokens = _tokenAddresses(composedPoolTokenConfigs).asIERC20();

        stablePool = IStablePool(
            _createStablePool(
                stablePoolFactory,
                StablePoolSpec({name: 'Stable DETF Pool', symbol: 'sDETF', poolCreator: owner, label: 'StableDetfPool'}),
                composedPoolTokenConfigs
            )
        );
        commonPool = IStablePool(
            _createStablePool(
                commonPoolFactory,
                StablePoolSpec({name: 'Common DETF Pool', symbol: 'cDETF', poolCreator: owner, label: 'CommonDetfPool'}),
                composedPoolTokenConfigs
            )
        );

        address[] memory reservePoolTokens = new address[](3);
        reservePoolTokens[0] = address(detfToken);
        reservePoolTokens[1] = address(stablePool);
        reservePoolTokens[2] = address(commonPool);
        TokenConfig[] memory reservePoolTokenConfigs = vault.buildTokenConfig(reservePoolTokens.asIERC20());
        address[] memory sortedReservePoolTokens = _tokenAddresses(reservePoolTokenConfigs);
        detfIndex = _indexOf(sortedReservePoolTokens, address(detfToken));
        stablePoolBptIndex = _indexOf(sortedReservePoolTokens, address(stablePool));
        commonPoolBptIndex = _indexOf(sortedReservePoolTokens, address(commonPool));
        reservePool = IWeightedPool(_createReservePool(reservePoolTokenConfigs));

        stablePoolAdapter = _deployPoolAdapter(address(stablePool), IERC20(address(stablePool)), sortedComposedPoolTokens, 'StablePoolAdapter');
        commonPoolAdapter = _deployPoolAdapter(address(commonPool), IERC20(address(commonPool)), sortedComposedPoolTokens, 'CommonPoolAdapter');
        reservePoolAdapter = _deployPoolAdapter(
            address(reservePool),
            IERC20(address(reservePool)),
            sortedReservePoolTokens.asIERC20(),
            'ReservePoolAdapter'
        );
    }

    function _createReservePool(TokenConfig[] memory tokenConfigs_) internal returns (address poolAddress_) {
        uint256[] memory weights = new uint256[](3);
        weights[0] = 333333333333333333;
        weights[1] = 333333333333333333;
        weights[2] = 1000000000000000000 - weights[0] - weights[1];

        PoolRoleAccounts memory roleAccounts;
        roleAccounts.poolCreator = owner;

        poolAddress_ = WeightedPoolFactory(testPoolFactory).create(
            'Reserve DETF Pool',
            'rDETF',
            tokenConfigs_,
            weights,
            roleAccounts,
            0.003e18,
            address(0),
            false,
            false,
            keccak256('Reserve DETF Pool_rDETF')
        );
        vm.label(poolAddress_, 'ReserveDetfPool');
    }

    function _deployStablePoolFactory(string memory saltLabel_) internal returns (StablePoolFactory factory_) {
        factory_ = StablePoolFactory(
            create3Factory.create3WithArgs(
                type(StablePoolFactory).creationCode,
                abi.encode(vault, uint32(365 days), 'Factory v1', 'Pool v1'),
                keccak256(bytes(saltLabel_))
            )
        );
    }

    function _createStablePool(
        StablePoolFactory factory_,
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
        revert('token not found');
    }

    function _deployPoolAdapter(
        address pool_,
        IERC20 bptToken_,
        IERC20[] memory poolTokens_,
        string memory saltLabel_
    ) internal returns (IStandardExchangeIn adapter_) {
        adapter_ = IStandardExchangeIn(
            create3Factory.create3WithArgs(
                type(BalancerV3SinglePoolStandardExchange).creationCode,
                abi.encode(IRouter(address(router)), pool_, bptToken_, poolTokens_),
                keccak256(bytes(saltLabel_))
            )
        );
    }
}