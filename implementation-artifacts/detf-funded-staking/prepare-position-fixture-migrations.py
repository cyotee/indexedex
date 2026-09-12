"""Prepare existing V3/V4 fixture migrations without changing active build inputs."""
from pathlib import Path
import difflib, hashlib, json, re

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = {}
multi_import = 'import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";'

def function_span(text, name):
    matches = list(re.finditer(r'    function ' + re.escape(name) + r'\(', text))
    assert len(matches) == 1, (name, len(matches))
    start = matches[0].start()
    opening = text.index('{', matches[0].end())
    depth, end = 1, opening + 1
    while depth:
        if text[end] == '{': depth += 1
        elif text[end] == '}': depth -= 1
        end += 1
    return start, end

def edit_function(text, name, edit):
    start, end = function_span(text, name)
    return text[:start] + edit(text[start:end]) + text[end:]

def add_import(text, value=multi_import):
    if value not in text:
        text = text.replace('pragma solidity ^0.8.0;', 'pragma solidity ^0.8.0;\n\n' + value, 1)
    return text

def dual_arrays(token0='_token0()', token1='_token1()', amount0='amount0', amount1='amount1'):
    return f'''        address[] memory tokens = new address[](2);
        tokens[0] = {token0};
        tokens[1] = {token1};
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = {amount0};
        amounts[1] = {amount1};
'''

def save(path, before, after):
    assert after != before, path
    changes[str(path.relative_to(root))] = (before, after)

for version in ['v3', 'v4']:
    for decimal in [False, True]:
        base = root / ('test/foundry/spec/protocol/dexes/uniswap/' + version)
        suffix = '_Decimals.sol' if decimal else '.t.sol'
        path = (base / 'decimals' if decimal else base) / ('Uniswap' + version.upper() + 'StandardExchange_LocalLiquidBuffer' + suffix)
        before = path.read_text()
        text = add_import(before)
        seed = '_bootstrapDeposit(_u0(20), _u1(20));' if version == 'v3' and decimal else (
            '_bootstrapDeposit(20);' if decimal else '_bootstrapDeposit(20 ether);')
        # Single-token behavior remains valid after mandatory two-token activation.
        for name in re.findall(r'function (test_T(?:1b_|2_|8_)[A-Za-z0-9_]+)\(', text):
            text = edit_function(text, name, lambda body: body.replace(' public {', ' public {\n        ' + seed, 1))
        if version == 'v3':
            old_name = 'test_T1b_idleDeposit_token0Only_doesNotRequireSleeveAndL'
            def single_after_activation(body):
                body = body.replace(old_name, 'test_T1b_subsequentSingleTokenDeposit_keepsFullRangeLiquidity')
                body = re.sub(r'        \(uint256 dep0, uint256 dep1\) = liquid.deployedReserve\(\);\n(?:        //[^\n]*\n)?        assertTrue\(dep0 \+ dep1 == 0[^\n]*\n',
                    '        assertGt(_centerLiquidity(), 0, "T1b: full-range position retained");\n', body)
                return body
            text = edit_function(text, old_name, single_after_activation)
        if decimal:
            def bootstrap(body):
                start = body.index('        uint256 shares0 =')
                end = body.index('        assertGt(shares', start)
                return body[:start] + dual_arrays() + '''        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
''' + body[end:]
            text = edit_function(text, '_bootstrapDeposit', bootstrap)
        if version == 'v3' and decimal:
            def locked_first(body):
                start = body.index('        lockCaller.runExchangeIn(')
                end = body.index('        assertEq(_centerLiquidity()', start)
                return body[:start] + dual_arrays() + '''        uint256 shares = lockCaller.runExchangeInManyToOne(
            address(vault), tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "T12: funded shares while blocked");
''' + body[end:]
            text = edit_function(text, 'test_T12_firstMintBlocked_thenFreeRebalanceCreatesPosition', locked_first)
        if version == 'v4':
            mint_type = 'MintableERC20Decimals' if decimal else 'ERC20PermitMintableStub'
            amount0 = '_u0(8)' if decimal else '8 ether'
            amount1 = '_u1(8)' if decimal else '8 ether'
            text = edit_function(text, 'test_T12_firstMintBlocked_thenFreeRebalanceCreatesPosition', lambda _: f'''    function test_T12_firstMintBlocked_thenFreeRebalanceCreatesPosition() public {{
        uint256 amount0 = {amount0};
        uint256 amount1 = {amount1};
        {mint_type}(_token0()).mint(address(unlockCaller), amount0);
        {mint_type}(_token1()).mint(address(unlockCaller), amount1);
        vm.startPrank(address(unlockCaller));
        IERC20(_token0()).approve(address(vault), amount0);
        IERC20(_token1()).approve(address(vault), amount1);
        vm.stopPrank();
''' + dual_arrays() + '''        uint256 shares = unlockCaller.runExchangeInManyToOne(
            address(vault), tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        assertGt(shares, 0, "first mint funded in both sleeve currencies");
        (uint256 dep0, uint256 dep1) = liquid.deployedReserve();
        assertEq(dep0, 0, "no token0 deployed during outer unlock");
        assertEq(dep1, 0, "no token1 deployed during outer unlock");
        assertEq(liquid.localReserve(_token0()), amount0, "token0 held in sleeve");
        assertEq(liquid.localReserve(_token1()), amount1, "token1 held in sleeve");
        liquid.rebalanceLiquidReserve();
        (dep0, dep1) = liquid.deployedReserve();
        assertGt(dep0, 0, "idle rebalance deploys token0");
        assertGt(dep1, 0, "idle rebalance deploys token1");
        assertTrue(liquid.canOpenPoolManagerUnlock(), "idle");
    }''')
            text = edit_function(text, 'test_T3_publicRebalanceAfterBlockedDeposit', lambda _: '''    function test_T3_publicRebalanceAfterBlockedDeposit() public {
        test_T2_inSessionDeposit_sleeveNoNestedUnlock();
        assertTrue(liquid.canOpenPoolManagerUnlock(), "idle after outer unlock");
        uint256 supplyBefore = vault.totalSupply();
        liquid.rebalanceLiquidReserve();
        assertEq(vault.totalSupply(), supplyBefore, "rebalance does not issue shares");
        _assertFreeWithinDeadband(0.2e18);
    }''')
            # Exercise an actual hostile-token pull, not failed initialization or unfunded pair input.
            def hostile_test(body):
                start = body.index('        hostile.setAttackTarget(')
                return body[:start] + '''        hostile.mint(address(this), 11 ether);
        pair.mint(address(this), 10 ether);
        hostile.approve(address(hVault), 11 ether);
        pair.approve(address(hVault), 10 ether);
''' + dual_arrays('Currency.unwrap(hk.currency0)', 'Currency.unwrap(hk.currency1)', '10 ether', '10 ether') + '''        uint256 initialShares = IStandardExchangeInMulti(address(hVault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(hVault)), 0, address(this), false, _deadline()
        );
        assertGt(initialShares, 0, "hostile vault activated before arming reentry");
        hostile.setAttackTarget(address(hVault), true);
        uint256 depositedShares = hVault.exchangeIn(
            IERC20(address(hostile)), 1 ether, IERC20(address(hVault)), 0, address(this), false, _deadline()
        );
        assertGt(depositedShares, 0, "outer funded deposit completes");
        assertEq(hostile.reentryAttempts(), 1, "hostile transferFrom reaches nested call");
        assertFalse(hostile.nestedCallSucceeded(), "nested deposit blocked");
        assertEq(hostile.nestedErrorSelector(), IReentrancyLock.IsLocked.selector, "nested guard error");
    }'''
            text = edit_function(text, 'test_T13_reentrancyBlockedDeposit', hostile_test)
            text = add_import(text, 'import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";')
            # Observe the nested error inside the hostile token: SafeTransferLib masks bubbled token errors.
            attack = '''            IStandardExchangeProxy(attackVault)
                .exchangeIn(IERC20(address(this)), 0, IERC20(attackVault), 0, address(this), true, block.timestamp + 1);'''
            assert attack in text
            text = text.replace(attack, '''            ++reentryAttempts;
            try IStandardExchangeProxy(attackVault).exchangeIn(
                IERC20(address(this)), 0, IERC20(attackVault), 0, address(this), true, block.timestamp + 1
            ) returns (uint256) {
                nestedCallSucceeded = true;
            } catch (bytes memory reason) {
                if (reason.length >= 4) {
                    bytes4 selector;
                    assembly { selector := mload(add(reason, 32)) }
                    nestedErrorSelector = selector;
                }
            }''', 1)
            hostile_class = 'contract HostileReenterERC20' + ('Decimals' if decimal else '') + ' {'
            assert hostile_class in text
            text = text.replace(hostile_class, hostile_class + '''
    uint256 public reentryAttempts;
    bool public nestedCallSucceeded;
    bytes4 public nestedErrorSelector;''', 1)
        save(path, before, text)

