"""Keep actual donation entrypoints and custody tests; replace retired LP-backed bond expectations."""
from pathlib import Path
import re,json,hashlib,sys
ROOT=Path.cwd();ART=ROOT/'implementation-artifacts/detf-funded-staking';F=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
def span(s,name):
 m=re.search(r'    function '+re.escape(name)+r'\(',s)
 if not m:return None
 a=s.index('{',m.end());j=a+1;n=1
 while n:
  if s[j]=='{':n+=1
  elif s[j]=='}':n-=1
  j+=1
 return m.start(),a,j

def body(s,name,text):
 pos=span(s,name)
 if not pos:return s
 start,a,j=pos
 return s[:a+1]+'\n'+text.strip('\n')+'\n    '+s[j-1:]
B={}
B[1]='''        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lp_ = _donatePair(dnDonor, AMT(10));
        _assertR12aUnassigned(before_, lp_);
        assertEq(IERC20(detf).balanceOf(detfUser), before_.userDetf, "gift cannot pay raw DETF to bonder");
        _assertNoJoinableDust();'''
B[2]='''        _ensureLiveBond();
        IERC20 payment_ = _openPairToken();
        address se_ = IUniswapV4SeBufferHook(detfInfo.hook()).standardExchangeOf(address(payment_));
        _fundOpenPair(dnDonor, AMT(20));
        vm.startPrank(dnDonor);
        payment_.approve(se_, AMT(20));
        uint256 shares_ = IStandardExchangeIn(se_).exchangeIn(payment_, AMT(20), IERC20(se_), 1, dnDonor, false, _deadline());
        vm.stopPrank();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 quote_ = _nftDonate().previewDonate(IERC20(se_), shares_);
        assertGt(quote_, 0, "SE-share donation quote");
        vm.startPrank(dnDonor);
        IERC20(se_).approve(address(_nft()), shares_);
        uint256 lp_ = _nftDonate().donate(IERC20(se_), shares_, quote_, false, _deadline());
        vm.stopPrank();
        assertEq(lp_, quote_, "actual SE-share donation preview");
        _assertR12aUnassigned(before_, lp_);
        _assertNoJoinableDust();'''
B[4]='''        _ensureLiveBond();
        uint256 raw_ = _buyDonationRaw(AMT(10));
        uint256 amount_ = raw_ / 4;
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 quote_ = _nftDonate().previewDonate(IERC20(detf), amount_);
        assertGt(quote_, 0, "self-leg donation preview");
        vm.startPrank(detfUser);
        IERC20(detf).approve(address(_nft()), amount_);
        uint256 lp_ = _nftDonate().donate(IERC20(detf), amount_, quote_, false, _deadline());
        vm.stopPrank();
        assertEq(lp_, quote_, "self-leg donation preview equals execution");
        _assertR12aUnassigned(before_, lp_);
        assertEq(IERC20(detf).balanceOf(detfUser), before_.userDetf - amount_, "donor supplies existing DETF self-leg");'''
B[6]='''        _ensureLiveBond();
        address bob_ = makeAddr("donation second bonder");
        (uint256 bobId_,) = _bondAs(bob_, AMT(80));
        bytes32 bobBefore_ = keccak256(abi.encode(IDetfBondNFT(address(_nft())).positionOf(bobId_)));
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lp_ = _donatePair(dnDonor, AMT(15));
        _assertR12aUnassigned(before_, lp_);
        assertEq(keccak256(abi.encode(IDetfBondNFT(address(_nft())).positionOf(bobId_))), bobBefore_, "gift preserves each funded position independently");
        _assertD2Identity();'''
B[7]='''        _ensureLiveBond();
        IERC20 token_ = _openPairToken();
        uint256 amount_ = AMT(8);
        _fundOpenPair(dnDonor, amount_);
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 quote_ = _nftDonate().previewDonate(token_, amount_);
        vm.startPrank(dnDonor);
        token_.transfer(address(_nft()), amount_);
        vm.recordLogs();
        detfInfo.donate(token_, amount_, true);
        vm.stopPrank();
        Vm.Log[] memory logs_ = vm.getRecordedLogs();
        bool found_;
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(_nft()) || logs_[i_].topics.length != 3 || logs_[i_].topics[0] != keccak256("ReserveDonated(address,address,uint256,uint256)")) continue;
            assertEq(address(uint160(uint256(logs_[i_].topics[1]))), dnDonor, "forwarded event preserves actual donor");
            assertEq(address(uint160(uint256(logs_[i_].topics[2]))), address(token_), "event payment token");
            (uint256 paid_, uint256 lp_) = abi.decode(logs_[i_].data, (uint256,uint256));
            assertEq(paid_, amount_, "whole forwarded payment");
            assertEq(lp_, quote_, "forwarded donation preview");
            _assertR12aUnassigned(before_, lp_);
            found_ = true;
        }
        assertTrue(found_, "canonical NFT donation event emitted");'''
