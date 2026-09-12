"""Regenerate the explicitly approved cleanup; dry-run until the active Forge exits."""
from pathlib import Path
import re,json,hashlib,difflib,sys,datetime
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking';b=r/'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf';d=r/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf';files={}
approval=json.loads((a/'v4-close-cleanup-owner-approval.json').read_text());assert approval['status'].startswith('APPROVED_BY_OWNER')
def get(p):return files.get(p,p.read_text())
def put(p,s):files[p]=s
def remove_function(s,name):
 m=re.search(r'^    function '+re.escape(name)+r'\s*\(',s,re.M);assert m,name
 start=m.start();brace=s.index('{',m.end());level=1;i=brace+1
 while level:
  if s[i]=='{':level+=1
  elif s[i]=='}':level-=1
  i+=1
 while i<len(s) and s[i]=='\n':i+=1
 return s[:start]+s[i:]
def reindex(s,array):
 pattern=re.compile(re.escape(array)+r'\[\d+\]\s*=');i=iter(range(1000));return pattern.sub(lambda m:array+'['+str(next(i))+'] =',s)
p=b/'interfaces/IUniswapV4Detf.sol';s=get(p)
for line in ['        RouteTableMode closeRouteMode;\n','        IoRoute[] closeRoutes;\n','    function closeRoutes() external view returns (IoRoute[] memory);\n','    function closeRouteMode() external view returns (RouteTableMode);\n']:
 assert line in s;s=s.replace(line,'')
s=s.replace('    error InvalidCloseRoutes();','    error InvalidPackageArguments();').replace('exchange, bond/close, maintenance','exchange, bond, maintenance');put(p,s)
p=b/'UniswapV4DetfRepo.sol';s=get(p)
s=re.sub(r'^import \{ThresholdMode\}[^\n]+\n','',s,flags=re.M)
for name in ['detfNftId','feeRecipientNftId','userBondedLp','closeRouteMode','closeTable']:
 s=re.sub(r'^        [^\n;]+\s'+name+r';\n','',s,flags=re.M)
for line in ['        s.userBondedLp = 0;\n','        IUniswapV4Detf.RouteTableMode close_,\n','        s.closeRouteMode = close_;\n','        s.detfNftId = detfNftId_;\n','        s.feeRecipientNftId = feeRecipientNftId_;\n']:s=s.replace(line,'')
s=s.replace('function _setBondNft(IDETFNFTVault vault_, uint256 detfNftId_, uint256 feeRecipientNftId_)','function _setBondNft(IDETFNFTVault vault_)')
for name in ['_addUserBondedLp','_subUserBondedLp']:s=remove_function(s,name)
put(p,s)
p=b/'UniswapV4DetfTarget.sol';s=get(p)
for name in ['_entryCloseRoutes','_entryCloseRouteMode']:s=remove_function(s,name)
s=s.replace('Repo._setBondNft(bondVault_, detfNftId_, DETF_FEE_TO_BOND_NFT_ID);','Repo._setBondNft(bondVault_);');put(p,s)
p=b/'UniswapV4DetfQueryTarget.sol';s=get(p)
for name in ['closeRoutes','closeRouteMode']:s=remove_function(s,name)
put(p,s)
p=b/'UniswapV4DetfQueryFacet.sol';s=get(p);s=re.sub(r'^        funcs_\[\d+\] = IUniswapV4Detf\.close(?:Routes|RouteMode)\.selector;\n','',s,flags=re.M);s=reindex(s,'funcs_').replace('new bytes4[](37)','new bytes4[](35)');put(p,s)
p=b/'UniswapV4DetfDFPkg.sol';s=get(p);s=s.replace('        ArgsLib.requireCustomClose(args);\n','').replace('            args.closeRouteMode,\n','')
start=s.index('        if (args.closeRouteMode');end=s.index('        if (args.donateRouteMode',start);s=s[:start]+s[end:]
s=re.sub(r'ArgsLib.storeCustomTable\(args.hook, address\(this\), (args\.\w+Routes), (s\.\w+Table), false, (?:false|true)\)',r'ArgsLib.storeCustomTable(address(this), \1, \2)',s)
s=s.replace('abi.decode(pkgArgs, (IUniswapV4Detf.PkgArgs))','_decodeArgs(pkgArgs)').replace('abi.decode(initArgs, (IUniswapV4Detf.PkgArgs))','_decodeArgs(initArgs)')
marker='    /// @dev Salt ignores `hook`';idx=s.index(marker);s=s[:idx]+'''    /// @dev Reject removed fields and noncanonical payloads instead of silently reinterpreting them.
    function _decodeArgs(bytes memory encoded_) private pure returns (IUniswapV4Detf.PkgArgs memory args_) {
        args_ = abi.decode(encoded_, (IUniswapV4Detf.PkgArgs));
        if (keccak256(encoded_) != keccak256(abi.encode(args_))) revert InvalidPackageArguments();
    }

'''+s[idx:];put(p,s)
p=b/'UniswapV4DetfProcessArgsLib.sol';s=get(p)
for name in ['requireCustomClose','storeDefaultClose']:s=remove_function(s,name)
s=s.replace('''    function storeCustomTable(
        address hook_,
        address detf_,
        IUniswapV4Detf.IoRoute[] memory rows_,
        Repo.Table storage table_,
        bool closeTable_,
        bool donateTable_
''','''    function storeCustomTable(
        address detf_,
        IUniswapV4Detf.IoRoute[] memory rows_,
        Repo.Table storage table_
''')
s=s.replace('_requireCustomRow(hook_, detf_, token_, vault_, closeTable_);','_requireCustomRow(detf_, token_, vault_);')
s=s.replace('''        if (donateTable_) {
            // subset vs mint∪bond is checked after both inbound tables are stored
        }
''','')
s=s.replace('''    function _requireCustomRow(
        address hook_,
        address detf_,
        address token_,
        address vault_,
        bool closeTable_
''','''    function _requireCustomRow(
        address detf_,
        address token_,
        address vault_
''')
start=s.index('        if (closeTable_)');end=s.index('        if (token_ == vault_)',start);s=s[:start]+s[end:];put(p,s)
# All typed V4 argument construction sites are discovered, not copied from the stale patch.
for tree in ['contracts','test','scripts']:
 for p in (r/tree).rglob('*.sol'):
  if p in files:continue
  s=p.read_text()
  if 'IUniswapV4Detf' not in s or not re.search(r'closeRouteMode|closeRoutes',s):continue
  if '/balancer/' in str(p) or 'slipstream' in str(p).lower():raise AssertionError('Excluded touch '+str(p))
  s=re.sub(r'^\s*closeRouteMode: IUniswapV4Detf.RouteTableMode.\w+,\n','\n',s,flags=re.M)
  s=re.sub(r'^\s*closeRoutes: new IUniswapV4Detf.IoRoute\[\]\(0\),\n','\n',s,flags=re.M)
  s=re.sub(r'^        args\.closeRouteMode = [^;]+;\n','',s,flags=re.M)
  s=re.sub(r'^        args\.closeRoutes(?:\[\d+\])?\s*=.*?;\n','',s,flags=re.M|re.S)
  put(p,s)
