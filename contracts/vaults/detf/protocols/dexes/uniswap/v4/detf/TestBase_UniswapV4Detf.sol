// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {ICreate3FactoryProxy} from "@crane/contracts/interfaces/proxies/ICreate3FactoryProxy.sol";
import {IFacetRegistry} from "@crane/contracts/interfaces/IFacetRegistry.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IERC8109Introspection} from "@crane/contracts/interfaces/IERC8109Introspection.sol";
import {IPostDeployAccountHook} from "@crane/contracts/interfaces/IPostDeployAccountHook.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {ERC721Facet} from "@crane/contracts/tokens/ERC721/ERC721Facet.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DetfComponentFactoryService} from "contracts/vaults/detf/common/factory/DetfComponentFactoryService.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {DetfPkgFactoryService} from "contracts/vaults/detf/common/factory/DetfPkgFactoryService.sol";
import {IRebasingClaimTokenDFPkg} from "contracts/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg.sol";
import {IUniswapV4DetfBondNFTVaultDFPkg} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/bondNft/UniswapV4DetfBondNFTVaultDFPkg.sol";
import {VaultComponentFactoryService} from "contracts/vaults/VaultComponentFactoryService.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
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
    IUniswapV4DualStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService as DualFactory
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4Detf_Facet_FactoryService} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Facet_FactoryService.sol";
import {UniswapV4Detf_Pkg_FactoryService} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol";

/**
 * @title TestBase_UniswapV4Detf
 * @notice Gold TestBase: CP hook first (predicted DETF as rawToken/owner), then DETF DFPkg via manager.
 */
