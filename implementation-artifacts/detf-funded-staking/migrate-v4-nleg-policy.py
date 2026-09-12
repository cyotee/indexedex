"""Consolidate n-leg policy overrides onto the funded shared assertions."""
from pathlib import Path
import hashlib, json, sys
ROOT = Path(__file__).resolve().parents[2]
ART = Path(__file__).resolve().parent

def replace_function(source, name, replacement):
    start = source.index('    function ' + name + '(')
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[:start] + replacement.rstrip() + source[end:]

records = []
for family in ('Weighted', 'Quad'):
    path = ROOT / f'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_{family}_Policy.sol'
    before = path.read_text()
    source = replace_function(before, '_skewSyntheticDown', '''    function _skewSyntheticDown(address d) internal virtual override {
        _skewSyntheticDownAmt(d, 80e9);
    }''')
    records.append((path, before, source, ['Use the shared funded, nine-decimal public reserve swaps for price skew.']))
    path = ROOT / f'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_{family}_Policy.t.sol'
    before = path.read_text()
    source = before
    names = ['test_policy_burn_allowed_when_synthetic_below_burnThreshold', 'test_D31_3_policyBurn_realizesThenGates']
    if family == 'Quad': names += ['test_policy_mint_blocked_in_deadband_then_allowed_after_push']
    for name in names:
        source = replace_function(source, name, '')
    mappings = ['Inherited ' + name + ' now executes the shared funded policy assertion in this actual family fixture.' for name in names]
    if family == 'Weighted':
        source = replace_function(source, 'test_T8_4_policy_pairA_not_pairB_via_trades', '''    function test_T8_4_policy_pairA_not_pairB_via_trades() public {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info_ = IUniswapV4Detf(d);
        IERC20 pairA_ = IERC20(address(pair0));
        IERC20 pairB_ = IERC20(address(pair1));
        assertTrue(_routeHas(info_.mintRoutes(), address(pairA_)), "default mint includes A");
        assertTrue(_routeHas(info_.mintRoutes(), address(pairB_)), "default mint includes B");
        _ensureFreeDetf(d, 1e9);
        for (uint256 i_; i_ < 48 && (info_.isMintingAllowed(pairB_) || !info_.isMintingAllowed(pairA_)); ++i_) {
            _donatePair(d, pairA_, 50 ether);
            uint256 balance_ = IERC20(d).balanceOf(detfUser);
            if (balance_ < 1e9) {
                _mintOn(d, LIVE_MINT_AMT);
                balance_ = IERC20(d).balanceOf(detfUser);
            }
            uint256 input_ = balance_ / 2;
            assertGt(input_, 0, "funded DETF available for public reserve swap");
            vm.startPrank(detfUser);
            IERC20(d).approve(info_.hook(), input_);
            IStandardExchangeIn(info_.hook()).exchangeIn(
                IERC20(d), input_, pairB_, 0, detfUser, false, _deadline()
            );
            vm.stopPrank();
        }
        assertTrue(info_.isMintingAllowed(pairA_), "A primary mint gate open");
        assertFalse(info_.isMintingAllowed(pairB_), "B primary mint gate closed");
        uint256 supply_ = IERC20(d).totalSupply();
        uint256 pending_ = info_.pendingExpansionDetf();
        _assertStandardSettlementOrder(d, pairB_, 1 ether, IERC20(d));
        assertEq(IERC20(d).totalSupply(), supply_ + pending_, "B uses funded reserve swap");
        assertTrue(info_.isMintingAllowed(pairA_), "A primary route remains available");
        supply_ = IERC20(d).totalSupply();
        _assertStandardSettlementOrder(d, pairA_, LIVE_MINT_AMT, IERC20(d));
        assertGt(IERC20(d).totalSupply(), supply_, "A executes new issuance");
    }''')
        mappings.append('T8.4 retains two simultaneous distinct per-leg gates; A issues through the standard route and B executes a supply-neutral swap, with preview and rollback checks for both.')
    records.append((path, before, source, mappings))
for path, before, source, mappings in records:
    if '--apply' in sys.argv: path.write_text(source)
    else: (ART / ('pending-' + path.name + '.txt')).write_text(source)
output = {'status': 'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged', 'files': [
    {'path': str(p.relative_to(ROOT)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest(), 'coverage_mapping': m}
    for p,b,s,m in records]}
(ART / ('v4-nleg-policy-migration.json' if '--apply' in sys.argv else 'pending-v4-nleg-policy-migration.json')).write_text(json.dumps(output, indent=2) + '\n')
print(output['status'])
