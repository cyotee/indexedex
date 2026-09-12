"""Prepare retained fixture migrations against the current main-repository files."""
from pathlib import Path
import difflib, hashlib, json, runpy

art = Path(__file__).resolve().parent
root = art.parent.parent
changes = runpy.run_path(str(art / 'prepare-position-roundtrip-followup.py'))['changes']

def replace_function(text, name, body):
    start = text.index('    function ' + name + '(')
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[:start] + body.rstrip() + text[end:]

def function(text, name):
    start = text.index('    function ' + name + '(')
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]

def keep(path, before, after):
    assert before != after
    changes[str(path.relative_to(root))] = (before, after)

base = root / 'test/foundry/spec/protocol/dexes/uniswap'
v3base = (base / 'v3/UniswapV3StandardExchange_FullRangeBook.t.sol').read_text()
for version in [3, 4]:
    path = base / f'v{version}/decimals/UniswapV{version}StandardExchange_FullRangeBook_Decimals.sol'
    before = path.read_text()
    body = function(v3base, 'test_FR5_bothTokensActivateThenSingleTokenDepositsRemainAvailable')
    body = body.replace('10 ether', '_u0(10)').replace('_dualJoin(amount, amount)', '_dualJoin(amount, _u1(10))')
    if version == 3:
        body = body.replace('ERC20PermitMintableStub(address(input)).mint(address(this), amount)', '_mint(address(input), address(this), amount)')
    else:
        body = body.replace('ERC20PermitMintableStub', 'MintableERC20Decimals').replace('UniswapV3Exchange', 'UniswapV4Exchange')
        body = body.replace('_liquidityAt(lower, upper)', '_liquidityAt(lower, upper, bytes32(0))')
    after = replace_function(before, 'test_FR5_singleTokenFirstMint_thenDualDepositMintsFullRangeL', body)
    if version == 3:
        body = function(v3base, 'test_FR6_importedNftConvertedToFullRange')
        body = body.replace('int24 importedLower = -spacing * 10;\n        int24 importedUpper = spacing * 10;',
            '(, int24 spotTick,,,,,) = pool.slot0();\n        int24 center = (spotTick / spacing) * spacing;\n        int24 importedLower = center - spacing * 10;\n        int24 importedUpper = center + spacing * 10;')
        body = body.replace('ERC20PermitMintableStub(token0).mint(address(this), 20 ether)', '_mint(token0, address(this), _u0(20))')
        body = body.replace('ERC20PermitMintableStub(token1).mint(address(this), 20 ether)', '_mint(token1, address(this), _u1(20))')
        body = body.replace('approve(address(npm), 20 ether);', 'approve(address(npm), _u0(20));', 1)
        body = body.replace('approve(address(npm), 20 ether);', 'approve(address(npm), _u1(20));', 1)
        body = body.replace('amount0Desired: 20 ether', 'amount0Desired: _u0(20)').replace('amount1Desired: 20 ether', 'amount1Desired: _u1(20)')
        after = replace_function(after, 'test_FR6_importedNftTicksNotRewritten', body)
    else:
        v4base = (base / 'v4/UniswapV4StandardExchange_FullRangeBook.t.sol').read_text()
        body = function(v4base, 'test_FR6_importConvertsRealNftToFullRangeIncludingEarnedFees')
        body = body.replace('        (IPositionManager manager, uint256 id) = _mintImportPosition(-120, 120);',
            '        (, int24 spotTick,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());\n        int24 center = (spotTick / poolKey.tickSpacing) * poolKey.tickSpacing;\n        int24 lowerImport = center - 120;\n        int24 upperImport = center + 120;\n        (IPositionManager manager, uint256 id) = _mintImportPosition(lowerImport, upperImport);')
        body = body.replace('true, 100 ether', 'true, _u0(100)').replace('false, 100 ether', 'false, _u1(100)')
        body = body.replace('_importEntitlement(manager, id, -120, 120)', '_importEntitlement(manager, id, lowerImport, upperImport)')
        body = body.replace('_liquidityAtOn(address(bound), -120, 120, bytes32(0))', '_liquidityAtOn(address(bound), lowerImport, upperImport, bytes32(0))')
        helpers = function(v4base, '_mintImportPosition') + '\n\n' + function(v4base, '_importEntitlement')
        helpers = helpers.replace('ERC20PermitMintableStub(token).mint(address(this), 10_000 ether)', 'MintableERC20Decimals(token).mint(address(this), _uOf(token, 10_000))')
        helpers = helpers.replace('1000 ether, 1000 ether', '_u0(1000), _u1(1000)')
        helpers = helpers.replace('uint128(1000 ether), uint128(1000 ether)', 'uint128(_u0(1000)), uint128(_u1(1000))')
        after = replace_function(after, 'test_FR6_importedNftTicksNotRewritten', body + '\n\n' + helpers)
        # Remove the non-funding PM double replaced by the actual vendored V4 manager.
        start = after.index('/// @dev Bind-path PositionManager for FR6.')
        end = after.index('/**\n * @title UniswapV4StandardExchange_FullRangeBook_Decimals', start)
        after = after[:start] + after[end:]
        imports = ['import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";']
        for line in v4base.splitlines():
            if any(line.startswith('import {' + name + '}') for name in [
                'FixedPointMathLib', 'FullMath', 'IStandardizedYield', 'IAllowanceTransfer',
                'PositionManager', 'PositionDescriptor', 'IWETH9', 'Actions',
                'LiquidityAmounts as ReferenceLiquidityAmounts']): imports.append(line)
        after = after.replace('pragma solidity ^0.8.0;\n', 'pragma solidity ^0.8.0;\n\n' + '\n'.join(imports) + '\n', 1)
        after = after.replace('import {PositionInfo} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/PositionInfoLibrary.sol";\n', '')
    keep(path, before, after)