for decimal in [False, True]:
    base = root / 'test/foundry/spec/protocol/dexes/uniswap/v4'
    path = (base / 'decimals' if decimal else base) / ('UniswapV4StandardExchange_NativeEthWrap' + ('_Decimals.sol' if decimal else '.t.sol'))
    before = path.read_text()
    text = add_import(before)
    pair10 = '_uA(10)' if decimal else '10 ether'
    pair11 = '_uA(11)' if decimal else '11 ether'
    pair1 = '_uA(1)' if decimal else '1 ether'
    token_type = 'MintableERC20Decimals' if decimal else 'ERC20PermitMintableStub'
    constructor_args = '"Pair", "PAIR", _tokenADecimals()' if decimal else '"Pair", "PAIR", 18, address(this), 0'
    old_deploy = 'pairToken = new ' + token_type + '(' + constructor_args + ');'
    assert old_deploy in text
    text = text.replace(old_deploy, 'pairToken = _deployNativePair();', 1)
    # Force the order that exposed the production bug; avoid a coincidental passing address sort.
    deploy_helper = '''    function _deployNativePair() internal returns (''' + token_type + ''' deployed) {
        bytes32 initHash = keccak256(abi.encodePacked(
            type(''' + token_type + ''').creationCode, abi.encode(''' + constructor_args + ''')
        ));
        for (uint256 nonce; ; ++nonce) {
            bytes32 salt = bytes32(nonce);
            address predicted = address(uint160(uint256(keccak256(
                abi.encodePacked(bytes1(0xff), address(this), salt, initHash)
            ))));
            if (predicted < address(weth)) {
                return new ''' + token_type + '''{salt: salt}(''' + constructor_args + ''');
            }
        }
    }

'''
    start, _ = function_span(text, '_assertNoNativeDust')
    text = text[:start] + deploy_helper + text[start:]
    def zapin(body):
        body = body.replace('deposit{value: 10 ether}', 'deposit{value: 11 ether}')
        body = body.replace('mint(address(this), ' + pair10 + ')', 'mint(address(this), ' + pair11 + ')')
        body = body.replace('approve(address(vault), 10 ether)', 'approve(address(vault), 11 ether)')
        body = body.replace('approve(address(vault), ' + pair10 + ')', 'approve(address(vault), ' + pair11 + ')')
        return body.replace('        uint256 shares0 =', '        _activateNativeVault(1 ether, ' + pair1 + ');\n\n        uint256 shares0 =', 1)
    text = edit_function(text, 'test_zapIn_nativeEthPool_unwrapsWethAndLeavesNoEthDust', zapin)
    old = '''        vault.exchangeIn(IERC20(address(weth)), 10 ether, IERC20(address(vault)), 0, address(this), false, _deadline());
        vault.exchangeIn(
            IERC20(address(pairToken)), ''' + pair10 + ''', IERC20(address(vault)), 0, address(this), false, _deadline()
        );'''
    assert text.count(old) == 2
    text = text.replace(old, '        _activateNativeVault(10 ether, ' + pair10 + ');')
    helper = '''    /// @dev PoolKey order is native currency first, exposed as WETH even when its address sorts last.
    function _activateNativeVault(uint256 wethAmount, uint256 pairAmount) internal returns (uint256 shares) {
''' + dual_arrays('address(weth)', 'address(pairToken)', 'wethAmount', 'pairAmount') + '''        uint256 preview = IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(
            tokens, amounts, IERC20(address(vault))
        );
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), preview, address(this), false, _deadline()
        );
        assertEq(shares, preview, "native activation preview equals execution");
        assertGt(shares, 0, "native two-token activation");
        assertGt(uint160(tokens[0]), uint160(tokens[1]), "WETH face deliberately sorts after pair");
        (tokens[0], tokens[1]) = (tokens[1], tokens[0]);
        vm.expectRevert(bytes4(keccak256("ExchangeInNotAvailable()")));
        IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(tokens, amounts, IERC20(address(vault)));
        vm.expectRevert(bytes4(keccak256("ExchangeInNotAvailable()")));
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
        _assertNoNativeDust();
    }

'''
    start, _ = function_span(text, '_assertNoNativeDust')
    text = text[:start] + helper + text[start:]
    save(path, before, text)

