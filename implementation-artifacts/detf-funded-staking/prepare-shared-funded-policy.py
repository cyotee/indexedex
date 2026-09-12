from pathlib import Path
import re,json,hashlib,sys
R=Path.cwd();A=R/'implementation-artifacts/detf-funded-staking';base=R/'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Policy.sol';original=base.read_text();files={}
a=original.index('    function _policyTokenUnits(');b=original.index('    function _assert_T1_',a);body=original[a:b]
body=body.replace('detfUser','_fundedPolicyUser()').replace('_deadline()','block.timestamp + 1 hours')
for x,y in {'_mintTokenOf':'_fundedPolicyMintToken','_fundToken':'_fundedPolicyFundToken','_nftLpOf':'_fundedPolicyLp','_skewSyntheticDown':'_fundedPolicySkewDown','_pushSyntheticUp':'_fundedPolicyPushUp','_ensureFreeDetf':'_fundedPolicyEnsureRaw','_firstBondOn':'_fundedPolicyBond','_donateMintToken':'_fundedPolicyDonate'}.items():body=body.replace(x,y)
body=body.replace('POLICY_MINT_THRESHOLD','1.05e18').replace('POLICY_BURN_THRESHOLD','0.95e18').replace('POLICY_EXPANSION_EPOCH','8 hours').replace('DEFAULT_MIN_LOCK','_fundedPolicyLock()').replace('_fundedPolicyDonate(d, 6 ether)','_fundedPolicyDonate(d, _policyTokenUnits(_fundedPolicyMintToken(d), 6))')
interface='''    function _fundedPolicyUser() internal view virtual returns (address);
    function _fundedPolicyMintToken(address d) internal view virtual returns (IERC20);
    function _fundedPolicyFundToken(address token, address user, uint256 amount) internal virtual;
    function _fundedPolicySkewDown(address d) internal virtual;
    function _fundedPolicyPushUp(address d) internal virtual;
    function _fundedPolicyEnsureRaw(address d, uint256 amount) internal virtual;
    function _fundedPolicyBond(address d, uint256 amount) internal virtual;
    function _fundedPolicyDonate(address d, uint256 amount) internal virtual;
    function _fundedPolicyLock() internal pure virtual returns (uint256);

    function _fundedPolicyLp(address d) private view returns (uint256) {
        IUniswapV4Detf info = IUniswapV4Detf(d);
        return IERC20(info.hook()).balanceOf(info.bondNftVault());
    }

'''
shared='''/// @notice Identical funded settlement and policy assertions over real reserve/provider fixtures.
abstract contract V4FundedPolicyAssertions is Test {
'''+interface+body+'}\n\n'
for suffix in ['', '_Decimals']:
 p=base.with_name('TestBase_UniswapV4Detf_Policy'+suffix+'.sol');s=p.read_text();a=s.index('    function _policyTokenUnits(');b=s.index('    function _assert_T1_',a);s=s[:a]+s[b:]
 s=s.replace(' is TestBase_UniswapV4Detf'+suffix+' {',' is TestBase_UniswapV4Detf'+suffix+', V4FundedPolicyAssertions {')
 if suffix:
  s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {V4FundedPolicyAssertions} from "'+str(base.relative_to(R))+'";')
 else:
  s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {Test} from "forge-std/Test.sol";')
  ix=s.index('/**\n * @title TestBase_UniswapV4Detf_Policy');s=s[:ix]+shared+s[ix:]
 adapters='''    function _fundedPolicyUser() internal view override returns (address) { return detfUser; }
    function _fundedPolicyMintToken(address d) internal view override returns (IERC20) { return _mintTokenOf(d); }
    function _fundedPolicyFundToken(address token, address user, uint256 amount) internal override { _fundToken(token, user, amount); }
    function _fundedPolicySkewDown(address d) internal override { _skewSyntheticDown(d); }
    function _fundedPolicyPushUp(address d) internal override { _pushSyntheticUp(d); }
    function _fundedPolicyEnsureRaw(address d, uint256 amount) internal override { _ensureFreeDetf(d, amount); }
    function _fundedPolicyBond(address d, uint256 amount) internal override { _firstBondOn(d, amount); }
    function _fundedPolicyDonate(address d, uint256 amount) internal override { _donateMintToken(d, amount); }
    function _fundedPolicyLock() internal pure override returns (uint256) { return DEFAULT_MIN_LOCK; }
'''
 s=s[:s.rfind('}')]+adapters+s[s.rfind('}'):];files[p]=s

def replace(s,name,body):
 m=re.search(r'    function '+re.escape(name)+r'\(',s);assert m,name
 a=s.index('{',m.end());j=a+1;n=1
 while n:
  if s[j]=='{':n+=1
  elif s[j]=='}':n-=1
  j+=1
 return s[:m.start()]+body+s[j:]
