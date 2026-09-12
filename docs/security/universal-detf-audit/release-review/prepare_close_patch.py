"""Prepare the custom-close inventory correction after preserving baseline evidence."""

import difflib
from pathlib import Path

root = Path(__file__).parent
changes = {}
path = Path('contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol')
before = path.read_text()
after = before.replace(
    '_payCustomClose(tokens_, minAmountsOut[0], recipient, deadline)',
    '_payCustomClose(tokens_, withdrawn_, minAmountsOut[0], recipient, deadline)', 1
)
start = after.index('    function _payCustomClose(')
end = after.index('    function _payDefaultClose(', start)
after = after[:start] + '''    function _payCustomClose(
        address[] memory tokens_,
        uint256[] memory withdrawn_,
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) private returns (uint256[] memory amountsOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        address closeTok_ = address(s.closeTable.tokens._values()[0]);
        uint256 proceeds_;
        for (uint256 k; k < tokens_.length; ++k) {
            address t_ = tokens_[k];
            if (t_ == address(this)) continue;
            uint256 leg_ = withdrawn_[k];
            if (t_ == closeTok_) {
                proceeds_ += leg_;
                continue;
            }
            if (leg_ == 0) continue;
            // Only this bond's withdrawn leg belongs to its closing holder.
            // Pre-existing inventory remains subject to the R19 dust policy.
            uint256 before_ = IERC20(closeTok_).balanceOf(address(this));
            IERC20(t_).forceApprove(s.hook, leg_);
            _hook().ownerSwapExactIn(t_, closeTok_, leg_, 0, deadline_);
            IERC20(t_).forceApprove(s.hook, 0);
            proceeds_ += IERC20(closeTok_).balanceOf(address(this)) - before_;
        }
        amountsOut_ = new uint256[](1);
        amountsOut_[0] = proceeds_;
        if (proceeds_ < minOut_) {
            revert IStandardExchangeErrors.MinAmountNotMet(minOut_, proceeds_);
        }
        if (proceeds_ > 0) IERC20(closeTok_).safeTransfer(recipient_, proceeds_);
    }

''' + after[end:]
assert after != before
changes[str(path)] = before, after

path = Path('test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Quad.t.sol')
before = path.read_text()
marker = '    function test_T8_3_firstBond_fourLegs()'
tests = '''    /// @notice Custom settlement must not swap unrelated pair inventory for a closing holder.
    function test_E6_customClose_doesNotSwapPriorPairInventory() public {
        IUniswapV4Detf info = IUniswapV4Detf(_deployQuadHookThenDetf(_customClosePair0Args()));
        vm.startPrank(detfUser);
        pair0.approve(address(info), type(uint256).max);
        pair1.approve(address(info), type(uint256).max);
        (uint256 tokenId,) = info.bond(
            IERC20(address(pair0)), 80 ether, DEFAULT_MIN_LOCK, detfUser,
            false, block.timestamp + 1 hours
        );
        info.bond(
            IERC20(address(pair1)), 40 ether, DEFAULT_MIN_LOCK, detfUser,
            false, block.timestamp + 1 hours
        );
        vm.stopPrank();
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 checkpoint = vm.snapshotState();
        vm.prank(detfUser);
        uint256[] memory clean = info.closeBondMature(
            tokenId, new uint256[](1), detfUser, block.timestamp + 1 hours
        );
        assertTrue(vm.revertToState(checkpoint));

        address donor = makeAddr("unrelatedQuadInventoryDonor");
        pair1.mint(donor, 10 ether);
        vm.prank(donor);
        pair1.transfer(address(info), 10 ether);
        uint256 balanceBefore = pair0.balanceOf(detfUser);
        vm.prank(detfUser);
        uint256[] memory funded = info.closeBondMature(
            tokenId, new uint256[](1), detfUser, block.timestamp + 1 hours
        );
        assertEq(funded[0], clean[0], "prior pair inventory is not converted into bond proceeds");
        assertEq(pair0.balanceOf(detfUser) - balanceBefore, clean[0], "only attributed settlement paid");
    }

'''
after = before.replace(marker, tests + marker, 1)
assert after != before
changes[str(path)] = before, after

patch = ''.join(''.join(difflib.unified_diff(
    before.splitlines(True), after.splitlines(True), fromfile='a/' + path, tofile='b/' + path
)) for path, (before, after) in changes.items())
(root / 'custom-close.patch').write_text(patch)
print('Prepared custom-close production fix and Quad regression; sources unchanged.')