abstract contract TestBase_UniswapV4Detf is TestBase_ERC4626StandardExchange {
    using BetterEfficientHashLib for bytes;
    using DetfFacetFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for ICreate3FactoryProxy;
    using DetfPkgFactoryService for IVaultRegistryDeployment;
    using VaultComponentFactoryService for ICreate3FactoryProxy;

    uint256 internal constant DEFAULT_MIN_LOCK = 30 days;
    uint256 internal constant DEFAULT_MAX_LOCK = 180 days;
    uint256 internal constant DEFAULT_CREATION_PAIR_PER_DETF = 1e18;

    address internal constant PERMIT2_ADDR = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    SimpleMintableERC20 internal pairToken;
    SimpleYieldERC4626 internal pairProtocolVault;
    address internal se;
    IPoolManager internal pm;
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
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Pair", "PAIR");
        pairProtocolVault = new SimpleYieldERC4626(pairToken);
        se = _deployERC4626SE(address(pairProtocolVault));
        pm = IPoolManager(address(new PoolManager(address(this))));

        _deployHookFactoryAndPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployHookThenDetf(_defaultDetfArgs());
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        pairToken.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        IERC20(se).approve(detf, type(uint256).max);
        vm.stopPrank();
    }

    function _deployHookFactory() internal {
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
    }

    function _deployHookFactoryAndPkg() internal {
        _deployHookFactory();

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
            abi.encode(type(IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage).name, "v1")._hash()
        );
    }

    function _deployBondNftVaultPkg() internal {
        detfNFTVaultFacet = create3Factory.deployUniswapV4DetfBondNFTVaultFacet();
        erc721FacetDetf = IFacet(
            create3Factory.deployFacet(type(ERC721Facet).creationCode, keccak256("Uv4Detf_ERC721Facet"))
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
        vm.label(address(bondNftVaultPkg), "Uv4Detf_BondNftVaultPkg");
    }

    function _deployRebasingClaimTokenPkg() internal {
        IFacet claimFacet_ = create3Factory.deployRebasingClaimTokenFacet();
        rebasingClaimTokenPkg = create3Factory.deployRebasingClaimTokenDFPkg(
            DetfComponentFactoryService.buildRICHIRPkgInit(
                erc20Facet, erc5267Facet, erc2612Facet, claimFacet_, diamondPackageFactory
            )
        );
        vm.label(address(rebasingClaimTokenPkg), "Uv4Detf_RebasingClaimTokenPkg");
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
        vm.label(address(detfPkg), "UniswapV4DetfDFPkg");
    }

    function _nLegDetfArgs(uint256 pairCount_) internal view returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _defaultDetfArgs();
        uint256[] memory creation_ = new uint256[](pairCount_);
        for (uint256 i; i < pairCount_; ++i) {
            creation_[i] = DEFAULT_CREATION_PAIR_PER_DETF;
        }
        args.creationPairPerDetfWad = creation_;
        args.openingPairPerDetfWad = new uint256[](0);
    }

    function _defaultDetfArgs() internal view returns (IUniswapV4Detf.PkgArgs memory args) {
        uint256[] memory creation_ = new uint256[](1);
        creation_[0] = DEFAULT_CREATION_PAIR_PER_DETF;
        args = IUniswapV4Detf.PkgArgs({
            name: "UniV4 DETF",
            symbol: "uv4DETF",
            hook: address(0),
            creationPairPerDetfWad: creation_,
            openingPairPerDetfWad: new uint256[](0),
            mintThreshold: 0,
            burnThreshold: 0,
            // Open: first-bond free legs typically leave synthetic < Policy mintThreshold.
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
        // Hook initAccount reads rawToken.decimals() before the DETF exists. Etch a
        // mintable ERC-20 at the predicted address for hook deploy, then clear so
        // CREATE2 can land the DETF diamond.
        vm.etch(predicted_, address(pairToken).code);
        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory hArgs =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se,
                pairToken: address(pairToken),
                rawToken: predicted_,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = CpHookFactory.findMineNonce(hookFactory, hookPkg, hArgs);
        reserveHook = CpHookFactory.deployHook(hookPkg, hArgs, mineNonce);
        // Production facets (tokens(), joinUnbalanced) are cut at finalize. DETF
        // processArgs reads hook.tokens(), so finalize while the predicted DETF
        // still has ERC-20 bytecode.
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(predicted_, address(pairToken));
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted_, "");
        args.hook = reserveHook;
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
        vm.label(reserveHook, "reserveHook");
    }

    function _finalizeHookPairs() internal {
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(detf, address(pairToken));
        bool ok = init.finalizeInitialization();
        require(ok, "finalize");
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

    function _firstBond(uint256 pairAmount_) internal virtual returns (uint256 tokenId, uint256 shares) {
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

    function _deployDualHook() internal returns (address dualHook_) {
        SimpleMintableERC20 tokenA = new SimpleMintableERC20("TokenA", "TKA");
        SimpleMintableERC20 tokenB = new SimpleMintableERC20("TokenB", "TKB");
        SimpleYieldERC4626 vaultA = new SimpleYieldERC4626(tokenA);
        SimpleYieldERC4626 vaultB = new SimpleYieldERC4626(tokenB);
        address seA = _deployERC4626SE(address(vaultA));
        address seB = _deployERC4626SE(address(vaultB));
        IFacet hooksFacet = DualFactory.deployHooksFacet(create3Factory);
        IFacet depositFacet = DualFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = DualFactory.deployWithdrawFacet(create3Factory);
        IFacet seFacet = DualFactory.deploySeFacet(create3Factory);
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage dualPkg = DualFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                hooksFacet: hooksFacet,
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                seFacet: seFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet
            }),
            abi.encode(type(IUniswapV4DualStandardExchangeBufferConstantProductHookPackage).name, "v1")._hash()
        );
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
        IUniswapV4DualStandardExchangeBufferConstantProductHookPackage.PkgArgs({
            poolManager: address(pm),
            feeOracle: address(indexedexManager),
            standardExchange0: seA,
            token0: address(tokenA),
            standardExchange1: seB,
            token1: address(tokenB)
        });
        uint256 mineNonce = DualFactory.findMineNonce(hookFactory, dualPkg, args);
        dualHook_ = DualFactory.deployHook(dualPkg, args, mineNonce);
    }

    function _assertNoJoinableDust() internal view virtual {
        address hook_ = detfInfo.hook();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "no hook LP on diamond");
        assertEq(IERC20(address(pairToken)).balanceOf(detf), 0, "no pair on diamond");
        assertEq(IERC20(se).balanceOf(detf), 0, "no SE share on diamond");
    }
}
