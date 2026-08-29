// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
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
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Weighted_ProdSe
 * @notice Shared Weighted n=3 production-SE wiring. Dual is not bound.
 * @dev Pair weights equal (3e17 / 3e17); DETF self-leg still needs a hook weight (4e17).
 *      Do not diamond-inherit Morpho / pons / Univ4Se TestBases with TestBase_UniswapV4Detf.
 */
abstract contract TestBase_UniswapV4Detf_Weighted_ProdSe is TestBase_UniswapV4Detf {
    using BetterEfficientHashLib for bytes;

    address internal pairA;
    address internal pairB;
    address internal se0;
    address internal se1;
    address internal mintToken;
    IUniswapV4StandardExchangeWeightedBufferHookPackage internal weightedHookPkg;

    function _craneCtx() internal view returns (SeLib.CraneCtx memory ctx) {
        ctx.create3Factory = create3Factory;
        ctx.indexedexManager = indexedexManager;
        ctx.diamondPackageFactory = diamondPackageFactory;
        ctx.permit2 = permit2;
        ctx.erc20Facet = erc20Facet;
        ctx.erc5267Facet = erc5267Facet;
        ctx.erc2612Facet = erc2612Facet;
        ctx.multiAssetBasicVaultFacet = multiAssetBasicVaultFacet;
        ctx.multiAssetStandardVaultFacet = multiAssetStandardVaultFacet;
        ctx.owner = owner;
    }

    function _finishWeightedProdSe() internal {
        if (address(pairToken) == address(0)) {
            pairToken = new SimpleMintableERC20("Etch", "ETCH");
        }
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
        mintToken = _readMintToken();
        se = se0;
        if (mintToken != address(0)) pairToken = SimpleMintableERC20(mintToken);
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
            abi.encode(type(IUniswapV4StandardExchangeWeightedBufferHookPackage).name, "prod-se")._hash()
        );
    }

    function _deployWeightedHookThenDetf(IUniswapV4Detf.PkgArgs memory args)
        internal
        returns (address detf_)
    {
        address predicted_ = _predictDetf(args);
        vm.etch(predicted_, address(pairToken).code);
        address[] memory toks = new address[](3);
        toks[0] = predicted_;
        toks[1] = pairA;
        toks[2] = pairB;
        _sortInPlace(toks);
        uint256[] memory w = new uint256[](3);
        address[] memory ses = new address[](3);
        address[] memory rps = new address[](3);
        for (uint256 i; i < 3; ++i) {
            if (toks[i] == predicted_) {
                // DETF self-leg has no pair-product weight; hook still requires n weights summing to 1e18.
                w[i] = 4e17;
                ses[i] = address(0);
            } else {
                w[i] = 3e17;
                ses[i] = toks[i] == pairA ? se0 : se1;
            }
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
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
        vm.label(reserveHook, "weightedReserveHook");
    }

    function _sortInPlace(address[] memory a) internal pure {
        uint256 n = a.length;
        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                if (a[i] > a[j]) (a[i], a[j]) = (a[j], a[i]);
            }
        }
    }

    function _readMintToken() internal view returns (address t) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) return toks[i];
        }
        revert("no mintToken");
    }

    function _otherPair() internal view returns (address t) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf && toks[i] != mintToken) return toks[i];
        }
        revert("no other pair");
    }

    function _approveUserForPairs() internal {
        vm.startPrank(detfUser);
        IERC20(pairA).approve(detf, type(uint256).max);
        IERC20(pairB).approve(detf, type(uint256).max);
        IERC20(pairA).approve(se0, type(uint256).max);
        IERC20(pairB).approve(se1, type(uint256).max);
        IERC20(se0).approve(detf, type(uint256).max);
        IERC20(se1).approve(detf, type(uint256).max);
        vm.stopPrank();
    }

    function _mintMintablePairs(uint256 amount) internal {
        SimpleMintableERC20(pairA).mint(detfUser, amount);
        SimpleMintableERC20(pairB).mint(detfUser, amount);
    }

    function _firstBond(uint256 pairAmount_) internal virtual override returns (uint256 tokenId, uint256 shares) {
        vm.startPrank(detfUser);
        (tokenId, shares) = detfInfo.bond(
            IERC20(mintToken), pairAmount_, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function _assertSeAllowancesZero() internal view {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            address se_ = IUniswapV4SeBufferHook(reserveHook).standardExchangeOf(toks[i]);
            if (se_ != address(0)) {
                assertEq(IERC20(se_).allowance(reserveHook, se_), 0, "SE allowance(hook, se)==0");
            }
        }
    }

    function _assertR19() internal {
        address hook_ = detfInfo.hook();
        address[] memory toks = IUniswapV4SeBufferHook(hook_).tokens();
        bool needSweep = IERC20(hook_).balanceOf(detf) > 0;
        for (uint256 i; i < toks.length; ++i) {
            if (IERC20(toks[i]).balanceOf(detf) > 0) needSweep = true;
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(toks[i]);
            if (se_ != address(0) && IERC20(se_).balanceOf(detf) > 0) needSweep = true;
        }
        if (needSweep) detfInfo.sweepDust();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "R19 hook LP");
        for (uint256 i; i < toks.length; ++i) {
            uint256 bal = IERC20(toks[i]).balanceOf(detf);
            if (bal > 10) {
                _logR19JoinFailure(hook_, toks[i], bal);
                assertLe(bal, 10, string.concat("R19 token after sweep ", vm.toString(toks[i])));
            }
            address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(toks[i]);
            if (se_ != address(0)) {
                uint256 seBal = IERC20(se_).balanceOf(detf);
                if (seBal > 10) {
                    emit log_named_address("R19 leftover SE", se_);
                    emit log_named_uint("R19 leftover SE bal", seBal);
                }
                assertLe(seBal, 10, "R19 SE share");
            }
        }
    }

    function _logR19JoinFailure(address hook_, address token_, uint256 bal_) internal {
        emit log_named_address("R19 leftover token", token_);
        emit log_named_uint("R19 leftover bal", bal_);
        try IUniswapV4SeBufferHook(hook_).previewJoinSingleAssetExactIn(token_, bal_) returns (uint256 p) {
            emit log_named_uint("R19 previewJoin", p);
        } catch (bytes memory err) {
            if (err.length >= 4) emit log_named_bytes32("R19 join revert", bytes32(err));
        }
        address se_ = IUniswapV4SeBufferHook(hook_).standardExchangeOf(token_);
        if (se_ != address(0)) {
            try IStandardExchangeIn(se_).previewExchangeIn(IERC20(token_), bal_, IERC20(se_)) returns (uint256 w) {
                emit log_named_uint("R19 sePreview wrap", w);
            } catch (bytes memory err2) {
                if (err2.length >= 4) emit log_named_bytes32("R19 wrap revert", bytes32(err2));
            }
        }
    }

    function _assertNoJoinableDust() internal view virtual override {
        address hook_ = detfInfo.hook();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "no hook LP on diamond");
        assertLe(IERC20(pairA).balanceOf(detf), 10, "no pairA on diamond");
        assertLe(IERC20(pairB).balanceOf(detf), 10, "no pairB on diamond");
        assertLe(IERC20(se0).balanceOf(detf), 10, "no se0 share on diamond");
        assertLe(IERC20(se1).balanceOf(detf), 10, "no se1 share on diamond");
    }
}