B[9]='''        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        IDetfNftReserveDonation receiver_ = _nftDonate();
        IERC20 lp_ = _lpToken();
        SimpleMintableERC20 junk_ = new SimpleMintableERC20("Junk", "JNK");
        uint256 deadline_ = _deadline();
        address attacker_ = makeAddr("donation no payment");
        vm.expectRevert();
        vm.prank(attacker_);
        receiver_.donate(IERC20(address(junk_)), 1, 0, true, deadline_);
        vm.expectRevert();
        vm.prank(attacker_);
        receiver_.donate(lp_, 1, 0, true, deadline_);
        assertEq(keccak256(abi.encode(_snapLive(dnUserOriginal))), keccak256(abi.encode(before_)), "failed unsupported/pretransferred LP payment cannot change custody or principal");'''
B[10]='''        _ensureLiveBond();
        uint256 amount_ = DONATION_AMOUNT;
        IERC20 token_ = _openPairToken();
        uint256 quote_ = _nftDonate().previewDonate(token_, amount_);
        assertGt(quote_, 0, "supported donation must preview");
        assertEq(quote_, detfInfo.previewJoinDonatedCapital(token_, amount_), "NFT and DETF donation previews agree");
        uint256 lp_ = _donatePair(dnDonor, amount_);
        assertEq(lp_, quote_, "donation preview equals execution");'''
B[12]='''        _ensureLiveBond();
        vm.warp(block.timestamp + 24 * 8 hours);
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lp_ = _donatePair(dnDonor, AMT(6));
        _assertR12aUnassigned(before_, lp_);
        uint256 pending_ = detfInfo.pendingExpansionDetf();
        uint256 backing_ = IERC20(detf).balanceOf(detfInfo.rebasingClaimToken());
        uint256 issued_ = IDETFFundedRewards(detf).synchronizeRewards();
        assertEq(issued_, pending_, "one catch-up mints the pending funded amount");
        assertEq(IERC20(detf).balanceOf(detfInfo.rebasingClaimToken()) - backing_, issued_, "only minted expansion funds staking");
        assertEq(IDETFFundedRewards(detf).synchronizeRewards(), 0, "same boundary cannot mint twice");'''
B[13]='''        _ensureLiveBond();
        uint256 raw_ = _buyDonationRaw(AMT(10));
        _donatePair(dnDonor, AMT(12));
        IDETFFundedRewards(detf).synchronizeRewards();
        uint256 amount_ = raw_ / 3;
        IERC20 payment_ = _openPairToken();
        bool primary_ = detfInfo.isBurningAllowed(payment_);
        uint256 supply_ = IERC20(detf).totalSupply();
        uint256 quote_ = IStandardExchangeIn(detf).previewExchangeIn(IERC20(detf), amount_, payment_);
        uint256 before_ = payment_.balanceOf(detfUser);
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, amount_);
        uint256 actual_ = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), amount_, payment_, quote_, detfUser, false, _deadline());
        vm.stopPrank();
        assertGt(actual_, 0, "exit after donated capital");
        assertEq(actual_, quote_, "post-donation burn preview equals execution");
        assertEq(payment_.balanceOf(detfUser) - before_, actual_, "post-donation actual settlement");
        assertEq(IERC20(detf).totalSupply(), primary_ ? supply_ - amount_ : supply_, "primary burn or existing-inventory swap supply");'''
B[14]='''        _ensureLiveBond();
        address bob_ = makeAddr("donation funded claim");
        (uint256 id_,) = _bondAs(bob_, AMT(60));
        IDetfBondNFT nft_ = IDetfBondNFT(address(_nft()));
        uint256 principal_ = nft_.positionOf(id_).principal;
        _donatePair(dnDonor, AMT(9));
        assertEq(nft_.positionOf(id_).principal, principal_, "reserve gift does not requote principal");
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        uint256 paid_ = _claimFundedDonationPosition(detfInfo, id_, bob_);
        assertGe(paid_, principal_, "mature funded principal plus actual rewards");
        assertEq(nft_.ownerOf(id_), address(0), "final claim retires purchased NFT");'''
