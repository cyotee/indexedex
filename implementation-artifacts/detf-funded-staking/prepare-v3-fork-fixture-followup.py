"""Prepare retained V3 live-pool fixture migrations without changing frozen sources."""
from pathlib import Path
import difflib, hashlib, json, re

art = Path(__file__).resolve().parent
root = art.parent.parent
drafts = art / 'v3-fork-fixture-followup-drafts'
drafts.mkdir(exist_ok=True)
files = [
    ('base', 'test/foundry/fork/base_main/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Fork.t.sol', 'WETH'),
    ('robinhood', 'test/foundry/fork/robinhood_4663/protocol/dexes/uniswap/v3/UniswapV3StandardExchange_Robinhood.t.sol', 'ROBINHOOD_MAIN.WETH9'),
]
changes, patches = [], []
for label, path, weth in files:
    before = (root / path).read_text()
    after = before.replace(
        'import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";',
        'import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";\n'
        'import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";'
    )
    prefix = 'test_fork_' if label == 'base' else 'test_fork4663_'
    start = after.index('    function ' + prefix)
    methods = '''    /// @dev Small live-pool payments, expressed in each token's native units.
    function _paymentUnit(address token) private view returns (uint256) {
        uint256 unit = 10 ** uint256(IERC20Metadata(token).decimals());
        return token == WETH_TOKEN ? unit / 1000 : unit;
    }

    function _depositBoth(address recipient, uint256 multiples) private returns (uint256 shares) {
        address[] memory tokens = new address[](2);
        tokens[0] = pool.token0();
        tokens[1] = pool.token1();
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = multiples * _paymentUnit(tokens[0]);
        amounts[1] = multiples * _paymentUnit(tokens[1]);
        deal(tokens[0], recipient, amounts[0]);
        deal(tokens[1], recipient, amounts[1]);
        vm.startPrank(recipient);
        IERC20(tokens[0]).approve(address(vault), amounts[0]);
        IERC20(tokens[1]).approve(address(vault), amounts[1]);
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 1, recipient, false, block.timestamp + 1
        );
        vm.stopPrank();
        assertEq(IERC20(address(vault)).balanceOf(recipient), shares, "funded initial shares");
    }

'''.replace('WETH_TOKEN', weth)
    if label == 'base':
        methods += '''    function test_fork_directSwap_and_zap() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        address alice = makeAddr("alice");
        uint256 payment = _paymentUnit(token0);
        deal(token0, alice, 2 * payment);
        vm.startPrank(alice);
        IERC20(token0).approve(address(vault), type(uint256).max);
        uint256 out = vault.exchangeIn(IERC20(token0), payment, IERC20(token1), 1, alice, false, block.timestamp + 1);
        assertEq(IERC20(token1).balanceOf(alice), out, "direct swap received");
        vm.stopPrank();

        // Activation needs both assets; the later one-token deposit remains supported.
        _depositBoth(makeAddr("seed-owner"), 10);
        uint256 quoted = vault.previewExchangeIn(IERC20(token0), payment, IERC20(address(vault)));
        assertGt(quoted, 0, "subsequent single-token quote");
        vm.prank(alice);
        uint256 shares = vault.exchangeIn(
            IERC20(token0), payment, IERC20(address(vault)), quoted, alice, false, block.timestamp + 1
        );
        assertEq(shares, quoted, "zap preview/execution");
        assertEq(IERC20(address(vault)).balanceOf(alice), shares, "zap received");
    }

'''
    methods += '''    function PREFIXMJ2_or_FR1_fullRangeCenter() public {
        uint256 shares = _depositBoth(makeAddr("alice"), 5);
        assertGt(shares, 0, "MJ2 shares");
        int24 spacing = pool.tickSpacing();
        (uint128 liq,,,,) = pool.positions(keccak256(abi.encodePacked(
            address(vault), TickMath.minUsableTick(spacing), TickMath.maxUsableTick(spacing)
        )));
        assertGt(liq, 0, "FR1/MJ2: full-range L");
    }

    function PREFIXA0_deadSharesOnResidual() public {
        address token0 = pool.token0();
        address token1 = pool.token1();
        deal(token0, address(vault), _paymentUnit(token0));
        deal(token1, address(vault), _paymentUnit(token1));
        uint256 userShares = _depositBoth(makeAddr("alice-a0"), 2);
        uint256 dead = IERC20(address(vault)).balanceOf(DEAD);
        assertGt(dead, 0, "A0 dead");
        // The user contributes twice each donated leg and may own at most 2/3.
        assertLe(userShares, 2 * dead, "A0 no capture of either donated leg");
        assertEq(IERC20(address(vault)).totalSupply(), userShares + dead, "A0 supply conservation");
    }

    function PREFIXblockedSleevePath() public {
        _depositBoth(makeAddr("seed-owner"), 10);
        UniswapV3BoundPoolLockSeCaller lockCaller = new UniswapV3BoundPoolLockSeCaller(pool);
        address token0 = pool.token0();
        uint256 payment = _paymentUnit(token0);
        deal(token0, address(lockCaller), 2 * payment);
        deal(pool.token1(), address(lockCaller), _paymentUnit(pool.token1()));
        vm.prank(address(lockCaller));
        IERC20(token0).approve(address(vault), payment);
        uint256 sleeveBefore = IERC20(token0).balanceOf(address(vault));
        uint256 supplyBefore = IERC20(address(vault)).totalSupply();
        uint256 shares = lockCaller.runExchangeIn(
            address(vault), IERC20(token0), payment, IERC20(address(vault)), 1, address(this), false, block.timestamp + 1
        );
        assertGt(shares, 0, "blocked sleeve mint");
        assertEq(IERC20(address(vault)).balanceOf(address(this)), shares, "blocked recipient shares");
        assertEq(IERC20(address(vault)).totalSupply(), supplyBefore + shares, "blocked supply delta");
        assertEq(IERC20(token0).balanceOf(address(vault)), sleeveBefore + payment, "payment retained in sleeve");
    }
}
'''.replace('PREFIX', prefix)
    after = after[:start] + methods
    if label == 'robinhood':
        after = after.replace(
            '        try vm.createSelectFork("robinhood_mainnet_alchemy") {}\n'
            '        catch {\n'
            '            vm.createSelectFork("robinhood_mainnet");\n'
            '        }',
            '        uint256 forkBlock = vm.envOr("ROBINHOOD_FORK_BLOCK", uint256(56118361));\n'
            '        try vm.createSelectFork("robinhood_mainnet_alchemy", forkBlock) {}\n'
            '        catch {\n'
            '            vm.createSelectFork("robinhood_mainnet", forkBlock);\n'
            '        }'
        )
    names = lambda source: re.findall(r'function\s+(test\w+)\s*\(', source)
    assert names(before) == names(after), (path, names(before), names(after))
    draft = drafts / (label + '.sol.txt')
    draft.write_text(after)
    patches.extend(difflib.unified_diff(before.splitlines(keepends=True), after.splitlines(keepends=True), fromfile=path, tofile=path))
    changes.append({'path': path, 'draft': str(draft.relative_to(root)),
        'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
        'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
        'retained_direct_cases': names(after)})
(art / 'v3-fork-fixture-followup.patch').write_text(''.join(patches))
record = {'status': 'PREPARED_NOT_APPLIED', 'changes': changes,
    'direct_cases': 7, 'additional_inherited_base_sanity_case': 1,
    'reason': 'Three retained cases require dual activation before later single-token deposits. Preserve all seven declared cases and inherited Base sanity; normalize actual token units, strengthen custody/conservation assertions, and pin Robinhood block.',
    'gate': 'Do not apply until active full build/hermetic/baseline attribution parent has exited. Preserve before hashes and backups; execute retained real-pool fork cases before acceptance.'}
(art / 'v3-fork-fixture-followup-prepared.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'status': record['status'], 'changed_sources': len(changes), 'direct_cases': 7}))
