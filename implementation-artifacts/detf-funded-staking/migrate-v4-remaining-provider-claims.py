from pathlib import Path
import re,json,hashlib,sys
ROOT=Path.cwd();ART=ROOT/'implementation-artifacts/detf-funded-staking';F=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
def span(s,name):
 m=re.search(r'    function '+re.escape(name)+r'\(',s);assert m
 a=s.index('{',m.end());j=a+1;n=1
 while n:
  if s[j]=='{':n+=1
  elif s[j]=='}':n-=1
  j+=1
 return m.start(),a,j
rows=[]
for p in [F/'pons/UniswapV4Detf_PonsV2Se.t.sol',F/'pons/decimals/UniswapV4Detf_PonsV2Se_Lifecycle_Decimals.sol']:
 b=p.read_text();s=b
 s=re.sub(r'(contract \w+ is [^{]+) \{',r'\1, V4FundedDonationAssertions {',s,count=1)
 s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {V4FundedDonationAssertions} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";')
 i,a,j=span(s,'test_H_CP_P2_close');t=s[i:j];cut=t.index('        address[] memory toks =')
 t=t[:cut]+'''        vm.warp(block.timestamp + DEFAULT_MIN_LOCK + 1);
        _assertSeAllowancesZero();
        _claimFundedDonationPosition(detfInfo, tokenId, detfUser);
        assertGt(_donationUnstake(detfInfo, detfUser), 0, "actual funded unstake");
        _assertR19();
        _assertSeAllowancesZero();
    }''';s=s[:i]+t+s[j:]
 s=s.replace('uint256 supplyBefore = IERC20(detf).totalSupply();','uint256 supplyBefore = IERC20(detf).totalSupply();\n        bool primary_ = detfInfo.isBurningAllowed(IERC20(mintToken));')
 s=s.replace('assertEq(IERC20(detf).totalSupply(), supplyBefore - burnIn, "DETF supply");','assertEq(IERC20(detf).totalSupply(), primary_ ? supplyBefore - burnIn : supplyBefore, "selected burn or swap branch supply");')
 rows.append((p,b,s))
p=F/'prod-se/UniswapV4Detf_Weighted_MorphoBlueSe.t.sol';b=p.read_text();s=b;i,a,j=span(s,'test_claimAfterMatureClose_clearsSeAllowances');t=s[i:j];cut=t.index('        vm.warp(')
t=t[:cut]+'''        _assertFundedMatureClaim(detf, bondId, detfUser);
        _assertSeAllowancesZero();
    }''';s=s[:i]+t+s[j:];rows.append((p,b,s))
for p,b,s in rows:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-provider-funded-claim-'+p.name+'.txt')).write_text(s)
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','coverage':'Pons native and payment-decimal fixtures use shared actual funded claim/unstake/custody controls, retain real reserve/SE allowance checks and branch-aware burn supply. Weighted Morpho lifecycle uses gold funded mature-claim helper with actual prior mint/burn retained.','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in rows]};(ART/('v4-remaining-provider-claim-migration.json' if '--apply' in sys.argv else 'pending-v4-remaining-provider-claim-migration.json')).write_text(json.dumps(r,indent=2)+'\n');print(r['status'],len(rows))
