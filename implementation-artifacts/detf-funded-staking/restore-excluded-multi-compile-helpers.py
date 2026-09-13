from pathlib import Path
import re,json,hashlib
art=Path('implementation-artifacts/detf-funded-staking')
root=Path('contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted')
f=root/'TestBase_MultiVaultWeightedDetf.sol'
oldroot=Path('/private/tmp/indexedex-detf-funded-staking-20260906')
old=(oldroot/f).read_text();s=f.read_text();before=s
(art/'excluded-multi-testbase-before.sol.reference').write_text(old)
names=[r['helper'] for r in json.loads((art/'excluded-multi-legacy-helper-inventory.json').read_text())]
names+=['_isKnownSeVault','_fundSeShares1','_deploySingleSeDetfPkg']
selected=[]
for m in re.finditer(r'^    function (\w+)\(',old,re.M):
    if m.group(1) not in names:continue
    start=m.start();brace=old.index('{',m.end());end=brace+1;depth=1
    while depth:depth+=(old[end]=='{')-(old[end]=='}');end+=1
    body=old[start:end]
    body=re.sub(r'^\s*args\.\b(thresholdMode|expansionCatchUpMaxSeconds|expansionCatchUpCapBps)\b[^\n]*\n','\n',body,flags=re.M)
    body=re.sub(r'^\s*(thresholdMode|expansionCatchUpMaxSeconds|expansionCatchUpCapBps):[^\n]*\n','\n',body,flags=re.M)
    if m.group(1)=='_deploySingleSeDetfPkg':
        body=body.replace('            diamondFactory: diamondPackageFactory','            syPkg: syPkg,\n            diamondFactory: diamondPackageFactory')
        body=body.replace('        ISingleStandardExchangeDETDFPkg.PkgInit', '        singleSeDetfExchangeInFacet = SingleStandardExchangeDETF_Component_FactoryService.deployExchangeInFacet(create3Factory);\n        ISingleStandardExchangeDETDFPkg.PkgInit',1)
    if m.group(1)=='_deployNestedSingleSeDetfLive' and 'ThresholdMode mode_' in body:
        body=body.replace('        _ensureSeVaults(1);','        if (address(singleSeDetfPkg) == address(0)) _deploySingleSeDetfPkg();\n        _ensureSeVaults(1);',1)
    selected.append(body)
needed=['IDETFNFTVault','ISingleStandardExchangeDETDFPkg','SingleStandardExchangeDETF_Component_FactoryService','SingleStandardExchangeDETF_Pkg_FactoryService','ISingleStandardExchangeDETFBonding','ISingleStandardExchangeDETFInfo','ThresholdMode']
imports=[]
for imp in re.findall(r'import\s*\{[^}]+\}\s*from\s*"[^"]+";',old,re.S):
    if any(re.search(r'\b'+name+r'\b',imp.split('from')[0]) for name in needed):imports.append(imp)
s=s.replace('/// @notice Real one-to-seven-leg', '\n'.join(imports)+'\n\n/// @notice Real one-to-seven-leg',1)
fields='''    // D60: aliases retained only for compilation of the excluded legacy test corpus.
    IStandardExchangeProxy internal seVault0;
    IStandardExchangeProxy internal seVault1;
    IERC20 internal seShare0;
    IERC20 internal seShare1;
    IERC20 internal rateAsset0;
    IERC20 internal rateAsset1;
    IFacet internal singleSeDetfExchangeInFacet;
    ISingleStandardExchangeDETDFPkg internal singleSeDetfPkg;
'''
s=s.replace('    address internal detf;',fields+'    address internal detf;',1)
s=s.replace('        _ensureSeVaults(2);','''        _ensureSeVaults(2);
        seVault0 = seVaults[0]; seVault1 = seVaults[1];
        seShare0 = seShares[0]; seShare1 = seShares[1];
        rateAsset0 = rateAssets[0]; rateAsset1 = rateAssets[1];''',1)
compat='''    /// @dev Legacy caller signature only; the current package has no configurable mode.
    function _buildPkgArgs(uint8 n, uint256 mint, uint256 burn, bool rated, ThresholdMode)
        internal view returns (IMultiVaultWeightedDetfDFPkg.PkgArgs memory)
    { return _buildPkgArgs(n, mint, burn, rated); }

    function _deployDetfN(uint8 n, uint256 mint, uint256 burn, bool rated, ThresholdMode)
        internal returns (address)
    { return _deployDetfN(n, mint, burn, rated); }

'''
s=s.rstrip()[:-1]+'\n    // D60 compilation maintenance: original setup helpers, no production API restoration.\n'+compat+'\n\n'.join(selected)+'\n}\n'
# Retired selector declarations are test-only. Do not change production interface IDs or proxy cuts.
legacy=[];symbols=[]
for suffix in ['Bonding','Info']:
    name='IMultiVaultWeightedDetf'+suffix
    op=oldroot/root/('MultiVaultWeightedDetf'+suffix+'Target.sol')
    orig=op.read_text();curr=(root/op.name).read_text()
    iface=orig[orig.index('interface '+name):orig.index('abstract contract')]
    currentNames=set(re.findall(r'function (\w+)\(',curr))
    declarations=[]
    for decl in re.findall(r'function\s+\w+\([^;]+;',iface,re.S):
        method=re.search(r'function (\w+)',decl).group(1)
        if method not in currentNames:declarations.append(decl);symbols.append(method)
    legacyName='ILegacyMultiVaultWeightedDetf'+suffix
    legacy.append('/// @dev Historical test ABI only; these declarations do not install retired selectors.\ninterface '+legacyName+' is '+name+' {\n    '+'\n    '.join(declarations)+'\n}\n')
    s=s.replace('    '+name+' internal detf'+suffix+';', '    '+legacyName+' internal detf'+suffix+';')
    s=s.replace('detf'+suffix+' = '+name+'(instance_);','detf'+suffix+' = '+legacyName+'(instance_);')
s=s.replace('/// @notice Real one-to-seven-leg','\n'.join(legacy)+'\n/// @notice Real one-to-seven-leg',1)
f.write_text(s)
changed=[{'path':str(f),'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}]
# Existing legacy caller imports may require the historical superset too. Assertions stay unchanged.
for spec in Path('test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted').rglob('*.sol'):
    t=spec.read_text();before=t
    if not any(re.search(r'\.'+method+r'\b',t) for method in symbols):continue
    for suffix in ['Bonding','Info']:
        name='IMultiVaultWeightedDetf'+suffix
        pattern=r'import\s*\{\s*'+name+r'\s*\}\s*from\s*"[^"]+";'
        t=re.sub(pattern,'import {ILegacyMultiVaultWeightedDetf'+suffix+' as '+name+'} from "'+str(f)+'";',t)
    if t!=before:
        spec.write_text(t);changed.append({'path':str(spec),'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(t.encode()).hexdigest()})
(art/'excluded-multi-compile-compatibility.json').write_text(json.dumps({'scope':'D60 compilation maintenance only; original legacy test assertions retained; no production selector/interface/economic change','source_snapshot':str(oldroot/f),'original_helper_sha256':hashlib.sha256(old.encode()).hexdigest(),'restored_helpers':names,'test_only_retired_selector_declarations':symbols,'files':changed,'validation':'pending full repository compile'},indent=2)+'\n')
print('Restored',len(selected),'helper bodies; test-only compatibility files:',len(changed))