path = base / 'v3/UniswapV3StandardExchangeOutQueryFacet_IFacet_Test.t.sol'
before = path.read_text()
after = before.replace('pragma solidity ^0.8.0;\n', 'pragma solidity ^0.8.0;\n\nimport {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\n', 1)
after = after.replace('controlInterfaces = new bytes4[](1);', 'controlInterfaces = new bytes4[](2);')
after = after.replace('controlInterfaces[0] = type(IStandardExchangeOut).interfaceId;', 'controlInterfaces[0] = type(IStandardExchangeOut).interfaceId;\n        controlInterfaces[1] = type(IStandardizedYield).interfaceId;')
control = (base / 'v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol').read_text()
body = function(control, 'controlFacetFuncs').replace('IStandardExchangeOutMulti.previewExchangeOutOneToMany', 'IStandardExchangeOut.previewExchangeOut')
after = replace_function(after, 'controlFacetFuncs', body)
keep(path, before, after)

for decimal in [False, True]:
    path = base / ('v4/decimals/adversarial/Adversarial_UniswapV4SE_E6ImpA0_Decimals.sol' if decimal else 'v4/adversarial/Adversarial_UniswapV4SE_E6ImpA0.t.sol')
    before = path.read_text()
    after = before.replace('pragma solidity ^0.8.0;\n', 'pragma solidity ^0.8.0;\n\nimport {IUniswapV4StandardExchangeLiquidReserve} from "contracts/protocols/dexes/uniswap/v4/interfaces/IUniswapV4StandardExchangeLiquidReserve.sol";\n', 1)
    marker = '        assertLt(shares_, vault.totalSupply(), "A0: attacker is not 100% supply");'
    amount1 = '_u1(1)' if decimal else 'mintIn_'
    assertions = f'''
        // Activation paid both assets. Independently bound ownership of each leg.
        IUniswapV4StandardExchangeLiquidReserve book = IUniswapV4StandardExchangeLiquidReserve(address(vault));
        (uint256 total0, uint256 total1) = book.deployedReserve();
        total0 += book.localReserve(token0_);
        total1 += book.localReserve(_token1());
        assertLe(shares_ * total0, mintIn_ * vault.totalSupply(), "A0: token0 claim excludes donation");
        assertLe(shares_ * total1, {amount1} * vault.totalSupply(), "A0: token1 claim limited to payment");
'''
    assert after.count(marker) == 1
    after = after.replace(marker, marker + assertions)
    after = after.replace('// Spent mintIn_; redeem must not return the donation.', '// Both deposited assets are worth mintIn_ token0 at the initial human 1:1 price.')
    after = after.replace('attackerTokBefore_ + mintIn_, "A0: no donation extract"', 'attackerTokBefore_ + 2 * mintIn_, "A0: recovery limited to both paid assets"')
    after = after.replace('        assertGt(vault.balanceOf(DEAD_SHARES_SINK), 0, "A0: dead shares remain after redeem");',
        '        assertEq(vault.balanceOf(attacker), 0, "A0: all attacker shares redeemed");\n        assertGt(vault.balanceOf(DEAD_SHARES_SINK), 0, "A0: dead shares remain after redeem");')
    # A raw-unit victim payment can now mint a positive high-precision share amount.
    old = '''        vm.expectRevert(UniswapV4StandardExchangeCommon.UniswapV4Exchange_ZeroAmount.selector);
        vault.exchangeIn(IERC20(token0_), victimIn_, IERC20(address(vault)), 0, victim, false, _deadline());
        vm.stopPrank();

        assertEq(IERC20(token0_).balanceOf(victim), victimTokBefore_, "A0: victim tokens returned");
        assertEq(vault.balanceOf(victim), 0, "A0: no zero-share credit");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "A0: attacker shares unchanged");
        assertEq(vault.totalSupply(), supplyBefore_, "A0: supply unchanged");'''
    new = '''        uint256 quoted = vault.previewExchangeIn(IERC20(token0_), victimIn_, IERC20(address(vault)));
        if (quoted == 0) {
            vm.expectRevert(UniswapV4StandardExchangeCommon.UniswapV4Exchange_ZeroAmount.selector);
            vault.exchangeIn(IERC20(token0_), victimIn_, IERC20(address(vault)), 0, victim, false, _deadline());
            assertEq(IERC20(token0_).balanceOf(victim), victimTokBefore_, "A0: zero-share payment returned");
        } else {
            uint256 received = vault.exchangeIn(IERC20(token0_), victimIn_, IERC20(address(vault)), quoted, victim, false, _deadline());
            assertEq(received, quoted, "A0: positive quote funds actual shares");
            assertEq(IERC20(token0_).balanceOf(victim), victimTokBefore_ - victimIn_, "A0: exact funded payment");
        }
        vm.stopPrank();

        assertEq(vault.balanceOf(victim), quoted, "A0: no payment without positive shares");
        assertEq(vault.balanceOf(attacker), attackerSharesBefore_, "A0: attacker shares unchanged");
        assertEq(vault.totalSupply(), supplyBefore_ + quoted, "A0: only victim shares issued");'''
    assert after.count(old) == 1
    after = after.replace(old, new)
    keep(path, before, after)

