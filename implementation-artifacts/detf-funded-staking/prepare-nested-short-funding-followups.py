"""Keep short-payment negatives independent of position reserve valuation views."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, hashlib, json

art = Path(__file__).resolve().parent
root = art.parent.parent
draft_dir = art / 'nested-short-funding-drafts'
draft_dir.mkdir(exist_ok=False)
changes, patch = [], []
for suffix in ('', '_Decimals'):
    path = 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial' + suffix + '.sol'
    before = (root / path).read_text()
    start = before.index('    function _assertT_NEST_2()')
    end = before.index('    function _assertT_NEST_3()', start)
    body = before[start:end]
    old = '''        vm.prank(detfUser);
        pairToken.transfer(se, dust_);
        uint256 Rh = IBasicVault(se).reserveOfToken(address(pairToken));
        uint256 Bh = IERC20(address(pairToken)).balanceOf(se);
        uint256 U = Bh >= Rh ? Bh - Rh : 0;
        assertTrue(U > 0, "need surplus");
        uint256 claimOver_ = U + 1;'''
    assert body.count(old) == 1
    body = body.replace(old, '''        uint256 before_ = IERC20(address(pairToken)).balanceOf(se);
        vm.prank(detfUser);
        pairToken.transfer(se, dust_);
        uint256 funded_ = IERC20(address(pairToken)).balanceOf(se);
        assertEq(funded_ - before_, dust_, "actual short payment delivered");
        uint256 receipts_ = IERC20(se).balanceOf(detfUser);
        // Position reserveOfToken includes deployed liquidity and is not a
        // liquid-balance checkpoint. Claim one more than the actual delivery.
        uint256 claimOver_ = dust_ + 1;''')
    old = '            _deadline()\n        );\n    }'
    assert body.count(old) == 1
    body = body.replace(old, '''            _deadline()
        );
        assertEq(IERC20(se).balanceOf(detfUser), receipts_, "short payment mints no receipt");
        assertEq(IERC20(address(pairToken)).balanceOf(se), funded_, "failed claim preserves actual custody");
    }''')
    after = before[:start] + body + before[end:]
    draft = draft_dir / (Path(path).name + '.txt')
    draft.write_text(after)
    changes.append({'path': path, 'draft': str(draft.relative_to(root)),
                    'reason': 'Measure actual transfer delta for the retained nested short-payment negative; preserve no-free-mint and custody assertions across liquid and position SE providers.',
                    'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                    'after_sha256': hashlib.sha256(after.encode()).hexdigest()})
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile='a/' + path, tofile='b/' + path))
record = {'status': 'PREPARED_NOT_APPLIED', 'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
          'gate': 'Entire active parent 4255 exits before application.', 'changes': changes,
          'scope': 'Two existing shared V4 adversarial fixtures; all declarations retained; no production edits.',
          'validation_passed': False, 'required_validation': 'Typecheck and actual nested short-payment negatives on V3/V4 and other production SE provider leaves.'}
(art / 'nested-short-funding-followups-prepared.json').write_text(json.dumps(record, indent=2) + '\n')
(art / 'nested-short-funding-followups.patch').write_text(''.join(patch))
print(json.dumps({'status': record['status'], 'draft_sources': len(changes), 'canonical_sources_changed': 0}))