for decimal in [False, True]:
    base = root / 'test/foundry/spec/protocol/dexes/uniswap/v3'
    path = (base / 'decimals/adversarial' if decimal else base / 'adversarial') / ('Adversarial_Reentrancy_Decimals.sol' if decimal else 'Adversarial_Reentrancy.t.sol')
    before = path.read_text()
    text = add_import(before)
    h100 = '_uH(100)' if decimal else '100 ether'
    p100 = '_uP(100)' if decimal else '100 ether'
    def payout(body):
        body = body.replace('        // Bootstrap shares via pair token zap so hostile is still paid on zap-out to hostile.\n', '')
        body = body.replace('        pairToken.mint(victim, ', '        hostile.mint(victim, ' + h100 + ');\n        pairToken.mint(victim, ', 1)
        body = body.replace('        tokenPair.approve', '        tokenHostile.approve(address(hostileVault), type(uint256).max);\n        tokenPair.approve', 1)
        start = body.index('        uint256 shares = hostileVault.exchangeIn(')
        end = body.index('        vm.stopPrank();', start)
        return body[:start] + '        uint256 shares = _activateHostileVault(' + h100 + ', ' + p100 + ', victim);\n' + body[end:]
    text = edit_function(text, 'test_C2_reentrancy_exchangeOut_isLocked', payout)
    def mint_callback(body):
        body = re.sub(r'        IERC20 tokenOut = IERC20\(address\(hostileVault\)\);[^\n]*\n', '', body)
        start = body.index('        uint256 shares = hostileVault.exchangeIn(')
        end = body.index('        vm.stopPrank();', start)
        p30 = '_uP(30)' if decimal else '30 ether'
        body = body[:start] + '        uint256 shares = _activateHostileVault(amountIn, ' + p30 + ', attacker);\n' + body[end:]
        return body.replace('C4 outer zap completed', 'C4 outer activation completed')
    text = edit_function(text, 'test_C4_callback_reentry_blocked', mint_callback)
    text = text.replace('authenticated mint callback (zap mint)', 'authenticated two-token activation mint callback')
    helper = '''    function _activateHostileVault(uint256 hostileAmount, uint256 pairAmount, address recipient)
        internal returns (uint256 shares)
    {
''' + dual_arrays('hostilePool.token0()', 'hostilePool.token1()', 'tokens[0] == address(hostile) ? hostileAmount : pairAmount', 'tokens[1] == address(hostile) ? hostileAmount : pairAmount') + '''        shares = IStandardExchangeInMulti(address(hostileVault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(hostileVault)), 0, recipient, false, block.timestamp + 1
        );
    }

'''
    start, _ = function_span(text, '_assertIsLockedProbe')
    text = text[:start] + helper + text[start:]
    save(path, before, text)

base = root / 'test/foundry/spec/protocol/dexes/uniswap/v3/decimals'
path = base / 'UniswapV3StandardExchange_FeeCompound_Decimals.sol'
before = path.read_text()
text = add_import(before)
start = text.index('        uint256 incumbentShares0 =')
end = text.index('\n        _swapHuman(', start)
text = text[:start] + dual_arrays('token0', 'token1', 'large0', 'large1') + '''        uint256 incumbentShares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, incumbent, false, block.timestamp + 1
        );
        vm.stopPrank();
''' + text[end:]
save(path, before, text)

