// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {PullRewardsTransferStrategy, ITransferStrategyBase} from
    "@crane/contracts/protocols/lending/aave/v3.6/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";
import {RewardsDataTypes} from "@crane/contracts/protocols/lending/aave/v3.6/rewards/libraries/RewardsDataTypes.sol";
import {AggregatorInterface} from "@crane/contracts/protocols/oracles/chainlink/AggregatorInterface.sol";
import {MockAggregator} from "@crane/contracts/protocols/lending/aave/v3.6/utils/mocks/oracle/CLAggregators/MockAggregator.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_AaveV3StataStandardExchange_Decimals} from
    "contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";

/**
 * @title AaveV3StataStandardExchange_Real_Decimals
 * @notice Shared real Stata money-path coverage for 6-, 9- and 18-decimal underlyings.
 * @dev Amounts for the configured underlying are `_u(human)`. SE vaultShare stays 18.
 *      Combo ID is recorded by the concrete suite (`U6` / `U9`).
 */
abstract contract AaveV3StataStandardExchange_Real_Decimals is
    TestBase_AaveV3StataStandardExchange_Decimals
{

    /// @dev Quote desired output independently from receipt custody and actual SE supply.
    function _assertExactOut(address asset, uint256 desired, bool prepaid) internal {
        uint256 receipt = asset == realStata ? desired : stataTokenV2.previewWithdraw(desired);
        uint256 supply = IERC20(realVault).totalSupply();
        uint256 required = Math.mulDiv(receipt, supply, IERC20(realStata).balanceOf(realVault), Math.Rounding.Ceil);
        assertGt(required, 0, "funded input required");
        assertEq(IStandardExchangeOut(realVault).previewExchangeOut(IERC20(realVault), IERC20(asset), desired), required);
        uint256 beforeShares = IERC20(realVault).balanceOf(address(this));
        uint256 beforeOutput = IERC20(asset).balanceOf(address(this));
        if (prepaid) IERC20(realVault).transfer(realVault, required);
        uint256 spent = IStandardExchangeOut(realVault).exchangeOut(
            IERC20(realVault), required, IERC20(asset), desired, address(this), prepaid, _deadline()
        );
        assertEq(spent, required, "exact-output quote/execution");
        assertEq(IERC20(asset).balanceOf(address(this)) - beforeOutput, desired, "exact output received");
        assertEq(beforeShares - IERC20(realVault).balanceOf(address(this)), spent, "actual shares spent");
        assertEq(IERC20(realVault).totalSupply(), supply - spent, "supply burn");
        assertEq(IERC20(realVault).balanceOf(realVault), 0, "no stranded prepaid shares");
    }

    function _exitPart(address asset, uint256 depositAmount, uint256 fraction, bool prepaid) internal {
        _fundUnderlying(depositAmount, address(this));
        IERC20(realBase).approve(realVault, depositAmount);
        uint256 shares = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), depositAmount, IERC20(realVault), 1, address(this), false, _deadline()
        );
        uint256 desired = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realVault), Math.mulDiv(shares, fraction, 100), IERC20(asset)
        );
        assertGt(desired, 0, "funded desired output");
        _assertExactOut(asset, desired, prepaid);
    }

    function test_Real_Route_BaseToSE_PreviewMatches() public {
        uint256 amount = _u(10);
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realVault)
        );

        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        assertEq(out, preview, "real: previewExchangeIn must equal execution BaseToSE");
        assertEq(IERC20(realVault).balanceOf(address(this)), out, "real recipient delta must match");
        assertGt(out, 0);
    }

    function test_Real_Route_StataToSE() public {
        uint256 amount = _u(5);

        _fundAToken(amount, address(this));
        IERC20(aToken).approve(realStata, amount);
        uint256 stataShares = stataTokenV2.depositATokens(amount, address(this));

        IERC20(realStata).approve(realVault, stataShares);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realStata), stataShares, IERC20(realVault)
        );

        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), stataShares, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );

        assertEq(out, preview, "real: preview must match for stata->SE");
        assertEq(IERC20(realVault).balanceOf(address(this)), out);
    }

    function test_Real_Route_SEToStata_PreviewMatches() public {
        _exitPart(realStata, _u(20), 50, false);
    }

    function test_Real_Route_SEToBase_PreviewMatches() public {
        _exitPart(realBase, _u(15), 33, false);
    }

    function testFuzz_Real_BaseToSE(uint256 amount) public {
        uint8 d = _underlyingDecimals();
        amount = bound(amount, 1 * (10 ** uint256(d)) / 1000, 500 * (10 ** uint256(d)));
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realVault)
        );
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );
        assertEq(out, preview);
        assertEq(IERC20(realVault).balanceOf(address(this)), out);
    }

    function testFuzz_Real_SEToStata(uint256 dep, uint256 burnFrac) public {
        dep = bound(dep, _u(5), _u(200));
        burnFrac = bound(burnFrac, 1, 90);
        _exitPart(realStata, dep, burnFrac, false);
    }

    function testFuzz_Real_FeeOnBaseToSE(uint256 amount, uint256 fee) public {
        amount = bound(amount, _u(1), _u(100));
        fee = bound(fee, 0, 0.05e18);
        _assertFundedMintFee(amount, fee);
    }

    function testFuzz_Real_SEToStata_Pretransferred(uint256 dep, uint256 burnFrac) public {
        dep = bound(dep, _u(5), _u(200));
        burnFrac = bound(burnFrac, 1, 80);
        _exitPart(realStata, dep, burnFrac, true);
    }

    function test_Real_Route_BaseToStata() public {
        uint256 amount = _u(10);
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realStata)
        );
        uint256 before = IERC20(realStata).balanceOf(address(this));
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realStata), 0, address(this), false, block.timestamp + 100
        );
        assertEq(out, preview, "real: previewExchangeIn BaseToStata");
        assertEq(IERC20(realStata).balanceOf(address(this)) - before, out);
        assertGt(out, 0);
    }

    /// @notice Honest same-tx push: transfer base then pretransferred=true.
    function test_Real_Route_BaseToStata_Pretransferred() public {
        uint256 amount = _u(8);
        _fundUnderlying(amount, address(this));
        IERC20(realBase).transfer(realVault, amount);
        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(realBase), amount, IERC20(realStata)
        );
        uint256 before = IERC20(realStata).balanceOf(address(this));
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realStata), 0, address(this), true, block.timestamp + 100
        );
        assertEq(out, preview, "real: pretransferred BaseToStata");
        assertEq(IERC20(realStata).balanceOf(address(this)) - before, out);
    }

    /// @notice I1: booked residual cannot free-credit a second pretransfer with U=0.
    function test_Real_Route_BaseToStata_Pretransferred_bookedInventory_reverts() public {
        uint256 residual = _u(15);
        uint256 honest = _u(1);
        _fundUnderlying(residual + honest, address(this));
        IERC20(realBase).transfer(realVault, residual);
        IERC20(realBase).approve(realVault, honest);
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), honest, IERC20(realStata), 0, address(this), false, block.timestamp + 100
        );

        vm.expectRevert(
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, residual, uint256(0))
        );
        IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), residual, IERC20(realStata), 0, address(this), true, block.timestamp + 100
        );
    }

    function test_Real_Route_ATokenToStata() public {
        uint256 amount = _u(6);
        _fundAToken(amount, address(this));
        IERC20(aToken).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(aToken), amount, IERC20(realStata)
        );
        uint256 before = IERC20(realStata).balanceOf(address(this));
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(aToken), amount, IERC20(realStata), 0, address(this), false, block.timestamp + 100
        );
        assertEq(out, preview, "real: aToken->stata");
        assertEq(IERC20(realStata).balanceOf(address(this)) - before, out);
        assertGt(out, 0);
    }

    function test_Real_Route_ATokenToSE() public {
        uint256 amount = _u(6);
        _fundAToken(amount, address(this));
        IERC20(aToken).approve(realVault, amount);

        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(
            IERC20(aToken), amount, IERC20(realVault)
        );
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(aToken), amount, IERC20(realVault), 0, address(this), false, block.timestamp + 100
        );
        assertEq(out, preview, "real: aToken->SE");
        assertEq(IERC20(realVault).balanceOf(address(this)), out);
        assertGt(out, 0);
    }

    /// @notice Exact aToken output settles through the real configured Aave pool.
    function test_Real_Route_SEToAToken() public {
        _exitPart(aToken, _u(12), 33, false);
    }

    function test_Real_Route_SEToBase_Pretransferred() public {
        _exitPart(realBase, _u(12), 33, true);
    }

    /// @notice Fee path: user receives full preview; feeTo mints extra shares.
    function test_Real_FeeApplicationAndMarker() public {
        assertEq(IAaveV3StataStandardVault(realVault).stataToken(), realStata, "configured receipt");
        _assertFundedMintFee(_u(10), 0.05e18);
    }

    function _assertFundedMintFee(uint256 amount, uint256 fee) internal {
        _setTestUsageFee(fee);
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);
        address recipient = makeAddr("stata-depositor");
        address collector = address(indexedexManager.feeTo());
        uint256 feeBefore = IERC20(realVault).balanceOf(collector);
        uint256 userBefore = IERC20(realVault).balanceOf(recipient);
        uint256 supplyBefore = IERC20(realVault).totalSupply();
        uint256 receiptBefore = IERC20(realStata).balanceOf(realVault);
        uint256 preview = IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realBase), amount, IERC20(realVault));
        uint256 acquired = stataTokenV2.previewDeposit(amount);
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realVault), preview, recipient, false, _deadline()
        );
        uint256 feeShares = Math.mulDiv(out, fee, 1e18);
        assertEq(out, preview, "fee quote/execution");
        assertEq(IERC20(realVault).balanceOf(recipient) - userBefore, out, "funded user receipt");
        assertEq(IERC20(realVault).balanceOf(collector) - feeBefore, feeShares, "live collector receipt");
        assertEq(IERC20(realVault).totalSupply(), supplyBefore + out + feeShares, "fee supply conservation");
        assertEq(IERC20(realStata).balanceOf(realVault), receiptBefore + acquired, "actual backing acquired");
    }

    function test_Real_FeeOnAndOff() public {
        _assertFundedMintFee(_u(5), 0);
        _assertFundedMintFee(_u(5), 0.05e18);
        _assertFundedMintFee(_u(5), 0);
    }

    /// @notice Reward forwarding uses an actually funded Aave emission campaign.
    function test_Real_RewardsForwarded() public {
        PullRewardsTransferStrategy strategy = new PullRewardsTransferStrategy(
            report.rewardsControllerProxy, EMISSION_ADMIN, EMISSION_ADMIN
        );
        vm.prank(poolAdmin);
        contracts.emissionManager.setEmissionAdmin(rewardToken, EMISSION_ADMIN);
        RewardsDataTypes.RewardsConfigInput[] memory config = new RewardsDataTypes.RewardsConfigInput[](1);
        config[0] = RewardsDataTypes.RewardsConfigInput(
            uint88(1 ether), 0, uint32(block.timestamp + 2 hours), aToken, rewardToken,
            ITransferStrategyBase(address(strategy)), AggregatorInterface(address(new MockAggregator(int256(1e8))))
        );
        vm.prank(EMISSION_ADMIN);
        contracts.emissionManager.configureAssets(config);
        deal(rewardToken, EMISSION_ADMIN, 7200 ether, true);
        vm.prank(EMISSION_ADMIN);
        IERC20(rewardToken).approve(address(strategy), 7200 ether);

        _assertFundedMintFee(_u(10), 0);
        vm.warp(block.timestamp + 60);
        uint256 expected = stataTokenV2.getClaimableRewards(realVault, rewardToken);
        assertGt(expected, 0, "funded reward accrued");
        address collector = address(indexedexManager.feeTo());
        uint256 beforeReward = IERC20(rewardToken).balanceOf(collector);
        _assertFundedMintFee(_u(1), 0);
        assertEq(IERC20(rewardToken).balanceOf(collector) - beforeReward, expected, "actual reward forwarded");
        assertEq(stataTokenV2.getClaimableRewards(realVault, rewardToken), 0, "no second reward claim");
        assertEq(IERC20(rewardToken).balanceOf(realVault), 0, "no stranded SE rewards");
    }

    /// @notice Registry deployment reuses the deterministic instance and its configured receipt.
    function test_Real_MarkerAndDeployment() public {
        assertEq(IAaveV3StataStandardVault(realVault).stataToken(), realStata);
        assertEq(_deployStataVault(realStata), realVault, "deterministic registered instance");
        assertGt(realVault.code.length, 0, "deployed proxy");
    }

    /// @notice Preserve the former mocked receipt-pretransfer fuzz case with actual Stata custody.
    function testFuzz_Real_StataToSE_Pretransferred(uint256 amount) public {
        amount = bound(amount, _u(1), _u(100));
        uint256 receipt = _acquireStata(address(this), amount);
        uint256 expected = IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realStata), receipt, IERC20(realVault));
        IERC20(realStata).transfer(realVault, receipt);
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), receipt, IERC20(realVault), expected, address(this), true, _deadline()
        );
        assertEq(out, expected, "prepaid receipt quote/execution");
        assertEq(IERC20(realStata).balanceOf(realVault), receipt, "actual prepaid custody");
        assertEq(IERC20(realVault).balanceOf(address(this)), out, "received SE shares");
    }

    /// @notice Preserve direct base-to-Stata fuzzing without a fake post-call mint.
    function testFuzz_Real_BaseToStata(uint256 amount) public {
        amount = bound(amount, _u(1), _u(100));
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);
        uint256 expected = stataTokenV2.previewDeposit(amount);
        uint256 beforeReceipt = IERC20(realStata).balanceOf(address(this));
        assertEq(IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realBase), amount, IERC20(realStata)), expected);
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realStata), expected, address(this), false, _deadline()
        );
        assertEq(out, expected);
        assertEq(IERC20(realStata).balanceOf(address(this)) - beforeReceipt, out);
        assertEq(IERC20(realVault).totalSupply(), 0, "direct route mints no SE shares");
    }
}
