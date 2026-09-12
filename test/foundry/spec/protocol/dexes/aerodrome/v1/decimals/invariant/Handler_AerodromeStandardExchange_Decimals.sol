// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";

/**
 * @title Handler_AerodromeStandardExchange_Decimals
 * @notice L3 handler on combo-decimal pairToken (tokenA) / other (tokenB). vaultShare stays 18.
 * @dev Bounds use raw token units. Host mints via MintableERC20Decimals.mint.
 */
contract Handler_AerodromeStandardExchange_Decimals is Test {
    IStandardExchangeProxy public immutable vault;
    MintableERC20Decimals public immutable tokenA;
    MintableERC20Decimals public immutable tokenB;
    address public immutable actor0;
    address public immutable actor1;
    uint256 public immutable minA;
    uint256 public immutable maxA;
    uint256 public immutable minB;
    uint256 public immutable maxB;

    uint256 public ghost_swapCount;
    uint256 public ghost_depositCount;
    uint256 public ghost_withdrawCount;

    constructor(
        IStandardExchangeProxy vault_,
        MintableERC20Decimals tokenA_,
        MintableERC20Decimals tokenB_,
        address actor0_,
        address actor1_
    ) {
        vault = vault_;
        tokenA = tokenA_;
        tokenB = tokenB_;
        actor0 = actor0_;
        actor1 = actor1_;
        uint256 unitA = 10 ** uint256(tokenA_.decimals());
        uint256 unitB = 10 ** uint256(tokenB_.decimals());
        minA = unitA / 1000 == 0 ? 1 : unitA / 1000;
        maxA = 5 * unitA;
        minB = unitB / 1000 == 0 ? 1 : unitB / 1000;
        maxB = 5 * unitB;
    }

    function _actor(uint256 seed) internal view returns (address) {
        return seed % 2 == 0 ? actor0 : actor1;
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    /// @notice Route1-style swap A→B or B→A.
    function swap(uint256 amountSeed, uint256 actorSeed, bool aToB) public {
        address actor = _actor(actorSeed);
        MintableERC20Decimals tin = aToB ? tokenA : tokenB;
        IERC20 tout = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));
        uint256 lo = aToB ? minA : minB;
        uint256 hi = aToB ? maxA : maxB;
        if (hi <= lo) return;
        uint256 amount = bound(amountSeed, lo, hi);
        tin.mint(actor, amount);
        vm.startPrank(actor);
        tin.approve(address(vault), amount);
        try IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(tin)), amount, tout, 0, actor, false, _deadline()
        ) {
            unchecked {
                ++ghost_swapCount;
            }
        } catch {}
        vm.stopPrank();
    }

    /// @notice LP → vault shares (route 4) or tokenA → shares (route 6).
    function vaultDeposit(uint256 amountSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        uint256 amount = bound(amountSeed, minA, maxA);
        tokenA.mint(actor, amount);
        tokenB.mint(actor, bound(amountSeed, minB, maxB));
        address asset_ = vault.asset();
        uint256 lpBal = IERC20(asset_).balanceOf(actor);
        uint256 lpFloor = 1e3;
        if (lpBal < lpFloor) {
            vm.startPrank(actor);
            tokenA.approve(address(vault), amount);
            try IStandardExchangeIn(address(vault)).exchangeIn(
                IERC20(address(tokenA)), amount, IERC20(address(vault)), 0, actor, false, _deadline()
            ) {
                unchecked {
                    ++ghost_depositCount;
                }
            } catch {}
            vm.stopPrank();
            return;
        }
        uint256 dep = bound(amountSeed, lpFloor, lpBal);
        vm.startPrank(actor);
        IERC20(asset_).approve(address(vault), dep);
        try vault.deposit(dep, actor) {
            unchecked {
                ++ghost_depositCount;
            }
        } catch {}
        vm.stopPrank();
    }

    /// @notice Withdraw vault shares → pairToken.
    function vaultWithdraw(uint256 shareSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        uint256 bal = IERC20(address(vault)).balanceOf(actor);
        if (bal < 1e3) return;
        uint256 shares = bound(shareSeed, 1e3, bal);
        vm.startPrank(actor);
        try IStandardExchangeIn(address(vault)).exchangeIn(
            IERC20(address(vault)), shares, IERC20(address(tokenA)), 0, actor, false, _deadline()
        ) {
            unchecked {
                ++ghost_withdrawCount;
            }
        } catch {}
        vm.stopPrank();
    }
}
