"""Prepare actual-proxy regressions for external provider transitions; do not run mid-compile."""
from pathlib import Path
import datetime, hashlib, json, sys

root = Path(__file__).resolve().parents[2]
art = Path(__file__).resolve().parent
changes = {}

def insert(relative, needle, added):
    p = root / relative
    b = p.read_text()
    assert needle in b, p
    changes[p] = (b, b.replace(needle, added + needle, 1))

p = root / 'test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol'
b = p.read_text()
s = b.replace('import {IStandardExchangeTransitionQuote}',
              'import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";\nimport {IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {IStandardExchangeTransitionQuote}')
helper = '''    function _assertExternalExchangeQuote(address exchange, IERC20 tokenIn, IERC20 asset, uint256 amount)
        internal
    {
        assertTrue(IERC165(exchange).supportsInterface(type(IStandardExchangeExternalQuote).interfaceId), "actual package declares external quote capability");
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(exchange);
        (bytes memory state,) = quote.quoteState(address(asset), address(this));
        (bytes memory projected, uint256 output, uint256 claim) =
            IStandardExchangeExternalQuote(exchange).quoteExternalExchange(state, address(tokenIn), amount);
        uint256 heldShares = IERC20(exchange).balanceOf(address(this));
        uint256 supply = IERC20(exchange).totalSupply();
        uint256 beforeAssets = asset.balanceOf(address(this));
        tokenIn.approve(exchange, amount);
        uint256 actual = IStandardExchangeIn(exchange).exchangeIn(
            tokenIn, amount, asset, output, address(this), false, block.timestamp
        );
        assertEq(actual, output, "external payment conversion output");
        assertEq(asset.balanceOf(address(this)) - beforeAssets, output, "external conversion receipt");
        assertEq(IERC20(exchange).balanceOf(address(this)), heldShares, "buffered SE shares remain owned");
        assertEq(IERC20(exchange).totalSupply(), supply, "external conversion does not issue SE shares");
        (bytes memory actualState, uint256 actualClaim) = quote.quoteState(address(asset), address(this));
        assertEq(actualClaim, claim, "post-external-conversion buffered claim");
        _assertProjectedState(actualState, projected);
    }

'''
needle = '    function _assertQuoteSequence('
assert needle in s
changes[p] = (b, s.replace(needle, helper + needle, 1))

for version in (3, 4):
    insert(f'test/foundry/spec/protocol/dexes/uniswap/v{version}/UniswapV{version}StandardExchange_FullRangeBook.t.sol',
           '    function testFuzz_transitionSequence_fundedPool(', '''    function test_externalSwapTransition_preservesFundedHolderBook() public {
        _dualJoin(10_000_000 ether, 10_000_000 ether);
        for (uint256 i; i < 2; ++i) {
            IERC20 input = IERC20(i == 0 ? _token0() : _token1());
            IERC20 asset = IERC20(i == 0 ? _token1() : _token0());
            ERC20PermitMintableStub(address(input)).mint(address(this), 1_000 ether);
            _assertExternalExchangeQuote(address(vault), input, asset, 1_000 ether);
        }
    }

''')

insert('test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_TransitionQuote.t.sol',
       '    function testFuzz_transitionSequence(', '''    function test_externalSwapAndLpRedemptionTransition() public {
        for (uint256 i; i < 3; ++i) {
            IStandardExchangeProxy se_ = _getVault(PoolConfig(i));
            IUniswapV2Pair pool_ = _getPool(PoolConfig(i));
            uint256 fundedLp_ = pool_.balanceOf(address(this)) / 100;
            IERC20(address(pool_)).approve(address(se_), fundedLp_);
            se_.exchangeIn(IERC20(address(pool_)), fundedLp_, IERC20(address(se_)), 1, address(this), false, _deadline());
            IERC20 input_ = IERC20(pool_.token0());
            IERC20 asset_ = IERC20(pool_.token1());
            deal(address(input_), address(this), 10_000 ether);
            _assertExternalExchangeQuote(address(se_), input_, asset_, 1 ether);
            _assertExternalExchangeQuote(address(se_), IERC20(address(pool_)), asset_, fundedLp_ / 10);
        }
    }

''')

insert('test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol',
       '    function testFuzz_transitionSequence(', '''    function test_externalProtocolVaultRedemptionTransition() public {
        MintableERC20Decimals asset_ = new MintableERC20Decimals("Asset", "ASSET", 18);
        SimpleYieldERC4626 vault_ = new SimpleYieldERC4626(asset_);
        address se_ = _deployERC4626SE(address(vault_));
        asset_.mint(address(this), 10_000 ether);
        asset_.approve(se_, 1_000 ether);
        IStandardExchangeIn(se_).exchangeIn(IERC20(address(asset_)), 1_000 ether, IERC20(se_), 1, address(this), false, block.timestamp);
        asset_.approve(address(vault_), 200 ether);
        uint256 payment_ = vault_.deposit(100 ether, address(this));
        vault_.simulateYield(100 ether);
        _assertExternalExchangeQuote(se_, IERC20(address(vault_)), IERC20(address(asset_)), payment_);
    }

''')

for p, (before, after) in changes.items():
    if '--apply' in sys.argv:
        p.write_text(after)
    else:
        (art / ('pending-external-quote-test-' + p.name + '.txt')).write_text(after)
record = {
    'recorded_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status': 'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'PREPARED_NOT_APPLIED',
    'scope': 'One shared assertion compares actual output, ownership/supply, aggregate buffered claim and every projected state field against real proxy execution. V3/V4 both directions, three real V2 pools including external LP redemption, and yield-bearing ERC4626 protocol-share payment.',
    'dependencies': ['prepare-external-se-quote-transition.py', 'Provider facet selector wiring and independent controls are still required.'],
    'files': [{'path': str(p.relative_to(root)), 'before_sha256': hashlib.sha256(b.encode()).hexdigest(), 'after_sha256': hashlib.sha256(s.encode()).hexdigest()} for p, (b, s) in changes.items()],
}
(art / 'external-se-quote-tests.json').write_text(json.dumps(record, indent=2)+'\n')
print(record['status'])
