from pathlib import Path
import re,json,hashlib,sys
ROOT=Path.cwd();ART=ROOT/'implementation-artifacts/detf-funded-staking';F=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
def span(s,name):
 m=re.search(r'    function '+re.escape(name)+r'\(',s);assert m,name
 a=s.index('{',m.end());j=a+1;n=1
 while n:
  if s[j]=='{':n+=1
  elif s[j]=='}':n-=1
  j+=1
 return m.start(),a,j
rows=[]
for p in [F/'UniswapV4Detf_IoTables.t.sol',F/'decimals/UniswapV4Detf_IoTables_Decimals.sol',F/'UniswapV4Detf_Quad.t.sol']:
 b=p.read_text();s=b
 if 'IoTables' in p.name:
  i,a,j=span(s,'test_T7_11_customClose_leftoverOwnerSwap');t=s[i:j];cut=t.index('        address[] memory toks_ =')
  t=t[:cut]+'''        _assertFundedMatureClaim(custom_, tokenId, detfUser);
    }''';s=s[:i]+t+s[j:]
  s=s.replace('/// @notice T7.11: Custom close length 1. Calls `closeBondMature`. Leftovers `ownerSwapExactIn` in `tokens()` order.','/// @notice T7.11: Retained configuration cannot alter funded sDETF claims or release protocol LP.')
 else:
  i,a,j=span(s,'test_T8_3_customClose_onePair');t=s[i:j];cut=t.index('        vm.warp(')
  t=t[:cut]+'''        _assertFundedMatureClaim(customDetf, tokenId, detfUser);
    }''';s=s[:i]+t+s[j:]
  i,a,j=span(s,'test_E6_customClose_doesNotSwapPriorPairInventory');t=s[i:j];cut=t.index('        uint256 checkpoint =')
  t=t[:cut]+'''        IDETFFundedRewards(address(info)).synchronizeRewards();
        IDetfBondNFT nft_ = IDetfBondNFT(info.bondNftVault());
        uint256 checkpoint_ = vm.snapshotState();
        vm.prank(detfUser);
        (uint256 cleanPrincipal_, uint256 cleanRewards_) = nft_.claimBond(tokenId, detfUser);
        assertTrue(vm.revertToState(checkpoint_));
        address donor_ = makeAddr("unrelatedQuadInventoryDonor");
        pair1.mint(donor_, 10 ether);
        vm.prank(donor_);
        pair1.transfer(address(info), 10 ether);
        IStakedDETF receipt_ = IStakedDETF(info.rebasingClaimToken());
        uint256 before_ = receipt_.balanceOf(detfUser);
        uint256 pairBefore_ = pair0.balanceOf(detfUser);
        uint256 lpBefore_ = IERC20(info.hook()).balanceOf(address(nft_));
        vm.prank(detfUser);
        (uint256 principal_, uint256 rewards_) = nft_.claimBond(tokenId, detfUser);
        assertEq(principal_, cleanPrincipal_, "unrelated reserve gift cannot inflate funded principal");
        assertEq(rewards_, cleanRewards_, "unallocated inventory is not staking income");
        assertEq(receipt_.balanceOf(detfUser) - before_, principal_ + rewards_, "only funded sDETF paid");
        assertEq(pair0.balanceOf(detfUser), pairBefore_, "no unrelated settlement payout");
        assertGe(pair1.balanceOf(address(info)), 10 ether, "gift retained by protocol");
        assertEq(IERC20(info.hook()).balanceOf(address(nft_)), lpBefore_, "protocol LP retained");
    }''';s=s[:i]+t+s[j:]
  s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";\nimport {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";')
 rows.append((p,b,s))
# CROPS duplicates the migrated DN18 disabled funding and three exit routes.
for p in [F/'pons/UniswapV4Detf_PonsV2Se_ProductLaw.t.sol',F/'pons/decimals/UniswapV4Detf_PonsV2Se_ProductLaw_Decimals.sol']:
 b=p.read_text();s=b;i,a,j=span(s,'test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork');s=s[:i]+s[j:];rows.append((p,b,s))
for p,b,s in rows:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-custom-funded-claim-'+p.name+'.txt')).write_text(s)
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','coverage':'Custom configuration remains pending A30; funded mature claims and actual reserve custody replace obsolete basket exits. Quad E6 compares actual clean funded payouts with unrelated actual pair inventory. Duplicate Pons CROPS disabled-route cases consolidated into DN18, retaining claims, unstake, burn and inbound rejection.','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in rows]};(ART/('v4-custom-funded-claim-migration.json' if '--apply' in sys.argv else 'pending-v4-custom-funded-claim-migration.json')).write_text(json.dumps(r,indent=2)+'\n');print(r['status'],len(rows))
