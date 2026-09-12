from pathlib import Path
import re,json,hashlib,sys
ROOT=Path.cwd();ART=ROOT/'implementation-artifacts/detf-funded-staking';F=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
def remove(s,name):
 m=re.search(r'    function '+re.escape(name)+r'\(',s)
 if not m:return s
 a=s.index('{',m.end());j=a+1;n=1
 while n:
  if s[j]=='{':n+=1
  elif s[j]=='}':n-=1
  j+=1
 return s[:m.start()]+s[j:]
hooks='''
    function _fundedFeeSubject() internal view override returns (IUniswapV4Detf) { return detfInfo; }
    function _fundedFeeOracle() internal view override returns (address) { return address(indexedexManager); }
    function _fundedFeeAdmin() internal view override returns (address) { return owner; }
    function _fundedFeeBoot() internal override returns (uint256 id_) { (id_,) = _bootAlice(20 ether); }
    function _fundedFeeBond(address d_, uint256 amount_) internal override returns (uint256, uint256) { return _bondOn(d_, bob, amount_); }
    function _fundedFeeLead(address) internal view override returns (IERC20) { return IERC20(launchToken); }
    function _fundedFeeUnits(uint256 whole_) internal pure override returns (uint256) { return whole_ * 1 ether; }
    function _fundedFeeLock() internal pure override returns (uint256) { return DEFAULT_MIN_LOCK; }
    function _fundedFeeDeploy(address creator_) internal override returns (address d_) {
        IUniswapV4Detf.PkgArgs memory args_ = _openArgsPolicy();
        args_.creator = creator_;
        d_ = _deployTagged(args_, string.concat("funded-fc", _nextTag()));
        _setPfc(d_); _setFeeOraclePfc(d_); _setBondTermsOn(d_);
    }
'''
rows=[]
for suffix,folder in [('',F/'pons'),('_Decimals',F/'pons/decimals')]:
 p=folder/('UniswapV4Detf_PonsV2Se_Stage11Helpers'+suffix+'.sol');b=p.read_text();s=b
 s=re.sub(r'(abstract contract \w+ is [^{]+) \{',r'\1, V4FundedFeeBehavior {',s,count=1)
 s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {V4FundedFeeBehavior} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_FeeCreatorClaimBase.sol";')
 s=s[:s.rfind('}')]+hooks+s[s.rfind('}'):];rows.append((p,b,s))
 for name in ['Policy','ProductLaw']:
  p=folder/('UniswapV4Detf_PonsV2Se_'+name+suffix+('.sol' if suffix else '.t.sol'));b=p.read_text();s=b
  for f in re.findall(r'function (_assertFC\d+)\(',s):s=remove(s,f)
  s=s.replace('assertEq(uint8(info.thresholdMode()), uint8(ThresholdMode.Policy), "Policy");','assertEq(info.mintThreshold(), POLICY_MINT_THRESHOLD, "mandatory mint threshold");\n        assertEq(info.burnThreshold(), POLICY_BURN_THRESHOLD, "mandatory burn threshold");')
  if s!=b:rows.append((p,b,s))
for p,b,s in rows:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-pons-funded-fee-'+p.name+'.txt')).write_text(s)
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','coverage':'Pons ProductLaw and Policy now inherit the same six independent funded fee tests as other reserve/provider fixtures, restoring current coverage after retired wrappers were consolidated. Removes unused twelve-case legacy helper copies; actual Pons deployment and token funding retained.','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in rows]};(ART/('v4-pons-funded-fee-migration.json' if '--apply' in sys.argv else 'pending-v4-pons-funded-fee-migration.json')).write_text(json.dumps(r,indent=2)+'\n');print(r['status'],len(rows))
