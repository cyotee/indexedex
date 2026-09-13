"""Prepare query component wiring only; do not mutate current compiled sources."""
from pathlib import Path
import difflib,hashlib,json
p=Path(__file__).resolve().parent;root=p.parent.parent
base=Path('contracts/protocols/dexes/camelot/v2');changes=[]
def add(path,after):
 f=root/path;before=f.read_text() if f.exists() else '';changes.append((path,before,after))
add(base/'CamelotV2StandardExchangeQuoteTarget.sol',(p/'pending-camelot-transition-target.sol.txt').read_text())
s=(root/'contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeQueryFacet.sol').read_text()
s=s.replace('UniswapV2StandardExchange','CamelotV2StandardExchange').replace('dexes/uniswap/v2/','dexes/camelot/v2/')
add(base/'CamelotV2StandardExchangeQueryFacet.sol',s)
f=base/'CamelotV2StandardExchangeDFPkg.sol';s=(root/f).read_text()
s=s.replace('import {IStandardizedYield}', 'import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";\nimport {IStandardizedYield}',1)
s=s.replace('        IFacet camelotV2StandardExchangeOutFacet;','        IFacet camelotV2StandardExchangeOutFacet;\n        IFacet camelotV2StandardExchangeQueryFacet;',1)
s=s.replace('    IFacet immutable CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET;','    IFacet immutable CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET;\n    IFacet immutable CAMELOT_V2_STANDARD_EXCHANGE_QUERY_FACET;',1)
s=s.replace('        CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET = pkgInit.camelotV2StandardExchangeOutFacet;','        CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET = pkgInit.camelotV2StandardExchangeOutFacet;\n        CAMELOT_V2_STANDARD_EXCHANGE_QUERY_FACET = pkgInit.camelotV2StandardExchangeQueryFacet;',1)
s=s.replace('new address[](8)','new address[](9)',1).replace('        return facetAddresses_;','        facetAddresses_[8] = address(CAMELOT_V2_STANDARD_EXCHANGE_QUERY_FACET);\n        return facetAddresses_;',1)
s=s.replace('new bytes4[](12)','new bytes4[](14)',1).replace('        return interfaces;','        interfaces[12] = type(IStandardExchangeTransitionQuote).interfaceId;\n        interfaces[13] = type(IStandardExchangeExternalQuote).interfaceId;\n        return interfaces;',1)
s=s.replace('new IDiamond.FacetCut[](8)','new IDiamond.FacetCut[](9)',1)
needle='''            functionSelectors: CAMELOT_V2_STANDARD_EXCHANGE_OUT_FACET.facetFuncs()
        });'''
assert s.count(needle)==1;s=s.replace(needle,needle+'''
        facetCuts_[8] = IDiamond.FacetCut({
            facetAddress: address(CAMELOT_V2_STANDARD_EXCHANGE_QUERY_FACET),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: CAMELOT_V2_STANDARD_EXCHANGE_QUERY_FACET.facetFuncs()
        });''',1)
add(f,s)
f=base/'CamelotV2_Component_FactoryService.sol';s=(root/f).read_text();start=s.index('    function deployCamelotV2StandardExchangeInFacet(')
s=s[:start]+'''    function _deployFacet(ICreate3FactoryProxy factory_, string memory name_) private returns (IFacet instance) {
        bytes memory code = ArtifactCreationCode.creationCode(string.concat(name_, ".sol:", name_));
        instance = factory_.deployFacet(code, ArtifactCreationCode.releaseSalt(abi.encode(name_)._hash(), code, ""));
        vm.label(address(instance), name_);
    }

    function deployCamelotV2StandardExchangeInFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_, "CamelotV2StandardExchangeInFacet");
    }

    function deployCamelotV2StandardExchangeOutFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_, "CamelotV2StandardExchangeOutFacet");
    }

    function deployCamelotV2StandardExchangeQueryFacet(ICreate3FactoryProxy factory_) internal returns (IFacet) {
        return _deployFacet(factory_, "CamelotV2StandardExchangeQueryFacet");
    }

    function deployCamelotV2StandardExchangeDFPkg(
        IVaultRegistryDeployment registry_, ICamelotV2StandardExchangeDFPkg.PkgInit memory init_
    ) internal returns (ICamelotV2StandardExchangeDFPkg instance) {
        bytes memory code = ArtifactCreationCode.creationCode("CamelotV2StandardExchangeDFPkg.sol:CamelotV2StandardExchangeDFPkg");
        bytes memory args = abi.encode(init_);
        instance = ICamelotV2StandardExchangeDFPkg(address(registry_.deployPkg(
            code, args, ArtifactCreationCode.releaseSalt(abi.encode("CamelotV2StandardExchangeDFPkg")._hash(), code, args)
        )));
        vm.label(address(instance), "CamelotV2StandardExchangeDFPkg");
    }
}
''';add(f,s)
f=base/'TestBase_CamelotV2StandardExchange.sol';s=(root/f).read_text()
s=s.replace('    IFacet camelotV2StandardExchangeOutFacet;','    IFacet camelotV2StandardExchangeOutFacet;\n    IFacet camelotV2StandardExchangeQueryFacet;',1)
s=s.replace('        camelotV2StandardExchangeOutFacet = create3Factory.deployCamelotV2StandardExchangeOutFacet();','        camelotV2StandardExchangeOutFacet = create3Factory.deployCamelotV2StandardExchangeOutFacet();\n        camelotV2StandardExchangeQueryFacet = create3Factory.deployCamelotV2StandardExchangeQueryFacet();',1)
s=s.replace('            camelotV2StandardExchangeOutFacet: camelotV2StandardExchangeOutFacet,','            camelotV2StandardExchangeOutFacet: camelotV2StandardExchangeOutFacet,\n            camelotV2StandardExchangeQueryFacet: camelotV2StandardExchangeQueryFacet,',1);add(f,s)
f=Path('scripts/foundry/anvil_base_main/Script_04_DeployDEXPackages.s.sol');s=(root/f).read_text();needle='        init.camelotV2StandardExchangeOutFacet = create3Factory.deployCamelotV2StandardExchangeOutFacet();';assert s.count(needle)==1;s=s.replace(needle,needle+'\n        init.camelotV2StandardExchangeQueryFacet = create3Factory.deployCamelotV2StandardExchangeQueryFacet();',1);add(f,s)
patch=''.join(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+str(f) if before else '/dev/null',tofile='b/'+str(f))) for f,before,after in changes)
(p/'camelot-projection-wiring.patch').write_text(patch)
(p/'camelot-projection-wiring-prepared.json').write_text(json.dumps({'status':'PREPARED_NOT_APPLIED_NOT_COMPILED','files':[{'path':str(f),'before_sha256':hashlib.sha256(before.encode()).hexdigest() if before else None,'after_sha256':hashlib.sha256(after.encode()).hexdigest()} for f,before,after in changes],'wiring':'Dedicated query target/facet, two interfaces/seven selectors, 9 package facets and 14 interfaces. Existing 27-decimal native SE and user PkgArgs remain unchanged. All three facets and package bind code/constructor to release salts.','before_application':'Confirm and fix the existing checkpoint/LP-preview defects using actual proxy regressions; finish projection tests and review protocol fee/zap behavior. Refresh this patch if its recorded source hashes change.','scope':'No Slipstream or Balancer DETF edits. Constructor changes concern this Camelot SE query component only.'},indent=2)+'\n')
print('Prepared',len(changes),'Camelot query wiring sources; not applied.')
