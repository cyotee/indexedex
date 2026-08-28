// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {PoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol";
import {IUniswapV3Factory} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {TestBase_ERC4626StandardExchange} from "contracts/test/bases/TestBase_ERC4626StandardExchange.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4Detf
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {
    UniswapV4DetfProductionSeDeployLib as SeLib
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfProductionSeDeployLib.sol";

/**
 * @title TestBase_UniswapV4Detf_Cp_Univ3Se
 * @notice H-CP-GV3: CP SE buffer hook + vanilla Uni V3 Standard Exchange.
 * @dev Burn/close revert TransferFromFailed (0x7939f424) if CP `_unwrapSeShares` lacks
 *      `IERC20(se).forceApprove(se, seIn)`. Dual is not bound. ERC-4626 is not this SE.
 */
abstract contract TestBase_UniswapV4Detf_Cp_Univ3Se is TestBase_UniswapV4Detf {
    SimpleMintableERC20 internal seOther;
    IUniswapV3Factory internal univ3Factory;
    IUniswapV3Pool internal univ3Pool;
    address internal mintToken;

    function setUp() public virtual override {
        TestBase_ERC4626StandardExchange.setUp();
        vm.etch(PERMIT2_ADDR, address(permit2).code);
        permit2 = IPermit2(PERMIT2_ADDR);

        pairToken = new SimpleMintableERC20("Pair", "PAIR");
        seOther = new SimpleMintableERC20("Rate", "RATE");
        pm = IPoolManager(address(new PoolManager(address(this))));

        univ3Factory = SeLib.newUniv3Factory();
        SeLib.Univ3SePkg memory v3pkg;
        v3pkg.factory = univ3Factory;
        v3pkg.pkg = SeLib.deployUniv3SePkg(_craneCtx(), univ3Factory);
        univ3Pool = SeLib.createUniv3PoolOneToOne(
            univ3Factory, address(pairToken), address(seOther), SeLib.GENERIC_V3_FEE
        );
        SeLib.seedUniv3Pool(univ3Pool);
        se = SeLib.deployUniv3Vault(v3pkg.pkg, univ3Pool);

        _deployHookFactoryAndPkg();
        _deployBondNftVaultPkg();
        _deployRebasingClaimTokenPkg();
        _deployDetfPkg();
        _setDefaultBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);

        detf = _deployHookThenDetf(_defaultDetfArgs());
        detfInfo = IUniswapV4Detf(detf);
        detfExchangeIn = IStandardExchangeIn(detf);
        _setBondTerms(DEFAULT_MIN_LOCK, DEFAULT_MAX_LOCK);
        mintToken = _readMintToken();

        pairToken.mint(detfUser, 10_000_000 ether);
        vm.startPrank(detfUser);
        pairToken.approve(detf, type(uint256).max);
        pairToken.approve(se, type(uint256).max);
        IERC20(se).approve(detf, type(uint256).max);
        vm.stopPrank();
    }

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

    function _readMintToken() internal view returns (address t) {
        address[] memory toks = IUniswapV4SeBufferHook(reserveHook).tokens();
        for (uint256 i; i < toks.length; ++i) {
            if (toks[i] != detf) return toks[i];
        }
        revert("no mintToken");
    }

    function _firstBond(uint256 pairAmount_) internal override returns (uint256 tokenId, uint256 shares) {
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

    function _assertNoJoinableDust() internal view override {
        address hook_ = detfInfo.hook();
        assertEq(IERC20(hook_).balanceOf(detf), 0, "no hook LP on diamond");
        assertEq(IERC20(mintToken).balanceOf(detf), 0, "no mintToken on diamond");
        assertEq(IERC20(se).balanceOf(detf), 0, "no SE share on diamond");
    }
}
