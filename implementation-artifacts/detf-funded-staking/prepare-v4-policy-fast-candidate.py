"""Try the already observed 2.2-WAD opening before the existing bounded fixture search."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];ART=Path(__file__).resolve().parent
folder=ROOT/'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf';records=[]
for suffix in ['', '_Decimals']:
 p=folder/('TestBase_UniswapV4Detf_Policy'+suffix+'.sol');b=p.read_text();s=b
 old='''        for (uint256 i; i < LAUNCH_RICH_MAX_STEPS; ++i) {
            IUniswapV4Detf.PkgArgs memory args = d31_ ? _policyD31Args() : _policyArgs();'''
 new='''        // This price already opens the primary gate in the gold fixtures.
        // Keep all original candidates as a fallback for distinct provider bindings.
        for (uint256 i; i <= LAUNCH_RICH_MAX_STEPS; ++i) {
            wad = i == 0 ? 2.2e18 : LAUNCH_RICH_START + (i - 1) * LAUNCH_RICH_STEP;
            IUniswapV4Detf.PkgArgs memory args = d31_ ? _policyD31Args() : _policyArgs();'''
 assert old in s,p;s=s.replace(old,new)
 old='''            wad += LAUNCH_RICH_STEP;
        }
        launchRichOpeningWad = wad - LAUNCH_RICH_STEP;'''
 new='''        }
        launchRichOpeningWad = wad;'''
 assert old in s,p;s=s.replace(old,new)
 records.append((p,b,s))
for p,b,s in records:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-fast-'+p.name+'.txt')).write_text(s)
r={'status':'applied; equivalent-policy validation and comparable warm timing pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged',
 'change':'First try the already observed 2.2-WAD price, then every original 1.1-to-2.25 candidate if needed. No synthetic price, funded input, oracle state, gas budget or assertion fabricated. Production code unchanged.',
 'measurement':'Capture the same Weighted/Quad policy selection on the source immediately before and after applying. Historical 44-case run confirms behavior but includes unrelated cases, so do not compare its entire command time as a policy-only speedup.',
 'files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in records]}
(ART/('v4-policy-fast-candidate.json' if '--apply' in sys.argv else 'pending-v4-policy-fast-candidate.json')).write_text(json.dumps(r,indent=2)+'\n')
print(r['status'])
