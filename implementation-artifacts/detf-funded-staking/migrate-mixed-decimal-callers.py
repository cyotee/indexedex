"""Share funded test behavior between default and native-decimal Mixed fixtures."""
from pathlib import Path
import hashlib
import json
import re

root = Path(__file__).resolve().parents[2]
base = root/'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer'
fixture = 'contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/TestBase_MixedBufferMultiVaultStableDetf'
groups = ['Deploy','Bootstrap','Bonding','Mint','Burn','NLegs','Guards','Routes','Liveness',
          'RateProviders','Pricing','PriceShift','Nested','NestedPush']
rows = []
for group in groups:
    name = 'MixedBufferMultiVaultStableDetf_'+group
    source = base/(name+'.t.sol')
    target = base/'decimals'/(name+'_Decimals.sol')
    original = source.read_text()
    previous = target.read_text()
    current = original.replace('address(dai)', 'address(_fixtureBufferToken())')
    current = current.replace('dai.approve(', '_fixtureBufferToken().approve(')
    custom_setup = 'function setUp()' in current
    if custom_setup:
        current = current.replace('function setUp() public override', 'function setUp() public virtual override',1)
    source.write_text(current)
    root_class = name+'_Test'
    assert re.search(r'contract\s+'+root_class+r'\s+is',current),source
    adapter = f'''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {{{root_class}}} from "{source.relative_to(root)}";
import {{TestBase_MixedBufferMultiVaultStableDetf_Decimals}} from "{fixture}_Decimals.sol";
'''
    if custom_setup:
        adapter += f'import {{TestBase_MixedBufferMultiVaultStableDetf}} from "{fixture}.sol";\n'
    adapter += f'''
/// @notice Runs the canonical funded behavior with actual native-decimal token books.
abstract contract {name}_Decimals is
    {root_class}, TestBase_MixedBufferMultiVaultStableDetf_Decimals
{{
'''
    if custom_setup:
        adapter += f'''    function setUp() public override({root_class}, TestBase_MixedBufferMultiVaultStableDetf) {{
        {root_class}.setUp();
    }}
'''
    adapter += '}\n'
    target.write_text(adapter)
    rows.append({'group':group, 'canonical_source':str(source.relative_to(root)),
                 'canonical_before_sha256':hashlib.sha256(original.encode()).hexdigest(),
                 'canonical_after_sha256':hashlib.sha256(current.encode()).hexdigest(),
                 'decimal_adapter':str(target.relative_to(root)),
                 'decimal_before_sha256':hashlib.sha256(previous.encode()).hexdigest(),
                 'decimal_after_sha256':hashlib.sha256(adapter.encode()).hexdigest(),
                 'old_tests':re.findall(r'function (test_\w+)\(',previous),
                 'shared_tests':re.findall(r'function (test_\w+)\(',current),
                 'before_lines':len(previous.splitlines()), 'after_lines':len(adapter.splitlines())})
    for wrapper in (base/'decimals').glob(name+'_B_*.t.sol'):
        text = wrapper.read_text()
        wrapper.write_text(text.replace('vaultShare / detfToken / claim / Bond NFT stay 18.',
            'DETF, sDETF and DETF SYs use 9 decimals; SE shares retain their existing precision.'))

output={'status':'validation pending', 'groups':len(groups), 'rows':rows,
        'LP_payment_scope':'Existing LP-only bond purchase and discovery assertions remain pending owner disposition; neither was retired.',
        'decision':'Shared funded behavior replaces copied legacy Open-mode and LP-claim test bodies. Every existing native-decimal wrapper remains, and the eight-book funded lifecycle has separate passing evidence.'}
(Path(__file__).resolve().parent/'mixed-decimal-behavior-consolidation.json').write_text(json.dumps(output,indent=2)+'\n')
print('Consolidated',len(rows),'decimal test bodies into adapters of canonical funded tests.')
print('Decimal adapter lines:',sum(row['before_lines'] for row in rows),'->',sum(row['after_lines'] for row in rows))
