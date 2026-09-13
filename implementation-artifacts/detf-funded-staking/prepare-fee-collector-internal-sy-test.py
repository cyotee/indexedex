"""Add one shared funded test for native SY caller context and live collector rotation."""
from pathlib import Path
p=Path('test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol')
s=p.read_text();marker='    function test_directLiquidityOperationsFollowDeploymentPolicy() public {'
assert marker in s
s=s.replace(marker,'''    function test_internalSYRedemptionUsesCurrentCollectorAfterRotation() public {
        uint256 amount = _seedFeeLp() / 100;
        IStandardizedYield sy = IStandardizedYield(address(_hook()));
        IFeeCollectorProxy previous = _collector();
        IERC20 lp = _lp();
        address buyer = _buyer();
        address output = _leadPayment();
        vm.prank(_admin(address(previous)));
        previous.pullFee(lp, amount * 3, address(sy));
        if (_policy()) {
            vm.prank(buyer); vm.expectRevert();
            sy.redeem(buyer, amount, output, 0, true);
        }
        _assertCollectorInternalPayout(sy, address(previous), amount, output, buyer);
        assertEq(sy.balanceOf(address(sy)), amount * 2);

        IFeeCollectorProxy next = _newCollector(address(0xFEE2));
        address oracle = address(_oracle());
        vm.prank(_admin(oracle)); IVaultFeeOracleManager(oracle).setFeeTo(next);
        if (_policy()) {
            vm.prank(address(previous)); vm.expectRevert();
            sy.redeem(buyer, amount, output, 0, true);
        }
        _assertCollectorInternalPayout(sy, address(next), amount, output, buyer);
        assertEq(sy.balanceOf(address(sy)), amount);
        if (_policy()) {
            vm.prank(buyer); vm.expectRevert();
            sy.redeem(buyer, amount, output, 0, true);
        }
        assertEq(sy.balanceOf(address(sy)), amount, "completed collector call leaves no public authority");
    }

    function _assertCollectorInternalPayout(
        IStandardizedYield sy, address collector, uint256 amount, address output, address receiver
    ) private {
        uint256 quote = sy.previewRedeem(output, amount);
        uint256 before = IERC20(output).balanceOf(receiver);
        vm.prank(collector);
        assertEq(sy.redeem(receiver, amount, output, quote, true), quote);
        assertEq(IERC20(output).balanceOf(receiver) - before, quote);
    }

'''+marker)
p.write_text(s)