B[16]='''        _ensureLiveBond();
        address bob_ = makeAddr("donation last prior holder");
        address carol_ = makeAddr("donation next holder");
        (uint256 bobId_,) = _bondAs(bob_, AMT(40));
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _claimFundedDonationPosition(detfInfo, dnUserBondId, detfUser);
        _claimFundedDonationPosition(detfInfo, bobId_, bob_);
        _donatePair(dnDonor, AMT(20));
        uint256 lp_ = _lpToken().balanceOf(address(_nft())) + _lpToken().balanceOf(detf);
        assertGt(lp_, 0, "all prior claims preserve donated protocol liquidity");
        (, uint256 principal_,,) = detfInfo.previewBond(_openPairToken(), AMT(30), DEFAULT_MIN_LOCK);
        (uint256 nextId_,) = _bondAs(carol_, AMT(30));
        assertEq(IDetfBondNFT(address(_nft())).positionOf(nextId_).principal, principal_, "next bond only receives its quoted funded purchase");
        assertGe(_lpToken().balanceOf(address(_nft())) + _lpToken().balanceOf(detf), lp_, "new bond cannot capture old LP");
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _claimFundedDonationPosition(detfInfo, nextId_, carol_);'''
B[17]='''        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 lp_ = _donatePair(dnDonor, AMT(8));
        _assertR12aUnassigned(before_, lp_);
        _assertD2Identity();'''
B[18]='''        _ensureLiveBond();
        uint256 raw_ = _buyDonationRaw(AMT(10));
        address bob_ = makeAddr("disabled bond owner");
        address carol_ = makeAddr("disabled staking holder");
        (uint256 bobId_,) = _bondAs(bob_, AMT(50));
        (uint256 carolId_,) = _bondAs(carol_, AMT(40));
        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _claimFundedDonationPosition(detfInfo, carolId_, carol_);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(detf, true);
        assertTrue(IVaultRegistryDisableQuery(address(indexedexManager)).isDisabled(detf));
        IERC20 token_ = _openPairToken();
        bytes memory error_ = abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, detf);
        uint256 deadline_ = _deadline();
        vm.startPrank(detfUser);
        vm.expectRevert(error_);
        detfInfo.donate(token_, AMT(1), false);
        vm.expectRevert(error_);
        IStandardExchangeIn(detf).exchangeIn(token_, AMT(1), IERC20(detf), 0, detfUser, false, deadline_);
        vm.expectRevert(error_);
        detfInfo.bond(token_, AMT(1), DEFAULT_MIN_LOCK, detfUser, false, deadline_);
        vm.stopPrank();
        _claimFundedDonationPosition(detfInfo, bobId_, bob_);
        assertGt(_donationUnstake(detfInfo, carol_), 0, "disabled instance retains funded unstaking");
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, raw_ / 4);
        uint256 out_ = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), raw_ / 4, token_, 1, detfUser, false, deadline_);
        vm.stopPrank();
        assertGt(out_, 0, "disabled instance retains reserve exit");'''
B[19]='''        _ensureLiveBond();
        IERC20 token_ = _openPairToken();
        uint256 amount_ = AMT(5);
        uint256 quote_ = _nftDonate().previewDonate(token_, amount_);
        assertGt(quote_, 0, "Permit2 donation preview");
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(dnDonor);
        token_.approve(address(permit2), type(uint256).max);
        IAllowanceTransfer(address(permit2)).approve(address(token_), address(_nft()), type(uint160).max, type(uint48).max);
        uint256 lp_ = _nftDonate().donateWithPermit2Allowance(token_, amount_, quote_, _deadline());
        vm.stopPrank();
        assertEq(lp_, quote_, "allowance donation preview equals execution");
        _assertR12aUnassigned(before_, lp_);'''
