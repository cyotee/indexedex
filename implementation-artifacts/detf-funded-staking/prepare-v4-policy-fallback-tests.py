from pathlib import Path
import json,hashlib
p=Path('test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol')
s=p.read_text()
s=s.replace('    function _policy() internal pure virtual returns (bool) { return true; }', '''    function _policy() internal pure virtual returns (bool) { return true; }
    function _deployFallbackInstance() internal virtual returns (address);

    struct FallbackSnapshot {
        uint256 supply;
        uint256 funding;
        uint256 protocolLp;
        uint256 inputBalance;
        uint256 outputBalance;
        uint256 quoted;
        uint256 pending;
    }

    function _fallbackArgs(IUniswapV4Detf.PkgArgs memory args_)
        internal pure returns (IUniswapV4Detf.PkgArgs memory)
    {
        args_.name = "V4 funded fallback";
        args_.symbol = "DETF";
        args_.mintThreshold = 100e18;
        args_.burnThreshold = 1;
        args_.expansionClosureRatePerYearWad = 1e18;
        return args_;
    }

    function _activateFallbackInstance() private returns (IUniswapV4Detf subject_) {
        subject_ = IUniswapV4Detf(_deployFallbackInstance());
        (address[] memory tokens_, uint256[] memory amounts_) = subject_.previewFirstBondPayments(
            IERC20(_leadPayment()), 1_000 ether
        );
        vm.startPrank(_buyer());
        for (uint256 i_; i_ < tokens_.length; ++i_) IERC20(tokens_[i_]).approve(address(subject_), amounts_[i_]);
        subject_.bond(IERC20(_leadPayment()), 1_000 ether, 30 days, _buyer(), false, block.timestamp);
        vm.stopPrank();
        assertEq(subject_.ownerOnlyLiquidity(), _policy());
        assertFalse(subject_.isMintingAllowed(IERC20(_leadPayment())));
        assertFalse(subject_.isBurningAllowed(IERC20(_leadPayment())));
    }

    function test_standardMintAndBurnFallbackMatchActualSwapWithoutIssuance() public {
        IUniswapV4Detf subject_ = _activateFallbackInstance();
        uint256 acquired_ = _assertFallbackExchange(subject_, IERC20(_leadPayment()), 10 ether, IERC20(address(subject_)));
        _assertFallbackExchange(subject_, IERC20(address(subject_)), acquired_ / 2, IERC20(_leadPayment()));
    }

    function test_standardFallbackSettlesFundedCatchupBeforeBothDirections() public {
        IUniswapV4Detf subject_ = _activateFallbackInstance();
        uint256 acquired_ = _assertFallbackExchange(subject_, IERC20(_leadPayment()), 10 ether, IERC20(address(subject_)));
        _fundReserveYield(subject_, 3_000 ether);
        vm.warp(block.timestamp + 25 hours);
        assertGt(subject_.pendingExpansionDetf(), 0, "real reserve yield funds due epochs");
        _assertFallbackExchange(subject_, IERC20(_leadPayment()), 10 ether, IERC20(address(subject_)));
        _fundReserveYield(subject_, 3_000 ether);
        vm.warp(block.timestamp + 25 hours);
        assertGt(subject_.pendingExpansionDetf(), 0, "later epochs have funded expansion");
        _assertFallbackExchange(subject_, IERC20(address(subject_)), acquired_ / 2, IERC20(_leadPayment()));
    }

    function _fundReserveYield(IUniswapV4Detf subject_, uint256 amount_) private {
        IUniswapV4SeBufferHook hook_ = IUniswapV4SeBufferHook(subject_.hook());
        address[] memory tokens_ = hook_.tokens();
        vm.startPrank(_buyer());
        for (uint256 i_; i_ < tokens_.length; ++i_) {
            address se_ = hook_.standardExchangeOf(tokens_[i_]);
            if (se_ == address(0)) continue;
            address protocol_ = IStandardizedYield(se_).yieldToken();
            IERC20(tokens_[i_]).approve(protocol_, amount_);
            SimpleYieldERC4626(protocol_).simulateYield(amount_);
        }
        vm.stopPrank();
    }

    function _assertFallbackExchange(IUniswapV4Detf subject_, IERC20 in_, uint256 amount_, IERC20 out_)
        private returns (uint256 paid_)
    {
        IERC20 detf_ = IERC20(address(subject_));
        IStandardExchangeIn exchange_ = IStandardExchangeIn(address(subject_));
        address staking_ = subject_.rebasingClaimToken();
        FallbackSnapshot memory before_ = FallbackSnapshot({
            supply: detf_.totalSupply(), funding: detf_.balanceOf(staking_),
            protocolLp: IERC20(subject_.hook()).balanceOf(subject_.bondNftVault()),
            inputBalance: in_.balanceOf(_buyer()), outputBalance: out_.balanceOf(_buyer()),
            quoted: exchange_.previewExchangeIn(in_, amount_, out_), pending: subject_.pendingExpansionDetf()
        });
        assertGt(before_.quoted, 0, "closed gate has executable swap quote");
        assertEq(before_.quoted, IUniswapV4SeBufferHook(subject_.hook()).previewSwapExactIn(address(in_), address(out_), amount_));
        vm.startPrank(_buyer());
        in_.approve(address(subject_), amount_);
        vm.expectRevert();
        exchange_.exchangeIn(in_, amount_, out_, before_.quoted + 1, _buyer(), false, block.timestamp);
        vm.stopPrank();
        assertEq(detf_.totalSupply(), before_.supply, "failed minimum rolls back expansion");
        assertEq(subject_.pendingExpansionDetf(), before_.pending, "failed minimum leaves epochs due");
        assertEq(in_.balanceOf(_buyer()), before_.inputBalance, "failed minimum restores payment");
        vm.prank(_buyer());
        paid_ = exchange_.exchangeIn(in_, amount_, out_, before_.quoted, _buyer(), false, block.timestamp);
        assertEq(paid_, before_.quoted);
        assertEq(in_.balanceOf(_buyer()), before_.inputBalance - amount_);
        assertEq(out_.balanceOf(_buyer()), before_.outputBalance + paid_);
        assertEq(detf_.totalSupply(), before_.supply + before_.pending, "swap neither mints nor burns DETF");
        assertEq(detf_.balanceOf(staking_), before_.funding + before_.pending, "only funded expansion reaches staking");
        assertEq(subject_.pendingExpansionDetf(), 0, "catchup consumed once");
        assertEq(IERC20(subject_.hook()).balanceOf(subject_.bondNftVault()), before_.protocolLp, "swap does not change owned LP");
    }''')
