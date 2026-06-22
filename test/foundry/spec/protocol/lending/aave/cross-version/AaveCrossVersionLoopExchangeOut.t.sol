// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IPoolAddressesProvider} from
    "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IPoolAddressesProvider.sol";
import {IAaveOracle} from "@crane/contracts/protocols/lending/aave/v3.6/interfaces/IAaveOracle.sol";
import {IAaveOracle as IAaveOracleV4} from
    "@crane/contracts/protocols/lending/aave/v4/spoke/interfaces/IAaveOracle.sol";

import {TestBase_AaveCrossVersionLoopV3Market} from
    "contracts/test/bases/TestBase_AaveCrossVersionLoopV3Market.sol";
import {AaveCrossVersionLoopExchangeBase} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeBase.sol";
import {AaveCrossVersionLoopExchangeInTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeInTarget.sol";
import {AaveCrossVersionLoopExchangeOutTarget} from
    "contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopExchangeOutTarget.sol";

/// @dev Combined In+Out vault mirroring the diamond (shared storage), plus test-only share views.
contract _LoopVault is AaveCrossVersionLoopExchangeInTarget, AaveCrossVersionLoopExchangeOutTarget {
    function totalShares() external view returns (uint256) {
        return ERC20Repo._totalSupply();
    }

    function shareBalance(address a) external view returns (uint256) {
        return ERC20Repo._balanceOf(a);
    }
}

/**
 * @title AaveCrossVersionLoopExchangeOut_Test
 * @notice Integration test for the withdraw exit (PRD decisions 11, 14, 15): exchangeOut burns
 *         shares and delivers tokenA, freed via the never-borrow rule from the HF buffer, all-or-revert.
 */
contract AaveCrossVersionLoopExchangeOut_Test is TestBase_AaveCrossVersionLoopV3Market {
    _LoopVault internal vault;
    address internal v3lp = address(0x3133);
    address internal v4lp = address(0x4144);

    function _initVault() internal {
        vault = new _LoopVault();
        vault.initCrossVersionLoop(
            AaveCrossVersionLoopExchangeBase.InitArgs({
                v36Pool: v36Pool,
                v36AddressesProvider: IPoolAddressesProvider(v36AddressesProvider),
                v36Oracle: IAaveOracle(v36Oracle),
                v4Spoke: v4Spoke,
                v4Hub: v4Hub,
                v4Oracle: IAaveOracleV4(address(v4Oracle)),
                tokenA: tokenA,
                tokenB: tokenB,
                v4AssetIdA: v4AssetIdA,
                v4ReserveIdA: v4ReserveIdA,
                v4AssetIdB: v4AssetIdB,
                v4ReserveIdB: v4ReserveIdB,
                shareName: "Cross Loop Vault",
                shareSymbol: "CLV"
            })
        );
    }

    function _seedBorrowLiquidity() internal {
        _mint(tokenB, v3lp, 2_000_000e6);
        vm.startPrank(v3lp);
        tokenB.approve(address(v36Pool), 2_000_000e6);
        v36Pool.supply(address(tokenB), 2_000_000e6, v3lp, 0);
        vm.stopPrank();

        _mint(tokenA, v4lp, 1_000e18);
        vm.startPrank(v4lp);
        tokenA.approve(address(v4Spoke), 1_000e18);
        v4Spoke.supply(v4ReserveIdA, 1_000e18, v4lp);
        vm.stopPrank();
    }

    function _deposit(uint256 amount) internal returns (uint256 shares) {
        _mint(tokenA, address(this), amount);
        tokenA.approve(address(vault), amount);
        shares = vault.exchangeIn(tokenA, amount, IERC20(address(vault)), 0, address(this), false, block.timestamp);
    }

    function test_exchangeOut_partial_withdraw_burns_shares_and_delivers() public {
        _initVault();
        _seedBorrowLiquidity();

        uint256 shares = _deposit(100e18);
        assertEq(vault.shareBalance(address(this)), shares, "holder has shares");
        uint256 supplyBefore = vault.totalShares();

        // Withdraw a modest amount serviceable from the HF buffer.
        uint256 want = 3e18;
        uint256 previewShares = vault.previewExchangeOut(IERC20(address(vault)), tokenA, want);

        uint256 balBefore = tokenA.balanceOf(address(this));
        uint256 amountIn = vault.exchangeOut(
            IERC20(address(vault)), type(uint256).max, tokenA, want, address(this), false, block.timestamp
        );

        assertEq(amountIn, previewShares, "preview == execution (shares burned)");
        assertEq(tokenA.balanceOf(address(this)) - balBefore, want, "received requested tokenA");
        assertEq(vault.shareBalance(address(this)), shares - amountIn, "shares burned from holder");
        assertEq(vault.totalShares(), supplyBefore - amountIn, "total supply reduced");
        // Vault remains solvent after the partial withdraw.
        assertGt(AaveV36ServiceHF(), 1e18, "vault V3 HF > 1 after withdraw");
    }

    function test_exchangeOut_exceeding_freeable_reverts() public {
        _initVault();
        _seedBorrowLiquidity();
        _deposit(100e18);

        // Requesting far more than the buffer can free reverts (all-or-revert, decision 15).
        vm.expectRevert();
        vault.previewExchangeOut(IERC20(address(vault)), tokenA, 10_000e18);
    }

    function AaveV36ServiceHF() internal view returns (uint256) {
        // Read V3 HF of the vault via the pool directly.
        (,,,,, uint256 hf) = v36Pool.getUserAccountData(address(vault));
        return hf;
    }
}
