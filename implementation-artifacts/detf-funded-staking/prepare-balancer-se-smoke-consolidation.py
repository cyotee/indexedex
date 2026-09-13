"""Move obsolete mock package smoke assertions into the existing production-path fixture."""
from pathlib import Path
from datetime import datetime, timezone
import difflib,hashlib,json,re

art=Path(__file__).resolve().parent;root=art.parent.parent
base='test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/'
drafts=art/'balancer-se-smoke-drafts';drafts.mkdir(exist_ok=False)
changes=[]
def save(path,after,reason):
    source=root/path;before=source.read_text();assert before!=after
    draft=drafts/(source.name+'.txt');draft.write_text(after)
    changes.append({'path':path,'draft':str(draft.relative_to(root)),'reason':reason,
        'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(after.encode()).hexdigest()})

oldpath=base+'StandardExchangeBufferPoolPkg_Smoke.t.sol'
names=re.findall(r'function (test_\w+)\(', (root/oldpath).read_text());assert len(names)==7
save(oldpath,'''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// The seven package declarations are exercised in TestBase_Smoke.t.sol using
// the existing manager/registry deployment and real facets. The former package
// constructed with mock addresses is retired; no declaration coverage is lost.
''','Retire the mock-address DFPkg constructor suite after moving all seven declarations into the existing production-path smoke suite.')

path=base+'TestBase_Smoke.t.sol';text=(root/path).read_text()
imports='''
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {StandardExchangeBufferPoolStandardVaultPkg} from
    "contracts/protocols/dexes/balancer/v3/pools/constProd/standardExchange/StandardExchangeBufferPoolStandardVaultPkg.sol";
'''
text=text.replace('pragma solidity ^0.8.0;','pragma solidity ^0.8.0;\n'+imports)
body='''
    /// @notice The registered package retains its eleven actual production facets.
    function test_facetAddresses_length() public view {
        assertEq(bufferPoolPkg.facetAddresses().length, 11);
    }

    /// @notice Existing declarations include standard exchange and native Pendle SY on the live pool.
    function test_facetInterfaces_length() public view {
        bytes4[] memory interfaces = bufferPoolPkg.facetInterfaces();
        assertEq(interfaces.length, 18);
        assertEq(interfaces[15], type(IStandardExchangeIn).interfaceId);
        assertEq(interfaces[16], type(IStandardExchangeOut).interfaceId);
        assertEq(interfaces[17], type(IStandardizedYield).interfaceId);
        for (uint256 i; i < interfaces.length; ++i) {
            assertTrue(IERC165(bufferPool).supportsInterface(interfaces[i]), "live pool declares package interface");
        }
    }

    /// @notice Compare exact constructor bindings to the real deployed facet addresses.
    function test_facetAddresses_matchesInit() public view {
        address[11] memory expected = [address(multiAssetBasicVaultFacet), address(multiAssetStandardVaultFacet),
            address(balancerV3VaultAwareFacet), address(betterBalancerV3PoolTokenFacet), address(defaultPoolInfoFacet),
            address(standardSwapFeePercentageBoundsFacet), address(unbalancedLiquidityInvariantRatioBoundsFacet),
            address(balancerV3AuthenticationFacet), address(bufferPoolFacet), address(poolLiquidityFacet), address(hookFacet)];
        address[] memory actual = bufferPoolPkg.facetAddresses();
        for (uint256 i; i < expected.length; ++i) {
            assertEq(actual[i], expected[i], "registered constructor facet binding");
            assertGt(actual[i].code.length, 0, "actual facet bytecode");
        }
    }

    /// @notice The production package publishes the expected stable name.
    function test_packageName_notEmpty() public view {
        assertEq(bufferPoolPkg.packageName(), "StandardExchangeBufferPoolStandardVaultPkg");
    }

    /// @notice Registry and package names agree.
    function test_name_matchesPackageName() public view {
        assertEq(bufferPoolPkg.name(), bufferPoolPkg.packageName());
    }

    /// @notice The registered package uses the current real manager registry.
    function test_vaultRegistry_immutable() public view {
        assertEq(address(StandardExchangeBufferPoolStandardVaultPkg(address(bufferPoolPkg)).VAULT_REGISTRY()), address(indexedexManager));
    }

    /// @notice Balancer accounting is bound to the actual deployed protocol vault.
    function test_balancerV3Vault_immutable() public view {
        assertEq(address(StandardExchangeBufferPoolStandardVaultPkg(address(bufferPoolPkg)).BALANCER_V3_VAULT()), address(bv3Vault));
    }
'''
text=text.rstrip();assert text.endswith('}');text=text[:-1]+body+'}\n'
save(path,text,'Consolidate every former declaration into the retained real registry/protocol fixture and check the installed interfaces.')

path=base+'bases/TestBase_StandardExchangeBufferPool.sol';text=(root/path).read_text()
text=text.replace('// These three facets are deployed directly (no FactoryService helper needed).',
    '// Use the same CREATE3 deployment path for these retained protocol facets.')
for name in ('DefaultPoolInfoFacet','StandardSwapFeePercentageBoundsFacet','StandardUnbalancedLiquidityInvariantRatioBoundsFacet'):
    old='IFacet(address(new '+name+'()))';assert text.count(old)==1
    text=text.replace(old,'create3Factory.deployFacet(vm.getCode("'+name+'.sol:'+name+'"), keccak256(abi.encode("'+name+'")))')
save(path,text,'Preserve the actual protocol fixture while deploying its remaining three facets through CREATE3 rather than constructors.')

record={'status':'PREPARED_NOT_APPLIED','recorded_at_utc':datetime.now(timezone.utc).isoformat(),
    'gate':'Entire active validation parent4255 must exit before applying.',
    'changes':changes,'validation_passed':False,'scope':'Balancer SE only; no Balancer-hosted DETF or Slipstream changes.'}
(art/'balancer-se-smoke-consolidation-prepared.json').write_text(json.dumps(record,indent=2)+'\n')
(art/'balancer-se-smoke-consolidation-map.json').write_text(json.dumps({'status':'PREPARED_NOT_APPLIED',
    'retirements':[{'old_source':oldpath,'old_function':name,'replacement_source':base+'TestBase_Smoke.t.sol',
        'replacement_function':name,'behavior':'Same declaration on actual registered package/proxy; fake SUT removed.'} for name in names]},indent=2)+'\n')
patch=''
for row in changes:
    patch+=''.join(difflib.unified_diff((root/row['path']).read_text().splitlines(True),(root/row['draft']).read_text().splitlines(True),
        fromfile='a/'+row['path'],tofile='b/'+row['path']))
(art/'balancer-se-smoke-consolidation.patch').write_text(patch)
print(json.dumps({'status':'PREPARED_NOT_APPLIED','sources':len(changes),'mapped_declarations':len(names)}))
