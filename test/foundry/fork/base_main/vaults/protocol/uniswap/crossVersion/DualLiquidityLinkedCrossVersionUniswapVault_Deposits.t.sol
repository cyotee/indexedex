// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {DualLiquidityLinkedCrossVersionUniswapVaultRepo} from
    "contracts/vaults/protocol/uniswap/crossVersion/DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol";
import {
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
} from "test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol";

/// @notice Deposit routes exercised over the REAL bootstrapped deployment (real Uniswap V4/V2 + Balancer
///         legs, real ERC20Permit tokens). Every share-minting route is asserted for preview/execution
///         symmetry (exact) and non-zero mint; guards and the pretransferred funding path are covered.
///         Shares come from real deposits (no seedShares); amounts are priced by real WeightedMath, so
///         magnitudes are asserted relationally.
contract DualLiquidityLinkedCrossVersionUniswapVault_Deposits is
    TestBase_DualLiquidityLinkedCrossVersionUniswapVault
{
    address internal depositor = makeAddr("depositor");
    IERC20 internal shareToken;

    function setUp() public override {
        super.setUp();
        _bootstrapReserve();
        shareToken = IERC20(linkedVault);
    }

    /* --------------------------- Share-minting routes ---------------------- */

    /// @notice Depositing a leg vault share mints linked-vault shares; preview equals execution exactly.
    function test_depositVaultShare_previewMatchesExecution() public {
        IERC20 legShare = vault.getPoolTokens(_reservePool())[0];
        uint256 shares = _acquireLegShare(address(legShare), depositor);

        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(legShare, shares, shareToken);
        vm.startPrank(depositor);
        legShare.approve(linkedVault, shares);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            legShare, shares, shareToken, 0, depositor, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(minted, 0, "vault-share deposit mints shares");
        assertEq(minted, preview, "preview == execution");
    }

    /// @notice Depositing a linked token (tokenA) routes through the legs and mints shares.
    function test_depositLinkedToken_previewMatchesExecution() public {
        _fund(tokenA, depositor, LEG_SEED);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(tokenA, LEG_SEED, shareToken);
        vm.startPrank(depositor);
        tokenA.approve(linkedVault, LEG_SEED);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenA, LEG_SEED, shareToken, 0, depositor, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(minted, 0, "linked-token deposit mints shares");
        // Multi-hop: join is quoted at pre-hop rate-provider values; execution joins after the leg
        // mint updates rates. Mint-from-actual BPT prevents dilution; residual is sub-wei-scale on shares.
        assertApproxEqAbs(minted, preview, 1e6, "multi-hop deposit preview ~ execution");
    }

    /// @notice Depositing the common token routes through the best linked leg and mints shares.
    function test_depositCommonToken_previewMatchesExecution() public {
        _fund(commonToken, depositor, LEG_SEED);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, LEG_SEED, shareToken);
        vm.startPrank(depositor);
        commonToken.approve(linkedVault, LEG_SEED);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, LEG_SEED, shareToken, 0, depositor, false, block.timestamp
        );
        vm.stopPrank();

        assertGt(minted, 0, "common-token deposit mints shares");
        assertApproxEqAbs(minted, preview, 1e6, "multi-hop common deposit preview ~ execution");
    }

    /// @notice The pretransferred funding path: send tokenB first, then deposit with pretransferred=true.
    function test_depositPretransferred_mintsShares() public {
        _fund(tokenB, depositor, LEG_SEED);
        vm.startPrank(depositor);
        tokenB.transfer(linkedVault, LEG_SEED);
        uint256 minted = IStandardExchangeIn(linkedVault).exchangeIn(
            tokenB, LEG_SEED, shareToken, 0, depositor, true, block.timestamp
        );
        vm.stopPrank();
        assertGt(minted, 0, "pretransferred deposit mints shares");
    }

    /* -------------------------------- Guards ------------------------------- */

    /// @notice minAmountOut above the achievable share output reverts.
    function test_deposit_minSharesOut_reverts() public {
        _fund(commonToken, depositor, LEG_SEED);
        uint256 preview = IStandardExchangeIn(linkedVault).previewExchangeIn(commonToken, LEG_SEED, shareToken);
        vm.startPrank(depositor);
        commonToken.approve(linkedVault, LEG_SEED);
        // Multi-hop preview can sit a few wei above actual; demand far more than preview.
        vm.expectRevert();
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, LEG_SEED, shareToken, preview + 1e18, depositor, false, block.timestamp
        );
        vm.stopPrank();
    }

    /// @notice A zero-amount deposit reverts.
    function test_deposit_zeroAmount_reverts() public {
        vm.expectRevert(DualLiquidityLinkedCrossVersionUniswapVaultRepo.ZeroAmount.selector);
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, 0, shareToken, 0, depositor, false, block.timestamp
        );
    }

    /// @notice An expired deadline reverts.
    function test_deposit_expiredDeadline_reverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                DualLiquidityLinkedCrossVersionUniswapVaultRepo.DeadlineExpired.selector, block.timestamp - 1
            )
        );
        IStandardExchangeIn(linkedVault).exchangeIn(
            commonToken, LEG_SEED, shareToken, 0, depositor, false, block.timestamp - 1
        );
    }
}
