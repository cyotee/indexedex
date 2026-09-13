from pathlib import Path
import re,json,hashlib,sys
ROOT=Path.cwd();ART=ROOT/'implementation-artifacts/detf-funded-staking';p=ROOT/'test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol';b=p.read_text();s=b
def replace(s,name,body):
 m=re.search(r'    function '+re.escape(name)+r'\(',s);assert m,name
 a=s.index('{',m.end());j=a+1;n=1
 while n:
  if s[j]=='{':n+=1
  elif s[j]=='}':n-=1
  j+=1
 return s[:m.start()]+body+s[j:]
s=s.replace('assertEq(IERC20Metadata(detf).decimals(), 18);','assertEq(IERC20Metadata(detf).decimals(), 9);')
s=s.replace('ownerOnlyLiquidity: true, owner: predicted','ownerOnlyLiquidity: args.ownerOnlyLiquidity, owner: predicted')
s=s.replace('    function _rehearse(uint256 family, uint256 backend) internal {','''    function test_cp_v4_publicLiquidity() public { _rehearse(0, 2, false); }
    function test_weighted_v4_publicLiquidity() public { _rehearse(1, 2, false); }
    function test_quad_v4_publicLiquidity() public { _rehearse(2, 2, false); }

    function _rehearse(uint256 family, uint256 backend) internal { _rehearse(family, backend, true); }

    function _rehearse(uint256 family, uint256 backend, bool restricted) internal {''')
s=s.replace('        args.name = "Rehearsal DETF";','        args.ownerOnlyLiquidity = restricted;\n        args.name = "Rehearsal DETF";')
s=s.replace('        assertEq(IERC20Metadata(detf).symbol(), "DETF");','''        assertEq(detfInfo.ownerOnlyLiquidity(), restricted, "DETF deployment policy");
        assertEq(IUniswapV4HookLiquidityPolicy(reserveHook).ownerOnlyLiquidity(), restricted, "actual hook policy agrees");
        assertEq(IMultiStepOwnable(reserveHook).owner(), detf, "DETF remains hook administrator");
        assertEq(IERC20Metadata(detf).symbol(), "DETF");''')
for version in [3,4]:
 expr=('SeDeploy.deployUniv3Vault(IUniswapV3StandardExchangeDFPkg(_pin("phase05_stage04_uniswap_v3_standard_exchange_pkg.json", ".uniV3SePkg", true)), pool)' if version==3 else 'SeDeploy.deployUniv4Vault(IUniswapV4StandardExchangeDFPkg(_pin("phase05_stage03_uniswap_v4_standard_exchange_pkg.json", ".uniV4SePkg", true)), key)')
 old='return '+expr+';';new='address vault_ = '+expr+';\n            _activatePositionSe(vault_, pair, other);\n            return vault_;';assert old in s;s=s.replace(old,new)
s=replace(s,'_lifecycle','''    function _lifecycle() internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(reserveHook, 0.1e18);
        vm.prank(detfUser);
        (uint256 bondId,) = detfInfo.bond{gas: TX_GAS}(IERC20(address(pairToken)), 100 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp + 1 hours);
        uint256 mintQuote = detfExchangeIn.previewExchangeIn{gas: TX_GAS}(IERC20(address(pairToken)), 10 ether, IERC20(detf));
        vm.prank(detfUser);
        assertEq(detfExchangeIn.exchangeIn{gas: TX_GAS}(IERC20(address(pairToken)), 10 ether, IERC20(detf), mintQuote, detfUser, false, block.timestamp + 1 hours), mintQuote, "standard purchase quote");
        uint256 burnAmount = mintQuote / 4;
        uint256 burnQuote = detfExchangeIn.previewExchangeIn{gas: TX_GAS}(IERC20(detf), burnAmount, IERC20(address(pairToken)));
        vm.prank(detfUser);
        assertEq(detfExchangeIn.exchangeIn{gas: TX_GAS}(IERC20(detf), burnAmount, IERC20(address(pairToken)), burnQuote, detfUser, false, block.timestamp + 1 hours), burnQuote, "standard reserve exit quote");
        _assertFundedMatureClaim(detf, bondId, detfUser);
        _claimAndCheckFeeBond();
        _checkFeeLpRedemption();
        detfInfo.sweepDust{gas: TX_GAS}();
        assertEq(IERC20(reserveHook).balanceOf(detf), 0, "reserve held in NFT custody");
        for (uint256 i; i < pairs.length; ++i) {
            assertLe(IERC20(pairs[i]).balanceOf(detf), 10, "pair dust");
            assertEq(IERC20(exchanges[i]).allowance(reserveHook, exchanges[i]), 0, "temporary SE allowance cleared");
        }
    }''')
