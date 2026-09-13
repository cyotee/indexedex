"""Prepare real-provider tests for external SE mint projection; apply after Forge exits."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
changes = []

def stage(relative, transform):
    path = root / relative
    before = path.read_text()
    after = transform(before)
    assert before != after, relative
    changes.append((path, before, after))

def assertions(source):
    anchor = '    function _assertQuoteSequence('
    assert anchor in source and 'function _assertExternalDepositQuote' not in source
    return source.replace(anchor, '''    function _assertExternalDepositQuote(
        address exchange, IERC20 tokenIn, IERC20 asset, uint256 amount, address holder
    ) internal {
        assertTrue(IERC165(exchange).supportsInterface(type(IStandardExchangeExternalQuote).interfaceId));
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(exchange);
        (bytes memory state,) = quote.quoteState(address(asset), holder);
        Step memory step;
        (step.state, step.output, step.claim) = IStandardExchangeExternalQuote(exchange)
            .quoteExternalDeposit(state, address(tokenIn), amount);
        address recipient = makeAddr("external SE mint recipient");
        uint256 beforeShares = IERC20(exchange).balanceOf(recipient);
        tokenIn.approve(exchange, amount);
        assertEq(IStandardExchangeIn(exchange).exchangeIn(
            tokenIn, amount, IERC20(exchange), step.output, recipient, false, block.timestamp
        ), step.output, "external mint return equals projection");
        assertEq(IERC20(exchange).balanceOf(recipient) - beforeShares, step.output, "funded user share receipt");
        assertEq(IERC20(exchange).totalSupply(), quote.quoteTotalSupply(step.state), "external mint includes issued fee shares");
        assertEq(IERC20(exchange).balanceOf(holder), quote.quoteShareBalance(step.state), "buffered holder and fee attribution");
        (bytes memory actual, uint256 claim) = quote.quoteState(address(asset), holder);
        assertEq(claim, step.claim, "post-mint buffered asset claim");
        _assertProjectedState(actual, step.state);
    }

''' + anchor, 1)

stage('test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol', assertions)

def positions(source):
    anchor = '    function test_externalSwapTransition_preservesFundedHolderBook() public {'
    assert anchor in source
    return source.replace(anchor, '''    function test_externalDepositTransition_preservesFundedHolderBook() public {
        _dualJoin(10_000_000 ether, 10_000_000 ether);
        for (uint256 i; i < 2; ++i) {
            IERC20 input = IERC20(i == 0 ? _token0() : _token1());
            IERC20 asset = IERC20(i == 0 ? _token1() : _token0());
            ERC20PermitMintableStub(address(input)).mint(address(this), 1_000 ether);
            _assertExternalDepositQuote(address(vault), input, asset, 1_000 ether, address(this));
        }
    }

''' + anchor, 1)

for version in ['v3', 'v4']:
    stage(f'test/foundry/spec/protocol/dexes/uniswap/{version}/Uniswap{version.upper()}StandardExchange_FullRangeBook.t.sol', positions)

def v2(source):
    anchor = '    function testFuzz_transitionSequence('
    assert anchor in source
    return source.replace(anchor, '''    function test_externalDepositTransition_rawAndLpWithFundedFees() public {
        for (uint256 i; i < 3; ++i) {
            IStandardExchangeProxy se = _getVault(PoolConfig(i));
            IUniswapV2Pair pool = _getPool(PoolConfig(i));
            address holder = address(indexedexManager.feeTo());
            uint256 lp = pool.balanceOf(address(this)) / 100;
            IERC20(address(pool)).approve(address(se), lp);
            se.exchangeIn(IERC20(address(pool)), lp, IERC20(address(se)), 1, holder, false, _deadline());
            vm.prank(owner);
            IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(se), 7e16);
            IERC20 asset = IERC20(pool.token1());
            IERC20 input = IERC20(pool.token0());
            deal(address(input), address(this), 10_000 ether);
            deal(address(asset), address(this), 10_000 ether);
            // Exercise the accounting asset, opposing asset, and already-funded LP payment.
            _assertExternalDepositQuote(address(se), asset, asset, 1 ether, holder);
            _assertExternalDepositQuote(address(se), input, asset, 1 ether, holder);
            _assertExternalDepositQuote(address(se), IERC20(address(pool)), asset, lp / 10, holder);
        }
    }

''' + anchor, 1)

stage('test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_TransitionQuote.t.sol', v2)

def erc4626(source):
    anchor = '    function testFuzz_transitionSequence('
    assert anchor in source
    return source.replace(anchor, '''    function test_externalDepositTransition_underlyingAndReceiptWithFundedFees() public {
        MintableERC20Decimals asset = new MintableERC20Decimals("Asset", "ASSET", 18);
        SimpleYieldERC4626 vault = new SimpleYieldERC4626(asset);
        address se = _deployERC4626SE(address(vault));
        address holder = address(indexedexManager.feeTo());
        asset.mint(address(this), 10_000 ether);
        asset.approve(se, 1_000 ether);
        IStandardExchangeIn(se).exchangeIn(IERC20(address(asset)), 1_000 ether, IERC20(se), 1, holder, false, block.timestamp);
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 7e16);
        asset.approve(address(vault), 200 ether);
        uint256 payment = vault.deposit(100 ether, address(this));
        vault.simulateYield(100 ether);
        _assertExternalDepositQuote(se, IERC20(address(vault)), IERC20(address(asset)), payment, holder);
        _assertExternalDepositQuote(se, IERC20(address(asset)), IERC20(address(asset)), 10 ether, holder);
    }

''' + anchor, 1)

stage('test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol', erc4626)

if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    for path, before, after in changes:
        assert path.read_text() == before
        path.write_text(after)
report = {
    'status': 'applied; validation pending' if args.apply else 'prepared; no Solidity changed',
    'scope': 'Existing real V2/V3/V4/ERC4626 provider suites, user receipts, entire projected state, supply and buffered fee-holder claims',
    'files': [{'path': str(path.relative_to(root)), 'before_sha256': hashlib.sha256(before.encode()).hexdigest(), 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, before, after in changes],
}
(artifacts / 'external-se-deposit-tests.patch').write_text(''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))) for path, before, after in changes))
(artifacts / 'external-se-deposit-tests.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'status': report['status'], 'files': len(changes)}))
