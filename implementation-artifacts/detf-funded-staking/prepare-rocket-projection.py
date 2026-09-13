"""Prepare current-source Rocket Pool quote changes without modifying Solidity."""
from pathlib import Path
import difflib, hashlib, json
art = Path(__file__).resolve().parent
root = art.parent.parent
changes = {}
base = 'contracts/protocols/staking/rocket-pool/'

def save(path, after):
    changes[path] = ((root/path).read_text(), after)

path = base+'RocketPoolRETHStandardExchangeInTarget.sol'
text = (root/path).read_text().replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRocketStorage} from "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRocketStorage.sol";
import {IRETH} from "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRETH.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterMath} from "@crane/contracts/utils/math/BetterMath.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {VaultFeeOracleQueryAwareRepo} from "contracts/oracles/fee/VaultFeeOracleQueryAwareRepo.sol";
import {RocketPoolRETHStandardExchangeRepo} from "contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeRepo.sol";''')
text = text.replace('    IStandardExchangeIn\n','    IStandardExchangeIn,\n    IStandardExchangeTransitionQuote,\n    IStandardExchangeExternalQuote\n')
assert text.endswith('}\n')
save(path, text[:-2]+(art/'pending-rocket-transition-methods.sol.txt').read_text()+'\n}\n')

path = base+'RocketPoolRETHStandardExchangeInFacet.sol'
text = (root/path).read_text().replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";''')
text = text.replace('interfaces = new bytes4[](1);','interfaces = new bytes4[](3);')
text = text.replace('interfaces[0] = type(IStandardExchangeIn).interfaceId;', '''interfaces[0] = type(IStandardExchangeIn).interfaceId;
        interfaces[1] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[2] = type(IStandardExchangeExternalQuote).interfaceId;''')
text = text.replace('funcs = new bytes4[](2);','funcs = new bytes4[](9);')
text = text.replace('funcs[1] = IStandardExchangeIn.exchangeIn.selector;', '''funcs[1] = IStandardExchangeIn.exchangeIn.selector;
        funcs[2] = IStandardExchangeTransitionQuote.quoteState.selector;
        funcs[3] = IStandardExchangeTransitionQuote.quoteAssets.selector;
        funcs[4] = IStandardExchangeTransitionQuote.quoteShareBalance.selector;
        funcs[5] = IStandardExchangeTransitionQuote.quoteTotalSupply.selector;
        funcs[6] = IStandardExchangeTransitionQuote.quoteTransition.selector;
        funcs[7] = IStandardExchangeExternalQuote.quoteExternalDeposit.selector;
        funcs[8] = IStandardExchangeExternalQuote.quoteExternalExchange.selector;''')
save(path,text)

path = base+'interfaces/IRocketPoolRETHStandardExchangeDFPkg.sol'
text = (root/path).read_text().replace('    error ZeroAddress();','    error ZeroAddress();\n    error InvalidPackageArguments();\n    error InvalidProtocolBinding();')
text = text.replace('        address depositPool;','        address depositPool;\n        address rocketStorage;')
text = text.replace('function deployVault(address rETH, address weth, address depositPool)', 'function deployVault(address rETH, address weth, address depositPool, address rocketStorage)')
save(path,text)

path = base+'RocketPoolRETHStandardExchangeRepo.sol'
text = (root/path).read_text().replace('        address depositPool;', '        address depositPool;\n        address rocketStorage;')
text = text.replace('_initialize(address rETH_, address weth_, address depositPool_)', '_initialize(address rETH_, address weth_, address depositPool_, address rocketStorage_)')
text = text.replace('        s.depositPool = depositPool_;','        s.depositPool = depositPool_;\n        s.rocketStorage = rocketStorage_;')
text = text[:-2]+'''    function _rocketStorage() internal view returns (address) {
        return _layout().rocketStorage;
    }
}
'''
save(path,text)

