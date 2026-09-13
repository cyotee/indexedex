"""Prepare a full-share round-trip assertion without changing active test inputs."""
from pathlib import Path
import difflib, hashlib, json

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = {}
for decimal in [False, True]:
    folder = root / 'test/foundry/spec/protocol/dexes/uniswap/v3'
    path = folder / ('decimals/adversarial/Adversarial_Accounting_Decimals.sol' if decimal
                     else 'adversarial/Adversarial_Accounting.t.sol')
    before = path.read_text()
    start = before.index('    function test_E1_roundTrip_zapInOut_conservation()')
    end = before.index('    function test_E2_zeroAmountAndDeadline()', start)
    amount0 = '_u0(100)' if decimal else '100 ether'
    amount1 = '_u1(100)' if decimal else '100 ether'
    mint_victim = '_mint(token0, victim, deposit);' if decimal else 'ERC20PermitMintableStub(token0).mint(victim, deposit);'
    mint_attacker = '_mint(token0, attacker, deposit);' if decimal else 'ERC20PermitMintableStub(token0).mint(attacker, deposit);'
    residual = '_u0(1)' if decimal else '1 ether'
    body = f'''    function test_E1_roundTrip_zapInOut_conservation() public {{
        address token0 = pool.token0();
        uint256 deposit = {amount0};
        // A separate holder provides both activation assets. The attacker pays only token0.
        {mint_victim}
        vm.startPrank(victim);
        IERC20(token0).approve(address(vault), type(uint256).max);
        _activateWithFundedToken0(victim, deposit, {amount1});
        vm.stopPrank();

        {mint_attacker}
        uint256 beforePayment = IERC20(token0).balanceOf(attacker);
        vm.startPrank(attacker);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 shares = vault.exchangeIn(
            IERC20(token0), deposit, IERC20(address(vault)), 0, attacker, false, block.timestamp + 1
        );
        vault.approve(address(vault), shares);
        uint256 beforeRedemption = IERC20(token0).balanceOf(attacker);
        uint256 recovered = vault.exchangeIn(
            IERC20(address(vault)), shares, IERC20(token0), 1, attacker, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(vault.balanceOf(attacker), 0, "all attacker shares redeemed");
        assertEq(IERC20(token0).balanceOf(attacker) - beforeRedemption, recovered, "actual recovery");
        assertGt(recovered, 0);
        assertLe(IERC20(token0).balanceOf(attacker), beforePayment, "round trip cannot exceed payment");
        _assertNoUnexpectedFreeInventory({residual});
    }}

'''
    after = before[:start] + body + before[end:]
    changes[str(path.relative_to(root))] = (before, after)

patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
    fromfile='a/' + path, tofile='b/' + path)) for path, (before, after) in changes.items())
(art / 'position-roundtrip-followup.patch').write_text(patch)
(art / 'position-roundtrip-followup-prepared.json').write_text(json.dumps({
    'status': 'PREPARED_NOT_APPLIED',
    'finding': 'The existing E1 test requests only one output unit through exchangeOut; it does not redeem all minted shares despite its round-trip name.',
    'correction': 'A separate holder performs two-token activation; the attacker pays only token0, redeems every acquired share through exact-input exchangeIn, and checks actual recovery and zero remaining shares.',
    'coverage': 'Same base and inherited decimal cases; no test, fuzz setting, or conservation bound removed.',
    'changes': [{'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, (before, after) in changes.items()],
    'application_gate': 'Wait for active validation PTY 52715 to exit. Preserve its actual results, then apply these exact current-file changes and run the retained E1 cases before final complete validation.'
}, indent=2) + '\n')
print('Prepared full-redemption E1 correction for two existing sources; no Solidity changed.')
