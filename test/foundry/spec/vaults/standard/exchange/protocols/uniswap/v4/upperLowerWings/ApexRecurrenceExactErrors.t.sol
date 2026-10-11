// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4UpperLowerWingsStandardExchangeVaultTokensTest as TokenFixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultTokens.t.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {SafeTransferLib} from "@crane/contracts/tokens/ERC20/utils/SafeTransferLib.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as Vault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultMoney as Money} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol";

/// @dev Callback observer only. The money and economic calls target the real vault.
contract WingsReviewCallbackObserver {
    bool public success;
    bytes public reason;
    function probe(address vault_, bytes calldata data_) external {
        (success, reason) = vault_.call(data_);
    }
}

contract WingsApexRecurrenceExactErrorsTest is TokenFixture {
    function _reviewDeposit() private {
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostile)), 1e12,
            IERC20(address(hostileVault)), 1e12, address(this), false, block.timestamp);
    }
    function test_review_inboundTaxExactErrorAndRollback() public {
        hostile.configure(false, address(0), true);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e12, 1e12 - 1));
        _reviewDeposit();
        assertEq(IERC20(address(hostileVault)).totalSupply(), 0);
        assertEq(hostile.balanceOf(address(this)), 1e18);
        assertEq(hostile.balanceOf(address(hostileVault)), 0);
    }
    function test_review_outboundTaxExactErrorAndRollback() public {
        _reviewDeposit();
        uint256 expected = IStandardExchangeIn(address(hostileVault)).previewExchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)));
        assertGt(expected, 1);
        uint256 held = hostile.balanceOf(address(hostileVault));
        hostile.configure(false, address(0), true);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, expected, expected - 1));
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp);
        assertEq(IERC20(address(hostileVault)).totalSupply(), 1e12);
        assertEq(hostile.balanceOf(address(hostileVault)), held);
    }
    function test_review_pauseAndBlacklistExactWrapperError() public {
        _reviewDeposit();
        uint256 balance = hostile.balanceOf(address(this));
        for (uint256 i; i < 2; ++i) {
            hostile.configure(i == 0, i == 0 ? address(0) : address(this), false);
            vm.expectRevert(SafeTransferLib.TransferFailed.selector);
            IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp);
            assertEq(IERC20(address(hostileVault)).totalSupply(), 1e12);
            assertEq(hostile.balanceOf(address(this)), balance);
        }
        hostile.configure(false, address(0), false);
        uint256 paid = IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp);
        assertGt(paid, 0);
        assertEq(hostile.balanceOf(address(this)) - balance, paid);
    }
    function test_review_negativeRebaseExactBackingError() public {
        _reviewDeposit();
        uint256 held = hostile.balanceOf(address(hostileVault));
        hostile.shrink(address(hostileVault), 1);
        vm.expectRevert(abi.encodeWithSelector(Money.BackingDeficit.selector, address(hostile), held, held - 1));
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp);
        assertEq(IERC20(address(hostileVault)).totalSupply(), 1e12);
        assertEq(hostile.balanceOf(address(hostileVault)), held - 1);
    }
    function test_review_callbackMoneyAndEconomicExactReentrancyError() public {
        WingsReviewCallbackObserver observer = new WingsReviewCallbackObserver();
        bytes memory operation = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(hostile)), 1, IERC20(address(hostileVault)), 0, address(this), false, block.timestamp));
        hostile.arm(address(observer), abi.encodeCall(observer.probe, (address(hostileVault), operation)));
        _reviewDeposit();
        assertTrue(hostile.attempted());
        assertFalse(observer.success());
        assertEq(observer.reason(), abi.encodeWithSelector(Vault.ReentrantOperation.selector));
        hostile.arm(address(observer), abi.encodeCall(observer.probe, (address(hostileVault), abi.encodeCall(Vault.liquidationValue, ()))));
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostile)), 1e12,
            IERC20(address(hostileVault)), 0, address(this), false, block.timestamp);
        assertTrue(hostile.attempted());
        assertFalse(observer.success());
        assertEq(observer.reason(), abi.encodeWithSelector(Vault.ReentrantOperation.selector));
    }
}

contract WingsApexRecurrenceUnfundedExitTest is Fixture {
    function test_review_eoaInternalSyRedeemConsumesSelfShares() public {
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1e12, IERC20(address(wings0)), 1e12, address(this), false, block.timestamp);
        uint256 shares = 1e9;
        IERC20(address(wings0)).transfer(address(wings0), shares);
        address outsider = makeAddr("review SY outsider");
        assertEq(outsider.code.length, 0);
        uint256 supply = IERC20(address(wings0)).totalSupply();
        uint256 held = IERC20(address(wings0)).balanceOf(address(wings0));
        vm.prank(outsider);
        vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
        IStandardizedYield(address(wings0)).redeem(outsider, shares, address(token0), 0, true);
        assertEq(token0.balanceOf(outsider), 0);
        assertEq(IERC20(address(wings0)).balanceOf(address(wings0)), held);
        assertEq(IERC20(address(wings0)).totalSupply(), supply);
    }

    function test_review_donationCannotFundSharelessExitExactError() public {
        IStandardExchangeIn(address(wings0)).exchangeIn(token0, 1e12, IERC20(address(wings0)), 1e12, address(this), false, block.timestamp);
        uint256 value = wings0.liquidationValue().value;
        (uint256 local0, uint256 local1) = wings0.localReserves();
        token0.transfer(address(wings0), 12345);
        token1.transfer(address(wings0), 67890);
        address outsider = makeAddr("review outsider");
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1, 0));
        IStandardExchangeIn(address(wings0)).exchangeIn(IERC20(address(wings0)), 1, token0, 0, outsider, false, block.timestamp);
        assertEq(IERC20(address(wings0)).totalSupply(), 1e12);
        assertEq(wings0.liquidationValue().value, value);
        (uint256 after0, uint256 after1) = wings0.localReserves();
        assertEq(after0, local0); assertEq(after1, local1);
        assertEq(token0.balanceOf(address(wings0)), local0 + 12345);
        assertEq(token1.balanceOf(address(wings0)), local1 + 67890);
        assertEq(token0.balanceOf(outsider), 0);
    }
}
