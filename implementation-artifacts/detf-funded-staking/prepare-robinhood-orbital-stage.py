"""Prepare the missing current Orbital package stage; do not apply during Forge."""
from pathlib import Path
import difflib,json
r=Path.cwd();a=r/'implementation-artifacts/detf-funded-staking';root=Path('scripts/foundry/anvil_robinhood_main');changes={}
def edit(p,fn):
 s=p.read_text();n=fn(s);assert n!=s,p;changes[p]=(s,n)
def add(p,n):
 assert not p.exists(),p;changes[p]=('',n)
def replace_once(s,x,y):
 assert s.count(x)==1,(x,s.count(x));return s.replace(x,y)
p=root/'Phase_06_Stage_05_OrbitalBufferHookPkg.sol';s=Path('scripts/foundry/anvil_robinhood_testnet/Phase_06_Stage_05_OrbitalBufferHookPkg.sol').read_text()
s=s.replace('import {IFacet}', 'import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";\n\nimport {IFacet}',1)
s=replace_once(s,'''        s.orbitalHookPkg = reg.deployPkg(
            type(OrbitalHookDFPkg).creationCode,
            abi.encode(init_),
            abi.encode(type(IOrbitalHookPkg).name, FixtureEconomics.SALT_NS)._hash()
        );''','''        bytes memory code = type(OrbitalHookDFPkg).creationCode;
        bytes memory args = abi.encode(init_);
        s.orbitalHookPkg = reg.deployPkg(
            code, args,
            ArtifactCreationCode.releaseSalt(abi.encode(type(IOrbitalHookPkg).name, FixtureEconomics.SALT_NS)._hash(), code, args)
        );''');add(p,s)
p=root/'Phase_06_Stage_05_OrbitalBufferHookPkg.s.sol';s=(root/'Phase_06_Stage_04_WeightedBufferHookPkg.s.sol').read_text();s=s.replace('04','05').replace('Weighted','Orbital').replace('weighted','orbital');add(p,s)
edit(root/'LaunchState.sol',lambda s:replace_once(s,'    address weightedHookPkg;','    address weightedHookPkg;\n    address orbitalHookPkg;'))
def io(s):
 s=replace_once(s,'    string internal constant FILE_06_04 = "phase06_stage04_weighted_buffer_hook_pkg.json";','    string internal constant FILE_06_04 = "phase06_stage04_weighted_buffer_hook_pkg.json";\n    string internal constant FILE_06_05 = "phase06_stage05_orbital_buffer_hook_pkg.json";')
 s=replace_once(s,'        _exportPkg("p0604", FILE_06_04, "weightedHookPkg", s.weightedHookPkg);','        _exportPkg("p0604", FILE_06_04, "weightedHookPkg", s.weightedHookPkg);\n        _exportPkg("p0605", FILE_06_05, "orbitalHookPkg", s.orbitalHookPkg);')
 s=replace_once(s,'        require(_hasCode(s.weightedHookPkg), "run Phase 06 Stage 04 first");','        require(_hasCode(s.weightedHookPkg), "run Phase 06 Stage 04 first");\n        s.orbitalHookPkg = _loadAddr(FILE_06_05, "orbitalHookPkg");\n        require(_hasCode(s.orbitalHookPkg), "run Phase 06 Stage 05 first");');return s
edit(root/'LaunchIo.sol',io)
edit(root/'Phase_09_Stage_01_ExportFrontend.s.sol',lambda s:replace_once(s,'        json = vm.serializeAddress("p", "weightedHookPkg", s.weightedHookPkg);','        json = vm.serializeAddress("p", "weightedHookPkg", s.weightedHookPkg);\n        json = vm.serializeAddress("p", "orbitalHookPkg", s.orbitalHookPkg);'))
def simulate(s):
 old='import {Phase_06_Stage_04_WeightedBufferHookPkg} from "./Phase_06_Stage_04_WeightedBufferHookPkg.sol";'
 s=replace_once(s,old,old+'\nimport {Phase_06_Stage_05_OrbitalBufferHookPkg} from "./Phase_06_Stage_05_OrbitalBufferHookPkg.sol";')
 old='        Phase_06_Stage_04_WeightedBufferHookPkg.execute(s);';return replace_once(s,old,old+'\n        Phase_06_Stage_05_OrbitalBufferHookPkg.execute(s);')
edit(root/'Script_SimulateArchitecture.s.sol',simulate)
edit(Path('scripts/shell/lib/rh_4663_stages.sh'),lambda s:replace_once(s.replace('# Stage 05-06 adds the mainnet V2 SE. Stage 06-05 (Orbital hook) stays unused.','# Stages 05-04/05-06 provide V3/V2 SE; 06-05 provides the current Orbital hook.'),'06 04\n06 06','06 04\n06 05\n06 06'))
edit(root/'deploy_all.sh',lambda s:replace_once(s,"'06 03'|'06 04'|'06 06'","'06 03'|'06 04'|'06 05'|'06 06'").replace('Run the 31 hook/backend integration cases against','Run the hook/backend integration matrix against'))
def docs(s):
 s=replace_once(s,'| 06 | 04 | `Phase_06_Stage_04_WeightedBufferHookPkg.s.sol` | Weighted buffer hook DFPkg |','| 06 | 04 | `Phase_06_Stage_04_WeightedBufferHookPkg.s.sol` | Weighted buffer hook DFPkg |\n| 06 | 05 | `Phase_06_Stage_05_OrbitalBufferHookPkg.s.sol` | Orbital buffer hook DFPkg |')
 s=s.replace('Stage numbers match 46630. 05-04 (Uni V3 SE) and 06-05 (Orbital hook) stay unused.','Stage numbers match 46630. V2/V3/V4 SE packages and all four V4 DETF reserve-hook families have current package stages.')
 return s.replace('minter facade, test tokens, Uni V3 rehearsal or SE package, Orbital hook, old family DETF packages','minter facade, test tokens, old family DETF packages')
edit(root/'README.md',docs)
p=Path('test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol')
def fork(s):
 begin=s.index('    function _currentOrbitalPackage()');end=s.index('    function _deployOrbital(',begin)
 s=s[:begin]+s[end:]
 return replace_once(s,'        IOrbitalPkg pkg = _currentOrbitalPackage();','        IOrbitalPkg pkg = IOrbitalPkg(_pin("phase06_stage05_orbital_buffer_hook_pkg.json", ".orbitalHookPkg", true));')
edit(p,fork)
patch=''.join(''.join(difflib.unified_diff(s.splitlines(True),n.splitlines(True),fromfile=str(p) if s else '/dev/null',tofile=str(p))) for p,(s,n) in changes.items())
(a/'robinhood-current-orbital-stage.patch').write_text(patch)
(a/'robinhood-current-orbital-stage-prepared.json').write_text(json.dumps({'status':'PREPARED_NOT_APPLIED','reason':'The approved fourth V4 reserve family lacks a Robinhood package stage/export; current rehearsal deploys its package inside the test instead of exercising a staged package pin. Reuse existing Orbital factory/package structure and current implementation-bound stage salts.','files':[str(p) for p in changes],'next':'Review and apply after active Forge exits; add stage replay/registry/facet coverage to existing StandardExchangeStages tests, then validate actual staged local deployment and lifecycle.','scope':'No production broadcast, Balancer DETF expansion or Slipstream work. Existing stage exports/other packages retained.'},indent=2)+'\n')
print(len(changes),'files prepared; current source files unchanged')
