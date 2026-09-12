from pathlib import Path
import re,sys,json,hashlib
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking';b=r/'test/foundry/spec/protocols/dexes/uniswap/v4/pons';files={}
helper='''/// @notice Actual bidirectional Pons swaps, including the pool's frozen fee terms.
abstract contract PonsV4QuoteAssertions is Test {
    function _assertPonsSwapQuotes(address se_, IERC20 pair_, IERC20 launch_, uint256 amount_) internal {
        uint256 bought_ = _assertPonsExactIn(se_, pair_, launch_, amount_);
        _assertPonsExactIn(se_, launch_, pair_, bought_ / 4);
        uint256 desired_ = bought_ / 100;
        uint256 quote_ = IStandardExchangeOut(se_).previewExchangeOut(pair_, launch_, desired_);
        assertGt(quote_, 0);
        uint256 pairBefore_ = pair_.balanceOf(address(this));
        uint256 launchBefore_ = launch_.balanceOf(address(this));
        pair_.approve(se_, quote_);
        uint256 paid_ = IStandardExchangeOut(se_).exchangeOut(pair_, quote_, launch_, desired_, address(this), false, block.timestamp);
        assertEq(paid_, quote_, "exact-output quote includes frozen input-leg hook fee and tax");
        assertEq(pair_.balanceOf(address(this)), pairBefore_ - paid_);
        assertEq(launch_.balanceOf(address(this)), launchBefore_ + desired_);
    }

    function _assertPonsExactIn(address se_, IERC20 in_, IERC20 out_, uint256 amount_) private returns (uint256 received_) {
        uint256 quote_ = IStandardExchangeIn(se_).previewExchangeIn(in_, amount_, out_);
        assertGt(quote_, 0);
        uint256 before_ = out_.balanceOf(address(this));
        in_.approve(se_, amount_);
        vm.expectRevert();
        IStandardExchangeIn(se_).exchangeIn(in_, amount_, out_, quote_ + 1, address(this), false, block.timestamp);
        assertEq(out_.balanceOf(address(this)), before_, "failed minimum rolls back output");
        received_ = IStandardExchangeIn(se_).exchangeIn(in_, amount_, out_, quote_, address(this), false, block.timestamp);
        assertEq(received_, quote_, "exact-input quote includes frozen output-leg hook fee and tax");
        assertEq(out_.balanceOf(address(this)), before_ + received_);
    }
}

'''
for native in [False,True]:
 p=b/'decimals/UniswapV4StandardExchange_PonsV2Pool_Decimals.sol' if native else b/'UniswapV4StandardExchange_PonsV2Pool.t.sol';s=p.read_text()
 if native:
  s=s.replace('import {IERC20}', 'import {PonsV4QuoteAssertions} from "test/foundry/spec/protocols/dexes/uniswap/v4/pons/UniswapV4StandardExchange_PonsV2Pool.t.sol";\nimport {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";\nimport {IERC20}',1)
  s=s.replace('is UniswapV4SeDecimalsHelpers {','is UniswapV4SeDecimalsHelpers, PonsV4QuoteAssertions {')
  s=s.replace('creatorTaxBps: 0,','creatorTaxBps: 137,')
  s=s.replace('''        vm.label(address(ponsSe), "UniV4Se_ponsV2_decimals");''','''        vm.label(address(ponsSe), "UniV4Se_ponsV2_decimals");
        uint256 quote_ = _uB(1) / 1000;
        quoteToken.mint(address(this), quote_);
        address[] memory tokens_ = ponsSe.vaultTokens();
        uint256[] memory amounts_ = new uint256[](2);
        for (uint256 i_; i_ < 2; ++i_) {
            amounts_[i_] = tokens_[i_] == launchToken ? 10_000 ether : quote_;
            IERC20(tokens_[i_]).approve(address(ponsSe), amounts_[i_]);
        }
        IStandardExchangeInMulti se_ = IStandardExchangeInMulti(address(ponsSe));
        uint256 preview_ = se_.previewExchangeInManyToOne(tokens_, amounts_, IERC20(address(ponsSe)));
        assertGt(preview_, 0);
        assertEq(se_.exchangeInManyToOne(tokens_, amounts_, IERC20(address(ponsSe)), preview_, address(this), false, _deadline()), preview_, "actual two-token activation");''')
  token='quoteToken';fund='quoteToken.mint(address(this), amount_);';amount='_uB(1) / 4'
 else:
  s=s.replace('import {IERC20}', 'import {Test} from "forge-std/Test.sol";\nimport {IERC20}',1)
  s=s.replace('contract UniswapV4StandardExchange_PonsV2Pool is TestBase_UniswapV4StandardExchange_PonsV2 {',helper+'contract UniswapV4StandardExchange_PonsV2Pool is TestBase_UniswapV4StandardExchange_PonsV2, PonsV4QuoteAssertions {\n    function setUp() public override { super.setUp(); _activatePonsSe(); }')
  token='weth';fund='_wrapWeth(address(this), amount_);';amount='0.25 ether'
 s=s.replace('uint256 wantOut = shares / 4;', 'uint256 wantOut = IStandardExchangeIn(address(ponsSe)).previewExchangeIn(IERC20(address(ponsSe)), shares / 4, IERC20(address('+token+')));')
 start=s.index('    function test_T10_6_');end=s.index('    function test_T10_7_',start)
 s=s[:start]+'''    function test_T10_6_swapOnSe_doesNotRevertFromMemeHookFee() public {
        uint256 amount_ = '''+amount+''';
        '''+fund+'''
        // A policy change applies only to future launches; this pool retains its frozen cuts.
        vm.prank(ponsV2Owner);
        ponsV2MemeHook.setHookFeeBps(777);
        _assertPonsSwapQuotes(address(ponsSe), IERC20(address('''+token+''')), IERC20(launchToken), amount_);
    }

'''+s[end:]
 files[p]=s
rows=[]
for p,s in files.items():
 old=p.read_text();assert old!=s
 rows.append({'path':str(p.relative_to(r)),'before':hashlib.sha256(old.encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest()})
 if '--apply' in sys.argv:p.write_text(s)
 else:(a/('pending-pons-pool-tests-'+p.name+'.txt')).write_text(s)
(a/('pons-pool-quote-tests.json' if '--apply' in sys.argv else 'pending-pons-pool-quote-tests.json')).write_text(json.dumps({'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':rows,'coverage':'Retain T10.1-T10.7 in all three actual Pons SE fixtures; fund required two-token activation; use native output units; shared exact-input/output and rollback assertions on both directions; native quote fixtures add nonzero creator tax and all fixtures verify frozen fee terms after changing future-launch policy.'},indent=2)+'\n')
print(len(files),'applied' if '--apply' in sys.argv else 'prepared')
