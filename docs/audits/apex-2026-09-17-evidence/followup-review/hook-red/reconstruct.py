from pathlib import Path
import hashlib,json,shutil,datetime
live=Path('/Users/cyotee/Development/projects-defi/daosys/lib/indexedex')
clone=Path('/tmp/apex-review-accounting-red-run')
ev=clone/'hook-red-evidence'
ev.mkdir(exist_ok=True)
base=Path('contracts/hooks/uniswap/v4/standardExchange')
paths=[base/'orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol',base/'dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol',base/'dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol']
paths += [base/f'constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook{x}.sol' for x in ['Repo','DepositCommon','WithdrawTarget','Target','SeTarget']]
tests=[Path('test/foundry/spec/hooks/uniswap/v4/standardExchange')/p for p in [
'orbital/UniswapV4StandardExchangeOrbitalBufferHook_Apex008.t.sol',
'orbital/UniswapV4StandardExchangeOrbitalBufferHook_RatedReserve.t.sol',
'dual/UniswapV4DualSEBCPHook_SeMatrix_ERC4626StandardExchange.t.sol',
'dual/UniswapV4DualSEBCPHook_SeMatrix_RebasingAwareERC4626.t.sol',
'constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_ERC4626StandardExchange.t.sol',
'constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_RebasingAwareERC4626.t.sol']]
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest={'status':'RECONSTRUCTED_PRE_REVIEW_HOOK_ACCOUNTING','method':'Copy current fixed source, reverse only this reviewer\'s native-custody helper and identity-book additions. Preserve prior dirty D60 implementation. Original pre-edit files were not saved; reconstructed hashes are not asserted to identify an original byte-for-byte snapshot. Comments may differ; old B>=R helper body and storage/sync behavior are restored.','createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'sourceFiles':[],'tests':[]}
oldhelper='''    /// @dev Reconstructed pre-review helper: compares local face against the virtual reserve.
    function _unbookedBalance(IERC20 token) internal view returns (uint256) {
        uint256 B = token.balanceOf(address(this));
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(token));
        return B >= R ? B - R : B;
    }
'''
for p in paths:
 current=(live/p).read_bytes(); s=current.decode(); before=s
 if p.name.endswith('Common.sol') and '/orbital/' in str(p):
  a=s.index('    /// @dev Credit is measured'); b=s.index('\n\n    function _pullSeFunding',a)
  s=s[:a]+oldhelper+s[b:]
  block='''        // Identity legs custody their backing in the face token; keep its native-unit book.
        for (uint8 i; i < 3; ++i) {
            address token = Repo._tokenAt(l, i);
            if (Repo._seAt(l, i) == token) l.reserves[token] = IERC20(token).balanceOf(address(this));
        }
'''
  assert block in s;s=s.replace(block,'',1)
 elif '/dual/' in str(p) and p.name.endswith('Common.sol'):
  a=s.index('    /// @dev Buffered face is unbooked'); b=s.index('    /// @dev Exact-out input',a)
  s=s[:a]+oldhelper+'\n'+s[b:]
  for line in ['        if (l.se0 == l.token0) l.localReserves[l.token0] = IERC20(l.token0).balanceOf(address(this));\n','        if (l.se1 == l.token1) l.localReserves[l.token1] = IERC20(l.token1).balanceOf(address(this));\n']:
   assert line in s;s=s.replace(line,'',1)
 elif '/dual/' in str(p):
  block='''        /// @dev Native token book for identity legs; independent of provider rate.
        mapping(address token => uint256 balance) localReserves;
'''
  assert block in s;s=s.replace(block,'',1)
 elif p.name.endswith('Repo.sol'):
  block='''        /// @dev Native token book for an identity pair leg, independent of provider rate.
        uint256 localPairReserve;
'''
  assert block in s;s=s.replace(block,'',1)
 else:
  block='''        if (l.pairToken == l.standardExchange) {
            l.localPairReserve = IERC20(l.pairToken).balanceOf(address(this));
        }
'''
  assert block in s;s=s.replace(block,'',1)
  if p.name.endswith('SeTarget.sol'):
   a=s.index('    /// @dev Raw and identity legs deduct'); b=s.index('    /// @dev Exact-out input',a)
   s=s[:a]+oldhelper+'\n'+s[b:]
 assert s != before
 (clone/p).write_text(s)
 manifest['sourceFiles'].append({'file':str(p),'currentFixedSha256':sha(current),'reconstructedSha256':sha(s.encode()),'originalPreEditSha256':None})
for p in tests:
 shutil.copy2(live/p,clone/p)
 manifest['tests'].append({'file':str(p),'sha256':sha((clone/p).read_bytes())})
for name in ['out','cache_forge']:
 a=(live/name).stat();b=(clone/name).stat()
 assert (a.st_dev,a.st_ino)!=(b.st_dev,b.st_ino)
 manifest[name]={'liveInode':a.st_ino,'cloneInode':b.st_ino,'cloneResolvedPath':str((clone/name).resolve())}
(ev/'reconstruction-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(ev/'source-paths.txt').write_text('\n'.join(map(str,paths))+'\n')
(ev/'test-paths.txt').write_text('\n'.join(map(str,tests))+'\n')
print(json.dumps({'sources':len(paths),'testFiles':len(tests),'manifest':str(ev/'reconstruction-manifest.json')}))