path = base+'RocketPoolRETHStandardExchangeDFPkg.sol'
text = (root/path).read_text().replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IRocketStorage} from "@crane/contracts/protocols/staking/ethereum/rocket-pool/interfaces/IRocketStorage.sol";''')
text = text.replace('function deployVault(address rETH_, address weth_, address depositPool_)', 'function deployVault(address rETH_, address weth_, address depositPool_, address rocketStorage_)')
text = text.replace('depositPool_ == address(0))','depositPool_ == address(0) || rocketStorage_ == address(0))')
text = text.replace('PkgArgs({rETH: rETH_, weth: weth_, depositPool: depositPool_})', 'PkgArgs({rETH: rETH_, weth: weth_, depositPool: depositPool_, rocketStorage: rocketStorage_})')
text = text.replace('interfaces = new bytes4[](10);','interfaces = new bytes4[](12);')
text = text.replace('interfaces[9] = type(IStandardizedYield).interfaceId;', '''interfaces[9] = type(IStandardizedYield).interfaceId;
        interfaces[10] = type(IStandardExchangeTransitionQuote).interfaceId;
        interfaces[11] = type(IStandardExchangeExternalQuote).interfaceId;''')
text = text.replace('RocketPoolRETHStandardExchangeRepo._initialize(args.rETH, args.weth, args.depositPool);','RocketPoolRETHStandardExchangeRepo._initialize(args.rETH, args.weth, args.depositPool, args.rocketStorage);')
old = '''    function processArgs(bytes memory pkgArgs) public pure returns (bytes memory) {
        return pkgArgs;
    }'''
new = '''    function processArgs(bytes memory pkgArgs) public view returns (bytes memory) {
        PkgArgs memory args = abi.decode(pkgArgs, (PkgArgs));
        if (keccak256(pkgArgs) != keccak256(abi.encode(args))) revert InvalidPackageArguments();
        if (args.rETH == address(0) || args.weth == address(0) || args.depositPool == address(0)
            || args.rocketStorage == address(0)) revert ZeroAddress();
        IRocketStorage registry = IRocketStorage(args.rocketStorage);
        if (registry.getAddress(keccak256("contract.addressrocketTokenRETH")) != args.rETH
            || registry.getAddress(keccak256("contract.addressrocketDepositPool")) != args.depositPool) {
            revert InvalidProtocolBinding();
        }
        return pkgArgs;
    }'''
assert text.count(old)==1
save(path,text.replace(old,new))

path = base+'RocketPoolRETH_Component_FactoryService.sol'
text = (root/path).read_text()
for name in ['RocketPoolRETHStandardExchangeInFacet','RocketPoolRETHStandardExchangeOutFacet','RocketPoolRETHMarkerFacet','RocketPoolRETHRebalanceFacet']:
    import re
    pattern = r'        instance = create3Factory.deployFacet\(\s*ArtifactCreationCode.creationCode\("'+name+r'.sol:'+name+r'"\),\s*abi.encode\("'+name+r'"\)._hash\(\)\s*\);'
    replacement = f'''        bytes memory code = ArtifactCreationCode.creationCode("{name}.sol:{name}");
        instance = create3Factory.deployFacet(code, keccak256(abi.encode("{name}", keccak256(code))));'''
    text,count = re.subn(pattern,replacement,text)
    assert count==1,name
start = text.index('        instance = IRocketPoolRETHStandardExchangeDFPkg(')
end = text.index('        vm.label(address(instance), "RocketPoolRETHStandardExchangeDFPkg");',start)
text = text[:start]+'''        bytes memory code = ArtifactCreationCode.creationCode("RocketPoolRETHStandardExchangeDFPkg.sol:RocketPoolRETHStandardExchangeDFPkg");
        bytes memory arguments = abi.encode(pkgInit);
        bytes32 releaseSalt = keccak256(abi.encode("RocketPoolRETHStandardExchangeDFPkg", keccak256(code), keccak256(arguments)));
        instance = IRocketPoolRETHStandardExchangeDFPkg(address(
            IVaultRegistryDeployment(address(indexedexManager)).deployPkg(code, arguments, releaseSalt)
        ));
'''+text[end:]
save(path,text)

path = base+'test/hermetic/HermeticRocketPoolPorts.sol'
text = (root/path).read_text()+'''
/// @dev External registry port for deployment binding only. This does not model
/// canonical deposit settings, validator queues or transition quote behavior.
contract HermeticRocketStorage {
    mapping(bytes32 => address) private addresses;

    constructor(address reth, address pool) {
        addresses[keccak256("contract.addressrocketTokenRETH")] = reth;
        addresses[keccak256("contract.addressrocketDepositPool")] = pool;
    }

    function getAddress(bytes32 key) external view returns (address) { return addresses[key]; }
}
'''
save(path,text)

path = 'contracts/test/bases/TestBase_RocketPoolRETHStandardExchange.sol'
text = (root/path).read_text().replace('    HermeticDepositPool\n','    HermeticDepositPool,\n    HermeticRocketStorage\n')
text = text.replace('    HermeticDepositPool public hermeticPool;', '    HermeticDepositPool public hermeticPool;\n    HermeticRocketStorage public hermeticRegistry;')
text = text.replace('        hermeticPool = new HermeticDepositPool(hermeticReth);','        hermeticPool = new HermeticDepositPool(hermeticReth);\n        hermeticRegistry = new HermeticRocketStorage(address(hermeticReth), address(hermeticPool));')
text = text.replace('deployVault(address(hermeticReth), address(hermeticWeth), address(hermeticPool))','deployVault(address(hermeticReth), address(hermeticWeth), address(hermeticPool), address(hermeticRegistry))')
save(path,text)

path = 'test/foundry/spec/protocol/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol'
text = (root/path).read_text().replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {HermeticRocketStorage} from "contracts/protocols/staking/rocket-pool/test/hermetic/HermeticRocketPoolPorts.sol";''')
text = text.replace('deployVault(address(reth2), address(hostile), address(pool2))','deployVault(address(reth2), address(hostile), address(pool2), address(new HermeticRocketStorage(address(reth2), address(pool2))))')
save(path,text)

