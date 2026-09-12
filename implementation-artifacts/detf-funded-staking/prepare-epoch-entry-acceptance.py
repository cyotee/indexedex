"""Prepare the explicit A22 before-boundary/late-entry regression on all V4 policies."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
path = root / 'test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol'
before = path.read_text()
anchor = '    function _fundReserveYield(IUniswapV4Detf subject_, uint256 amount_) private {'
addition = '''    /// @notice A22: stake present one second before the boundary receives its
    /// funded expansion; a deposit processing that boundary enters afterward.
    function test_boundaryStakeParticipationAndLateEntryOrdering() public {
        IUniswapV4Detf subject = _activateFallbackInstance();
        uint256 acquired = _assertFallbackExchange(subject, IERC20(_leadPayment()), 10 ether, IERC20(address(subject)));
        uint256 principal = acquired / 3;
        assertGt(principal, 0);
        IStakedDETF staking = IStakedDETF(subject.rebasingClaimToken());
        address early = address(0xEA412);
        address late = address(0x1A7E);
        uint256 boundary = subject.lastExpansionTimestamp() + 8 hours;
        vm.startPrank(_buyer());
        IERC20(address(subject)).transfer(early, principal);
        IERC20(address(subject)).transfer(late, principal);
        vm.stopPrank();
        _fundReserveYield(subject, 3_000 ether);
        vm.warp(boundary - 1);
        vm.startPrank(early);
        IERC20(address(subject)).approve(address(staking), principal);
        staking.exchangeIn(IERC20(address(subject)), principal, IERC20(address(staking)), principal, early, false, block.timestamp);
        vm.stopPrank();
        assertEq(staking.balanceOf(early), principal, "no time weighting before first boundary");
        assertEq(subject.pendingExpansionDetf(), 0, "incomplete interval is not funded");
        vm.warp(boundary);
        uint256 pending = subject.pendingExpansionDetf();
        uint256 backing = IERC20(address(subject)).balanceOf(address(staking));
        assertGt(pending, 0, "real reserve yield funds eligible expansion");
        vm.startPrank(late);
        IERC20(address(subject)).approve(address(staking), principal);
        staking.exchangeIn(IERC20(address(subject)), principal, IERC20(address(staking)), principal, late, false, block.timestamp);
        vm.stopPrank();
        assertGt(staking.balanceOf(early), principal, "pre-boundary stake participates");
        assertEq(staking.balanceOf(late), principal, "boundary-processing deposit enters after distribution");
        assertEq(IERC20(address(subject)).balanceOf(address(staking)), backing + pending + principal);
        assertEq(subject.lastExpansionTimestamp(), boundary);
        assertEq(subject.pendingExpansionDetf(), 0, "boundary consumed exactly once");
        uint256 earlyClaim = staking.balanceOf(early);
        vm.prank(early);
        staking.exchangeIn(IERC20(address(staking)), earlyClaim, IERC20(address(subject)), earlyClaim, early, false, block.timestamp);
        assertEq(staking.balanceOf(early), 0);
        assertEq(IERC20(address(subject)).balanceOf(early), earlyClaim, "funded reward and principal unstake one-for-one");
        assertEq(staking.balanceOf(late), principal, "another holder's full exit cannot consume late principal");
    }

'''
assert anchor in before
assert 'function test_boundaryStakeParticipationAndLateEntryOrdering' not in before
after = before.replace(anchor, addition + anchor, 1)
record = {
    'status': 'applied; validation pending' if args.apply else 'prepared, not applied while Solidity compiles',
    'path': str(path.relative_to(root)),
    'criteria': ['A2', 'A3', 'A17', 'A22', 'A25'],
    'scope': 'One inherited production-path case across four V4 reserves and both liquidity policies; existing fixture and actual yield funding.',
    'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
    'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
}
(artifacts / 'epoch-entry-acceptance.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))))
if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    path.write_text(after)
(artifacts / 'epoch-entry-acceptance.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
