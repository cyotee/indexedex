// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_FactoryService as WeightedFactory
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol";
import {
    IUniswapV4Detf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @title TestBase_UniswapV4Detf_Weighted
/// @notice Same UniswapV4DetfDFPkg, n=3 weighted hook (DETF + two pairs).
abstract contract TestBase_UniswapV4Detf_Weighted is TestBase_UniswapV4Detf {
    using BetterEfficientHashLib for bytes;

    SimpleMintableERC20 internal pair0;
    SimpleMintableERC20 internal pair1;
    address internal se0;
    address internal se1;
    IUniswapV4StandardExchangeWeightedBufferHookPackage internal weightedHookPkg;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pair0 = new SimpleMintableERC20("Pair0", "P0");
        pair1 = new SimpleMintableERC20("Pair1", "P1");
        pairToken = pair0;
        se0 = _deployERC4626SE(address(new SimpleYieldERC4626(pair0)));
        se1 = _deployERC4626SE(address(new SimpleYieldERC4626(pair1)));
        se = se0;
        pm = IPoolManager(address(new PoolManager(address(this))));

        _deployHookFactory();
        _deployWeightedHookPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployWeightedHookThenDetf(_nLegDetfArgs(2));
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        pair0.mint(detfUser, 10_000_000 ether);
        pair1.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pair0.approve(detf, type(uint256).max);
        pair1.approve(detf, type(uint256).max);
        pair0.approve(se0, type(uint256).max);
        pair1.approve(se1, type(uint256).max);
        IERC20(se0).approve(detf, type(uint256).max);
        IERC20(se1).approve(detf, type(uint256).max);
        vm.stopPrank();
    }

    function _deployWeightedHookPkg() internal {
        IFacet hooksFacet = WeightedFactory.deployHooksFacet(create3Factory);
        IFacet joinFacet = WeightedFactory.deployJoinFacet(create3Factory);
        IFacet exitFacet = WeightedFactory.deployExitFacet(create3Factory);
        IFacet seFacet = WeightedFactory.deploySeFacet(create3Factory);
        weightedHookPkg = WeightedFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                joinFacet: joinFacet,
                exitFacet: exitFacet,
                seFacet: seFacet,
                hooksFacet: hooksFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(type(IUniswapV4StandardExchangeWeightedBufferHookPackage).name, "v1")._hash()
        );
    }

    /// @dev Bind a 3-token weighted hook to `args.hook` without deploying the DETF.
    function _deployWeightedHookForArgs(IUniswapV4Detf.PkgArgs memory args)
        internal
        returns (address predicted_)
    {
        predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(pair0).code);
        address[] memory toks = new address[](3);
        toks[0] = predicted_;
        toks[1] = address(pair0);
        toks[2] = address(pair1);
        _sortInPlace(toks);
        uint256[] memory w = new uint256[](3);
        w[0] = 4e17;
        w[1] = 3e17;
        w[2] = 3e17;
        address[] memory ses = new address[](3);
        address[] memory rps = new address[](3);
        for (uint256 i; i < 3; ++i) {
            if (toks[i] == predicted_) ses[i] = address(0);
            else if (toks[i] == address(pair0)) ses[i] = se0;
            else ses[i] = se1;
        }
        IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeWeightedBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                n: 3,
                tokens: toks,
                weights: w,
                standardExchanges: ses,
                rateProviders: rps,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = WeightedFactory.findMineNonce(hookFactory, weightedHookPkg, hArgs);
        reserveHook = WeightedFactory.deployHook(weightedHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(toks[0], toks[1]);
        init.deployPair(toks[0], toks[2]);
        init.deployPair(toks[1], toks[2]);
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted_, "");
        args.hook = reserveHook;
        vm.label(reserveHook, "weightedReserveHook");
    }

    function _deployWeightedHookThenDetf(IUniswapV4Detf.PkgArgs memory args)
        internal
        returns (address detf_)
    {
        address predicted_ = _deployWeightedHookForArgs(args);
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
    }

    function _sortInPlace(address[] memory a) internal pure {
        uint256 n = a.length;
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                if (a[i] > a[j]) (a[i], a[j]) = (a[j], a[i]);
            }
        }
    }

    function _customMintPair0Args() internal view returns (IUniswapV4Detf.PkgArgs memory args) {
        args = _nLegDetfArgs(2);
        args.name = "WCustomMint";
        args.symbol = "wMint1";
        args.mintRouteMode = IUniswapV4Detf.RouteTableMode.Custom;
        args.mintRoutes = new IUniswapV4Detf.IoRoute[](1);
        args.mintRoutes[0] =
            IUniswapV4Detf.IoRoute({token: IERC20(address(pair0)), vault: IStandardExchange(se0)});
    }

    function _fundActor(address vault_, address who, uint256 amt) internal {
        pair0.mint(who, amt);
        pair1.mint(who, amt);
        vm.startPrank(who);
        pair0.approve(vault_, type(uint256).max);
        pair1.approve(vault_, type(uint256).max);
        pair0.approve(se0, type(uint256).max);
        pair1.approve(se1, type(uint256).max);
        IERC20(se0).approve(vault_, type(uint256).max);
        IERC20(se1).approve(vault_, type(uint256).max);
        vm.stopPrank();
    }

    function _firstBond(uint256 pairAmount_) internal virtual override returns (uint256 tokenId, uint256 shares) {
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(address(pair0)),
            pairAmount_,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _assertNoJoinableDust() internal view virtual override {
        address hook_ = detfInfo.hook();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "no hook LP");
        assertEq(IERC20(address(pair0)).balanceOf(detf), 0, "no pair0");
        assertEq(IERC20(address(pair1)).balanceOf(detf), 0, "no pair1");
        assertEq(IERC20(se0).balanceOf(detf), 0, "no se0");
        assertEq(IERC20(se1).balanceOf(detf), 0, "no se1");
    }
}
