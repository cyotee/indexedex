// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";

/**
 * @title Handler_AerodromeStandardExchange
 * @notice L3 handler: random swap / vault deposit / vault withdraw on balanced Aerodrome SE vault.
 * @dev Wave 2A. try/catch + ghosts. Host mints tokens via stub.mint.
 */
contract Handler_AerodromeStandardExchange is Test {
    IStandardExchangeProxy public immutable vault;
    ERC20PermitMintableStub public immutable tokenA;
    ERC20PermitMintableStub public immutable tokenB;
    address public immutable actor0;
    address public immutable actor1;

    uint256 public ghost_swapCount;
    uint256 public ghost_depositCount;
    uint256 public ghost_withdrawCount;

    constructor(
        IStandardExchangeProxy vault_,
        ERC20PermitMintableStub tokenA_,
        ERC20PermitMintableStub tokenB_,
        address actor0_,
        address actor1_
    ) {
        vault = vault_;
        tokenA = tokenA_;
        tokenB = tokenB_;
        actor0 = actor0_;
        actor1 = actor1_;
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
        ERC20PermitMintableStub tin = aToB ? tokenA : tokenB;
        IERC20 tout = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));
        uint256 amount = bound(amountSeed, 1e15, 5e18);
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

    /// @notice LP → vault shares (route 4 class): need LP first via zap-ish path simplified.
    function vaultDeposit(uint256 amountSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        // Fund both tokens and swap once to get activity; deposit path uses LP if actor holds it.
        uint256 amount = bound(amountSeed, 1e15, 3e18);
        tokenA.mint(actor, amount);
        tokenB.mint(actor, amount);
        // Prefer deposit of vault asset (LP) if balance exists; else swap only.
        address asset_ = vault.asset();
        uint256 lpBal = IERC20(asset_).balanceOf(actor);
        if (lpBal < 1e12) {
            // Acquire LP via exchangeIn token → vault shares path (route 6) or skip.
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
        uint256 dep = bound(amountSeed, 1e12, lpBal);
        vm.startPrank(actor);
        IERC20(asset_).approve(address(vault), dep);
        try vault.deposit(dep, actor) {
            unchecked {
                ++ghost_depositCount;
            }
        } catch {}
        vm.stopPrank();
    }

    /// @notice Withdraw vault shares → LP or token.
    function vaultWithdraw(uint256 shareSeed, uint256 actorSeed) public {
        address actor = _actor(actorSeed);
        uint256 bal = IERC20(address(vault)).balanceOf(actor);
        if (bal < 1e12) return;
        uint256 shares = bound(shareSeed, 1e12, bal);
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
