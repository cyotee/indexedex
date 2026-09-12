"""Consolidate J1-J3 controls without restoring retired production selectors."""
from pathlib import Path
import hashlib,json,sys
ROOT=Path(__file__).resolve().parents[2];ART=Path(__file__).resolve().parent
folder=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
common=(ART/'pending-v4-surface-behavior.txt').read_text().replace('previewStakingGonsPerUnit(), 0','previewStakingGonsPerUnit(payment_, 1 ether), 0')
records=[]
for family in ('','Weighted','Orbital'):
 cls='Adversarial_Surface' if not family else f'UniswapV4Detf_{family}_Adversarial_Surface'
 base='TestBase_UniswapV4Detf_Adversarial' if not family else f'TestBase_UniswapV4Detf_{family}_Adversarial'
 p=folder/('adversarial/Adversarial_Surface.t.sol' if not family else cls+'.t.sol')
 before=p.read_text()
 if not family:s=common
 else:s=f'''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{IERC20}} from "@crane/contracts/interfaces/IERC20.sol";
import {{IFacet}} from "@crane/contracts/interfaces/IFacet.sol";
import {{IUniswapV4Detf}} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {{{base}}} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/{base}.sol";
import {{V4FundedSurfaceBehavior}} from "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_Surface.t.sol";
'''
 s+=f'''\ncontract {cls} is {base}, V4FundedSurfaceBehavior {{
    function _surfaceSubject() internal view override returns (IUniswapV4Detf) {{ return detfInfo; }}
    function _surfaceFacets() internal view override returns (IFacet[5] memory) {{ return detfProductFacets; }}
    function _surfaceSeed() internal override {{ _goLive(500 ether); }}
    function _surfaceMint() internal override returns (uint256) {{ return _mintPairTo(detf, detfUser, 25 ether); }}
    function _surfaceBuyer() internal view override returns (address) {{ return detfUser; }}
    function _surfaceAttacker() internal view override returns (address) {{ return attacker; }}
    function _surfacePayment() internal view override returns (IERC20) {{ return IERC20(address(pairToken)); }}
}}
'''
 records.append((p,before,s))
for p,b,s in records:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-funded-'+p.name+'.txt')).write_text(s)
record={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()} for p,b,s in records],'coverage_mapping':{'J1':'Reviewed 48 current interface selectors occur exactly once in the actual product facet union. Removed controls replaced by current funded/SY/policy methods.','J2':'Each of the four real bindings routes every current selector to its exact facet; eleven retired aliases are absent. Quad retains its existing separate hook join-surface test.','J3':'Current getters, standard input/output, funded previews and reward maintenance execute through actual proxies; zero input and retained privileged callbacks reject unauthorized callers.'},'scope_note':'Inert closeRoutes/closeRouteMode getters remain in expected controls while their separately rejected cleanup is pending approval. No production selectors added or removed.'}
(ART/('v4-surface-test-consolidation.json' if '--apply' in sys.argv else 'pending-v4-surface-test-consolidation.json')).write_text(json.dumps(record,indent=2)+'\n')
print(record['status'])