B[20]='''        _ensureLiveBond();
        IERC20 token_ = _openPairToken();
        uint256 amount_ = AMT(4);
        uint256 deadline_ = _deadline();
        uint256 quote_ = _nftDonate().previewDonate(token_, amount_);
        assertGt(quote_, 0, "signature donation preview");
        ISignatureTransfer.PermitTransferFrom memory signed_ = ISignatureTransfer.PermitTransferFrom({permitted: ISignatureTransfer.TokenPermissions({token: address(token_), amount: amount_}), nonce: 0, deadline: deadline_});
        bytes memory data_ = abi.encode(signed_, _signPermit2(dnDonorPk, address(token_), amount_, address(_nft()), 0, deadline_));
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        vm.startPrank(dnDonor);
        token_.approve(address(permit2), type(uint256).max);
        uint256 lp_ = _nftDonate().donateWithPermit2Signature(token_, amount_, quote_, deadline_, data_);
        vm.stopPrank();
        assertEq(lp_, quote_, "signature donation preview equals execution");
        _assertR12aUnassigned(before_, lp_);
        IDetfNftReserveDonation receiver_ = _nftDonate();
        bytes32 afterFirst_ = keccak256(abi.encode(_snapLive(dnUserOriginal)));
        vm.expectRevert();
        vm.prank(dnDonor);
        receiver_.donateWithPermit2Signature(token_, amount_, quote_, deadline_, data_);
        assertEq(keccak256(abi.encode(_snapLive(dnUserOriginal))), afterFirst_, "used signature cannot receive another LP credit");'''
B[21]='''        _ensureLiveBond();
        DnLiveSnap memory before_ = _snapLive(dnUserOriginal);
        uint256 first_ = _donatePair(dnDonor, AMT(13));
        _assertD2Identity();
        uint256 second_ = _donatePair(dnDonor, AMT(3));
        _assertR12aUnassigned(before_, first_ + second_);
        _assertD2Identity();'''
