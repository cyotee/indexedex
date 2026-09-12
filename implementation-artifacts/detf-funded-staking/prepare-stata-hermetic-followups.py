"""Prepare reviewed Stata fixes without changing the active validation snapshot."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, hashlib, json, re

art = Path(__file__).resolve().parent
root = art.parent.parent
draft = art / 'stata-hermetic-followup-drafts'
draft.mkdir(exist_ok=True)
changes = []
patches = []

def functions(text):
    return re.findall(r'\bfunction\s+(test\w+)\s*\(', text)

def function_span(text, name):
    match = re.search(r'    function ' + re.escape(name) + r'\s*\(', text)
    assert match, name
    opening = text.index('{', match.end())
    depth = 1
    end = opening + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return match.start(), end

def replace_function(text, name, replacement):
    start, end = function_span(text, name)
    return text[:start] + replacement.rstrip() + text[end:]

def save(path, text, reason):
    before = (root / path).read_text()
    assert before != text, path
    dest = draft / (Path(path).name + '.txt')
    assert not dest.exists(), 'Preserve prior prepared evidence.'
    dest.write_text(text)
    changes.append(dict(path=path, draft=str(dest.relative_to(root)), reason=reason,
        before_sha256=hashlib.sha256(before.encode()).hexdigest(),
        after_sha256=hashlib.sha256(text.encode()).hexdigest(),
        declared_tests_before=functions(before), declared_tests_after=functions(text)))
    patches.extend(difflib.unified_diff(before.splitlines(True), text.splitlines(True), fromfile=path, tofile=path))

production = 'contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutTarget.sol'
s = (root / production).read_text()
old = '        return Math.mulDiv(needed_, ERC20Repo._totalSupply(), held_, Math.Rounding.Ceil);'
assert old in s
s = s.replace(old, '''        uint256 supply_ = ERC20Repo._totalSupply();
        // Idle donated receipts do not authorize an unfunded zero-share exit.
        if (supply_ == 0 || held_ == 0) revert InvalidStataPayment();
        return Math.mulDiv(needed_, supply_, held_, Math.Rounding.Ceil);''')
save(production, s, 'Reject positive exact-output withdrawals from an empty SE supply or backing; preserve proportional ceil pricing.')

base = 'contracts/test/bases/TestBase_AaveV3StataStandardExchange_Decimals.sol'
s = (root / base).read_text()
s = s.replace('import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";',
'''import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";''')
s = s.replace('6- or 9-dec.', '6-, 9- or 18-dec.')
s = s.replace('        if (d == 6) {', '        if (d == 18) return tokenList.weth;\n        if (d == 6) {')
start = s.index('        vm.mockCall(', s.index('    function _bindIndexedExRealVault'))
end = s.index('        _fundUnderlying', start)
s = s[:start] + s[end:]
s = s.replace('    function _deadline()', '''    /// @dev Use the real manager. A zero per-vault override falls through to its default.
    function _setTestUsageFee(uint256 fee) internal {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(fee);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(realVault, fee);
        vm.stopPrank();
        assertEq(indexedexManager.usageFeeOfVault(realVault), fee, "actual configured fee");
    }

    function _deadline()''')
save(base, s, 'Share the real Crane Stata fixture across all three decimal cases; remove ineffective address-zero oracle mocks.')

real = 'test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_Real_Decimals.sol'
s = (root / real).read_text()
s = s.replace('import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";',
'''import {Math} from "@crane/contracts/utils/Math.sol";
import {IAaveV3StataStandardVault} from "contracts/interfaces/IAaveV3StataStandardVault.sol";''')
opening = s.index('{', s.index('abstract contract')) + 1
helpers = '''
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
'''
s = s[:opening] + '\n' + helpers + s[opening:]
replacements = {
'test_Real_Route_SEToStata_PreviewMatches': '        _exitPart(realStata, _u(20), 50, false);',
'test_Real_Route_SEToBase_PreviewMatches': '        _exitPart(realBase, _u(15), 33, false);',
'test_Real_Route_SEToBase_Pretransferred': '        _exitPart(realBase, _u(12), 33, true);',
'test_Real_Route_SEToAToken': '        _exitPart(aToken, _u(12), 33, false);',
}
for name, body in replacements.items():
    s = replace_function(s, name, f'    function {name}() public {{\n{body}\n    }}')
for name, prepaid, maximum in [('testFuzz_Real_SEToStata', False, 90), ('testFuzz_Real_SEToStata_Pretransferred', True, 80)]:
    s = replace_function(s, name, f'''    function {name}(uint256 dep, uint256 burnFrac) public {{
        dep = bound(dep, _u(5), _u(200));
        burnFrac = bound(burnFrac, 1, {maximum});
        _exitPart(realStata, dep, burnFrac, {str(prepaid).lower()});
    }}''')
s = replace_function(s, 'testFuzz_Real_FeeOnBaseToSE', '''    function testFuzz_Real_FeeOnBaseToSE(uint256 amount, uint256 fee) public {
        amount = bound(amount, _u(1), _u(100));
        fee = bound(fee, 0, 0.05e18);
        _assertFundedMintFee(amount, fee);
    }''')
s = replace_function(s, 'test_Real_FeeApplicationAndMarker', '''    function test_Real_FeeApplicationAndMarker() public {
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
    }''')
s = s.replace('    /// @dev N/A: production `AaveV3StataStandardExchangeOutTarget._pool()` is `address(0)`,\n    ///      so SE→aToken cannot settle via `pool.supply` on Crane Stata. Mock `test_Route_SEToAToken`\n    ///      used `vm.mockCall` and is EX-MOCK.','    /// @notice Exact aToken output settles through the real configured Aave pool.')
s = s.replace('Gold Real `test_Real_Route_*` / `testFuzz_Real_*` on a non-18 Stata base.', 'Shared real Stata money-path coverage for 6-, 9- and 18-decimal underlyings.')
save(real, s, 'Consolidated actual-protocol route tests distinguish desired output from shares spent, include actual aToken exits, and configure/check real fee receipts.')

real18 = 'test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_Real.t.sol'
save(real18, '''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {AaveV3StataStandardExchange_Real_Decimals} from
    "test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_Real_Decimals.sol";

/// @notice Every shared real Stata route on the Crane WETH/18-decimal deployment.
contract AaveV3StataStandardExchange_RealTest is AaveV3StataStandardExchange_Real_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) { return 18; }
}
''', 'Replace the duplicated 18-decimal fixture body with the same real-protocol cases as the retained 6/9-decimal leaves.')

adversarial = 'test/foundry/spec/protocol/lending/aave/v3.6/decimals/Adversarial_AaveV3StataSE_SecurePull_Decimals.sol'
s = (root / adversarial).read_text()
s = s.replace('import {IERC20}', 'import {AaveV3StataStandardExchangeInTarget as StataIn} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeInTarget.sol";\nimport {AaveV3StataStandardExchangeOutTarget as StataOut} from "contracts/protocols/lending/aave/v3.6/AaveV3StataStandardExchangeOutTarget.sol";\nimport {Math} from "@crane/contracts/utils/Math.sol";\nimport {IERC20}', 1)
s = s.replace('    /// @notice E5: zero amount on empty vault yields 0 shares (no free mint); no residual product.', '    /// @notice E5: zero payment reverts without minting shares or changing inventory.')
s = s.replace('        uint256 out_ = IStandardExchangeIn(realVault).exchangeIn(\n            IERC20(realStata), 0,', '        vm.expectRevert(StataIn.InvalidStataPayment.selector);\n        IStandardExchangeIn(realVault).exchangeIn(\n            IERC20(realStata), 0,')
s = s.replace('        assertEq(out_, 0, "E5 zero in -> zero out");\n', '')
s = s.replace('    /// @notice E5: unsupported junk tokenOut → ExchangeInNotAvailable.', '    /// @notice E5: unsupported output reports the route-specific error.')
s = s.replace('        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);', '        vm.expectRevert(abi.encodeWithSelector(StataIn.InvalidStataRoute.selector, realStata, address(junk_)));')
s = s.replace('        vm.expectRevert(bytes("slippage"));', '        vm.expectRevert(abi.encodeWithSelector(StataIn.StataSlippage.selector, stataShares_ + 1, stataShares_));', 1)
s = s.replace('        vm.expectRevert(bytes("slippage"));', '        vm.expectRevert(abi.encodeWithSelector(StataIn.StataSlippage.selector, uint256(type(uint128).max), stataShares_));', 1)
s = replace_function(s, 'test_E1_mintRedeemRoundTrip_bounded', '''    function test_E1_mintRedeemRoundTrip_bounded() public {
        uint256 paid = _acquireStata(attacker, _testAmt());
        vm.startPrank(attacker);
        IERC20(realStata).approve(realVault, paid);
        uint256 shares = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), paid, IERC20(realVault), 1, attacker, false, _deadline()
        );
        uint256 expected = Math.mulDiv(shares, IERC20(realStata).balanceOf(realVault), IERC20(realVault).totalSupply());
        uint256 beforeStata = IERC20(realStata).balanceOf(attacker);
        uint256 received = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realVault), shares, IERC20(realStata), expected, attacker, false, _deadline()
        );
        vm.stopPrank();
        assertEq(received, expected, "independent proportional redemption");
        assertEq(IERC20(realStata).balanceOf(attacker) - beforeStata, received, "actual receipt");
        assertEq(IERC20(realVault).balanceOf(attacker), 0, "all user shares burned");
        assertLe(received, paid, "no profitable round trip");
    }''')
s = s.replace('        vm.prank(attacker);\n        vm.expectRevert();\n        IStandardExchangeOut(realVault).exchangeOut(', '''        vm.expectRevert(StataOut.InvalidStataPayment.selector);
        IStandardExchangeOut(realVault).previewExchangeOut(IERC20(realVault), IERC20(realStata), amountOut_);
        vm.prank(attacker);
        vm.expectRevert(StataOut.InvalidStataPayment.selector);
        IStandardExchangeOut(realVault).exchangeOut(''')
save(adversarial, s, 'Preserve all attack tests, use exact typed errors and full-share proportional redemption; enforce empty-supply rejection in both preview and execution.')

adversarial18 = 'test/foundry/spec/protocol/lending/aave/v3.6/adversarial/Adversarial_AaveV3StataSE_SecurePull.t.sol'
old = (root / adversarial18).read_text()
extra = []
for name in ['test_F1_diamondCut_blocked', '_facetFuncsContains', 'test_J1_facetFuncs_coversTargetApi', 'test_J2_proxyLoupe_allProductSelectors', 'test_J3_proxyCallable_smoke_eachSelector']:
    start, end = function_span(old, name)
    fn = old[start:end]
    fn = re.sub(r'\bvault\b', 'realVault', fn)
    fn = fn.replace('mockStata', 'realStata')
    extra.append(fn)
new = '''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IDiamondCut} from "@crane/contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {Adversarial_AaveV3StataSE_SecurePull_Decimals} from
    "test/foundry/spec/protocol/lending/aave/v3.6/decimals/Adversarial_AaveV3StataSE_SecurePull_Decimals.sol";

/// @notice All retained attack cases on real 18-decimal Crane Stata, plus proxy surface checks.
contract Adversarial_AaveV3StataSE_SecurePull is Adversarial_AaveV3StataSE_SecurePull_Decimals {
    function _underlyingDecimals() internal pure override returns (uint8) { return 18; }
''' + '\n\n'.join(extra) + '\n}\n'
save(adversarial18, new, 'Consolidate duplicated mocked attacks into real shared decimal fixture; retain F1/J1/J2/J3 production proxy checks.')

(art / 'stata-hermetic-followups.patch').write_text(''.join(patches))
record = dict(status='PREPARED_NOT_APPLIED', recorded_at_utc=datetime.now(timezone.utc).isoformat(),
    active_source_sha256='96d7a3ff1d5d6d8f41f1ff0c7a8dd09419e8243b669dd27700325822edf63dde',
    gate='Do not apply until the entire active full-hermetic parent session 4255 exits.',
    changes=changes,
    remaining=['Review/typecheck prepared fixtures and retained case mappings.',
        'The obsolete 24-case mocked product fixture still needs an explicit complete mapping to actual-protocol replacements before retirement.',
        'Review other actual completed-suite failures, apply checked changes, then execute affected real Stata/native SY cases and matching final validation.'],
    bug='Positive exact-output with zero SE supply and donated receipt inventory computed zero required shares; existing H2 test catches unauthorized withdrawal.',
    evidence='implementation-hermetic-test.log (active partial run; final attribution pending)',
    validation_passed=False)
(art / 'stata-hermetic-followups-prepared.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'status':record['status'],'drafts':len(changes),'canonical_sources_changed':0,'runtime_validation':False}))
