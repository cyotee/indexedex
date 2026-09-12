"""Prepare actual prepaid protocol-receipt mint regressions in the existing provider suite."""
import argparse
import difflib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
path = root / 'test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol'
before = path.read_text()
anchor = '    function testFuzz_transitionSequence('
assert anchor in before and 'function test_prepaidProtocolReceiptMintUsesPrepaymentBacking' not in before
addition = '''    function test_prepaidProtocolReceiptMintUsesPrepaymentBacking() public {
        (address se, SimpleYieldERC4626 vault, IERC20 asset) = _fundPrepaidReceiptCase();
        uint256 payment = 10 ether;
        uint256 quoted = IStandardExchangeIn(se).previewExchangeIn(IERC20(address(vault)), payment, IERC20(se));
        uint256 backing = vault.balanceOf(se);
        uint256 balance = IERC20(se).balanceOf(address(this));
        vault.transfer(se, payment);
        uint256 minted = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(vault)), payment, IERC20(se), quoted, address(this), true, block.timestamp
        );
        assertEq(minted, quoted, "prepaid protocol shares quote against prepayment backing");
        assertEq(IERC20(se).balanceOf(address(this)) - balance, quoted);
        assertEq(vault.balanceOf(se), backing + payment, "new reserve is retained once");
        assertEq(asset.balanceOf(se), 0);
    }

    function test_prepaidProtocolReceiptExactOutputRefundsOnlyUnusedPayment() public {
        (address se, SimpleYieldERC4626 vault,) = _fundPrepaidReceiptCase();
        uint256 wanted = 5 ether;
        uint256 quoted = IStandardExchangeOut(se).previewExchangeOut(IERC20(address(vault)), IERC20(se), wanted);
        uint256 maximum = quoted + 3 ether;
        uint256 backing = vault.balanceOf(se);
        uint256 wallet = vault.balanceOf(address(this));
        uint256 balance = IERC20(se).balanceOf(address(this));
        vault.transfer(se, maximum);
        uint256 spent = IStandardExchangeOut(se).exchangeOut(
            IERC20(address(vault)), maximum, IERC20(se), wanted, address(this), true, block.timestamp
        );
        assertEq(spent, quoted, "prepaid exact-output cost retains prepayment quote");
        assertEq(IERC20(se).balanceOf(address(this)) - balance, wanted);
        assertEq(vault.balanceOf(se), backing + spent, "existing backing and required payment retained");
        assertEq(vault.balanceOf(address(this)), wallet - spent, "only unused user payment refunded");
    }

    function _fundPrepaidReceiptCase() private returns (address se, SimpleYieldERC4626 vault, IERC20 asset) {
        MintableERC20Decimals token = new MintableERC20Decimals("Asset", "ASSET", 18);
        vault = new SimpleYieldERC4626(token);
        se = _deployERC4626SE(address(vault));
        asset = IERC20(address(token));
        token.mint(address(this), 1_000 ether);
        token.approve(se, 100 ether);
        IStandardExchangeIn(se).exchangeIn(asset, 100 ether, IERC20(se), 1, address(this), false, block.timestamp);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 7e16);
        token.approve(address(vault), 100 ether);
        vault.deposit(100 ether, address(this));
    }

'''
after = before.replace(anchor, addition + anchor, 1)
after = after.replace('import {IStandardExchangeIn}', 'import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";\nimport {IStandardExchangeIn}', 1)
if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    path.write_text(after)
(artifacts / 'erc4626-prepaid-regressions.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))))
record = {'status': 'applied; reproduction pending' if args.apply else 'prepared; Solidity unchanged', 'path': str(path.relative_to(root)), 'reason': 'Custom donation trace confirms prepaid protocol receipt is incorrectly included in pre-mint backing. Exact-output companion verifies required input and refund without touching existing reserves.'}
(artifacts / 'erc4626-prepaid-regressions.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record))
