from pathlib import Path
import re,json,shutil,datetime
art=Path(__file__).resolve().parent;root=art.parent.parent
for ext in ('json','log'):shutil.copy2(art/('implementation-full-build.'+ext),art/('full-build-matrix-and-retired-mint-failure.'+ext))
base=root/'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single'
for rel in ['SingleStandardExchangeDETF_ComposedStableMatrix.t.sol','decimals/SingleStandardExchangeDETF_ComposedStableMatrix_Decimals.sol']:
 p=base/rel;s=p.read_text();s,count=re.subn(r'^\s*(thresholdMode|expansionCatchUpMaxSeconds|expansionCatchUpCapBps):[^\n]*\n','\n',s,flags=re.M);assert count==3
 start=s.index('pkgInit_ = ISingleStandardExchangeDETDFPkg.PkgInit({');end=s.index('});',start)+3;body=s[start:end];fields=re.findall(r'^\s*(\w+):\s*(.+?)(?:,)?\s*$',body,flags=re.M)
 assert len(fields)==15,(p,fields)
 replacement='// D60: retain only the historical fixture inputs; newly required\n        // funded components remain unset in this excluded legacy matrix.\n        '+'\n        '.join('pkgInit_.'+key+' = '+value.rstrip(',')+';' for key,value in fields)
 s=s[:start]+replacement+s[end:];p.write_text(s)
files=[
 'UniswapV4Detf_Orbital_Adversarial_Reentrancy.t.sol',
 'UniswapV4Detf_Weighted_Adversarial_Reentrancy.t.sol',
 'adversarial/Adversarial_Reentrancy.t.sol',
 'decimals/adversarial/Adversarial_Reentrancy_Decimals.sol']
base=root/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'
for rel in files:
 p=base/rel;s=p.read_text();i=re.search(r'pragma solidity [^;]+;',s).end();s=s[:i]+'\nimport {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";\n'+s[i:]
 s=s.replace('hostileInfo.mint(','IStandardExchangeIn(hostileDetf).exchangeIn(')
 amount='_uPair(50)' if 'Decimals' in rel else '50 ether'
 old='            '+amount+',\n            0,\n            detfUser,';new='            '+amount+',\n            IERC20(hostileDetf),\n            0,\n            detfUser,';assert old in s;s=s.replace(old,new)
 unit='_uPair(1)' if 'Decimals' in rel else '1 ether'
 anchor='        hostilePair.arm(hostileDetf, reentry);'
 control='''        // Prove the exact callback succeeds when the DETF is unlocked and
        // leave a second funded payment available for the nested attempt.
        hostilePair.mint(address(hostilePair), 2 * UNIT);
        vm.prank(address(hostilePair));
        hostilePair.approve(hostileDetf, 2 * UNIT);
        vm.prank(address(hostilePair));
        (bool controlOk,) = hostileDetf.call(reentry);
        assertTrue(controlOk, "funded callback succeeds outside the lock");
'''.replace('UNIT',unit)
 assert anchor in s;s=s.replace(anchor,control+anchor)
 s=s.replace('        hostilePair.disarm();','        assertEq(hostilePair.balanceOf(address(hostilePair)), '+unit+', "locked callback cannot spend its payment");\n        hostilePair.disarm();')
 p.write_text(s)
(art/'matrix-and-reentrancy-caller-migration.json').write_text(json.dumps({'recorded_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'status':'APPLIED_AWAITING_FULL_BUILD_AND_RUNTIME','excluded_scope':'Two historical Single-over-Composed matrices: remove missing input members and assign only their existing fixture inputs. Required funded components remain unset; no excluded functional migration.','v4_scope':'Four CP/Weighted/Orbital/decimal adversarial callers use standard exchange instead of retired mint. Each proves the same funded bond callback succeeds outside the lock, then checks IsLocked and untouched callback payment during execution.','v4_files':files},indent=2)+'\n')
print('Updated 2 excluded matrix fixtures and 4 V4 reentrancy callers')
