// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {WeightedPoolFactory} from
    "@crane/contracts/external/balancer/v3/pool-weighted/contracts/WeightedPoolFactory.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IPool} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IPool.sol";
import {MockERC20} from "@crane/contracts/test/mocks/MockERC20.sol";

import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardVaultPkg} from "contracts/interfaces/IStandardVaultPkg.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    TestBase_BalancerV3StandardExchangeRouter
} from "contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol";
import {
    IStandardExchangeRateProviderDFPkg,
    StandardExchangeRateProviderDFPkg
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderDFPkg.sol";
import {
    StandardExchangeRateProviderFacet
} from "contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IDetfSelfNftInventoryDFPkg} from "contracts/vaults/detf/common/factory/nft/IDetfSelfNftInventoryDFPkg.sol";
import {IDETFNFTVaultDFPkg} from "contracts/vaults/detf/common/bondNft/DETFNFTVaultDFPkg.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IRebasingClaimToken} from "contracts/interfaces/IRebasingClaimToken.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {
    IMultiVaultWeightedDetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {
    MultiVaultWeightedDetf_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetf_Component_FactoryService.sol";
import {
    IMultiVaultWeightedDetfBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol";
import {
    IMultiVaultWeightedDetfInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {
    ISingleStandardExchangeDETDFPkg
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETDFPkg.sol";
import {
    SingleStandardExchangeDETF_Component_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Component_FactoryService.sol";
import {
    SingleStandardExchangeDETF_Pkg_FactoryService
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETF_Pkg_FactoryService.sol";
import {
    ISingleStandardExchangeDETFBonding
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFBondingTarget.sol";
import {
    ISingleStandardExchangeDETFInfo
} from "contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/SingleStandardExchangeDETFInfoTarget.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {IRouter} from "@crane/contracts/interfaces/protocols/dexes/aerodrome/IRouter.sol";

/// @title TestBase_MultiVaultWeightedDetf
/// @notice Production MultiVaultWeightedDetf against production Aerodrome SE vaults (N up to 7).
abstract contract TestBase_MultiVaultWeightedDetf is TestBase_BalancerV3StandardExchangeRouter {
    using VaultComponentFactoryService for ICreate3FactoryProxy;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using MultiVaultWeightedDetf_Component_FactoryService for ICreate3FactoryProxy;
    using MultiVaultWeightedDetf_Component_FactoryService for IVaultRegistryDeployment;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;

    function _ensureProtocolNft(address instance_) internal {
        address nft_ = IMultiVaultWeightedDetfInfo(instance_).bondNftVault();
        if (nft_ == address(0)) return;
        if (IDETFNFTVault(nft_).detfNFTId() != 0) return;
        vm.prank(instance_);
        IDETFNFTVault(nft_).initializeDETFNFT();
    }

    function _warpPastUnlock(address instance_, uint256 tokenId_) internal {
        address nft_ = IMultiVaultWeightedDetfInfo(instance_).bondNftVault();
        uint256 unlock_ = IDETFNFTVault(nft_).unlockTimeOf(tokenId_);
        if (block.timestamp <= unlock_) {
            vm.warp(unlock_ + 1);
        }
    }
    uint8 internal constant MAX_LEGS = 7;

    IFacet internal multiAssetBasicVaultFacetDetf;
    IFacet internal multiAssetStandardVaultFacetDetf;
    IFacet internal multiVaultWeightedDetfExchangeInFacet;
    IFacet internal multiVaultWeightedDetfBondingFacet;
    IFacet internal multiVaultWeightedDetfInfoFacet;
    IFacet internal detfNFTVaultFacet;
    IFacet internal erc721Facet;
    IFacet internal singleSeDetfExchangeInFacet;

    IStandardExchangeRateProviderDFPkg internal rateProviderPkg;
    IDetfSelfNftInventoryDFPkg internal bondNftVaultPkg;
    IRebasingClaimTokenDFPkg internal rebasingClaimTokenPkg;
    IMultiVaultWeightedDetfDFPkg internal multiVaultWeightedDetfPkg;
    ISingleStandardExchangeDETDFPkg internal singleSeDetfPkg;

    /// @dev Up to 7 production Aerodrome SE vault legs.
    IStandardExchangeProxy[MAX_LEGS] internal seVaults;
    IERC20[MAX_LEGS] internal seShares;
    IERC20[MAX_LEGS] internal rateAssets;
    address[MAX_LEGS] internal legTokenA;
    address[MAX_LEGS] internal legTokenB;
    bool[MAX_LEGS] internal legStable;
    uint8 internal seVaultReady; // how many legs deployed

    // Back-compat aliases used by existing suites
    IStandardExchangeProxy internal seVault0;
    IStandardExchangeProxy internal seVault1;
    IERC20 internal seShare0;
    IERC20 internal seShare1;
    IERC20 internal rateAsset0;
    IERC20 internal rateAsset1;

    MockERC20 internal extraToken0;
    MockERC20 internal extraToken1;

    address internal detf;
    IMultiVaultWeightedDetfInfo internal detfInfo;
    IMultiVaultWeightedDetfBonding internal detfBonding;
    IStandardExchangeIn internal detfExchangeIn;

    function setUp() public virtual override {
        super.setUp();

        multiAssetBasicVaultFacetDetf = create3Factory.deployMultiAssetBasicVaultFacet();
        multiAssetStandardVaultFacetDetf = create3Factory.deployMultiAssetStandardVaultFacet();
        multiVaultWeightedDetfExchangeInFacet =
            MultiVaultWeightedDetf_Component_FactoryService.deployExchangeInFacet(create3Factory);
        multiVaultWeightedDetfBondingFacet =
            MultiVaultWeightedDetf_Component_FactoryService.deployBondingFacet(create3Factory);
        multiVaultWeightedDetfInfoFacet =
            MultiVaultWeightedDetf_Component_FactoryService.deployInfoFacet(create3Factory);
        singleSeDetfExchangeInFacet =
            SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);

        _deployRateProviderPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployMultiVaultWeightedDetfPkg();
        _deploySingleSeDetfPkg();

        // Ensure at least 2 SE vaults for default suites; N-range tests call _ensureSeVaults(N).
        _ensureSeVaults(2);
        seVault0 = seVaults[0];
        seVault1 = seVaults[1];
        seShare0 = seShares[0];
        seShare1 = seShares[1];
        rateAsset0 = rateAssets[0];
        rateAsset1 = rateAssets[1];

        detf = _deployDetfN(1, 0, 0, true);
        detfInfo = IMultiVaultWeightedDetfInfo(detf);
        detfBonding = IMultiVaultWeightedDetfBonding(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _ensureProtocolNft(detf);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Package deploys                                */
    /* ---------------------------------------------------------------------- */

    function _deployRateProviderPkg() internal {
        IFacet rateProviderFacet = IFacet(
            create3Factory.deployFacet(
                type(StandardExchangeRateProviderFacet).creationCode,
                keccak256("MultiVaultWeightedDetf_RateProviderFacet")
            )
        );
        rateProviderPkg = IStandardExchangeRateProviderDFPkg(
            address(
                create3Factory.deployPackageWithArgs(
                    type(StandardExchangeRateProviderDFPkg).creationCode,
                    abi.encode(
                        IStandardExchangeRateProviderDFPkg.PkgInit({
                            rateProviderFacet: rateProviderFacet,
                            diamondFactory: diamondPackageFactory
                        })
                    ),
                    keccak256("MultiVaultWeightedDetf_RateProviderDFPkg")
                )
            )
        );
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployDETFNFTVaultFacet();
        erc721Facet = IFacet(
            create3Factory.deployFacet(
                type(ERC721Facet).creationCode, keccak256("MultiVaultWeightedDetf_ERC721Facet")
            )
        );

        IDETFNFTVaultDFPkg.PkgInit memory nftPkgInit = DetfComponentFactoryService.buildDETFNFTVaultPkgInit(
            erc721Facet,
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
    }

    function _deployRebasingClaimTokenPkg() internal {
        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        rebasingClaimTokenPkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );
    }

    function _deployMultiVaultWeightedDetfPkg() internal {
        IMultiVaultWeightedDetfDFPkg.PkgInit memory pkgInit = IMultiVaultWeightedDetfDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: multiVaultWeightedDetfExchangeInFacet,
            bondingFacet: multiVaultWeightedDetfBondingFacet,
            infoFacet: multiVaultWeightedDetfInfoFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            diamondFactory: diamondPackageFactory
        });

        vm.startPrank(owner);
        multiVaultWeightedDetfPkg =
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(pkgInit);
        vm.stopPrank();
        vm.label(address(multiVaultWeightedDetfPkg), "MultiVaultWeightedDetfDFPkg");
    }

    function _deploySingleSeDetfPkg() internal {
        ISingleStandardExchangeDETDFPkg.PkgInit memory pkgInit = ISingleStandardExchangeDETDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacetDetf,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacetDetf,
            exchangeInFacet: singleSeDetfExchangeInFacet,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            balancerV3Router: IBalancerV3StandardExchangeRouterProxy(address(seRouter)),
            balancerV3Vault: IVault(address(vault)),
            weightedPoolFactory: WeightedPoolFactory(testPoolFactory),
            rateProviderPkg: rateProviderPkg,
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg,
            diamondFactory: diamondPackageFactory
        });
        vm.startPrank(owner);
        singleSeDetfPkg = SingleStandardExchangeDETF_Pkg_FactoryService.deploySingleStandardExchangeDETDFPkg(
            IVaultRegistryDeployment(address(indexedexManager)), pkgInit
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                    Production SE vault inventory                       */
    /* ---------------------------------------------------------------------- */

    /// @dev Deploy production Aerodrome SE vaults until `n` legs exist (max 7).
    function _ensureSeVaults(uint8 n) internal {
        require(n >= 1 && n <= MAX_LEGS, "n out of range");
        while (seVaultReady < n) {
            _deploySeVaultAt(seVaultReady);
            unchecked {
                ++seVaultReady;
            }
        }
    }

    function _deploySeVaultAt(uint8 index) internal {
        // All volatile — Aerodrome SE package reverts PoolMustNotBeStable.
        // 0 dai/usdc (router TestBase vault)
        // 1 dai/weth
        // 2 usdc/weth
        // 3 extra0/dai
        // 4 extra0/usdc
        // 5 extra0/weth
        // 6 extra1/dai
        if (index == 0) {
            seVaults[0] = daiUsdcVault;
            seShares[0] = IERC20(address(daiUsdcVault));
            rateAssets[0] = IERC20(address(dai));
            legTokenA[0] = address(dai);
            legTokenB[0] = address(usdc);
            legStable[0] = false;
            vm.label(address(seVaults[0]), "SeVault0_DaiUsdc");
            return;
        }

        if (address(extraToken0) == address(0)) {
            extraToken0 = new MockERC20("Extra0", "EX0", 18);
            extraToken1 = new MockERC20("Extra1", "EX1", 18);
        }

        address tokenA_;
        address tokenB_;
        IERC20 rate_;
        if (index == 1) {
            tokenA_ = address(dai);
            tokenB_ = address(weth);
            rate_ = IERC20(address(weth));
        } else if (index == 2) {
            tokenA_ = address(usdc);
            tokenB_ = address(weth);
            rate_ = IERC20(address(usdc));
        } else if (index == 3) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(dai);
            rate_ = IERC20(address(dai));
        } else if (index == 4) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(usdc);
            rate_ = IERC20(address(usdc));
        } else if (index == 5) {
            tokenA_ = address(extraToken0);
            tokenB_ = address(weth);
            rate_ = IERC20(address(weth));
        } else {
            tokenA_ = address(extraToken1);
            tokenB_ = address(dai);
            rate_ = IERC20(address(dai));
        }

        address poolAddr = aerodromePoolFactory.createPool(tokenA_, tokenB_, false);
        _seedPoolLiquidity(tokenA_, tokenB_, false, 1_000e18);

        address vaultAddr = aerodromeStandardExchangeDFPkg.deployVault(IPool(poolAddr));
        seVaults[index] = IStandardExchangeProxy(vaultAddr);
        seShares[index] = IERC20(vaultAddr);
        rateAssets[index] = rate_;
        legTokenA[index] = tokenA_;
        legTokenB[index] = tokenB_;
        legStable[index] = false;
        vm.label(vaultAddr, string(abi.encodePacked("SeVault", _u(index))));
    }

    function _seedPoolLiquidity(address tokenA_, address tokenB_, bool stable_, uint256 amount_) internal {
        _mintToken(tokenA_, address(this), amount_);
        _mintToken(tokenB_, address(this), amount_);
        IERC20(tokenA_).approve(address(aerodromeRouter), amount_);
        IERC20(tokenB_).approve(address(aerodromeRouter), amount_);
        aerodromeRouter.addLiquidity(
            tokenA_, tokenB_, stable_, amount_, amount_, 1, 1, address(this), block.timestamp + 1 hours
        );
    }

    function _mintToken(address token_, address to_, uint256 amount_) internal {
        if (token_ == address(weth)) {
            vm.deal(to_, amount_ + 1 ether);
            vm.prank(to_);
            weth.deposit{value: amount_}();
            if (to_ != address(this)) {
                // already on to_
            }
            return;
        }
        // dai/usdc and MockERC20 expose mint in this test stack
        (bool ok,) = token_.call(abi.encodeWithSignature("mint(address,uint256)", to_, amount_));
        if (!ok) {
            // fallback: some tokens mint to msg.sender
            MockERC20(token_).mint(to_, amount_);
        }
    }

    function _u(uint8 i) internal pure returns (string memory) {
        if (i == 0) return "0";
        if (i == 1) return "1";
        if (i == 2) return "2";
        if (i == 3) return "3";
        if (i == 4) return "4";
        if (i == 5) return "5";
        return "6";
    }

    /* ---------------------------------------------------------------------- */
    /*                         DETF instance deploys                          */
    /* ---------------------------------------------------------------------- */

    /// @param rated_ if true, set rateAsset per leg; if false all unrated.
    /// @dev Default mode Policy (PRD §16).
    function _deployDetfN(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_, bool rated_)
        internal
        returns (address detf_)
    {
        return _deployDetfN(n, mintThreshold_, burnThreshold_, rated_, ThresholdMode.Policy);
    }

    function _deployDetfN(
        uint8 n,
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        bool rated_,
        ThresholdMode mode_
    ) internal returns (address detf_) {
        _ensureSeVaults(n);
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(n, mintThreshold_, burnThreshold_, rated_, mode_);
        detf_ = _deployWithArgs(args);
        vm.label(detf_, string(abi.encodePacked("MultiVaultWeightedDetf_N", _u(n))));
    }

    function _buildPkgArgs(uint8 n, uint256 mintTh_, uint256 burnTh_, bool rated_)
        internal
        view
        returns (IMultiVaultWeightedDetfDFPkg.PkgArgs memory args)
    {
        return _buildPkgArgs(n, mintTh_, burnTh_, rated_, ThresholdMode.Policy);
    }

    function _buildPkgArgs(
        uint8 n,
        uint256 mintTh_,
        uint256 burnTh_,
        bool rated_,
        ThresholdMode mode_
    ) internal view returns (IMultiVaultWeightedDetfDFPkg.PkgArgs memory args) {
        args.vaults = new IStandardExchangeProxy[](n);
        args.vaultShares = new IERC20[](n);
        args.rateProviders = new IRateProvider[](n);
        args.rateAssets = new IERC20[](n);
        args.vaultWeights = new uint256[](n);
        args.name = string(abi.encodePacked("MVW N", _u(n)));
        args.symbol = string(abi.encodePacked("mvw", _u(n)));
        args.mintThreshold = mintTh_;
        args.burnThreshold = burnTh_;
        args.thresholdMode = mode_;
        args.expansionClosureRatePerSecond = 0;
        args.expansionCatchUpMaxSeconds = 0;
        args.expansionCatchUpCapBps = 0;
        _fillLegsAndWeights(args, n, rated_, 50e16);
    }

    function _fillLegsAndWeights(
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args,
        uint8 n,
        bool rated_,
        uint256 vaultWeightBudget_
    ) internal view {
        uint256 remaining_ = vaultWeightBudget_;
        for (uint256 i; i < n; ++i) {
            args.vaults[i] = seVaults[i];
            args.vaultShares[i] = seShares[i];
            args.rateProviders[i] = IRateProvider(address(0));
            args.rateAssets[i] = rated_ ? rateAssets[i] : IERC20(address(0));
            if (i + 1 == n) args.vaultWeights[i] = remaining_;
            else {
                args.vaultWeights[i] = remaining_ / (n - i);
                remaining_ -= args.vaultWeights[i];
            }
            if (args.vaultWeights[i] == 0) args.vaultWeights[i] = 1;
        }
        uint256 sumW_;
        for (uint256 i; i < n; ++i) {
            sumW_ += args.vaultWeights[i];
        }
        args.weightDetf = 1e18 - sumW_;
        if (args.weightDetf == 0) {
            args.vaultWeights[n - 1] -= 1;
            args.weightDetf = 1;
        }
    }

    function _deployWithArgs(IMultiVaultWeightedDetfDFPkg.PkgArgs memory args)
        internal
        returns (address detf_)
    {
        vm.startPrank(owner);
        detf_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    /// @dev Mixed: leg0 rated, remaining unrated (requires n>=2). Default Policy.
    function _deployDetfNMixedRated(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address detf_)
    {
        return _deployDetfNMixedRated(n, mintThreshold_, burnThreshold_, ThresholdMode.Policy);
    }

    function _deployDetfNMixedRated(
        uint8 n,
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        ThresholdMode mode_
    ) internal returns (address detf_) {
        _ensureSeVaults(n);
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(n, mintThreshold_, burnThreshold_, true, mode_);
        args.name = "MVW Mixed";
        args.symbol = "mvwM";
        for (uint256 i = 1; i < n; ++i) {
            args.rateAssets[i] = IERC20(address(0));
        }
        detf_ = _deployWithArgs(args);
    }

    /// @dev N=2 with both legs rated to the same rateAsset (distinct vaults). Default Policy.
    function _deployDetfN2SameRateAsset(uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address detf_)
    {
        return _deployDetfN2SameRateAsset(mintThreshold_, burnThreshold_, ThresholdMode.Policy);
    }

    function _deployDetfN2SameRateAsset(
        uint256 mintThreshold_,
        uint256 burnThreshold_,
        ThresholdMode mode_
    ) internal returns (address detf_) {
        // Legs 0 (dai/usdc) and 3 (extra0/dai) both rate as dai — distinct vaults.
        _ensureSeVaults(4);
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args;
        args.vaults = new IStandardExchangeProxy[](2);
        args.vaultShares = new IERC20[](2);
        args.rateProviders = new IRateProvider[](2);
        args.rateAssets = new IERC20[](2);
        args.vaultWeights = new uint256[](2);
        args.vaults[0] = seVaults[0];
        args.vaults[1] = seVaults[3];
        args.vaultShares[0] = IERC20(address(seVaults[0]));
        args.vaultShares[1] = IERC20(address(seVaults[3]));
        args.rateAssets[0] = IERC20(address(dai));
        args.rateAssets[1] = IERC20(address(dai));
        args.vaultWeights[0] = 20e16;
        args.vaultWeights[1] = 20e16;
        args.weightDetf = 60e16;
        args.mintThreshold = mintThreshold_;
        args.burnThreshold = burnThreshold_;
        args.thresholdMode = mode_;
        args.expansionClosureRatePerSecond = 0;
        args.expansionCatchUpMaxSeconds = 0;
        args.expansionCatchUpCapBps = 0;
        args.name = "MVW SameRate";
        args.symbol = "mvwSR";
        detf_ = _deployWithArgs(args);
    }

    // Back-compat wrappers
    function _deployDetfN1() internal returns (address) {
        return _deployDetfN(1, 0, 0, true);
    }

    function _deployDetfN2(uint256 mintThreshold_, uint256 burnThreshold_) internal returns (address) {
        return _deployDetfN(2, mintThreshold_, burnThreshold_, true);
    }

    /// @dev Dual-path always-allow when live (mint+burn math / multi-leg / adversarial suites).
    /// @dev Historical Policy mint=1 / burn=max is **illegal** under PRD §16.3 (`mint > burn`).
    ///      Always-allow is product **Open**. Kept name for call-site compatibility.
    function _deployOpenThresholdDetf() internal returns (address) {
        return _deployOpenModeDetfN(1);
    }

    /// @dev Same as `_deployOpenThresholdDetf` for N legs.
    function _deployOpenThresholdDetfN(uint8 n) internal returns (address) {
        return _deployOpenModeDetfN(n);
    }

    /// @dev Product Open mode: threshold gates always pass when live; live/inert still enforced.
    ///      Thresholds resolve/store (defaults for 0,0); gates ignore them.
    function _deployOpenModeDetfN(uint8 n) internal returns (address) {
        return _deployDetfN(n, 0, 0, true, ThresholdMode.Open);
    }

    /// @dev Legal extreme Policy pair (mint > burn) for T4b/T18 — mode remains Policy.
    function _deployExtremePolicyPairDetfN(uint8 n) internal returns (address) {
        return _deployDetfN(n, 2, 1, true, ThresholdMode.Policy);
    }

    /// @dev Policy mode with explicit custom mint/burn band (already resolved; non-zero).
    function _deployPolicyThresholdsN(uint8 n, uint256 mintThreshold_, uint256 burnThreshold_)
        internal
        returns (address)
    {
        return _deployDetfN(n, mintThreshold_, burnThreshold_, true, ThresholdMode.Policy);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Nested SE DETF                            */
    /* ---------------------------------------------------------------------- */

    function _deployNestedSingleSeDetfLive(address bonder, uint256 lpAmount)
        internal
        returns (address nested_)
    {
        return _deployNestedSingleSeDetfLive(bonder, lpAmount, ThresholdMode.Open);
    }

    /// @dev Nested Single SE DETF with explicit mode (outer/inner modes are independent).
    function _deployNestedSingleSeDetfLive(address bonder, uint256 lpAmount, ThresholdMode mode_)
        internal
        returns (address nested_)
    {
        _ensureSeVaults(1);
        ISingleStandardExchangeDETDFPkg.PkgArgs memory args = ISingleStandardExchangeDETDFPkg.PkgArgs({
            name: "Nested Single SE DETF",
            symbol: "nSSE",
            standardExchangeVault: seVaults[0],
            standardExchangeVaultShare: IERC20(address(0)),
            rateTarget: rateAssets[0],
            detfWeight: 0,
            vaultShareWeight: 0,
            mintThreshold: 0,
            burnThreshold: 0,
            thresholdMode: mode_,
            expansionClosureRatePerSecond: 0,
            expansionCatchUpMaxSeconds: 0,
            expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        nested_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(singleSeDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();

        uint256 seShares_ = _fundSeSharesLeg(0, bonder, lpAmount);
        vm.startPrank(bonder);
        seShares[0].approve(nested_, seShares_);
        ISingleStandardExchangeDETFBonding(nested_).bond(
            seShares[0], seShares_, DEFAULT_MIN_LOCK, bonder, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        require(ISingleStandardExchangeDETFInfo(nested_).isReserveLive(), "nested not live");
    }

    /// @dev Outer multi-vault with leg0 = nested Single SE DETF (unrated abstract 1:1), leg1 = production SE.
    /// @dev Historical (1, max) call sites: use Open mode overload for always-allow when live.
    function _deployOuterOverNested(address nestedDetf_, uint256 mintTh_, uint256 burnTh_)
        internal
        returns (address outer_)
    {
        // mint=1 burn=max was dual-path always-allow; map to Open under §16.3.
        if (mintTh_ == 1 && burnTh_ == type(uint256).max) {
            return _deployOuterOverNested(nestedDetf_, 0, 0, ThresholdMode.Open);
        }
        return _deployOuterOverNested(nestedDetf_, mintTh_, burnTh_, ThresholdMode.Policy);
    }

    function _deployOuterOverNested(
        address nestedDetf_,
        uint256 mintTh_,
        uint256 burnTh_,
        ThresholdMode mode_
    ) internal returns (address outer_) {
        _ensureSeVaults(2);
        IStandardExchangeProxy[] memory vaults_ = new IStandardExchangeProxy[](2);
        IERC20[] memory shares_ = new IERC20[](2);
        IRateProvider[] memory rps_ = new IRateProvider[](2);
        IERC20[] memory ras_ = new IERC20[](2);
        uint256[] memory weights_ = new uint256[](2);
        vaults_[0] = IStandardExchangeProxy(nestedDetf_);
        vaults_[1] = seVaults[1];
        shares_[0] = IERC20(nestedDetf_);
        shares_[1] = seShares[1];
        ras_[0] = IERC20(address(0)); // abstract 1:1 for nested DETF share
        ras_[1] = rateAssets[1];
        weights_[0] = 20e16;
        weights_[1] = 20e16;

        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args = IMultiVaultWeightedDetfDFPkg.PkgArgs({
            name: "Outer MVW Nested",
            symbol: "omvwN",
            vaults: vaults_,
            vaultShares: shares_,
            rateProviders: rps_,
            rateAssets: ras_,
            weightDetf: 60e16,
            vaultWeights: weights_,
            mintThreshold: mintTh_,
            burnThreshold: burnTh_,
            thresholdMode: mode_,
            expansionClosureRatePerSecond: 0,
            expansionCatchUpMaxSeconds: 0,
            expansionCatchUpCapBps: 0
        });
        vm.startPrank(owner);
        outer_ = indexedexManager.deployVault(
            IStandardVaultPkg(address(multiVaultWeightedDetfPkg)), abi.encode(args)
        );
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------------- */
    /*                         Fund / go-live helpers                         */
    /* ---------------------------------------------------------------------- */

    function _fundSeSharesLeg(uint8 leg, address to, uint256 amount) internal returns (uint256 shares_) {
        require(leg < seVaultReady, "leg not ready");
        address tokenA_ = legTokenA[leg];
        address tokenB_ = legTokenB[leg];
        bool stable_ = legStable[leg];

        _mintToken(tokenA_, to, amount);
        _mintToken(tokenB_, to, amount);

        vm.startPrank(to);
        IERC20(tokenA_).approve(address(aerodromeRouter), amount);
        IERC20(tokenB_).approve(address(aerodromeRouter), amount);
        (,, uint256 liquidity) = aerodromeRouter.addLiquidity(
            tokenA_, tokenB_, stable_, amount, amount, 1, 1, to, block.timestamp + 1 hours
        );
        address asset_ = seVaults[leg].asset();
        IERC20(asset_).approve(address(seVaults[leg]), liquidity);
        shares_ = seVaults[leg].deposit(liquidity, to);
        vm.stopPrank();
    }

    function _fundSeShares0(address to, uint256 lpAmount) internal returns (uint256 shares_) {
        shares_ = _fundSeSharesLeg(0, to, lpAmount);
    }

    function _fundSeShares1(address to, uint256 amount) internal returns (uint256 shares_) {
        shares_ = _fundSeSharesLeg(1, to, amount);
    }

    /// @dev Fund nested DETF shares by minting on nested after it is live (open threshold).
    function _fundNestedDetfShares(address nested_, address to, uint256 lpAmount)
        internal
        returns (uint256 nestedShares_)
    {
        uint256 seShares_ = _fundSeSharesLeg(0, to, lpAmount);
        vm.startPrank(to);
        seShares[0].approve(nested_, seShares_);
        nestedShares_ = IStandardExchangeIn(nested_).exchangeIn(
            seShares[0], seShares_, IERC20(nested_), 0, to, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev Multi-leg initializeReserve + bond(BPT). `lpAmount` used per leg.
    function _goLiveViaBptBond(address instance_, address user, uint256 lpAmount)
        internal
        returns (uint256 tokenId_, uint256 bpt_)
    {
        uint256 n_ = IMultiVaultWeightedDetfInfo(instance_).vaultCount();
        uint256[] memory amounts_ = new uint256[](n_);
        address[] memory shareTokens_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares();

        for (uint256 i; i < n_; ++i) {
            // Match share token to a known seVaults index or nested diamond.
            amounts_[i] = _fundSharesForInstanceLeg(instance_, i, user, lpAmount);
        }

        vm.startPrank(user);
        for (uint256 i; i < n_; ++i) {
            IERC20(shareTokens_[i]).approve(instance_, amounts_[i]);
        }
        bpt_ = IMultiVaultWeightedDetfBonding(instance_).initializeReserve(
            amounts_, block.timestamp + 1 hours
        );
        address pool_ = IMultiVaultWeightedDetfInfo(instance_).reservePool();
        IERC20(pool_).approve(instance_, bpt_);
        (tokenId_,) = IMultiVaultWeightedDetfBonding(instance_).bond(
            IERC20(pool_), bpt_, DEFAULT_MIN_LOCK, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _fundSharesForInstanceLeg(address instance_, uint256 legIndex_, address user, uint256 lpAmount)
        internal
        returns (uint256 shares_)
    {
        address share_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares()[legIndex_];
        address vault_ = IMultiVaultWeightedDetfInfo(instance_).underlyingVaults()[legIndex_];

        // Nested DETF: share is the nested diamond address.
        if (share_ == vault_ && !_isKnownSeVault(vault_)) {
            return _fundNestedDetfShares(vault_, user, lpAmount);
        }

        // Find matching seVaults slot
        for (uint8 i; i < seVaultReady; ++i) {
            if (address(seVaults[i]) == vault_ || address(seShares[i]) == share_) {
                return _fundSeSharesLeg(i, user, lpAmount);
            }
        }
        // Fallback: deposit into vault via asset()
        return _fundSeSharesLeg(0, user, lpAmount);
    }

    function _isKnownSeVault(address vault_) internal view returns (bool) {
        for (uint8 i; i < seVaultReady; ++i) {
            if (address(seVaults[i]) == vault_) return true;
        }
        return false;
    }

    function _mintOnLeg(address instance_, uint8 legIndex_, address user, uint256 lpAmount)
        internal
        returns (uint256 out_)
    {
        uint256 shares_ = _fundSharesForInstanceLeg(instance_, legIndex_, user, lpAmount);
        address shareToken_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares()[legIndex_];
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(IERC20(shareToken_), shares_, IERC20(instance_));
        vm.startPrank(user);
        IERC20(shareToken_).approve(instance_, shares_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(shareToken_), shares_, IERC20(instance_), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertEq(preview_, out_, "mint preview==exec");
    }

    function _burnToLeg(address instance_, uint8 legIndex_, address user, uint256 detfAmount_)
        internal
        returns (uint256 out_)
    {
        address shareToken_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares()[legIndex_];
        uint256 preview_ =
            IStandardExchangeIn(instance_).previewExchangeIn(IERC20(instance_), detfAmount_, IERC20(shareToken_));
        vm.startPrank(user);
        IERC20(instance_).approve(instance_, detfAmount_);
        out_ = IStandardExchangeIn(instance_).exchangeIn(
            IERC20(instance_), detfAmount_, IERC20(shareToken_), 0, user, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertApproxEqAbs(preview_, out_, 10, "burn preview~=exec");
    }

    function _assertInert(address instance_) internal view {
        assertFalse(IMultiVaultWeightedDetfInfo(instance_).isReserveLive(), "expected inert");
    }

    function _assertLive(address instance_) internal view {
        assertTrue(IMultiVaultWeightedDetfInfo(instance_).isReserveLive(), "expected live");
        assertTrue(IMultiVaultWeightedDetfInfo(instance_).reservePool() != address(0), "pool");
    }

    function _assertNoFreeInventory(address instance_) internal view {
        assertEq(IERC20(instance_).balanceOf(instance_), 0, "residual free detf");
        address[] memory shares_ = IMultiVaultWeightedDetfInfo(instance_).vaultShares();
        for (uint256 i; i < shares_.length; ++i) {
            assertEq(IERC20(shares_[i]).balanceOf(instance_), 0, "residual vault share");
        }
    }

    function _feeTo() internal view returns (address) {
        return address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo());
    }

    /* ---------------------------------------------------------------------- */
    /*                     Protocol compound test helpers                     */
    /* ---------------------------------------------------------------------- */

    /// @dev Enable non-zero seigniorage so mint/bond produce inventory DETF on the bond vault.
    function _enableSeigniorageIncentive(address instance_, uint256 incentiveWad_) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setSeigniorageIncentivePercentageOfVault(
            instance_, incentiveWad_
        );
        vm.stopPrank();
    }

    function _bondNftVault(address instance_) internal view returns (IDETFNFTVault) {
        return IDETFNFTVault(IMultiVaultWeightedDetfInfo(instance_).bondNftVault());
    }

    function _detfNftId(address instance_) internal view returns (uint256) {
        return _bondNftVault(instance_).detfNFTId();
    }

    /// @dev Protocol NFT principal (BPT share units) — claim rate path depends on this rising after compound.
    function _protocolNftPrincipal(address instance_) internal view returns (uint256) {
        IDETFNFTVault vault_ = _bondNftVault(instance_);
        return vault_.originalSharesOf(vault_.detfNFTId());
    }

    function _protocolPendingRewards(address instance_) internal view returns (uint256) {
        IDETFNFTVault vault_ = _bondNftVault(instance_);
        return vault_.pendingRewards(vault_.detfNFTId());
    }

    /// @dev Bootstrap open-mode multi-vault DETF, sell first BPT bond into protocol NFT so it has principal
    ///      shares, then create a second locked user bond and seed inventory via mint (seigniorage on).
    /// @return instance_ Open-mode DETF diamond.
    /// @return userBondId_ Second user bond still locked (for C3 claim-while-locked).
    function _setupProtocolRewardsLive(address bonder_, address minter_)
        internal
        returns (address instance_, uint256 userBondId_)
    {
        instance_ = _deployOpenModeDetfN(1);
        // 20% seigniorage incentive → inventory = afterFee * 10% (half of incentive).
        _enableSeigniorageIncentive(instance_, 0.20e18);

        // First BPT bond → live; sell to protocol so detf NFT earns reward share.
        // Keep sizes modest vs pool to avoid Balancer MaxInRatio on subsequent DETF-only joins.
        (uint256 firstId_,) = _goLiveViaBptBond(instance_, bonder_, 1_000e18);
        _warpPastUnlock(instance_, firstId_);
        vm.prank(bonder_);
        IMultiVaultWeightedDetfBonding(instance_).sellPositionToDetfNft(firstId_, 0, bonder_);
        assertGt(_protocolNftPrincipal(instance_), 0, "protocol nft has principal after sell");

        // Second vault-share bond: user keeps NFT (for claim-while-locked).
        uint256 seSharesBond_ = _fundSeShares0(bonder_, 200e18);
        vm.startPrank(bonder_);
        seShare0.approve(instance_, seSharesBond_);
        (userBondId_,) = IMultiVaultWeightedDetfBonding(instance_).bond(
            seShare0, seSharesBond_, DEFAULT_MIN_LOCK, bonder_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();

        // Mint seigniorage with inventory DETF into bond vault reward pool.
        uint256 seSharesMint_ = _fundSeShares0(minter_, 50e18);
        vm.startPrank(minter_);
        seShare0.approve(instance_, seSharesMint_);
        IStandardExchangeIn(instance_).exchangeIn(
            seShare0, seSharesMint_, IERC20(instance_), 0, minter_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    /// @dev Seed extra free DETF inventory on the bond vault (forces reward balance without another mint).
    ///      **Adds** to existing vault balance (does not set absolute) so `lastRewardTokenBalance`
    ///      accounting stays consistent with inventory already deposited via production mint/bond.
    function _seedBondVaultRewardDetf(address instance_, uint256 amount_) internal {
        address vault_ = address(_bondNftVault(instance_));
        uint256 before_ = IERC20(instance_).balanceOf(vault_);
        // Non-SUT controllability: forge deal adjusts ERC20 balance + totalSupply.
        deal(instance_, vault_, before_ + amount_, true);
    }

    /* ---------------------------------------------------------------------- */
    /*                  Natural expansion / price-shift helpers               */
    /* ---------------------------------------------------------------------- */

    /// @dev Warp wall-clock for expansion accrual (Foundry cheatcode).
    function _warp(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }

    /// @dev Real trade on underlying Aerodrome DAI/USDC pool (moves SE share rate provider).
    /// @param buyUsdc_ True = DAI→USDC (skew); false = USDC→DAI.
    function _shiftUnderlyingPrice(bool buyUsdc_, uint256 amountIn_) internal {
        address trader_ = bob;
        address tokenIn_ = buyUsdc_ ? address(dai) : address(usdc);
        address tokenOut_ = buyUsdc_ ? address(usdc) : address(dai);
        if (buyUsdc_) {
            dai.mint(trader_, amountIn_);
        } else {
            usdc.mint(trader_, amountIn_);
        }
        IRouter.Route[] memory routes_ = new IRouter.Route[](1);
        routes_[0] = IRouter.Route({
            from: tokenIn_,
            to: tokenOut_,
            stable: false,
            factory: address(aerodromePoolFactory)
        });
        vm.startPrank(trader_);
        IERC20(tokenIn_).approve(address(aerodromeRouter), amountIn_);
        aerodromeRouter.swapExactTokensForTokens(amountIn_, 0, routes_, trader_, block.timestamp + 1 hours);
        vm.stopPrank();
    }

    /// @dev Drive synthetic above mint threshold under **default Policy** via real underlying trades.
    ///      Bootstrap synthetic is often already ~1.25e18 (> 1.05). Falls back to rate skew.
    function _pushSyntheticAboveMintThreshold(address instance_) internal {
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        require(info_.isReserveLive(), "must be live");
        if (info_.isMintingAllowed()) return;

        for (uint256 i; i < 20 && !info_.isMintingAllowed(); ++i) {
            _shiftUnderlyingPrice(true, 20_000e18 * (i + 1));
            if (info_.isMintingAllowed()) return;
            _shiftUnderlyingPrice(false, 20_000e18 * (i + 1));
        }
        require(info_.isMintingAllowed(), "could not open mint under default thresholds");
    }

    /// @dev Deploy uniquely named Policy multi-vault instance (CREATE3 salt includes args).
    function _deployPolicyNamed(string memory name_, string memory symbol_) internal returns (address detf_) {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args =
            _buildPkgArgs(1, 0, 0, true, ThresholdMode.Policy);
        args.name = name_;
        args.symbol = symbol_;
        detf_ = _deployWithArgs(args);
        vm.label(detf_, name_);
    }

    /// @dev Live Policy DETF with locked user bond + protocol NFT principal (for expansion/compound).
    /// @dev Does **not** push synthetic here (caller runs `_pushSyntheticAboveMintThreshold` when needed).
    function _setupPolicyExpansionLive(address bonder_, address helper_)
        internal
        returns (address instance_, uint256 userBondId_)
    {
        instance_ = _deployPolicyNamed("Natural Expansion MVW DETF", "neMVW");
        _enableSeigniorageIncentive(instance_, 0.20e18);

        (uint256 firstId_,) = _goLiveViaBptBond(instance_, bonder_, 1_000e18);
        _warpPastUnlock(instance_, firstId_);
        vm.prank(bonder_);
        IMultiVaultWeightedDetfBonding(instance_).sellPositionToDetfNft(firstId_, 0, bonder_);

        uint256 seSharesBond_ = _fundSeShares0(bonder_, 200e18);
        vm.startPrank(bonder_);
        seShare0.approve(instance_, seSharesBond_);
        (userBondId_,) = IMultiVaultWeightedDetfBonding(instance_).bond(
            seShare0, seSharesBond_, DEFAULT_MIN_LOCK, bonder_, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(
            _bondNftVault(instance_).effectiveSharesOf(userBondId_),
            0,
            "user bond has effective shares"
        );

        // Seed expansion clock at live (first bond already set it); public touch is safe at dt≈0.
        IMultiVaultWeightedDetfInfo(instance_).compoundProtocolRewards();

        helper_; // reserved for multi-actor suites
    }

    /// @dev Expected max expansion mint under resolved defaults for given supply (bps cap).
    function _maxExpansionMintDefault(uint256 totalSupply_) internal pure returns (uint256) {
        return (totalSupply_ * DETFNaturalExpansionLib.DEFAULT_CATCH_UP_CAP_BPS) / 10_000;
    }
}
