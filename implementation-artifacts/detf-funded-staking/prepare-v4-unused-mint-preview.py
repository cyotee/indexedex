from pathlib import Path
import json,hashlib,sys
R=Path.cwd();A=R/'implementation-artifacts/detf-funded-staking';root=R/'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf';rows=[]
p=root/'UniswapV4DetfTarget.sol';b=p.read_text();s=b;a=s.index('    function _entryPreviewMint(');z=s.index('    function _entryPeekPairEq(',a);body=s[a:z]
body=body.replace('returns (uint256 grossDetf, uint256 userDetf, uint256 lpOut)','returns (uint256 grossDetf, uint256 userDetf)').replace('return (0, 0, 0);','return (0, 0);').replace('return (0, userDetf, 0);','return (0, userDetf);')
x=body.index('        address share_ = address(v_);');y=body.index('        grossDetf = _quoteMintGross',x);body=body[:x]+body[y:]
s=s[:a]+body+s[z:];s=s.replace('(, amountOut_,) = _entryPreviewMint','(, amountOut_) = _entryPreviewMint')
files={p:s};p=root/'UniswapV4DetfQueryTarget.sol';s=p.read_text().replace('(uint256 gross_,,) = _entryPreviewMint','(uint256 gross_,) = _entryPreviewMint');files[p]=s
for p,s in files.items():
 b=p.read_text();assert s!=b;rows.append({'path':str(p.relative_to(R)),'before':hashlib.sha256(b.encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest()})
 if '--apply' in sys.argv:p.write_text(s)
 else:(A/('pending-unused-preview-'+p.name+'.txt')).write_text(s)
(A/('v4-unused-mint-preview-cleanup.json' if '--apply' in sys.argv else 'pending-v4-unused-mint-preview-cleanup.json')).write_text(json.dumps({'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':rows,'reason':'All internal callers consume only gross issuance and/or the final user amount. Remove the discarded hypothetical SE mint and LP join preview left over from the retired standalone mint preview. Existing pair valuation, branch selection, family issuance curve and fee split remain unchanged. No storage/close-configuration fields are touched.'},indent=2)+'\n');print(len(rows),'files applied' if '--apply' in sys.argv else 'files prepared')