for decimal in [False, True]:
    path = base / ('v4/decimals/UniswapV4StandardExchange_TwapPoke_Decimals.sol' if decimal else 'v4/UniswapV4StandardExchange_TwapPoke.t.sol')
    before = path.read_text()
    body = function(before, '_zapIn')
    setup = body[body.index('        assertEq(token,'):body.index('        shares = IStandardExchangeInMulti')]
    setup = setup.replace('address[] memory tokens = new address[](2);', 'tokens = new address[](2);')
    setup = setup.replace('uint256[] memory amounts = new uint256[](2);', 'amounts = new uint256[](2);')
    helper = '''    function _fundDualInput(address token, uint256 amountIn)
        internal returns (address[] memory tokens, uint256[] memory amounts)
    {
''' + setup + '    }'
    oldsetup = body[body.index('        assertEq(token,'):body.index('        shares = IStandardExchangeInMulti')]
    body = body.replace(oldsetup, '        (address[] memory tokens, uint256[] memory amounts) = _fundDualInput(token, amountIn);\n')
    after = replace_function(before, '_zapIn', helper + '\n\n' + body)
    body = function(after, 'test_H16_pokeRevertFailOpen')
    body = body.replace('        vm.expectEmit(false, false, false, true, address(vault));',
        '        (address[] memory tokens, uint256[] memory amounts) = _fundDualInput(_token0(), amountIn);\n        vm.expectEmit(false, false, false, true, address(vault));')
    body = body.replace('        uint256 shares = _zapIn(_token0(), amountIn);', '''        uint256 shares = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(vault)), 0, address(this), false, block.timestamp + 1 hours
        );''')
    after = replace_function(after, 'test_H16_pokeRevertFailOpen', body)
    keep(path, before, after)

patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
    fromfile='a/' + path, tofile='b/' + path)) for path, (before, after) in changes.items())
(art / 'position-runtime-migrations.patch').write_text(patch)
(art / 'position-runtime-migrations-prepared.json').write_text(json.dumps({
    'status': 'PREPARED_NOT_APPLIED',
    'basis': 'Actual position runtime failures and review of retained E1 round-trip coverage.',
    'scope': 'Existing V3/V4 fixtures only. Preserve all concrete decimal leaves, test counts, fuzz settings, conservation and authorization checks.',
    'changes': [{'path': path, 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, (before, after) in changes.items()],
    'application_gate': 'Wait for active validation PTY 52715 and children to exit before applying canonical sources.'
}, indent=2) + '\n')
print('Prepared', len(changes), 'current-source fixture corrections; no canonical Solidity changed.')
