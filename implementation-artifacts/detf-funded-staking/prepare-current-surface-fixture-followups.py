"""Prepare current proxy/facet expectations without touching the active source snapshot."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, hashlib, json

art = Path(__file__).resolve().parent
root = art.parent.parent
drafts = art / 'current-surface-fixture-followup-drafts'
drafts.mkdir(exist_ok=False)
changes = []

def save(path, transform, reason):
    source = root / path
    before = source.read_text()
    after = transform(before)
    assert before != after, path
    draft = drafts / (source.name + '.txt')
    assert not draft.exists(), draft
    draft.write_text(after)
    changes.append({'path':path, 'draft':str(draft.relative_to(root)), 'reason':reason,
        'before_sha256':hashlib.sha256(before.encode()).hexdigest(),
        'after_sha256':hashlib.sha256(after.encode()).hexdigest()})

def replace(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new)

detf = 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/'
hooks = 'test/foundry/spec/hooks/uniswap/v4/standardExchange/'
sy_import = 'import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";\n'
sy_names = ['deposit','redeem','exchangeRate','yieldToken','assetInfo','getTokensIn','getTokensOut',
    'isValidTokenIn','isValidTokenOut','previewDeposit','previewRedeem','getRewardTokens',
    'accruedRewards','rewardIndexesCurrent','rewardIndexesStored','claimRewards']

def add_sy_control(text, old_count, new_count, label):
    text = replace(text, 'pragma solidity ^0.8.0;\n', 'pragma solidity ^0.8.0;\n\n' + sy_import)
    old = f'        assertEq(funcs_.length, {old_count}, "{label}");'
    lines = [f'        assertTrue(_contains(funcs_, IStandardizedYield.{name}.selector), "J1 SY {name}");' for name in sy_names]
    return replace(text, old, '\n'.join(lines) + f'\n        assertEq(funcs_.length, {new_count}, "{label}");')

def funded_surface(text):
    text = replace(text, 'new bytes4[](48)', 'new bytes4[](46)')
    text = replace(text, 'assertEq(count, 48,', 'assertEq(count, 46,')
    text = replace(text, 'bytes4[8] memory retired_', 'bytes4[10] memory retired_')
    return replace(text, 'bytes4(keccak256("thresholdMode()")),',
        'bytes4(keccak256("thresholdMode()")),\n            bytes4(keccak256("closeRouteMode()")),\n            bytes4(keccak256("closeRoutes()")),')
save(detf+'UniswapV4Detf_FacetPackaging.t.sol', funded_surface,
    'Owner-approved close getters absent; all 46 current selectors remain unique and route to their CREATE3 facets.')
save(detf+'UniswapV4Detf_BondNftPackaging.t.sol',
    lambda text:replace(replace(text,
        'import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";',
        'import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";'),
        'IDETFNFTVault.createPosition.selector','IDetfBondNFT.createFundedPosition.selector'),
    'Find the live funded position facet; preserve generic ERC721 and guarded transfer assertions.')

def cp_surface(text):
    for old,new in [('funcs_.length, 46, "J1 SeFacet','funcs_.length, 47, "J1 SeFacet'),
        ('single_.length, 5,','single_.length, 7,'),('preview_.length, 8,','preview_.length, 10,'),
        ('funcs_.length, 19,','funcs_.length, 23,')]: text=replace(text,old,new)
    return add_sy_control(text,13,29,'J1 WithdrawFacet facetFuncs length')
save(hooks+'constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_Surface.t.sol',
    cp_surface,'Retain deposit partition/disjointness and loupe checks; assert every Pendle selector on the withdrawal facet.')
save(hooks+'dual/UniswapV4DualSEBCPHook_Surface.t.sol',
    lambda text:add_sy_control(text,6,22,'J1 SeFacet facetFuncs length'),
    'Assert all sixteen native SY methods alongside the existing six SE/owner-swap selectors.')

def orbital_surface(text):
    text = add_sy_control(text,6,22,'J1 SeFacet facetFuncs length')
    text = replace(text,'    IFacet internal depositFacet;','    IFacet internal depositFacet;\n    IFacet internal depositQueryFacet;\n    IFacet internal depositZapFacet;')
    text = replace(text,'        depositFacet = PkgFactory.deployDepositFacet(create3Factory);',
        '        depositFacet = PkgFactory.deployDepositFacet(create3Factory);\n        depositQueryFacet = hookPkg.DEPOSIT_QUERY_FACET();\n        depositZapFacet = hookPkg.DEPOSIT_ZAP_FACET();')
    text = replace(text,'        assertTrue(_contains(funcs_, IHook.radius.selector), "J1 radius");',
        '        assertTrue(_contains(depositQueryFacet.facetFuncs(), IHook.radius.selector), "J1 radius query");')
    text = replace(text,'funcs_.length, 45, "J1 HooksFacet','funcs_.length, 46, "J1 HooksFacet')
    start = text.index('    function test_J1_deposit_targetSelectors_subseteq_facetFuncs()')
    end = text.index('    function test_J1_withdraw_', start)
    old = text[start:end]
    # Keep the original interface checks, but bind each selector to its actual split facet.
    new = old.replace('        bytes4[] memory funcs_ = depositFacet.facetFuncs();',
        '        bytes4[] memory funcs_ = depositFacet.facetFuncs();\n        bytes4[] memory queries_ = depositQueryFacet.facetFuncs();\n        bytes4[] memory zaps_ = depositZapFacet.facetFuncs();')
    for name in ['previewAddLiquidity','previewDepositSingle','previewZapSplit','previewDepositFlexible']:
        new = new.replace('_contains(funcs_, IHook.'+name, '_contains(queries_, IHook.'+name)
    new = new.replace('_contains(funcs_, IHook.depositSingle', '_contains(zaps_, IHook.depositSingle')
    new = new.replace('_contains(funcs_, IUniswapV4SeBufferHook.joinSingleAssetExactIn',
        '_contains(zaps_, IUniswapV4SeBufferHook.joinSingleAssetExactIn')
    new = replace(new, '        assertEq(funcs_.length, 16, "J1 DepositFacet facetFuncs length");',
        '        assertEq(funcs_.length, 4, "J1 deposit execution selectors");\n        assertEq(queries_.length, 11, "J1 deposit query selectors");\n        assertEq(zaps_.length, 3, "J1 deposit zap selectors");')
    text = replace(text,old,new)
    text = replace(text,'        _assertFacetFuncsOnLoupe(depositFacet, address(depositFacet));',
        '        _assertFacetFuncsOnLoupe(depositFacet, address(depositFacet));\n        _assertFacetFuncsOnLoupe(depositQueryFacet, address(depositQueryFacet));\n        _assertFacetFuncsOnLoupe(depositZapFacet, address(depositZapFacet));')
    return replace(text,'assertEq(loupeHooks_, address(hooksFacet), "J3 radius loupe");',
        'assertEq(loupeHooks_, address(depositQueryFacet), "J3 radius loupe");')
save(hooks+'orbital/UniswapV4StandardExchangeOrbitalBufferHook_Surface.t.sol',orbital_surface,
    'Cover every split deposit facet on the live proxy and the complete native SY surface; radius belongs to deposit queries.')

def staged(text):
    text=replace(text,'        cuts = new IDiamond.FacetCut[](8);',
        '        cuts = new IDiamond.FacetCut[](adds.length + 1);')
    old='\n'.join(f'        cuts[{i+1}] = adds[{i}];' for i in range(7))
    return replace(text,old,'        for (uint256 i; i < adds.length; ++i) cuts[i + 1] = adds[i];')
for family,stem in [('weighted','UniswapV4StandardExchangeWeightedBufferHook'),
        ('orbital','UniswapV4StandardExchangeOrbitalBufferHook'),
        ('stable/quad/curve','UniswapV4StandardExchangeCurveQuadStableBufferHook')]:
    def stage_transform(text, family=family):
        text=staged(text)
        if family=='stable/quad/curve':
            text=replace(text,'assertEq(prod.length, 7);','assertEq(prod.length, 8);')
            text=replace(text,'        assertEq(prod[6].facetAddress, address(erc2612Facet));',
                '        assertEq(prod[6].facetAddress, address(erc2612Facet));\n        assertEq(prod[7].facetAddress, address(hookPkg.JOIN_QUERY_FACET()));')
            text=replace(text,'assertEq(ifaces.length, 11);','assertEq(ifaces.length, 12);')
        return text
    save(hooks+family+'/'+stem+'_StagedInit.t.sol',stage_transform,
        'Expected DiamondCut includes every current production facet, then the unchanged InitializationFinalized event.')

def orbital_package(text):
    text=replace(text,'pragma solidity ^0.8.0;\n','pragma solidity ^0.8.0;\n\n'+sy_import)
    text=replace(text,'assertEq(cuts.length, 7);','assertEq(cuts.length, 9);')
    text=replace(text,'        assertEq(cuts[6].facetAddress, address(erc2612Facet));',
        '        assertEq(cuts[6].facetAddress, address(erc2612Facet));\n        assertEq(cuts[7].facetAddress, address(hookPkg.DEPOSIT_QUERY_FACET()));\n        assertEq(cuts[8].facetAddress, address(hookPkg.DEPOSIT_ZAP_FACET()));')
    text=replace(text,'        _assertSelectorsEq(cuts[6].functionSelectors, erc2612Facet.facetFuncs());',
        '        _assertSelectorsEq(cuts[6].functionSelectors, erc2612Facet.facetFuncs());\n        _assertSelectorsEq(cuts[7].functionSelectors, hookPkg.DEPOSIT_QUERY_FACET().facetFuncs());\n        _assertSelectorsEq(cuts[8].functionSelectors, hookPkg.DEPOSIT_ZAP_FACET().facetFuncs());')
    text=replace(text,'assertEq(ids.length, 12);','assertEq(ids.length, 13);')
    text=replace(text,'        assertEq(ids[11], type(IDetfReserveQuote).interfaceId);',
        '        assertEq(ids[11], type(IDetfReserveQuote).interfaceId);\n        assertEq(ids[12], type(IStandardizedYield).interfaceId);')
    text=replace(text,'assertEq(facets.length, 11);','assertEq(facets.length, 13);')
    return replace(text,'        assertEq(facets[10], address(erc2612Facet));',
        '        assertEq(facets[10], address(erc2612Facet));\n        assertEq(facets[11], address(hookPkg.DEPOSIT_QUERY_FACET()));\n        assertEq(facets[12], address(hookPkg.DEPOSIT_ZAP_FACET()));')
save(hooks+'orbital/UniswapV4StandardExchangeOrbitalBufferHook_PackageDecl.t.sol',orbital_package,
    'Keep exact package declaration ordering, expanded with the two split deposit facets and Pendle interface.')

def quad_surface(text):
    text=replace(text,'bytes4[] memory queries = new bytes4[](26);','bytes4[] memory queries = new bytes4[](27);')
    return replace(text,'        _assertInstalledHookFacet(queries);',
        '        queries[26] = IDetfReserveQuote.previewJoinAfterDeposit.selector;\n        _assertInstalledHookFacet(queries);')
save(detf+'UniswapV4Detf_Quad_Adversarial_Surface.t.sol',quad_surface,
    'Retain exact facet membership and retired-claim negatives while including funded deposit projection.')

record={'status':'PREPARED_NOT_APPLIED','recorded_at_utc':datetime.now(timezone.utc).isoformat(),
    'gate':'Do not apply until entire active validation parent4255 has exited.',
    'scope':'Existing in-scope V4 tests only; every declaration retained. No product, Balancer DETF, or Slipstream change.',
    'changes':changes,'validation_passed':False}
(art/'current-surface-fixture-followups-prepared.json').write_text(json.dumps(record,indent=2)+'\n')
patch=''
for row in changes:
    patch+=''.join(difflib.unified_diff((root/row['path']).read_text().splitlines(True),
        (root/row['draft']).read_text().splitlines(True),fromfile='a/'+row['path'],tofile='b/'+row['path']))
(art/'current-surface-fixture-followups.patch').write_text(patch)
print(json.dumps({'status':record['status'],'sources':len(changes),'canonical_sources_unchanged':True}))