path = 'test/foundry/fork/eth_main/vaults/staking/rocket-pool/RocketPoolRETHStandardExchange_Fork.t.sol'
text = (root/path).read_text().replace('deployVault(MAINNET_RETH, MAINNET_WETH, depositPool)','deployVault(MAINNET_RETH, MAINNET_WETH, depositPool, MAINNET_ROCKET_STORAGE)')
text = text.replace('pragma solidity ^0.8.0;', '''pragma solidity ^0.8.0;
import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IStandardExchangeTransitionQuote, IStandardExchangeExternalQuote} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {TransitionQuoteAssertions} from "test/foundry/spec/vaults/standard/TransitionQuoteAssertions.sol";''')
save(path,text+(art/'pending-rocket-projection-tests.sol.txt').read_text())

patch = ''.join(''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+path,tofile='b/'+path)) for path,(before,after) in changes.items())
(art/'rocket-projection.patch').write_text(patch)
record = {'status':'PREPARED_NOT_APPLIED','source_freeze':'Wait for complete validation session 52340 and its child Forge processes to exit.','reason':'Exact existing Rocket Pool SE composition needs canonical protocol settings, capacity and collateral inputs. Existing Rocket Pool PRD deployment sketch permits rocketStorage.','deployment_change':'Append rocketStorage to per-instance PkgArgs/deployVault, validate existing rETH/depositPool bindings against it, and retain the same 10 facets and registry architecture.','projection_scope':'Actual deposit-pool versions 3 and 4, one-pass soft sleeve staking, funded usage-fee SE receipts, exact oracle conversions, collateral-limited burns and separate holder/external operations.','evidence':'rocket-projection-input-preflight.json is read-only state evidence, not execution validation.','source_references':['https://raw.githubusercontent.com/rocket-pool/rocketpool/v1.3.1/contracts/contract/deposit/RocketDepositPool.sol','lib/crane/contracts/external/rocketpool/contract/deposit/RocketDepositPool.sol','lib/crane/contracts/external/rocketpool/contract/token/RocketTokenRETH.sol'],'changes':[{'path':path,'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(after.encode()).hexdigest()} for path,(before,after) in changes.items()],'required_validation':['Current-source build and EIP-170 sizes','Existing hermetic SE/native SY/adversarial tests','Pinned actual protocol full-state quote sequences, nonzero deposit fee, queue assignment, soft failure and collateral burn','Deployment binding negatives and stale-code salt regression']}
record['fork_blocks'] = {'deposit_pool_v3': 24000000, 'deposit_pool_v4': 25934585}
record['preflight_records'] = ['rocket-projection-input-preflight.json', 'rocket-projection-input-preflight-25934585.json']
record['required_actual_protocol_executions'] = 14
record['draft_diagnostics'] = {}
for kind, label, report_name in [('production','rocket-draft','rocket-draft-compile.json'),
                                  ('typecheck','rocket-draft-test','rocket-draft-test-typecheck.json')]:
    input_file = art/(label+'-compiler-input.json')
    report_file = art/report_name
    if input_file.exists() and report_file.exists():
        diagnostic = json.loads(report_file.read_text())
        wanted = {p:{'content':after} for p,(_,after) in changes.items()
                  if kind == 'typecheck' or (p.startswith(base) and '/test/' not in p)}
        matches = (json.loads(input_file.read_text())['sources'] == wanted
                   and hashlib.sha256(input_file.read_bytes()).hexdigest() == diagnostic.get('compiler_input_sha256'))
        record['draft_diagnostics'][kind] = {'record':report_name,'source_matches_prepared_patch':matches,
            'errors':diagnostic.get('errors'), 'runtime_bytes':diagnostic.get('runtime_bytes'),
            'limitation':'In-memory diagnostic only, not Forge artifact or actual protocol validation.'}
(art/'rocket-projection-prepared.json').write_text(json.dumps(record,indent=2)+'\n')
print('Prepared',len(changes),'sources; no Solidity changed.')
