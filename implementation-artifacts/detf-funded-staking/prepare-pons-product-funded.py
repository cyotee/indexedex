from pathlib import Path
import re,json,hashlib,sys
R=Path.cwd();A=R/'implementation-artifacts/detf-funded-staking';pons=R/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons';records=[]
def replace(s,name,body):
 m=re.search(r'    function '+re.escape(name)+r'\(',s);assert m,name
 a=s.index('{',m.end());j=a+1;n=1
 while n:
  if s[j]=='{':n+=1
  elif s[j]=='}':n-=1
  j+=1
 return s[:m.start()]+body+s[j:]
for suffix in ['', '_Decimals']:
 p=(pons/('decimals' if suffix else ''))/('UniswapV4Detf_PonsV2Se_ProductLaw'+suffix+('.sol' if suffix else '.t.sol'));b=p.read_text();s=b
 s=replace(s,'test_preMaturity_sell_reverts','''    function test_principalVestsLinearlyWhileStaked() public {
        (uint256 id_,) = _firstBond(100 ether);
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        uint256 owned_ = IERC20(reserveHook).balanceOf(address(nft_));
        vm.prank(detfUser);
        assertEq(nft_.claimPrincipal(id_, detfUser), 0, "no principal elapsed at purchase");
        vm.warp(position_.startTimestamp + position_.vestingDuration / 2);
        IDETFFundedRewards(detf).synchronizeRewards();
        IERC20 staking_ = IERC20(detfInfo.rebasingClaimToken());
        uint256 before_ = staking_.balanceOf(detfUser);
        uint256 rewards_ = nft_.previewClaim(id_).rewardsDue;
        vm.prank(detfUser);
        uint256 paid_ = nft_.claimPrincipal(id_, detfUser);
        assertEq(paid_, position_.principal / 2, "halfway linear principal");
        assertEq(staking_.balanceOf(detfUser) - before_, paid_, "principal paid only as sDETF");
        assertEq(nft_.previewClaim(id_).rewardsDue, rewards_, "separate rewards remain claimable");
        assertEq(nft_.positionOf(id_).claimedPrincipal, paid_);
        assertEq(IERC20(reserveHook).balanceOf(address(nft_)), owned_, "vesting never consumes protocol LP");
    }''')
 s=replace(s,'test_postMaturity_sell_mintsRebasingClaim','''    function test_matureBondPaysFundedStakingAndRetainsLiquidity() public {
        _firstBond(100 ether);
        (uint256 id_,) = _firstBond(40 ether);
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        uint256 principal_ = nft_.positionOf(id_).principal;
        _warpMature(id_);
        IDETFFundedRewards(detf).synchronizeRewards();
        uint256 rewards_ = nft_.previewClaim(id_).rewardsDue;
        uint256 supply_ = IERC20(detf).totalSupply();
        (uint256 paidPrincipal_, uint256 paid_) = _d10SellToClaimOn(detf, id_, detfUser);
        assertEq(paidPrincipal_, principal_, "fixed funded purchase");
        assertEq(paid_, principal_ + rewards_, "already funded principal and rewards");
        assertEq(IERC20(detf).totalSupply(), supply_, "claim mints no DETF");
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, id_));
        nft_.ownerOf(id_);
    }''')
 s=replace(s,'test_claimRewards_whileLocked','''    function test_claimRewards_whileLocked() public {
        _setPfc(detf);
        (uint256 id_,) = _firstBond(100 ether);
        _firstBond(10 ether); // Actual funded issuance rewards the existing staked purchase.
        IDetfBondNFT nft_ = IDetfBondNFT(detfInfo.bondNftVault());
        DETFFundedStakingMath.BondPosition memory position_ = nft_.positionOf(id_);
        assertLt(block.timestamp, position_.startTimestamp + position_.vestingDuration);
        uint256 rewards_ = nft_.previewClaim(id_).rewardsDue;
        assertGt(rewards_, 0, "funded growth while locked");
        IERC20 staking_ = IERC20(detfInfo.rebasingClaimToken());
        uint256 before_ = staking_.balanceOf(detfUser);
        uint256 rawBefore_ = IERC20(detf).balanceOf(detfUser);
        vm.prank(detfUser);
        uint256 paid_ = nft_.claimRewards(id_, detfUser);
        assertEq(paid_, rewards_);
        assertEq(staking_.balanceOf(detfUser) - before_, paid_, "rewards paid as sDETF");
        assertEq(IERC20(detf).balanceOf(detfUser), rawBefore_);
        assertEq(nft_.positionOf(id_).claimedPrincipal, 0, "no principal claimed");
        assertEq(nft_.previewClaim(id_).rewardsDue, 0, "no second reward claim");
    }''')
 s=s.replace('uint256 preview_ = claim_.previewRedeem(redeem_);','uint256 preview_ = IStandardExchangeIn(address(claim_)).previewExchangeIn(IERC20(address(claim_)), redeem_, IERC20(detf));')
 s=replace(s,'test_D15_redeem_paysDetf_only','')
 s=replace(s,'test_compound_raises_protocolLp','''    function test_issuanceFundsStakingImmediatelyAndSettlementDoesNotJoinLp() public {
        _assert_compound_raises_protocolLp(_deployOpenLive());
    }''')
 s=replace(s,'test_open_never_expands','''    function test_mandatoryPolicyWithoutFundedPremiumDoesNotExpand() public {
        _assert_open_never_expands(_deployOpenLive());
    }''')
 for name,path in [('IDETFFundedRewards','contracts/interfaces/IStakedDETF.sol'),('IERC721Errors','@crane/contracts/interfaces/IERC721Errors.sol')]:
  if name=='IDETFFundedRewards':s=s.replace('import {IStakedDETF}', 'import {IStakedDETF, IDETFFundedRewards}')
  else:s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {'+name+'} from "'+path+'";')
 records.append({'path':str(p.relative_to(R)),'before':hashlib.sha256(b.encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest()})
 if '--apply' in sys.argv:p.write_text(s)
 else:(A/('pending-funded-product-'+p.name+'.txt')).write_text(s)
(A/('pons-product-funded-migration.json' if '--apply' in sys.argv else 'pending-pons-product-funded-migration.json')).write_text(json.dumps({'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':records,'mapping':'Pons pre-maturity sale rejection replaced by half-duration principal claim retaining independent rewards; old mature sale replaced by funded payout/NFT retirement/custody conservation; locked staking rewards paid as sDETF; standard one-to-one unstake; duplicate D15 paid-DETF test consolidated into D15_8 and D15_1; old compound/Open replaced by shared immediate funding and mandatory-premium policy assertions.'},indent=2)+'\n')
print(len(records),'files prepared' if '--apply' not in sys.argv else 'files applied')
