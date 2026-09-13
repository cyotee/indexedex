"""Complete the existing CP SE-share input route using projected receipt/redemption state."""
from pathlib import Path
base=Path('contracts/hooks/uniswap/v4/standardExchange/constantProduct/single')
p=base/'UniswapV4SingleStandardExchangeBufferConstantProductHookDepositPreviewTarget.sol';s=p.read_text()
marker='''        Repo.Layout storage l = Repo._layout();
        (uint256 sold_, uint256 other_, uint256 kept_) = _previewZapSplit(tokenIn_, amountIn_);'''
assert marker in s;s=s.replace(marker,'''        Repo.Layout storage l = Repo._layout();
        if (tokenIn_ == l.standardExchange) return _quoteShareZapState(amountIn_);
        (uint256 sold_, uint256 other_, uint256 kept_) = _previewZapSplit(tokenIn_, amountIn_);''')
marker='    function _quoteZapUnwrap('
helper='''    /// @dev Fee LP is minted before payment receipt by joinSingleAssetExactIn.
    /// The received SE shares are then unwrapped before the existing pair-side zap.
    function _quoteShareZapState(uint256 shares) private view returns (ZapQuote memory q) {
        Repo.Layout storage l = Repo._layout();
        IStandardExchangeTransitionQuote quote = IStandardExchangeTransitionQuote(l.standardExchange);
        (q.state,) = quote.quoteState(l.pairToken, address(this));
        (q.state,,,) = quote.quoteTransition(q.state, IStandardExchangeTransitionQuote.Operation.ReceiveShares, shares);
        uint256 amount;
        (q.state,, amount, q.pairReserve) = quote.quoteTransition(
            q.state, IStandardExchangeTransitionQuote.Operation.RedeemExactIn, shares
        );
        if (q.pairReserve == 0) q.pairReserve = 1;
        q.rawReserve = IERC20(l.rawToken).balanceOf(address(this));
        (,,, uint256 fullClaim) = quote.quoteTransition(q.state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, amount);
        fullClaim = fullClaim > q.pairReserve ? fullClaim - q.pairReserve : 0;
        uint256 sold = _pairZapSaleAmount(amount, fullClaim, q.pairReserve);
        uint256 afterClaim;
        (q.state,,, afterClaim) = quote.quoteTransition(q.state, IStandardExchangeTransitionQuote.Operation.DepositExactIn, sold);
        uint256 claimIn = afterClaim > q.pairReserve ? afterClaim - q.pairReserve : 0;
        q.rawAdded = Math.fromWadFloor(Math.saleQuote(
            Math.toWad(claimIn, _decimalsOf(l.pairToken)),
            Math.toWad(q.pairReserve, _decimalsOf(l.pairToken)),
            Math.toWad(q.rawReserve, _decimalsOf(l.rawToken))
        ), _decimalsOf(l.rawToken));
        q.rawReserve -= q.rawAdded;
        q.pairReserve = afterClaim == 0 ? 1 : afterClaim;
        q.pairAdded = amount - sold;
    }

    function _pairZapSaleAmount(uint256 amount, uint256 claim, uint256 reserve) private view returns (uint256 sold) {
        uint8 decimals = _decimalsOf(Repo._layout().pairToken);
        uint256 saleClaim = Math.fromWadFloor(
            Math.swapDepositSaleAmt(Math.toWad(claim, decimals), Math.toWad(reserve, decimals)), decimals
        );
        sold = claim == 0 ? amount / 2 : amount * saleClaim / claim;
        if (sold > amount) sold = amount;
        if (sold == 0 || sold >= amount) sold = amount / 2;
    }

'''
assert marker in s;s=s.replace(marker,helper+marker);p.write_text(s)
p=base/'UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget.sol';s=p.read_text()
old='''        tokens_ = new address[](2);
        tokens_[0] = l_.rawToken;
        tokens_[1] = l_.pairToken;
    }

    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }'''
new='''        tokens_ = new address[](3);
        tokens_[0] = l_.rawToken;
        tokens_[1] = l_.pairToken;
        tokens_[2] = l_.standardExchange;
    }

    function getTokensOut() public view override returns (address[] memory tokens_) {
        Repo.Layout storage l_ = Repo._layout();
        tokens_ = new address[](2);
        tokens_[0] = l_.rawToken;
        tokens_[1] = l_.pairToken;
    }'''
assert old in s;s=s.replace(old,new);p.write_text(s)
p=Path('test/foundry/spec/vaults/standard/sy/SingleConstantProductHookNativeSY.t.sol');s=p.read_text()
s=s.replace('assertEq(inputs_.length, 2);','assertEq(inputs_.length, 3);')
s=s.replace('assertEq(abi.encode(inputs_), abi.encode(sy_.getTokensOut()));','''assertEq(inputs_[2], se);
        assertEq(sy_.getTokensOut().length, 2);
        assertFalse(sy_.isValidTokenOut(se), "share output remains directionally unsupported");''')
# Reuse the existing route loop and fixture; fund actual SE tokens before its share input.
s=s.replace('''        IERC20[2] memory tokens_ = [IERC20(address(rawToken)), IERC20(address(pairToken))];''','''        vm.startPrank(user);
        pairToken.approve(se, 20 ether);
        IStandardExchangeIn(se).exchangeIn(pairToken, 20 ether, IERC20(se), 0, user, false, block.timestamp);
        IERC20(se).approve(hook, type(uint256).max);
        vm.stopPrank();
        IERC20[3] memory tokens_ = [IERC20(address(rawToken)), IERC20(address(pairToken)), IERC20(se)];''')
s=s.replace('address out_ = address(tokens_[1 - i_]);','address out_ = address(tokens_[i_ == 0 ? 1 : 0]);')
p.write_text(s)