# Reuse the same funded-yield helper for existing LP-payment catchup coverage.
start=s.index('        address[] memory tokens_ = _hook().tokens();',s.index('    function test_lpBondSettlesExpansionBeforeTakingPayment'))
end=s.index('        vm.warp(block.timestamp + 25 hours);',start)
s=s[:start]+'        _fundReserveYield(_subject(), 3_000 ether);\n'+s[end:]
for cls,deploy,n in [('CpReserveLiquidityTest','_deployHookThenDetf',1),('WeightedReserveLiquidityTest','_deployWeightedHookThenDetf',2),('OrbitalReserveLiquidityTest','_deployOrbitalHookThenDetf',2),('CurveQuadReserveLiquidityTest','_deployCurveHookThenDetf',3)]:
 start=s.index('contract '+cls+' ')
 at=s.index('    function _subject()',start)
 arg='_defaultDetfArgs()' if n==1 else f'_nLegDetfArgs({n})'
 s=s[:at]+f'    function _deployFallbackInstance() internal override returns (address) {{ return {deploy}(_fallbackArgs({arg})); }}\n'+s[at:]
assert 'test_standardMintAndBurnFallbackMatchActualSwapWithoutIssuance' not in p.read_text()
p.write_text(s)
print('Applied shared V4 funded fallback cases across four reserves and both liquidity policies.')