# Retire validation of deleted fields. Keep and strengthen current deployment checks.
for suffix,folder in [('',d),('_Decimals',d/'decimals')]:
 p=folder/('UniswapV4Detf_Deploy'+suffix+('.t.sol' if not suffix else '.sol'));s=get(p)
 for name in ['test_T7_1_customCloseLengthNotOne_reverts','test_T7_1_customCloseLengthTwo_reverts']:s=remove_function(s,name)
 s=s.replace('T7.1 Dual revert, custom close length, deploy wiring.','T7.1 Deployment wiring and rejection of obsolete payload encoding.')
 if not suffix:
  s=s.replace('import {IUniswapV4Detf} from','import {IUniswapV4Detf, IUniswapV4DetfDFPkg} from')
  index=s.index('    function test_deploy_inert_until_first_bond')
  s=s[:index]+'''    function test_deploymentRejectsNoncanonicalPayload() public {
        bytes memory canonical_ = abi.encode(_defaultDetfArgs());
        detfPkg.calcSalt(canonical_);
        bytes memory obsolete_ = bytes.concat(canonical_, bytes32(0));
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidPackageArguments.selector);
        detfPkg.calcSalt(obsolete_);
    }

'''+s[index:]
 put(p,s)
for suffix,folder in [('',d),('_Decimals',d/'decimals')]:
 p=folder/('UniswapV4Detf_IoTables'+suffix+('.t.sol' if not suffix else '.sol'));s=get(p)
 s=s.replace('Retained configuration cannot alter funded sDETF claims or release protocol LP.','Funded sDETF claims retain protocol LP without a separate close configuration.')
 s=s.replace('test_T7_11_customClose_leftoverOwnerSwap','test_T7_11_fundedClaim_retainsProtocolLp').replace('CustomClose1','FundedClaimInstance').replace('"CC1"','"FC1"')
 s=re.sub(r'^        IUniswapV4Detf.IoRoute\[\] memory close_ = info.closeRoutes\(\);\n        assertEq\(close_\.length[^\n]+\n        assertEq\(address\(close_\[0\]\.token\)[^\n]+\n','',s,flags=re.M)
 put(p,s)