pons=R/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons'
for suffix in ['', '_Decimals']:
 p=(pons/('decimals' if suffix else ''))/('UniswapV4Detf_PonsV2Se_Stage11Helpers'+suffix+'.sol');s=p.read_text()
 s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {V4FundedPolicyAssertions} from "'+str(base.relative_to(R))+'";')
 s=s.replace('V4FundedFeeBehavior {','V4FundedFeeBehavior, V4FundedPolicyAssertions {')
 s=s.replace('POLICY_EXPANSION_EPOCH = 1 days','POLICY_EXPANSION_EPOCH = 8 hours')
 s=s.replace('    address internal policyCreator;','    mapping(address => uint256) internal _policyInitialBond;\n    address internal policyCreator;')
 s=s.replace('return pairAmount_ * ONE_WAD / opening_;','return pairAmount_ * ONE_WAD / opening_ / 1e9;')
 a=s.index('    function _firstBondOn(');b=s.index('    function _mintOn(',a);part=s[a:b]
 part=part.replace('        vm.stopPrank();','        vm.stopPrank();\n        if (_policyInitialBond[d] == 0) _policyInitialBond[d] = tokenId;');s=s[:a]+part+s[b:]
 # Reuse actual gold acquisition and public reserve swaps, preserving the Pons fixture.
 for name in ['_ensureFreeDetf','_skewSyntheticDownAmt']:
  m=re.search(r'    function '+name+r'\(',original);a=original.index('{',m.end());j=a+1;n=1
  while n:
   if original[j]=='{':n+=1
   elif original[j]=='}':n-=1
   j+=1
  s=replace(s,name,original[m.start():j])
 s=s.replace('_skewSyntheticDownAmt(d, 80 ether)','_skewSyntheticDownAmt(d, 80e9)')
 # Propagate real donation failures; an unsuccessful push must not look like a fixture state change.
 s=s.replace('try IUniswapV4Detf(d).donate(IERC20(token), amount, false) {} catch {}','IUniswapV4Detf(d).donate(IERC20(token), amount, false);')
 s=s.replace('try this.donateTokenExternal(d, toks_[i], 200 ether) {} catch {}','_donateToken(d, toks_[i], 200 ether);')
 adapters='''    function _fundedPolicyUser() internal view override returns (address) { return detfUser; }
    function _fundedPolicyMintToken(address) internal view override returns (IERC20) { return IERC20(launchToken); }
    function _fundedPolicyFundToken(address token, address user, uint256 amount) internal override { assertEq(token, launchToken); _fundLaunch(user, amount); }
    function _fundedPolicySkewDown(address d) internal override { _skewSyntheticDown(d); }
    function _fundedPolicyPushUp(address d) internal override { _pushSyntheticUp(d); }
    function _fundedPolicyEnsureRaw(address d, uint256 amount) internal override { _ensureFreeDetf(d, amount); }
    function _fundedPolicyBond(address d, uint256 amount) internal override { _firstBondOn(d, amount); }
    function _fundedPolicyDonate(address d, uint256 amount) internal override { _donateToken(d, launchToken, amount); }
    function _fundedPolicyLock() internal pure override returns (uint256) { return DEFAULT_MIN_LOCK; }
'''
 s=s[:s.rfind('}')]+adapters+s[s.rfind('}'):];files[p]=s
 p=(pons/('decimals' if suffix else ''))/('UniswapV4Detf_PonsV2Se_Policy'+suffix+('.sol' if suffix else '.t.sol'));s=p.read_text()
 names=['T7_8_policy_isMintingAllowed_token','policy_mint_blocked_in_deadband_then_allowed_after_push','policy_burn_allowed_when_synthetic_below_burnThreshold','D31_1_policyMint_realizesThenGates','D31_2_realizeWouldCloseMint_revertsUnchanged','D31_3_policyBurn_realizesThenGates']
 for name in names:
  deploy='_deployD31LaunchRichLive' if name.startswith('D31') else '_deployPolicyLaunchRichLive'
  s=replace(s,'test_'+name,'    function test_'+name+'() public {\n        _assert_'+name+'('+deploy+'());\n    }')
 s=s.replace('_claimTokOf(d).previewRedeem(redeem_)','IStandardExchangeIn(address(_claimTokOf(d))).previewExchangeIn(IERC20(address(_claimTokOf(d))), redeem_, IERC20(d))')
 s=replace(s,'test_D15_redeem_paysDetf_only','') # Exact duplicate; covered by D15_8 and D15_1.
 s=replace(s,'test_D15_9_ungatedVsPolicy','') # Same funded unstake in closed gate as D22.
 files[p]=s
records=[]
for p,s in files.items():
 b=p.read_text();assert b!=s,p
 records.append({'path':str(p.relative_to(R)),'before':hashlib.sha256(b.encode()).hexdigest(),'after':hashlib.sha256(s.encode()).hexdigest()})
 if '--apply' in sys.argv:p.write_text(s)
 else:(A/('pending-shared-policy-'+p.name+'.txt')).write_text(s)
(A/('shared-funded-policy-migration.json' if '--apply' in sys.argv else 'pending-shared-funded-policy-migration.json')).write_text(json.dumps({'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','files':records,'mapping':'Gold root/native policy assertions consolidated into one behavior shared with actual Pons fixtures. Six Pons policy tests now invoke identical funded settlement assertions; Pons D15_redeem maps to D15_8+D15_1 and D15_9 maps to D22. No fabricated DETF balance or swallowed reserve donation in Pons policy skew.'},indent=2)+'\n')
print(len(files),'files prepared' if '--apply' not in sys.argv else 'files applied')
