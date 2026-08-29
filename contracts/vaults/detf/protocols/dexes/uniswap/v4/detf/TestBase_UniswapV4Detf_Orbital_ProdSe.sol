// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4HookStagedPairInit
} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4HookStagedPairInit.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbitalFactory
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {
    IUniswapV4Detf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Orbital_ProdSe
 * @notice Shared orbital n=3 production-SE helpers. Does not bind Dual. ERC-4626 is not these SEs.
 * @dev Children deploy two distinct SEs then `_finishOrbitalDetf`. firstBond pulls 100 ether of
 *      each non-DETF `tokens()` entry (lead via `bond(mintToken)`, other legs via full-book pull).
 */
abstract contract TestBase_UniswapV4Detf_Orbital_ProdSe is TestBase_UniswapV4Detf {
    using BetterEfficientHashLib for bytes;

    address internal pairAddr0;
    address internal pairAddr1;
    address internal se0;
    address internal se1;
    address internal mintToken;
    IUniswapV4StandardExchangeOrbitalBufferHookPackage internal orbitalHookPkg;

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

    function _deployOrbitalHookPkg() internal {
        IFacet hooksFacet = OrbitalFactory.deployHooksFacet(create3Factory);
        IFacet depositFacet = OrbitalFactory.deployDepositFacet(create3Factory);
        IFacet withdrawFacet = OrbitalFactory.deployWithdrawFacet(create3Factory);
        IFacet seFacet = OrbitalFactory.deploySeFacet(create3Factory);
        orbitalHookPkg = OrbitalFactory.deployPackage(
            IVaultRegistryDeployment(address(indexedexManager)),
            owner,
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgInit({
                vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
                vaultFeeOracleQuery: IVaultFeeOracleQuery(address(indexedexManager)),
                depositFacet: depositFacet,
                withdrawFacet: withdrawFacet,
                seFacet: seFacet,
                hooksFacet: hooksFacet,
                erc20Facet: erc20Facet,
                erc5267Facet: erc5267Facet,
                erc2612Facet: erc2612Facet,
                multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
                multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
                multiStepOwnableFacet: multiStepOwnableFacet
            }),
            abi.encode(type(IUniswapV4StandardExchangeOrbitalBufferHookPackage).name, "v1")._hash()
        );
    }

    function _seOfPair(address token_, address predicted_, address p0, address p1, address s0, address s1)
        internal
        pure
        returns (address)
    {
        if (token_ == predicted_) return address(0);
        if (token_ == p0) return s0;
        if (token_ == p1) return s1;
        revert("unmapped orbital pair");
    }

    function _sort3(address a, address b, address c) internal pure returns (address, address, address) {
        if (a > b) (a, b) = (b, a);
        if (b > c) (b, c) = (c, b);
        if (a > b) (a, b) = (b, a);
        return (a, b, c);
    }

    function _deployOrbitalHookThenDetf(IUniswapV4Detf.PkgArgs memory args) internal returns (address detf_) {
        return _deployOrbitalHookThenDetf(args, pairAddr0, pairAddr1, se0, se1);
    }

    function _deployOrbitalHookThenDetf(
        IUniswapV4Detf.PkgArgs memory args,
        address p0,
        address p1,
        address s0,
        address s1
    ) internal returns (address detf_) {
        address predicted_ = _predictDetf(args);
        if (address(pairToken) == address(0)) {
            pairToken = new SimpleMintableERC20("Etch", "ETCH");
        }
        vm.etch(predicted_, address(pairToken).code);
        (address t0, address t1, address t2) = _sort3(predicted_, p0, p1);
        IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs memory hArgs =
            IUniswapV4StandardExchangeOrbitalBufferHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                token0: t0,
                token1: t1,
                token2: t2,
                se0: _seOfPair(t0, predicted_, p0, p1, s0, s1),
                se1: _seOfPair(t1, predicted_, p0, p1, s0, s1),
                se2: _seOfPair(t2, predicted_, p0, p1, s0, s1),
                rp0: address(0),
                rp1: address(0),
                rp2: address(0),
                tickSpacing: 0,
                sqrtPriceX96: 0,
                ownerOnlyLiquidity: true,
                owner: predicted_
            });
        uint256 mineNonce = OrbitalFactory.findMineNonce(hookFactory, orbitalHookPkg, hArgs);
        reserveHook = OrbitalFactory.deployHook(orbitalHookPkg, hArgs, mineNonce);
        IUniswapV4HookStagedPairInit init = IUniswapV4HookStagedPairInit(reserveHook);
        init.deployPair(t0, t1);
        init.deployPair(t1, t2);
        init.deployPair(t0, t2);
        require(init.finalizeInitialization(), "finalize");
        vm.etch(predicted_, "");
        args.hook = reserveHook;
        vm.startPrank(owner);
        detf_ = detfPkg.deployVault(args);
        vm.stopPrank();
        require(detf_ == predicted_, "detf != predicted");
        vm.label(detf_, args.symbol);
        vm.label(reserveHook, "orbitalReserveHook");
    }

    function _finishOrbitalDetf(address p0, address p1, address s0, address s1) internal {
        require(s0 != s1 && s0 != address(0) && s1 != address(0), "two distinct SEs");
        require(p0 != p1 && p0 != address(0) && p1 != address(0), "two pairs");
        pairAddr0 = p0;
        pairAddr1 = p1;
        se0 = s0;
        se1 = s1;
        se = s0;
        _deployHookFactory();
        _deployOrbitalHookPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        detf = _deployOrbitalHookThenDetf(_nLegDetfArgs(2), p0, p1, s0, s1);
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        mintToken = _readMintToken();
        if (mintToken != address(0)) pairToken = SimpleMintableERC20(mintToken);
        uint256[] memory creation_ = detfInfo.creationPairPerDetfWad();
        require(creation_.length == 2, "creationPairPerDetfWad n-1");
        require(creation_[0] == 1e18 && creation_[1] == 1e18, "creation 1e18");
    }

    function _readMintToken() internal view returns (address t) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) return toks[i];
        }
        revert("no mintToken");
    }

    function _approveUserPairs(address user) internal {
        vm.startPrank(user);
        IERC20(pairAddr0).approve(detf, type(uint256).max);
        IERC20(pairAddr1).approve(detf, type(uint256).max);
        IERC20(se0).approve(detf, type(uint256).max);
        IERC20(se1).approve(detf, type(uint256).max);
        vm.stopPrank();
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
        assertLe(IERC20(pairAddr0).balanceOf(detf), 10, "no pair0 on diamond");
        assertLe(IERC20(pairAddr1).balanceOf(detf), 10, "no pair1 on diamond");
        assertLe(IERC20(se0).balanceOf(detf), 10, "no se0 share on diamond");
        assertLe(IERC20(se1).balanceOf(detf), 10, "no se1 share on diamond");
    }
}
