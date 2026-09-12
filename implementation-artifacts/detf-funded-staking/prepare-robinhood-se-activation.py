"""Prepare two-token activation in existing Robinhood V4 SE launch helpers."""
from pathlib import Path
import datetime, hashlib, json, sys

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
base = root / 'scripts/foundry/anvil_robinhood_testnet'
changes = {}
p = base / 'PoolSeedLib.sol'
b = p.read_text()
s = b.replace('import {IERC20}', 'import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";\nimport {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";\nimport {IERC20}')
s = s.replace('library PoolSeedLib {', 'library PoolSeedLib {\n    using BetterSafeERC20 for IERC20;')
helper = '''    /// @notice Seed the SE's own full-range book before any one-token DETF intake.
    /// Existing pool liquidity alone does not activate an empty position vault.
    function activateStandardExchange(address se, PoolKey memory key, uint256 amount, address receiver)
        internal
    {
        if (IERC20(se).totalSupply() != 0) return;
        address[] memory tokens = new address[](2);
        tokens[0] = Currency.unwrap(key.currency0);
        tokens[1] = Currency.unwrap(key.currency1);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;
        uint256 minimum = IStandardExchangeInMulti(se).previewExchangeInManyToOne(tokens, amounts, IERC20(se));
        require(minimum != 0, "SE activation quote");
        IERC20(tokens[0]).forceApprove(se, amount);
        IERC20(tokens[1]).forceApprove(se, amount);
        IStandardExchangeInMulti(se).exchangeInManyToOne(tokens, amounts, IERC20(se), minimum, receiver, false, block.timestamp);
        IERC20(tokens[0]).forceApprove(se, 0);
        IERC20(tokens[1]).forceApprove(se, 0);
    }

'''
needle = '    function initEmpty('
assert needle in s
changes[p] = (b, s.replace(needle, helper + needle, 1))

for filename in ('UniV4SeInstanceLib.sol', 'Phase_07_Stage_04_UniV4SeUsd.sol'):
    p = base / filename
    b = p.read_text()
    s = b.replace('_poolSeRp(s, seeder,', '_poolSeRp(s, owner_, seeder,')
    s = s.replace('        LaunchState storage s,\n        address seeder,', '        LaunchState storage s,\n        address receiver,\n        address seeder,')
    needle = '        se = s.uniV4SePkg.deployVault(key);'
    assert needle in s
    s = s.replace(needle, needle + '\n        PoolSeedLib.activateStandardExchange(se, key, seed, receiver);')
    changes[p] = (b, s)

for p, (before, after) in changes.items():
    if '--apply' in sys.argv:
        p.write_text(after)
    else:
        (art / ('pending-se-activation-' + p.name + '.txt')).write_text(after)
record = {
    'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED',
    'finding': 'Both existing Robinhood helpers seeded the underlying V4 pool but left newly deployed SE supply at zero. Their next single-token DETF intake conflicts with mandatory two-token SE activation.',
    'change': 'Reuse each configured seed amount for a real two-token SE activation before creating its rate provider. Initial SE shares belong to the existing deployment receiver. Share supply prevents repeated activation; clear temporary approvals. No broadcast is performed by this preparation.',
    'validation_required': 'Compile launch sources and cover the shared activation helper through actual V4 proxy execution before any local rehearsal; no production deployment authorized by this script.',
    'files': [{'path': str(p.relative_to(root)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest()} for p, (b, s) in changes.items()],
}
(art / 'robinhood-se-activation.json').write_text(json.dumps(record, indent=2)+'\n')
print(record['status'])
