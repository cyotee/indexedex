"""Migrate the retained T7.10 liquidity formula to independent funded U/G accounting."""
from pathlib import Path
import re,json,hashlib,sys
ROOT=Path(__file__).resolve().parents[2];ART=Path(__file__).resolve().parent
folder=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf';records=[]
for suffix,sub,pons in [('',folder,False),('_Decimals',folder/'decimals',False),('',folder/'pons',True),('_Decimals',folder/'pons/decimals',True)]:
 p=sub/(('UniswapV4Detf_PonsV2Se_ProductLaw' if pons else 'UniswapV4Detf_IoTablesOpenBase')+suffix+('.t.sol' if pons and not suffix else '.sol'))
 b=p.read_text();s=b
 m=re.search(r'    function test_T7_10_laterBond_joinUnbalanced_unboostedG\(',s);assert m
 at=s.index('{',m.end());j=at+1;depth=1
 while depth:
  if s[j]=='{':depth+=1
  elif s[j]=='}':depth-=1
  j+=1
 body=(ART/'pending-v4-io-funded-bond.txt').read_text().replace('FIRST_AMOUNT','_uPair(80)' if suffix and not pons else ('_uLaunch(80)' if suffix else '80 ether')).replace('LATER_AMOUNT','_uPair(20)' if suffix and not pons else ('_uLaunch(20)' if suffix else '20 ether')).replace('PAYMENT_ADDRESS','launchToken' if pons else 'address(pairToken)')
 # Pons decimal helpers use their own actual funding scale; resolve its existing first-bond amount.
 if pons and suffix:
  old=s[m.start():j]
  first=re.search(r'_firstBond\(([^;]+)\);',old)[1]
  amount=re.search(r'uint256 mintTokenIn_ = ([^;]+);',old)[1]
  body=body.replace('_uLaunch(80)',first).replace('_uLaunch(20)',amount)
 s=s[:m.start()]+body+s[j:]
 for names,path in [('IDetfBondNFT','contracts/interfaces/IDetfBondNFT.sol'),('IStakedDETF','contracts/interfaces/IStakedDETF.sol')]:
  if '"'+path+'"' not in s:s=s.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\nimport {'+names+'} from "'+path+'";')
 records.append((p,b,s))
for p,b,s in records:
 if '--apply' in sys.argv:p.write_text(s)
 else:(ART/('pending-funded-io-'+p.name+'.txt')).write_text(s)
r={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','decision':'D32 independent U/G with existing proportional liquidity formula retained','mapping':'T7.10 keeps actual proportional G reference and LP funding; purchased P0 and reward pot checked independently, P0 staked immediately, exact raw issuance/backing deltas and actual protocol LP ownership. Retired ordinary previewMint is not used as a bond purchase quote.','files':[{'path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(b.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()}for p,b,s in records]}
(ART/('v4-io-funded-bond-migration.json' if '--apply' in sys.argv else 'pending-v4-io-funded-bond-migration.json')).write_text(json.dumps(r,indent=2)+'\n')
print(r['status'],len(records),'files')
