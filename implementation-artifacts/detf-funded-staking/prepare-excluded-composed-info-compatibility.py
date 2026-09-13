from pathlib import Path
import re,json,hashlib
art=Path('implementation-artifacts/detf-funded-staking');root=Path('contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common');path=root/'TestBase_ComposedStableCommonDetf_Components.sol'
source=root/'IComposedStableCommonDetfInfo.sol';old=(Path('/private/tmp/indexedex-detf-funded-staking-20260906')/source).read_text();current=source.read_text();names=set(re.findall(r'function (\w+)\(',current));decls=[d for d in re.findall(r'function\s+\w+\([^;]+;',old,re.S) if re.search(r'function (\w+)',d).group(1) not in names]
s=path.read_text();before=s;name='ILegacyComposedStableCommonDetfInfo';assert 'interface '+name not in s
imports='import {IComposedStableCommonDetfInfo} from "'+str(source)+'";\nimport {ThresholdMode} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";\n\n'
interface='/// @dev Historical test declarations only; production interface IDs and selectors are unchanged.\ninterface '+name+' is IComposedStableCommonDetfInfo {\n    '+'\n    '.join(decls)+'\n}\n\n'
s=s.replace('contract RebasingDETFTokenPricingHarness',imports+interface+'contract RebasingDETFTokenPricingHarness',1);path.write_text(s);changes=[str(path)]
methods=[re.search(r'function (\w+)',d).group(1) for d in decls]
for f in Path('test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common').rglob('*.sol'):
 s=f.read_text();before=s
 if not any('.'+m in s for m in methods):continue
 s=re.sub(r'import\s*\{\s*IComposedStableCommonDetfInfo\s*\}\s*from\s*[\'\"][^\'\"]+[\'\"];', 'import {'+name+' as IComposedStableCommonDetfInfo} from "'+str(path)+'";',s)
 if s!=before:f.write_text(s);changes.append(str(f))
(art/'excluded-composed-info-test-compatibility.json').write_text(json.dumps({'scope':'D60 test declaration compilation maintenance; original assertions retained','files':changes,'validation':'pending default full build'},indent=2)+'\n')
print('Updated historical Composed info declarations in',len(changes),'files')
