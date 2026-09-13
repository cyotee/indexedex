"""Extend the existing sequential-quote assertion, avoiding per-family duplicate fixtures."""
from pathlib import Path
p=Path('test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol');s=p.read_text()
marker='''            _assertProjectedState(actualState_, steps_[i].state);
        }
    }''';assert s.count(marker)==1
s=s.replace(marker,'''            _assertProjectedState(actualState_, steps_[i].state);
        }
        _assertShareReceipt(exchange_, asset_, holder_);
    }''')
marker='    function _assertProjectedState('
helper='''    function _assertShareReceipt(address exchange, IERC20 asset, address holder) internal {
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(exchange);
        address receiver = makeAddr("se quote receipt holder");
        uint256 shares = IERC20(exchange).balanceOf(holder) / 20;
        assertGt(shares, 0, "receipt test uses actually funded shares");
        uint256 supply = IERC20(exchange).totalSupply();
        (bytes memory state,) = quote.quoteState(address(asset), receiver);
        (bytes memory projected,,, uint256 projectedClaim) = quote.quoteTransition(
            state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, shares
        );
        vm.prank(holder); IERC20(exchange).transfer(receiver, shares);
        (bytes memory actual, uint256 actualClaim) = quote.quoteState(address(asset), receiver);
        _assertProjectedState(actual, projected);
        assertEq(actualClaim, projectedClaim, "received shares retain the actual backing claim");
        assertEq(IERC20(exchange).totalSupply(), supply, "share transfer cannot issue supply");
        vm.prank(receiver); IERC20(exchange).transfer(holder, shares);
    }

''';assert s.count(marker)==1;s=s.replace(marker,helper+marker);p.write_text(s)
p=Path('test/foundry/spec/vaults/standard/sy/V3FullRangeNativeSY.t.sol');s=p.read_text().replace('import {IERC20}', 'import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";\nimport {IERC20}',1).replace('is TestBase_UniswapV3StandardExchange, IUniswapV3FlashCallback {','is TestBase_UniswapV3StandardExchange, IUniswapV3FlashCallback, TransitionQuoteAssertions {')
marker='    function test_installedQueryFacetsFitRuntimeLimit()'
assert marker in s;s=s.replace(marker,'''    function test_receivedSharesDoNotRebalanceOrChangePoolInventory() public {
        _activate();
        _assertShareReceipt(address(se), token0, address(this));
    }

'''+marker);p.write_text(s)
p=Path('test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol');s=p.read_text()
for path,name in (
('test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_TransitionQuote.t.sol','UniswapV2StandardExchange_TransitionQuote'),
('test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol','ERC4626StandardExchange_TransitionQuote'),
('test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_TransitionQuote.t.sol','MorphoBlueStandardExchange_TransitionQuote')):
 assert path not in s;s+=f'\nimport {{{name}}} from "{path}";\n'
p.write_text(s)