path = base / 'UniswapV3StandardExchange_Import_Decimals.sol'
before = path.read_text()
def around_spot(body):
    return body.replace('        address token0 =', '''        // Callers specify offsets around the human 1:1 spot, which is not tick zero for mixed decimals.
        (, int24 currentTick,,,,,) = pool.slot0();
        int24 alignedTick = (currentTick / pool.tickSpacing()) * pool.tickSpacing();
        tickLower += alignedTick;
        tickUpper += alignedTick;
        address token0 =''', 1)
text = edit_function(before, '_mintNpmPosition', around_spot)
save(path, before, text)

for version in ['v3', 'v4']:
    for decimal in [False, True]:
        base = root / ('test/foundry/spec/protocol/dexes/uniswap/' + version)
        path = (base / 'decimals' if decimal else base) / ('Uniswap' + version.upper() + 'StandardExchangeDFPkg_Deploy' + ('_Decimals.sol' if decimal else '.t.sol'))
        before = path.read_text()
        text = before.replace('interfaces.length, 13,', 'interfaces.length, 15,')
        text = text.replace('config.vaultTypes.length, 12,', 'config.vaultTypes.length, 15,')
        save(path, before, text)

for decimal in [False, True]:
    base = root / 'test/foundry/spec/protocol/dexes/uniswap/v4'
    path = (base / 'decimals' if decimal else base) / ('UniswapV4StandardExchangeRoutes_Test_Decimals.sol' if decimal else 'UniswapV4StandardExchangeRoutes_Test.t.sol')
    before = path.read_text()
    text = add_import(before)
    unit0 = lambda n: '_u0(' + str(n) + ')' if decimal else str(n) + ' ether'
    unit1 = lambda n: '_u1(' + str(n) + ')' if decimal else str(n) + ' ether'
    mint_type = 'MintableERC20Decimals' if decimal else 'ERC20PermitMintableStub'
    # The same first-activation case covers quote, funding, recipient and supply, replacing duplicate setups.
    for side in ['token0', 'token1']:
        text = edit_function(text, 'test_previewExchangeIn_zap_firstDeposit_matchesExecution_' + side + 'ToShares', lambda _: '')
        text = text.replace('test_exchangeIn_zap_' + side + 'ToShares_firstDeposit', 'test_twoTokenActivation_' + side + 'Dominant_previewAndExecution')
    text = edit_function(text, '_test_previewExchangeIn_zap_firstDeposit_matchesExecution', lambda _: '')
    text = edit_function(text, '_test_exchangeIn_zap_firstDeposit', lambda _: '''    function _test_exchangeIn_zap_firstDeposit(bool token0Dominant) internal {
''' + dual_arrays('_token0Address()', '_token1Address()', 'token0Dominant ? ' + unit0(2) + ' : ' + unit0(1), 'token0Dominant ? ' + unit1(1) + ' : ' + unit1(2)) + '''        address recipient = makeAddr(token0Dominant ? "firstToken0Dominant" : "firstToken1Dominant");
        for (uint256 i; i < 2; ++i) {
            _tokenStub(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(vault), amounts[i]);
        }
        uint256 preview = IStandardExchangeInMulti(address(vault)).previewExchangeInManyToOne(
            tokens, amounts, IERC20(address(vault))
        );
        uint256 shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), preview, recipient, false, _deadline()
        );
        assertGt(shares, 0, "two-token initial shares");
        assertEq(shares, preview, "activation preview equals execution");
        assertEq(vault.balanceOf(recipient), shares, "activation recipient shares");
        assertEq(vault.totalSupply(), shares, "activation total supply");
        assertGt(vault.reserveOfToken(tokens[0]), 0, "activation token0 reserve");
        assertGt(vault.reserveOfToken(tokens[1]), 0, "activation token1 reserve");
    }''')
    if not decimal:
        text = edit_function(text, '_bootstrapDualShares', lambda _: '')
        text = text.replace('_bootstrapDualShares()', '_bootstrapShares()')
    text = edit_function(text, '_bootstrapShares', lambda _: '''    function _bootstrapShares() internal returns (uint256 bootstrapShares) {
''' + dual_arrays('_token0Address()', '_token1Address()', unit0(2), unit1(2)) + '''        for (uint256 i; i < 2; ++i) {
            _tokenStub(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(vault), amounts[i]);
        }
        bootstrapShares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
    }''')
    def second(body):
        start = body.index('        uint256 bootstrapAmount =')
        end = body.index('        assertGt(bootstrapShares', start)
        return body[:start] + '        ' + mint_type + ' t0 = _tokenStub(_token0Address());\n        uint256 bootstrapShares = _bootstrapShares();\n' + body[end:]
    text = edit_function(text, 'test_exchangeIn_zap_token0ToShares_secondDeposit', second)
    if decimal:
        def preview_second(body):
            start = body.index('        uint256 bootstrapAmount =')
            end = body.index('        uint256 amountIn =', start)
            return body[:start] + '        _bootstrapShares();\n\n' + body[end:]
        text = edit_function(text, '_test_previewExchangeIn_zap_secondDeposit_matchesExecution', preview_second)
    for name in ['test_exchangeIn_zap_pretransferred_true', 'test_exchangeIn_zap_reverts_whenMinSharesTooHigh']:
        text = edit_function(text, name, lambda body: body.replace(' public {', ' public {\n        _bootstrapShares();', 1))
    save(path, before, text)

