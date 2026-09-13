"""Migrate policy state preparation to funded public swaps, preserving originals."""
from pathlib import Path
import hashlib, json, re
from datetime import datetime, timezone
from build_provenance import capture

art = Path(__file__).resolve().parent
root = art.parent.parent
prior = json.loads((art / 'hermetic-remediation-v4-policy-funded-opening.json').read_text())
assert prior.get('finished_at_utc') and prior['status'] != 'RUNNING'
before = capture(root)
backup = art / 'before-public-policy-fixtures'
backup.mkdir(exist_ok=True)
assert not any(backup.iterdir()), 'Never overwrite earlier source evidence.'
changes = {}

def replace_function(source, name, replacement):
    match = re.search(r'    function ' + re.escape(name) + r'\(', source)
    assert match, name
    opening = source.index('{', match.start())
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[:match.start()] + replacement + source[end:]

base = 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/'
shared = base + 'TestBase_UniswapV4Detf_Policy.sol'
s = (root / shared).read_text()
anchor = '    function _policyBurnToken(address d) internal view returns (IERC20) {'
assert s.count(anchor) == 1
s = s.replace(anchor, '''    /// @dev Move the live reserve with actual user trades in native token units.
    /// Each purchase is small relative to its current reserve and checks the
    /// same preview, payment and payout deltas as an external market participant.
    function _policyBuyFromReserve(address d) internal {
        address hook_ = IUniswapV4Detf(d).hook();
        address[] memory tokens_ = IUniswapV4SeBufferHook(hook_).tokens();
        uint256[] memory reserves_ = IUniswapV4SeBufferHook(hook_).previewExitProportional(IERC20(hook_).totalSupply());
        address user_ = _fundedPolicyUser();
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            if (tokens_[i_] == d) continue;
            uint256 amount_ = reserves_[i_] / 20;
            assertGt(amount_, 0, "funded public market input");
            IERC20 input_ = IERC20(tokens_[i_]);
            _fundedPolicyFundToken(tokens_[i_], user_, amount_);
            IStandardExchangeIn market_ = IStandardExchangeIn(hook_);
            uint256 quote_ = market_.previewExchangeIn(input_, amount_, IERC20(d));
            uint256 inputBefore_ = input_.balanceOf(user_);
            uint256 outputBefore_ = IERC20(d).balanceOf(user_);
            vm.startPrank(user_);
            input_.approve(hook_, amount_);
            uint256 paid_ = market_.exchangeIn(input_, amount_, IERC20(d), quote_, user_, false, block.timestamp + 1 hours);
            vm.stopPrank();
            assertEq(paid_, quote_, "public reserve preview/execution");
            assertEq(inputBefore_ - input_.balanceOf(user_), amount_, "actual public payment");
            assertEq(IERC20(d).balanceOf(user_) - outputBefore_, paid_, "actual public payout");
            if (IUniswapV4Detf(d).isMintingAllowed()) return;
        }
    }

''' + anchor)
changes[shared] = s
for name in ['Policy', 'Policy_Decimals', 'Weighted_Policy', 'Orbital_Policy', 'Quad_Policy']:
    path = base + 'TestBase_UniswapV4Detf_' + name + '.sol'
    s = changes.get(path, (root / path).read_text())
    s = replace_function(s, '_pushSyntheticUp', '    function _pushSyntheticUp(address d) internal virtual' + (' override' if name not in ['Policy', 'Policy_Decimals'] else '') + ' {\n        _policyBuyFromReserve(d);\n    }')
    for fn in ['_ownerSwap', 'ownerSwapExternal']:
        if re.search(r'    function ' + fn + r'\(', s):
            s = replace_function(s, fn, '')
    s = re.sub(r'    /// @dev D30: prank\(detf\).*\n    ///      Chunked:.*\n', '', s)
    changes[path] = s

test_root = root / 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
retired = []
for p in sorted(test_root.rglob('*.t.sol')):
    s = p.read_text()
    old = s
    if re.search(r'    function _ownerSwap\(', s):
        s = replace_function(s, '_ownerSwap', '')
    name = 'test_T8_4_policy_pairA_not_pairB_via_trades'
    if '/prod-se/UniswapV4Detf_Weighted_' in p.as_posix() and re.search(r'    function ' + name + r'\(', s):
        s = replace_function(s, name, '    // Per-token asymmetric gates were superseded by the common synthetic gate.\n    // Inherited policy tests cover route discovery, public fallback and reopening.')
        retired.append({'source': p.relative_to(root).as_posix(), 'retired_test': name,
                        'reason': 'Mandatory common synthetic gate and swap fallback supersede pair-specific gating and expected price-only reverts.',
                        'replacement_source': shared,
                        'replacement_functions': ['_assert_T7_8_policy_isMintingAllowed_token', '_assert_policy_mint_blocked_in_deadband_then_allowed_after_push']})
    if s != old:
        changes[p.relative_to(root).as_posix()] = s
assert len(retired) == 7
rows = []
for path, after in sorted(changes.items()):
    p = root / path
    old = p.read_bytes()
    dest = backup / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(old)
    p.write_text(after)
    rows.append({'path': path, 'before_sha256': hashlib.sha256(old).hexdigest(), 'after_sha256': hashlib.sha256(p.read_bytes()).hexdigest()})
record = {'status': 'APPLIED_RUNTIME_VALIDATION_PENDING', 'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
          'before': before, 'after': capture(root), 'changes': rows, 'retired_declarations': retired,
          'scope': 'Existing V4 native and decimal policy fixtures; public swaps with real user payments replace SUT impersonation and oversized donations. No product formulas or D60/D66 functionality changed.'}
(art / 'public-policy-fixtures-applied.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps({'changed_sources': len(rows), 'retired_declarations': len(retired), 'source_sha256': record['after']['source_and_config_sha256']}))