p=b/'TestBase_UniswapV4Detf_Quad.sol';s=get(p);s=s.replace('_customClosePair0Args','_fundedClaimArgs').replace('QCustomClose','QFundedClaim').replace('qClose1','qClaim');put(p,s)
p=d/'UniswapV4Detf_Quad.t.sol';s=get(p);s=s.replace('_customClosePair0Args','_fundedClaimArgs').replace('test_T8_3_customClose_onePair','test_T8_3_fundedClaim_retainsWholeReserve');s=re.sub(r'^        IUniswapV4Detf.IoRoute\[\] memory close_ = info.closeRoutes\(\);\n(?:        assertEq\([^\n]+\n){3}','',s,flags=re.M);put(p,s)
p=d/'UniswapV4Detf_Close.t.sol';s=get(p).replace('CustomCloseInventory','FundedClaimInventory');put(p,s)
p=r/'test/foundry/spec/protocols/staking/token/TokenStaking_PonsUv4Detf.t.sol';s=get(p)
s=s.replace(''' * @dev Launch token is `$DTF` (hook pair). Claim `rateAsset()` is that pair
 *      (`completeReserveClaim` binds `hookPairTokens[0]`). Close Custom is one
 *      hook-pair row (PRD: custom close length 1); mint/bond/burn/donate list
 *      both WETH and DTF.''',''' * @dev Funded staking is backed by raw DETF; mint/bond/burn/donate routes list
 *      both WETH and the launch token. Bond claims pay sDETF without an asset-selecting close.''')
s=re.sub(r'^        IUniswapV4Detf.IoRoute\[\] memory close_ = detfInfo.closeRoutes\(\);\n(?:        assertEq\([^\n]+\n){2}','',s,flags=re.M);put(p,s)
p=d/'adversarial/Adversarial_Surface.t.sol';s=get(p)
s=re.sub(r'^        s_\[\d+\] = IUniswapV4Detf\.close(?:Routes|RouteMode)\.selector;\n','',s,flags=re.M);s=reindex(s,'s_').replace('new bytes4[](48)','new bytes4[](46)')
s=s.replace('bytes4[11] memory retired_', 'bytes4[13] memory retired_').replace('            bytes4(keccak256("thresholdMode()"))','            bytes4(keccak256("thresholdMode()")),\n            bytes4(keccak256("closeRoutes()")),\n            bytes4(keccak256("closeRouteMode()"))')
s=s.replace('        // These inert configuration getters remain until the separately recorded cleanup approval.\n        info_.closeRoutes(); info_.closeRouteMode();\n','');put(p,s)
for name in ['detfAbi.ts','detfDeploy.ts','detfDeploy.test.ts']:
 p=r/'frontend/apps/dtf/app/create/lib'/name;s=get(p)
 if name=='detfDeploy.test.ts':s=s.replace('    expect(args.closeRouteMode).toBe(ROUTE_TABLE_DEFAULT)','    expect(args).not.toHaveProperty(\'closeRouteMode\')\n    expect(args).not.toHaveProperty(\'closeRoutes\')')
 else:s=''.join(line for line in s.splitlines(keepends=True) if not re.search(r'\bcloseRouteMode\b|\bcloseRoutes\b',line))
 put(p,s)
rows=[];patch=[]
for p,s in files.items():
 old=p.read_text()
 if old==s:continue
 rel=str(p.relative_to(r));rows.append({'path':rel,'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
 patch.extend(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='a/'+rel,tofile='b/'+rel))
 if '--apply' in sys.argv:p.write_text(s)
 else:
  dest=a/'approved-v4-close-cleanup-preview'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.with_suffix(dest.suffix+'.txt').write_text(s)
(a/'pending-v4-close-config-cleanup.patch').write_text(''.join(patch))
record={'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'approval':'v4-close-cleanup-owner-approval.json','status':'APPLIED_VALIDATION_PENDING' if '--apply' in sys.argv else 'REGENERATED_CURRENT_MAIN_READY_AFTER_FORGE','files':rows,'removed_storage':['detfNftId','feeRecipientNftId','userBondedLp','closeRouteMode','closeTable'],'removed_proxy_getters':['closeRoutes()','closeRouteMode()'],'current_product_selectors':46,'query_facet_selectors':35,'coverage_mapping':{'customCloseLengthNotOne/customCloseLengthTwo':'Retired field validation is obsolete; canonical payload rejection and 13 removed-selector negatives cover current deployment/API requirements. Native repetitions retired; native inert/wiring assertions retained.','T7.11/T8.3':'Retain real funded claim/unstake and whole protocol-LP custody assertions; remove only obsolete configuration assertions.','Standing roles':'Retain reserved-role initialization and wiring event; remove unused stored copies of fixed role IDs.'},'preserved':'Funded bond claim/vesting/reward code, standard staking/exchange/SY exits, D60 Balancer DETF exclusion, D66 Slipstream deferral, unrelated working-tree changes.'}
(a/'approved-v4-close-cleanup.json').write_text(json.dumps(record,indent=2)+'\n')
print(record['status'],len(rows),'files')