for decimal in [False, True]:
    base = root / 'test/foundry/spec/protocol/dexes/uniswap/v3'
    for family in ['Routes', 'Previews']:
        path = (base / 'decimals' if decimal else base) / ('UniswapV3StandardExchange_' + family + ('_Decimals.sol' if decimal else '.t.sol'))
        before = path.read_text()
        text = add_import(before)
        mint_other = '_mint(pool.token1(), alice, amount1);' if decimal else 'ERC20PermitMintableStub(pool.token1()).mint(alice, amount1);'
        helper = '''    /// @dev Caller has already funded/approved token0 and is pranking as alice.
    function _activateWithFundedToken0(uint256 amount0, uint256 amount1) internal returns (uint256 shares) {
        ''' + mint_other + '''
        IERC20(pool.token1()).approve(address(vault), amount1);
''' + dual_arrays('pool.token0()', 'pool.token1()') + '''        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, alice, false, block.timestamp + 1
        );
    }

'''
        start, _ = function_span(text, 'setUp')
        text = text[:start] + helper + text[start:]
        if family == 'Routes':
            for name in ['test_zapIn_firstDeposit_createsPositionsAndShares', 'test_zapIn_subsequentDeposit_addsSameTicks', 'test_zapOut_paysMeasuredToken']:
                def initial_call(body):
                    old = 'vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1)'
                    assert old in body
                    return body.replace(old, '_activateWithFundedToken0(amountIn, ' + ('_u1(100)' if decimal else '100 ether') + ')', 1)
                text = edit_function(text, name, initial_call)
            text = text.replace('test_zapIn_firstDeposit_createsPositionsAndShares', 'test_twoTokenActivation_createsPositionsAndShares')
            def unsupported(body):
                amount = '_u0(10)' if decimal else '10 ether'
                old = 'vault.exchangeIn(IERC20(token0), ' + amount + ', IERC20(address(vault)), 0, alice, false, block.timestamp + 1)'
                assert old in body
                return body.replace(old, '_activateWithFundedToken0(' + amount + ', ' + ('_u1(10)' if decimal else '10 ether') + ')', 1)
            text = edit_function(text, 'test_unsupportedRoutes_revert', unsupported)
            def slippage(body):
                # Keep the exact slippage assertion meaningful after activation, and prove no partial mint.
                if not decimal:
                    body = body.replace(' public {', ' public {\n        uint256 amountIn = 100 ether;', 1)
                marker = '        vm.expectRevert();'
                mint_again = '_mint(token0, alice, amountIn);' if decimal else 'ERC20PermitMintableStub(token0).mint(alice, amountIn);'
                replacement = '        uint256 supplyBefore = _activateWithFundedToken0(amountIn, ' + ('_u1(100)' if decimal else '100 ether') + ');\n        ' + mint_again + '\n        vm.expectRevert(bytes4(keccak256("UniswapV3ExchangeIn_SlippageExceeded()")));'
                assert marker in body
                body = body.replace(marker, replacement, 1)
                return body.replace('totalSupply(), 0, "no partial share mint"', 'totalSupply(), supplyBefore, "no partial share mint"')
            text = edit_function(text, 'test_slippage_revertsWithoutPartialMint', slippage)
        else:
            for number, side in [('03', '0'), ('04', '1')]:
                name = 'test_P_IN_' + number + '_zapIn_token' + side + '_firstDeposit'
                mint = '_mint(token, alice, amount);' if decimal else 'ERC20PermitMintableStub(token).mint(alice, amount);'
                amount = '_u' + side + '(50)' if decimal else '50 ether'
                text = edit_function(text, name, lambda _, number=number, side=side, mint=mint, amount=amount: '''    function test_P_IN_''' + number + '_singleToken' + side + '''ActivationRejected() public {
        address token = pool.token''' + side + '''();
        uint256 amount = ''' + amount + ''';
        assertEq(vault.previewExchangeIn(IERC20(token), amount, IERC20(address(vault))), 0, "one token cannot activate");
        ''' + mint + '''
        vm.startPrank(alice);
        IERC20(token).approve(address(vault), amount);
        uint256 balanceBefore = IERC20(token).balanceOf(alice);
        vm.expectRevert(bytes4(keccak256("UniswapV3Exchange_ZeroAmount()")));
        vault.exchangeIn(IERC20(token), amount, IERC20(address(vault)), 0, alice, false, block.timestamp + 1);
        vm.stopPrank();
        assertEq(IERC20(address(vault)).totalSupply(), 0, "no unbacked initial shares");
        assertEq(IERC20(token).balanceOf(alice), balanceBefore, "failed activation returns input");
    }''')
            text = edit_function(text, 'test_P_IN_05_zapIn_subsequent_afterFees', lambda body: body.replace(
                'vault.exchangeIn(IERC20(token0), bootstrap, IERC20(address(vault)), 0, alice, false, block.timestamp + 1)',
                '_activateWithFundedToken0(bootstrap, ' + ('_u1(100)' if decimal else '100 ether') + ')', 1))
            text = edit_function(text, 'test_P_OUT_03_04_zapOut_bothTokens', lambda body: body.replace(
                'vault.exchangeIn(IERC20(token0), amountIn, IERC20(address(vault)), 0, alice, false, block.timestamp + 1)',
                '_activateWithFundedToken0(amountIn, ' + ('_u1(100)' if decimal else '100 ether') + ')', 1))
        save(path, before, text)

