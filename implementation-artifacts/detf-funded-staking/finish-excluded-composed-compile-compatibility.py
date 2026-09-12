from pathlib import Path
import re,json,hashlib
art=Path('implementation-artifacts/detf-funded-staking');root=Path('contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common');changes=[]
f=root/'ComposedStableCommonDetf_Component_FactoryService.sol';s=f.read_text();before=s
s=s.replace('\npkgInit_.','\n        pkgInit_.').replace('\npkgArgs_.','\n        pkgArgs_.');f.write_text(s)
changes.append({'path':str(f),'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
f=root/'RebasingDETFTokenTarget.sol';s=f.read_text();before=s
old=(Path('/private/tmp/indexedex-detf-funded-staking-20260906')/'contracts/interfaces/IComposedStableCommonDetfBonding.sol').read_text();curr=Path('contracts/interfaces/IComposedStableCommonDetfBonding.sol').read_text();names=set(re.findall(r'function (\w+)\(',curr));decls=[d for d in re.findall(r'function\s+\w+\([^;]+;',old,re.S) if re.search(r'function (\w+)',d).group(1) not in names]
legacy='ILegacyComposedStableCommonDetfBonding';pos=s.index('contract RebasingDETFTokenTarget')
assert 'interface '+legacy not in s
s=s[:pos]+'/// @dev D60: historical callee declarations for the excluded token; no new proxy selectors.\ninterface '+legacy+' is IComposedStableCommonDetfBonding {\n    '+'\n    '.join(decls)+'\n}\n\n'+s[pos:]
s=s.replace('IComposedStableCommonDetfBonding(address(layoutStruct_.detf))',legacy+'(address(layoutStruct_.detf))');f.write_text(s);changes.append({'path':str(f),'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
for row in json.loads((art/'excluded-stale-test-package-inputs.json').read_text()):
 f=Path(row['path']);s=f.read_text();before=s
 if '/stable/' in str(f) or 'ComposedStableMatrix' in f.name:continue
 s=re.sub(r'^\s*\w+\.(thresholdMode|expansionCatchUpMaxSeconds|expansionCatchUpCapBps)\s*=[^\n]*\n','\n',s,flags=re.M)
 s=re.sub(r'^\s*(thresholdMode|expansionCatchUpMaxSeconds|expansionCatchUpCapBps):[^\n]*\n','\n',s,flags=re.M)
 if s!=before:f.write_text(s);changes.append({'path':str(f),'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
(art/'excluded-composed-compile-compatibility.json').write_text(json.dumps({'scope':'D60 compilation maintenance only. Legacy Composed callee signatures retained separately; historical factory builders populate surviving inputs only and do not implement missing launch functionality. Single/Multi test input assignments updated for existing argument types.','files':changes,'validation':'pending default full build'},indent=2)+'\n')
print('Compilation compatibility updated:',len(changes),'files')
