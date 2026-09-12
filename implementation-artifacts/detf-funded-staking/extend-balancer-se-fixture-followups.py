"""Prepare actual-currency and native-unit corrections for retained Balancer SE tests."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, hashlib, json, re, shutil

art=Path(__file__).resolve().parent; root=art.parent.parent
record_path=art/'balancer-se-fixture-followups-prepared.json'
record=json.loads(record_path.read_text());assert len(record['changes'])==1
shutil.copy2(record_path,art/'balancer-se-fixture-followups-initial-routing.json')
drafts=art/'balancer-se-fixture-followup-drafts'
base='test/foundry/spec/protocols/dexes/balancer/v3/pools/'

def rep(text,old,new,count=1):
    assert text.count(old)==count,old
    return text.replace(old,new)

def save(path,transform,reason):
    source=root/path; before=source.read_text();after=transform(before);assert before!=after
    draft=drafts/(source.name+'.txt');assert not draft.exists();draft.write_text(after)
    record['changes'].append({'path':path,'draft':str(draft.relative_to(root)),'reason':reason,
        'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(after.encode()).hexdigest()})

def cross_pair(text):
    text=text.replace('address(rateAsset)','address(buffer0)').replace('rateAsset.mint(alice, amt);','_mintToken(address(buffer0), alice, amt);')
    # Only buffer input quantities have underlying decimals; SE shares retain 18.
    text=re.sub(r'uint256 amt = ([235])e18;\n        _mintToken\(address\(buffer0\), alice, amt\);',
        r'uint256 amt = _from18(address(buffer0), \1e18);\n        _mintToken(address(buffer0), alice, amt);',text)
    text=rep(text,'uint256 amt = 5e18;\n        usdt.mint(alice, amt);',
        'uint256 amt = _from18(address(buffer1), 5e18);\n        usdt.mint(alice, amt);')
    return rep(text,'        rateAsset.mint(alice, 3e18);\n        swapExactIn(alice, buffer0, IERC20(address(seVault)), 3e18);',
        '        uint256 amount = _from18(address(buffer0), 3e18);\n        _mintToken(address(buffer0), alice, amount);\n        swapExactIn(alice, buffer0, IERC20(address(seVault)), amount);')
save(base+'weighted/multiPairBuffer/decimals/MultiPairBuffer_CrossPair_Decimals.sol',cross_pair,
    'Use configured buffer0 and native payment quantities, preserving cross-pair book isolation checks.')

def mixed_roles(text):
    text=re.sub(r'\b(rateAsset|pairToken)\b',lambda m:'pairToken' if m[0]=='rateAsset' else 'rateAsset',text)
    text=re.sub(r'uint256 amountIn = 10e18;\n        (pairToken|rateAsset)\.mint',
        r'uint256 amountIn = _from18(address(\1), 10e18);\n        \1.mint',text)
    # Each LP funding leg and maximum uses its own raw units.
    text=text.replace('pairToken.mint(alice, ML_INIT_BUFFER * 2);','pairToken.mint(alice, _from18(address(pairToken), ML_INIT_BUFFER) * 2);')
    text=text.replace('rateAsset.mint(alice, ML_INIT_UNPAIRED * 2);','rateAsset.mint(alice, _from18(address(rateAsset), ML_INIT_UNPAIRED) * 2);')
    text=text.replace('_mintToken(address(weth), alice, ML_INIT_UNPAIRED * 2);','_mintToken(address(weth), alice, _from18(address(weth), ML_INIT_UNPAIRED) * 2);')
    text=rep(text,'        uint256 n = ml().tokenCount();\n        uint256[] memory maxAmts',
        '        uint256 n = ml().tokenCount();\n        (IERC20[] memory poolTokens,,,) = bv3Vault.getPoolTokenInfo(mixedLegPool);\n        uint256[] memory maxAmts')
    text=text.replace('maxAmts[t] = ML_INIT_UNPAIRED;','maxAmts[t] = _from18(address(poolTokens[t]), ML_INIT_UNPAIRED);')
    return text.replace('maxAmts[t] = ML_INIT_BUFFER;','maxAmts[t] = _from18(address(poolTokens[t]), ML_INIT_BUFFER);')
save(base+'weighted/mixedLegBuffer/decimals/MixedLegWeightedBufferPool_Decimals.sol',mixed_roles,
    'Correct buffer/unpaired roles to the configured fixture and normalize actual token transfers, retaining exact output/book checks.')

def p4(text):
    # The retained U4/P2 helper must avoid buffer0 as an unpaired token too.
    text=text.replace('address(ml().bufferToken(0)), address(rateAsset)','address(ml().bufferToken(0)), address(buffer0)')
    text=rep(text,'        uint256 amt = 2e18;\n        rateAsset.mint(alice, amt);',
        '        uint256 amt = _from18(address(buffer0), 2e18);\n        _mintToken(address(buffer0), alice, amt);')
    text=rep(text,'        uint256 amt = 2e18;\n        usdt.mint(alice, amt);',
        '        uint256 amt = _from18(address(buffer1), 2e18);\n        usdt.mint(alice, amt);')
    text=rep(text,'if (i == 0) return IERC20(address(pairToken));','if (i == 0) return IERC20(address(rateAsset));')
    return text.replace('pair buffers = rateAsset, usdt.','pair buffers = pairToken, usdt.').replace('Indices 0..2 = pairToken, weth, wsteth;','Indices 0..2 = rateAsset, weth, wsteth;')
save(base+'weighted/mixedLegBuffer/decimals/MixedLeg_P4_Smoke_Decimals.sol',p4,
    'Preserve four-pair and U4/P2 fixtures while using actual buffer roles and native swap amounts.')

def mixed_funding(text):
    text=rep(text,'pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\n\nimport {Math} from "@crane/contracts/utils/Math.sol";')
    old='''        // WAD-raw both legs so SE shares (always 18) stay WAD-sized for init/swaps.
        uint256 amtA = tokenAmount;
        uint256 amtR = tokenAmount;'''
    new='''        // Fund actual proportional pool reserves for the requested SE-share fixture budget.
        // Equal raw token amounts are not proportional in a mixed-decimal pool.
        Pool pool = _aeroPoolAt(pairIndex);
        (uint256 r0, uint256 r1,) = pool.getReserves();
        uint256 supply = pool.totalSupply();
        uint256 amtA = Math.mulDiv(tokenAmount * 2, pool.token0() == tokenA ? r0 : r1, supply, Math.Rounding.Ceil) + 1;
        uint256 amtR = Math.mulDiv(tokenAmount * 2, pool.token0() == tokenA ? r1 : r0, supply, Math.Rounding.Ceil) + 1;'''
    text=rep(text,old,new)
    return rep(text,'        sharesOut = _addLpAndDeposit(pairIndex, recipient, tokenA, amtA, amtR);',
        '        sharesOut = _addLpAndDeposit(pairIndex, recipient, tokenA, amtA, amtR);\n        require(sharesOut >= tokenAmount, "funded SE-share fixture budget");')
save(base+'weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool_Decimals.sol',mixed_funding,
    'Actually acquire enough SE shares through proportional Aerodrome liquidity; prevent initializer transfer failures without fabricating SE balances.')

def mp_init(text):
    text=rep(text,'_mintToken(address(_bufferAt(i)), alice, MP_INIT_BUFFER * 2);',
        '_mintToken(address(_bufferAt(i)), alice, _from18(address(_bufferAt(i)), MP_INIT_BUFFER) * 2);')
    return rep(text,'amounts[t] = MP_INIT_BUFFER;','amounts[t] = _from18(address(poolTokens[t]), MP_INIT_BUFFER);')
save(base+'weighted/multiPairBuffer/bases/TestBase_MultiPairStandardExchangeBufferPool_Decimals.sol',mp_init,
    'Seed each buffer with the same human-unit amount, preventing 6/9-decimal book inflation and arithmetic overflow.')

def mp_spec(text):
    text=text.replace('rateAsset','pairToken')
    text=rep(text,'ttaScaled18(MP_INIT_BUFFER)','MP_INIT_BUFFER')
    text=text.replace('pairToken.mint(alice, MP_INIT_BUFFER * 2);','pairToken.mint(alice, _from18(address(tta), MP_INIT_BUFFER) * 2);')
    text=text.replace('maxAmts[bIdx] = MP_INIT_BUFFER;','maxAmts[bIdx] = _from18(address(tta), MP_INIT_BUFFER);')
    text=text.replace('pairToken.mint(alice, 100e18);','pairToken.mint(alice, _from18(address(tta), 100e18));')
    return text.replace('amounts[p.bufferIndex(0)] = 100e18;','amounts[p.bufferIndex(0)] = _from18(address(tta), 100e18);')
save(base+'weighted/multiPairBuffer/decimals/MultiPairStandardExchangeBufferPool_Decimals.sol',mp_spec,
    'Use the configured TTA for payments and received balances; match independently scaled initialization and liquidity amounts.')

def rate_units(text):
    text=rep(text,'        uint256 quoteShares = totalShares < 1e18 ? totalShares : 1e18;',
        '        uint256 subjectUnit = 10 ** IERC20Metadata(address(wrapper_)).decimals();\n        uint256 quoteShares = totalShares < subjectUnit ? totalShares : subjectUnit;')
    text=rep(text,'if (quoteShares != 1e18)', 'if (quoteShares != subjectUnit)')
    return rep(text,'out * 1e18 + quoteShares - 1','out * subjectUnit + quoteShares - 1')
save('test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol',rate_units,
    'Independent manual-rate vector uses one native wrapper token, including its retained ten-decimal offset.')

record['updated_at_utc']=datetime.now(timezone.utc).isoformat()
record['validation_passed']=False
record['required_validation']='Typecheck then all retained affected decimal leaves and actual provider paths; no Balancer DETF changes.'
record_path.write_text(json.dumps(record,indent=2)+'\n')
patch=''
for row in record['changes']:
    assert hashlib.sha256((root/row['path']).read_bytes()).hexdigest()==row['before_sha256']
    patch+=''.join(difflib.unified_diff((root/row['path']).read_text().splitlines(True),
        (root/row['draft']).read_text().splitlines(True),fromfile='a/'+row['path'],tofile='b/'+row['path']))
(art/'balancer-se-fixture-followups.patch').write_text(patch)
print(json.dumps({'status':'PREPARED_NOT_APPLIED','sources':len(record['changes']),'canonical_sources_unchanged':True}))