for decimal in [False, True]:
    base = root / 'test/foundry/spec/protocol/dexes/uniswap/v3'
    folder = base / ('decimals/adversarial' if decimal else 'adversarial')
    path = folder / ('TestBase_UniswapV3StandardExchange_Adversarial' + ('_Decimals.sol' if decimal else '.sol'))
    before = path.read_text()
    text = add_import(before)
    mint = '_mint(pool.token1(), actor, amount1);' if decimal else 'ERC20PermitMintableStub(pool.token1()).mint(actor, amount1);'
    helper = '''    /// @dev The caller already funded/approved token0 and is pranking as actor.
    function _activationInputs(address actor, uint256 amount0, uint256 amount1)
        internal returns (address[] memory tokens, uint256[] memory amounts)
    {
        ''' + mint + '''
        IERC20(pool.token1()).approve(address(vault), amount1);
        tokens = new address[](2);
        tokens[0] = pool.token0();
        tokens[1] = pool.token1();
        amounts = new uint256[](2);
        amounts[0] = amount0;
        amounts[1] = amount1;
    }

    function _activateWithFundedToken0(address actor, uint256 amount0, uint256 amount1)
        internal returns (uint256 shares)
    {
        (address[] memory tokens, uint256[] memory amounts) = _activationInputs(actor, amount0, amount1);
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, actor, false, block.timestamp + 1
        );
    }

'''
    start, _ = function_span(text, '_assertNoUnexpectedFreeInventory')
    text = text[:start] + helper + text[start:]
    text = text.replace('Token0-only first mint may hold all free\n        // (full-range L needs both tokens). Dust bound applies only when both sides exist.',
        'Initial activation supplies both tokens.\n        // A subsequent single-token deposit can remain in the sleeve.')
    save(path, before, text)
    for family, targets in {
        'Accounting': {'test_E1_roundTrip_zapInOut_conservation': 100, 'test_E4_successPath_residualPolicy': 50},
        'Donation': {'test_A1_donation_doesNotGrantFreeSharesAsPrincipal': 100, 'test_A3_feeTiming_tinyZapAfterFees': 200},
        'PriceManipulation': {'test_B1_spotManip_noUnboundedFreeLunch': 100},
    }.items():
        path = folder / ('Adversarial_' + family + ('_Decimals.sol' if decimal else '.t.sol'))
        before = path.read_text()
        text = add_import(before)
        for name, human in targets.items():
            def activate(body, human=human):
                pattern = r'vault.exchangeIn\(IERC20\(token0\), ([^,]+), IERC20\(address\(vault\)\), 0, (attacker|victim), false, block.timestamp \+ 1\)'
                match = re.search(pattern, body)
                assert match, name
                amount1 = '_u1(' + str(human) + ')' if decimal else str(human) + ' ether'
                return body[:match.start()] + '_activateWithFundedToken0(' + match[2] + ', ' + match[1] + ', ' + amount1 + ')' + body[match.end():]
            text = edit_function(text, name, activate)
        if family == 'Accounting':
            def exact_slippage(body):
                amount0 = '_u0(50)' if decimal else '50 ether'
                amount1 = '_u1(50)' if decimal else '50 ether'
                start = body.index('        vm.expectRevert();')
                end = body.index('        vm.stopPrank();', start)
                return body[:start] + '''        (address[] memory tokens, uint256[] memory amounts) = _activationInputs(
            attacker, ''' + amount0 + ', ' + amount1 + '''
        );
        vm.expectRevert(bytes4(keccak256("UniswapV3ExchangeIn_SlippageExceeded()")));
        IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), type(uint256).max, attacker, false, block.timestamp + 1
        );
''' + body[end:]
            text = edit_function(text, 'test_E3_slippage_atomicNoPartialMint', exact_slippage)
        save(path, before, text)
    path = folder / ('Adversarial_SecRemediation' + ('_Decimals.sol' if decimal else '.t.sol'))
    before = path.read_text()
    amount1 = 'amountIn * _u1(1) / _u0(1)' if decimal else 'amountIn'
    def zap(body):
        start = body.index('        shares = vault.exchangeIn(')
        end = body.index('        vm.stopPrank();', start)
        return body[:start] + '''        if (IERC20(address(vault)).totalSupply() == 0) {
            assertEq(pairToken, pool.token0(), "activation fixture token0 funding");
            shares = _activateWithFundedToken0(actor, amountIn, ''' + amount1 + ''');
        } else {
            shares = vault.exchangeIn(
                IERC20(pairToken), amountIn, IERC20(address(vault)), 0, actor, false, _deadline()
            );
        }
''' + body[end:]
    text = edit_function(before, '_zapIn', zap)
    def initial_donation(body):
        start = body.index('        uint256 shares_ = vault.exchangeIn(')
        end = body.index('        vm.stopPrank();', start)
        return body[:start] + '        uint256 shares_ = _activateWithFundedToken0(attacker, zapIn_, ' + ('_u1(10)' if decimal else '10 ether') + ');\n' + body[end:]
    text = edit_function(text, 'test_A0_donatePair_thenFirstZapIn_cannotRedeemDonation', initial_donation)
    text = text.replace('test_A0_donatePair_thenFirstZapIn_cannotRedeemDonation', 'test_A0_donatePair_thenTwoTokenActivation_cannotRedeemDonation')
    save(path, before, text)

for version in ['v3', 'v4']:
    for decimal in [False, True]:
        base = root / ('test/foundry/spec/protocol/dexes/uniswap/' + version)
        path = (base / 'decimals' if decimal else base) / ('Uniswap' + version.upper() + 'StandardExchange_MultiJoinExit' + ('_Decimals.sol' if decimal else '.t.sol'))
        before = path.read_text()
        name = 'test_MJ1_lengthNotTwo_reverts_singleZapInStillWorks'
        if 'function ' + name not in before: continue
        seed = '_join(_u0(4), _u1(4));' if decimal else '_join(4 ether, 4 ether);'
        text = edit_function(before, name, lambda body: body.replace(' public {', ' public {\n        ' + seed, 1))
        save(path, before, text)