s=replace(s,'_claimAndCheckFeeBond','''    function _claimAndCheckFeeBond() internal {
        IDetfBondNFT nft = IDetfBondNFT(detfInfo.bondNftVault());
        IFeeCollectorProxy collector = IVaultFeeOracleQuery(address(indexedexManager)).feeTo();
        assertEq(nft.ownerOf(1), address(collector), "original standing fee role");
        IStakedDETF receipt = IStakedDETF(detfInfo.rebasingClaimToken());
        uint256 fees = receipt.balanceOf(address(collector));
        assertGt(fees, 0, "standing fees already funded");
        address collectorOwner = IMultiStepOwnable(address(collector)).owner();
        vm.prank(collectorOwner);
        collector.pullFee(IERC20(address(receipt)), fees, detfUser);
        assertEq(receipt.balanceOf(address(collector)), 0, "all displayed fee receipts transferred");
        _assertFundedUnstake(detf, detfUser, fees);
        vm.prank(detfUser);
        detfInfo.bond{gas: TX_GAS}(IERC20(address(pairToken)), 10 ether, DEFAULT_MIN_LOCK, detfUser, false, block.timestamp);
        assertGt(receipt.balanceOf(address(collector)), 0, "new issuance pays standing rights after full prior receipt redemption");
        assertEq(nft.positionOf(1).principal, 0, "standing role is not purchased LP principal");
        assertGe(IERC20(detf).balanceOf(address(receipt)), receipt.totalSupply(), "actual held DETF backs staking");
    }''')
s=replace(s,'_checkProjectedLiquidation','''    function _checkFeeLpRedemption() internal {
        IFeeCollectorProxy collector = IVaultFeeOracleQuery(address(indexedexManager)).feeTo();
        IERC20 lp = IERC20(reserveHook);
        uint256 amount = lp.balanceOf(address(collector)) / 2;
        assertGt(amount, 0, "real accrued fee LP");
        uint256 owned = lp.balanceOf(detfInfo.bondNftVault());
        uint256[] memory quote = IUniswapV4SeBufferHook(reserveHook).previewExitProportional{gas: TX_GAS}(amount);
        address recipient = makeAddr("rehearsal fee redemption");
        address[] memory tokens = IUniswapV4SeBufferHook(reserveHook).tokens();
        vm.prank(IMultiStepOwnable(address(collector)).owner());
        uint256[] memory actual = collector.redeemReserveLiquidity{gas: TX_GAS}(lp, amount, quote, recipient, block.timestamp);
        assertEq(actual, quote, "collector proportional redemption preview");
        for (uint256 i; i < tokens.length; ++i) assertEq(IERC20(tokens[i]).balanceOf(recipient), actual[i], "collector actual settlement");
        assertEq(lp.balanceOf(detfInfo.bondNftVault()), owned, "external fee LP redemption preserves protocol-owned LP");
        assertEq(lp.allowance(address(collector), reserveHook), 0, "collector clears LP approval");
    }

    function _activatePositionSe(address vault_, address pair_, address other_) internal {
        address[] memory tokens_ = new address[](2);
        tokens_[0] = pair_ < other_ ? pair_ : other_;
        tokens_[1] = pair_ < other_ ? other_ : pair_;
        uint256[] memory amounts_ = new uint256[](2);
        for (uint256 i_; i_ < 2; ++i_) {
            amounts_[i_] = 10_000 ether;
            SimpleMintableERC20(tokens_[i_]).mint(address(this), amounts_[i_]);
            IERC20(tokens_[i_]).approve(vault_, amounts_[i_]);
        }
        uint256 quote_ = IStandardExchangeInMulti(vault_).previewExchangeInManyToOne(tokens_, amounts_, IERC20(vault_));
        uint256 actual_ = IStandardExchangeInMulti(vault_).exchangeInManyToOne{gas: TX_GAS}(tokens_, amounts_, IERC20(vault_), quote_, address(this), false, block.timestamp);
        assertGt(actual_, 0, "both tokens activate position SE");
        assertEq(actual_, quote_, "position activation quote");
    }''')
for name,path in [('IStakedDETF','contracts/interfaces/IStakedDETF.sol'),('IDetfBondNFT','contracts/interfaces/IDetfBondNFT.sol'),('IFeeCollectorProxy','contracts/interfaces/proxies/IFeeCollectorProxy.sol'),('IMultiStepOwnable','@crane/contracts/access/ERC8023/IMultiStepOwnable.sol'),('IUniswapV4HookLiquidityPolicy','contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol'),('IStandardExchangeInMulti','contracts/interfaces/IStandardExchangeInMulti.sol')]:
 if '"'+path+'"' not in s:s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {'+name+'} from "'+path+'";')
if '--apply' in sys.argv:p.write_text(s)
else:(ART/'pending-robinhood-funded-rehearsal.sol.txt').write_text(s)
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','scope':'Actual local Robinhood fork rehearsal; no production broadcast or deployment performed by migration. Balancer SE rehearsal retained; no excluded Balancer DETF or deferred Slipstream work.','changes':'9 decimals; native position two-token activation; policy carried to actual hooks with public V4 cases; standard purchase/exit; actual funded mature claim and unstake; actual Fee Collector receives later standing receipts after full prior payout and redeems actual fee LP. Existing transaction gas bounds retained.','file':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()};(ART/('robinhood-funded-rehearsal-migration.json' if '--apply' in sys.argv else 'pending-robinhood-funded-rehearsal-migration.json')).write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
