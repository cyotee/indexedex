"""Prepare state-based policy fixtures without modifying the active Forge inputs."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, hashlib, json

art = Path(__file__).resolve().parent
root = art.parent.parent
draft_dir = art / 'funded-policy-fixture-drafts'
draft_dir.mkdir(exist_ok=False)
changes = []
patch = []

def save(path, before, after, reason):
    assert before != after
    draft = draft_dir / (Path(path).name + '.txt')
    draft.write_text(after)
    changes.append({'path': path, 'draft': str(draft.relative_to(root)), 'reason': reason,
                    'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                    'after_sha256': hashlib.sha256(after.encode()).hexdigest()})
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                     fromfile='a/' + path, tofile='b/' + path))

base = 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/'
for suffix in ('', '_Decimals'):
    path = base + 'TestBase_UniswapV4Detf_Policy' + suffix + '.sol'
    before = (root / path).read_text()
    after = before
    old = '        _ensureFreeDetf(d, 1e9);\n        uint256 available_ = IERC20(d).balanceOf(detfUser) / 2;'
    assert after.count(old) == 1
    after = after.replace(old, '''        // Fractions of a DETF remain spendable after earlier reserve swaps.
        // Do not attempt to claim an already consumed bond merely because the
        // remaining balance is below one whole (1e9-unit) token.
        _ensureFreeDetf(d, 1);
        uint256 available_ = IERC20(d).balanceOf(detfUser) / 2;''')
    old = '        d = _deployTagged(_openArgsPolicy(), _nextTag());'
    assert after.count(old) == 1
    after = after.replace(old, '''        // A configured 1:1 opening is not necessarily a no-premium reserve
        // valuation (notably for Orbital). Set an explicit below-peg launch;
        // the shared no-expansion assertion still checks the actual price.
        d = _deployTagged(_withOpening(_openArgsPolicy(), 0.5e18), _nextTag());''')
    if not suffix:
        old = '        vm.warp(block.timestamp + 30 * 365 days);\n        uint256 pending_ = info_.pendingExpansionDetf();'
        assert after.count(old) == 1
        after = after.replace(old, '''        _warpUntilSettlementClosesMint(d, token_);
        uint256 pending_ = info_.pendingExpansionDetf();''')
        marker = '    function _assert_D31_2_realizeWouldCloseMint_revertsUnchanged(address d) internal {'
        helper = '''    /// @dev Establish the trigger on the real family book. Thirty years at 5%
    /// need not close every opening premium. Each probe is rolled back before
    /// the actual preview/implicit-settlement comparison below.
    function _warpUntilSettlementClosesMint(address d, IERC20 token_) private {
        uint256 start_ = block.timestamp;
        uint256 elapsed_ = 30 * 365 days;
        for (uint256 i_; i_ < 8; ++i_) {
            vm.warp(start_ + elapsed_);
            uint256 snapshot_ = vm.snapshotState();
            IDETFFundedRewards(d).synchronizeRewards();
            bool closed_ = !IUniswapV4Detf(d).isMintingAllowed(token_);
            assertTrue(vm.revertToStateAndDelete(snapshot_));
            if (closed_) return;
            elapsed_ *= 2;
        }
        revert("fixture cannot establish post-expansion gate closure");
    }

'''
        after = after.replace(marker, helper + marker)
    save(path, before, after, 'Preserve fractional purchased DETF for repeated swaps, use an explicit below-peg no-expansion fixture, and establish actual post-expansion gate closure without a fixed-horizon assumption.')

path = 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol'
before = (root / path).read_text()
old = '        args.symbol = "wH8";'
assert before.count(old) == 1
after = before.replace(old, '''        args.symbol = "wH8";
        // Isolate route membership while the mandatory primary gate is open.
        args.openingPairPerDetfWad = new uint256[](2);
        args.openingPairPerDetfWad[0] = 2.2e18;
        args.openingPairPerDetfWad[1] = 2.2e18;''')
save(path, before, after, 'Use an actual rich launch for the retained custom mint-route membership test; keep both positive A and negative B assertions.')

record = {'status': 'PREPARED_NOT_APPLIED', 'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
          'gate': 'Apply only after the entire active parent session 4255 exits.',
          'changes': changes, 'validation_passed': False,
          'scope': 'Existing policy fixtures only; production price, reserve and expansion math unchanged. All declarations and final assertions retained.',
          'required_validation': 'Draft typecheck, then actual gold policy/claim cases and provider/decimal policy leaves. Other runtime failures may remain.'}
(art / 'funded-policy-fixture-followups-prepared.json').write_text(json.dumps(record, indent=2) + '\n')
(art / 'funded-policy-fixture-followups.patch').write_text(''.join(patch))
print(json.dumps({'status': record['status'], 'draft_sources': len(changes), 'canonical_sources_changed': 0}))