# DN22 retains its actual unlock harness and new common custody oracle.
paths=[F/'UniswapV4Detf_ReserveDonationOpenBase.sol',F/'decimals/UniswapV4Detf_ReserveDonationOpenBase_Decimals.sol',F/'pons/UniswapV4Detf_PonsV2Se_Stage11Helpers.sol',F/'pons/decimals/UniswapV4Detf_PonsV2Se_Stage11Helpers_Decimals.sol',F/'pons/UniswapV4Detf_PonsV2Se_ProductLaw.t.sol',F/'pons/decimals/UniswapV4Detf_PonsV2Se_ProductLaw_Decimals.sol',F/'UniswapV4Detf_Stage11OpenSuite.sol',F/'decimals/UniswapV4Detf_Stage11OpenSuite_Decimals.sol',F/'UniswapV4Detf_Quad_ReserveDonation.t.sol']
rows=[]
for p in paths:
 b=p.read_text();s=b;native='decimals' in p.parts and 'pons' not in p.parts
 if 'ReserveDonationOpenBase' in p.name or 'Stage11Helpers' in p.name:
  s=re.sub(r'    struct DnLiveSnap \{.*?\n    \}\n','',s,flags=re.S)
  s=s.replace('_nft().originalSharesOf(dnUserBondId)','IDetfBondNFT(address(_nft())).positionOf(dnUserBondId).principal')
  s=body(s,'_snapLive','        orig_;\n        return _fundedDonationSnapshot(detfInfo, dnUserBondId, detfUser);')
  s=body(s,'_assertR12aUnassigned','        _assertFundedDonationOnly(detfInfo, dnUserBondId, detfUser, before_, lpOut_);')
  s=body(s,'_assertD2Identity','        _assertDonationStanding(detfInfo, address(indexedexManager));')
  # Inherited tests keep their actual provider and native-unit funding helpers.
  buy='''
    function _buyDonationRaw(uint256 amount_) internal returns (uint256 out_) {
        IERC20 token_ = _openPairToken();
        _fundOpenPair(detfUser, amount_);
        uint256 quote_ = IStandardExchangeIn(detf).previewExchangeIn(token_, amount_, IERC20(detf));
        vm.startPrank(detfUser);
        token_.approve(detf, amount_);
        out_ = IStandardExchangeIn(detf).exchangeIn(token_, amount_, IERC20(detf), quote_, detfUser, false, _deadline());
        vm.stopPrank();
        assertEq(out_, quote_, "actual standard acquisition for self-leg or burn");
        assertGt(out_, 0, "actual acquired DETF");
    }
'''
  s=s[:s.rfind('}')]+buy+s[s.rfind('}'):]
  s=re.sub(r'(abstract contract \w+ is [^{]+) \{',r'\1, V4FundedDonationAssertions {',s,count=1)
 if 'ReserveDonationOpenBase' in p.name:
  s=body(s,'_d10SellToClaim','        return _claimFundedDonationPosition(detfInfo, tokenId_, seller_);')
  s=body(s,'_assertCloseBurnRedeem','''        _claimFundedDonationPosition(detfInfo, bobId_, bob_);
        _donationUnstake(detfInfo, carol_);
        IERC20 token_ = _openPairToken();
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, aliceDetf_ / 4);
        uint256 paid_ = IStandardExchangeIn(detf).exchangeIn(IERC20(detf), aliceDetf_ / 4, token_, 1, detfUser, false, _deadline());
        vm.stopPrank();
        assertGt(paid_, 0, "reserve exit while disabled");''')
 for m in list(re.finditer(r'    function (test_DN(\d+)_\w+)\(',s))[::-1]:
  n=int(m[2]);name=m[1]
  if n not in B:continue
  t=B[n]
  amt=lambda n: '_uPair('+n+')' if native else n+' ether'
  t=re.sub(r'AMT\((\d+)\)',lambda m:amt(m[1]),t)
  t=t.replace('DONATION_AMOUNT',('_dnDonateAmt('+amt('7')+')') if 'pons' not in p.parts else amt('7'))
  s=body(s,name,t)
 # Existing test IDs retain continuity; descriptions now state the funded model.
 descriptions={1:'Pair donation increases protocol LP without changing funded positions.',2:'Actual SE shares become protocol LP while funded staking remains separate.',4:'Existing raw DETF can fund the reserve self-leg without new issuance.',6:'Reserve gifts preserve both funded positions and standing rewards.',7:'Forwarded donation identifies the original EOA and exact received LP.',9:'Unsupported and unreceived LP payments cannot create credit.',10:'Supported donation preview equals the actual issued LP.',12:'Reserve gifts preserve funded stake; catch-up distributes only newly minted DETF.',13:'Standard reserve exit still executes after donated liquidity.',14:'Mature funded bond claims retain donated protocol LP.',16:'After all prior claims, a new bond receives only its funded purchase.',17:'Donations preserve standing weights and actual backing.',18:'Disabled instances reject funding but retain funded claims and reserve exits.',19:'Actual Permit2 allowance donation with exact preview and custody.',20:'Actual Permit2 signature donation, exact preview, and replay rejection.',21:'Repeated reserve gifts leave standing staking rights unchanged.'}
 for n,description in descriptions.items():
  s=re.sub(r'    /// @notice[^\n]*\n(    function test_DN'+str(n)+r'_)','    /// @notice '+description+'\n'+r'\1',s)
 # Direct calls are retained only for current standard, funded NFT and actual hook interfaces.
 if s!=b:
  imports={'IStakedDETF, IDETFFundedRewards':'contracts/interfaces/IStakedDETF.sol','IDetfBondNFT':'contracts/interfaces/IDetfBondNFT.sol','DETFFundedStakingMath':'contracts/vaults/detf/common/core/DETFFundedStakingMath.sol','Math':'@crane/contracts/utils/Math.sol','Vm':'forge-std/Vm.sol'}
  if p==paths[0]:imports['Test']='forge-std/Test.sol'
  if p!=paths[0] and ('ReserveDonationOpenBase' in p.name or 'Stage11Helpers' in p.name):imports['V4FundedDonationAssertions']=str(paths[0].relative_to(ROOT))
  for names,path in imports.items():
   if names=='V4FundedDonationAssertions' or '"'+path+'"' not in s:s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {'+names+'} from "'+path+'";')
  if p==paths[0]:
   extra=(ART/'pending-v4-funded-donation-assertions.txt').read_text().replace('p_.gons','p_.stakingGons').replace('quote_.principal,','quote_.principalDue,').replace('quote_.rewards,','quote_.rewardsDue,')
   at=s.index('/// @notice Stage 11');s=s[:at]+extra+'\n'+s[at:]
  rows.append((p,b,s))
for p,b,s in rows:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-funded-donation-'+p.name+'.txt')).write_text(s)
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','coverage':'Retains all donation route/security/Permit2/unlock/provider IDs. Shared actual funded principal/gons/backing/standing/custody assertions replace LP-backed NAV. Mature claims retain all protocol LP; new bond receives only its quoted funded allocation. Preview checks no longer swallow failures or use percentage tolerances.','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in rows]}
(ART/('v4-funded-donation-migration.json' if '--apply' in sys.argv else 'pending-v4-funded-donation-migration.json')).write_text(json.dumps(r,indent=2)+'\n');print(r['status'],len(rows))