for decimal in [False, True]:
    base = root / 'test/foundry/spec/protocol/dexes/uniswap/v4'
    folder = base / 'decimals' if decimal else base
    suffix = '_Decimals.sol' if decimal else '.t.sol'
    path = folder / ('UniswapV4StandardExchange_TwapPoke' + suffix)
    before = path.read_text()
    text = add_import(before)
    mint_type = 'MintableERC20Decimals' if decimal else 'ERC20PermitMintableStub'
    amount1 = 'amountIn * _uOf(Currency.unwrap(poolKey.currency1), 1) / _uOf(token, 1)' if decimal else 'amountIn'
    text = edit_function(text, '_zapIn', lambda _: '''    function _zapIn(address token, uint256 amountIn) internal returns (uint256 shares) {
        assertEq(token, _token0(), "TWAP fixture starts from token0");
''' + dual_arrays('_token0()', 'Currency.unwrap(poolKey.currency1)', 'amountIn', amount1) + '''        for (uint256 i; i < 2; ++i) {
            ''' + mint_type + '''(tokens[i]).mint(address(this), amounts[i]);
            IERC20(tokens[i]).approve(address(vault), amounts[i]);
        }
        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, block.timestamp + 1 hours
        );
        assertGt(shares, 0, "funded activation writes TWAP");
    }''')
    def hostile_twap(body):
        body = re.sub(r'        ' + mint_type + r'\(_token0\(\)\).mint\(address\(this\), amountIn\);\n', '', body)
        body = body.replace('        IERC20(_token0()).approve(address(vault), amountIn);\n', '')
        start = body.index('        uint256 shares = vault.exchangeIn(')
        end = body.index('        assertGt(shares', start)
        return body[:start] + '        uint256 shares = _zapIn(_token0(), amountIn);\n' + body[end:]
    text = edit_function(text, 'test_H16_pokeRevertFailOpen', hostile_twap)
    save(path, before, text)

    path = folder / ('UniswapV4StandardExchange_Univ4SeNestedCaller' + suffix)
    before = path.read_text()
    text = add_import(before)
    def funded_holder(body):
        start = body.index('        uint256 amountIn =')
        end = body.index('        assertGt(shares', start)
        return body[:start] + '        uint256 shares = _mintInitialShares();\n' + body[end:]
    for name in re.findall(r'function (test_exchangeIn_shares_contractHolder\w+)\(', text):
        text = edit_function(text, name, funded_holder)
    amount_a = '_uA(10)' if decimal else '10 ether'
    amount_b = '_uB(10)' if decimal else '10 ether'
    helper = '''    function _mintInitialShares() internal returns (uint256 shares) {
        tokenA.mint(address(this), ''' + amount_a + ''');
        tokenB.mint(address(this), ''' + amount_b + ''');
        tokenA.approve(address(vault), ''' + amount_a + ''');
        tokenB.approve(address(vault), ''' + amount_b + ''');
''' + dual_arrays('Currency.unwrap(poolKey.currency0)', 'Currency.unwrap(poolKey.currency1)', 'tokens[0] == address(tokenA) ? ' + amount_a + ' : ' + amount_b, 'tokens[1] == address(tokenA) ? ' + amount_a + ' : ' + amount_b) + '''        shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, _deadline()
        );
    }

'''
    start, _ = function_span(text, 'setUp')
    text = text[:start] + helper + text[start:]
    save(path, before, text)

    path = folder / ('UniswapV4StandardExchange_LocalLiquidBuffer_H2' + suffix)
    before = path.read_text()
    text = add_import(before)
    marker = '        assertTrue(liquid.canOpenPoolManagerUnlock(), "SE idle at deploy");'
    assert marker in text
    # Establish the SE's two-token book before the reserve hook starts its single-token buffering.
    text = text.replace(marker, marker + '\n        _activateUnderlyingSe();', 1)
    amount_pair = '_uA(100)' if decimal else '100 ether'
    amount_other = '_uB(100)' if decimal else '100 ether'
    helper = '''    function _activateUnderlyingSe() internal {
        pairToken.mint(address(this), ''' + amount_pair + ''');
        seOtherToken.mint(address(this), ''' + amount_other + ''');
        pairToken.approve(address(seVault), ''' + amount_pair + ''');
        seOtherToken.approve(address(seVault), ''' + amount_other + ''');
''' + dual_arrays('Currency.unwrap(sePoolKey.currency0)', 'Currency.unwrap(sePoolKey.currency1)', 'tokens[0] == address(pairToken) ? ' + amount_pair + ' : ' + amount_other, 'tokens[1] == address(pairToken) ? ' + amount_pair + ' : ' + amount_other) + '''        uint256 shares = IStandardExchangeInMulti(address(seVault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(seVault)), 0, address(this), false, block.timestamp + 1 hours
        );
        assertGt(shares, 0, "two-token SE activation before hook liquidity");
    }

'''
    start, _ = function_span(text, '_amountForCurrency')
    text = text[:start] + helper + text[start:]
    save(path, before, text)

    base = root / 'test/foundry/spec/protocol/dexes/uniswap/v3'
    folder = base / ('decimals/adversarial' if decimal else 'adversarial')
    path = folder / ('Adversarial_Griefing' + ('_Decimals.sol' if decimal else '.t.sol'))
    before = path.read_text()
    text = add_import(before)
    amount0 = '_uToken(token0, 20)' if decimal else '20 ether'
    amount1 = '_uToken(p.token1(), 20)' if decimal else '20 ether'
    mint = '_mint(p.token1(), attacker, ' + amount1 + ');' if decimal else 'ERC20PermitMintableStub(p.token1()).mint(attacker, 20 ether);'
    text = text.replace('        vm.startPrank(attacker);', '        ' + mint + '\n        vm.startPrank(attacker);', 1)
    start = text.index('        uint256 shares = IStandardExchangeProxy(v).exchangeIn(')
    end = text.index('        vm.stopPrank();', start)
    text = text[:start] + '        IERC20(p.token1()).approve(v, type(uint256).max);\n' + dual_arrays('token0', 'p.token1()', amount0, amount1) + '''        uint256 shares = IStandardExchangeInMulti(v).exchangeInManyToOne(
            tokens, amounts, IERC20(v), 0, attacker, false, block.timestamp + 1
        );
''' + text[end:]
    save(path, before, text)

# Keep existing security regressions reachable after two-token initialization.
for decimal in [False, True]:
    folder = root / 'test/foundry/spec/protocol/dexes/uniswap/v4' / ('decimals/adversarial' if decimal else 'adversarial')
    suffix = '_Decimals.sol' if decimal else '.t.sol'
    mint_type = 'MintableERC20Decimals' if decimal else 'ERC20PermitMintableStub'
    for family in ['SecurePull', 'E6ImpA0']:
        path = folder / ('Adversarial_UniswapV4SE_' + family + suffix)
        before = path.read_text()
        text = add_import(before)
        amount1 = 'amountIn_ * _u1(1) / _u0(1)' if decimal else 'amountIn_'
        def activation(body):
            call = '        shares_ = vault.exchangeIn(IERC20(token0_), amountIn_, IERC20(address(vault)), 0, to_, false, _deadline());'
            assert call in body
            replacement = '        if (vault.totalSupply() == 0) {\n            uint256 amount1_ = ' + amount1 + ';\n            ' + mint_type + '(_token1()).mint(to_, amount1_);\n            IERC20(_token1()).approve(address(vault), amount1_);\n'
            replacement += dual_arrays('token0_', '_token1()', 'amountIn_', 'amount1_').replace('        ', '            ')
            replacement += '\n'.join([
                '            shares_ = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(',
                '                tokens, amounts, IERC20(address(vault)), 0, to_, false, _deadline()',
                '            );', '        } else {', '    ' + call, '        }'])
            return body.replace(call, replacement, 1)
        text = edit_function(text, '_mintSeShares', activation)
        if family == 'SecurePull':
            def honest_inventory(body):
                start = body.index('        ' + mint_type + '(token0_).mint(victim, honestIn_);')
                end = body.index('        vm.stopPrank();', start) + len('        vm.stopPrank();')
                return body[:start] + '        _mintSeShares(victim, honestIn_);' + body[end:]
            for name in ['test_I1_pretransferred_inventoryNoInCallTransfer_revertsDelta0', 'test_I1_pretransferred_claimedLeInventory_stillReverts']:
                text = edit_function(text, name, honest_inventory)
            def positive(body):
                start = body.index('        address token0_ =')
                end = body.index('        assertGt(out_', start)
                return body[:start] + '        uint256 out_ = _mintSeShares(attacker, amountIn_);\n' + body[end:]
            text = edit_function(text, 'test_I_positive_honestPullMint_succeeds', positive)
            text = edit_function(text, 'test_J3_proxyCallable_smoke_eachSelector', lambda body: body.replace(' public {', ' public {\n        _mintSeShares(victim, ' + ('_u0(2)' if decimal else '2 ether') + ');', 1))
        save(path, before, text)

path = root / 'test/foundry/spec/protocol/dexes/uniswap/v3/decimals/adversarial/Adversarial_Import_Decimals.sol'
before = path.read_text()
text = before.replace('        int24 spacing = pool.tickSpacing();', '        int24 spacing = pool.tickSpacing();\n        (, int24 spotTick,,,,,) = pool.slot0();\n        int24 center = (spotTick / spacing) * spacing;', 1)
text = text.replace('tickLower: -spacing * 8,', 'tickLower: center - spacing * 8,', 1).replace('tickUpper: spacing * 8,', 'tickUpper: center + spacing * 8,', 1)
save(path, before, text)

patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
    fromfile='a/' + path, tofile='b/' + path)) for path, (before, after) in changes.items())
(art / 'position-fixture-migrations.patch').write_text(patch)
(art / 'position-fixture-migrations-prepared.json').write_text(json.dumps({
    'status': 'PREPARED_NOT_APPLIED',
    'authority': 'Approved two-token initial activation, retained subsequent single-token routes, native ETH compatibility and production-first test migration.',
    'changes': [{'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, (before, after) in changes.items()],
    'coverage_preserved': ['V3/V4 base and decimal local-buffer suites', 'V4 native ETH deposit, swaps and withdrawal',
        'V3 authenticated callback and payout reentrancy', 'V4 hostile transferFrom reentrancy after funded activation',
        'V3 decimal incumbent fee protection and imported-position authorization'],
    'renamed_cases': {'test_T1b_idleDeposit_token0Only_doesNotRequireSleeveAndL': 'test_T1b_subsequentSingleTokenDeposit_keepsFullRangeLiquidity'},
    'consolidated_cases': 'V4 Routes base/decimal: each former first-deposit execution + duplicate preview case becomes one two-token activation case checking preview, receipts, supply and both reserves; two parameter directions retained. V3 Routes retain positive two-token activation; V3 Previews replace obsolete first single-token success with exact zero-preview/revert/no-loss checks in both directions.',
    'validation': 'Draft compilation and actual retained tests required; no test failures are waived.'
}, indent=2) + '\n')
print('Prepared fixture migrations across', len(changes), 'existing sources; no Solidity changed.')
