"""Prepare, but do not apply, the scoped implementation-sensitive CREATE3 patch.

This keeps the first build's source stable until baseline regressions execute.
Run from the repository root. The resulting patch is reviewable with git apply
--stat and --check. It does not touch hook-instance salt calculations.
"""

import difflib
import re
from pathlib import Path

ROOT = Path(__file__).parent
changes = {}


def change(path, transform):
    path = Path(path)
    before = path.read_text()
    after = transform(before)
    assert before != after, str(path)
    changes[str(path)] = (before, after)


def functions(source, names, transform):
    for name in names:
        start = source.index('function ' + name + '(')
        body = source.index('{', start)
        depth = 1
        end = body + 1
        while depth:
            depth += (source[end] == '{') - (source[end] == '}')
            end += 1
        source = source[:body + 1] + transform(source[body + 1:end - 1]) + source[end - 1:]
    return source


def facet(body):
    pattern = r'(\w+) = create3Factory\.deployFacet\(\s*(.*?),\s*(abi\.encode\("[^"]+"\)\._hash\(\))\s*\);'
    def replacement(match):
        result, code, namespace = match.groups()
        return ('bytes memory initCode_ = ' + code + ';\n'
                '        ' + result + ' = create3Factory.deployFacet(\n'
                '            initCode_, ArtifactCreationCode.releaseSalt(' + namespace + ', initCode_, bytes(""))\n'
                '        );')
    result, n = re.subn(pattern, replacement, body, flags=re.S)
    assert n == 1, body
    return result


def package(body):
    pattern = r'(?:ArtifactCreationCode\.creationCode\("[^"]+"\)|type\(\w+\)\.creationCode)'
    code_match = re.search(pattern, body)
    assert code_match, body
    code = code_match.group()
    # Namespace hashes contain parentheses, so read the final argument with a
    # balanced scan instead of relying on regex for Solidity nesting.
    args_start = code_match.end() + body[code_match.end():].index(',') + 1
    args_end = body.index(',', args_start)
    args = body[args_start:args_end].strip()
    namespace_start = args_end + 1
    end = namespace_start
    depth = 0
    while True:
        char = body[end]
        if char == ')' and depth == 0:
            break
        depth += (char == '(') - (char == ')')
        end += 1
    namespace = body[namespace_start:end].strip()
    assert args.startswith('abi.encode('), args
    assert namespace, body
    line_start = body.rfind('\n', 0, code_match.start()) + 1
    indent = re.match(r' *', body[line_start:]).group()
    body = (body[:code_match.start()] + 'initCode_,\n'
            + indent + 'initArgs_,\n'
            + indent + 'ArtifactCreationCode.releaseSalt(' + namespace + ', initCode_, initArgs_)\n'
            + indent[:-4] + body[end:])
    return ('\n        bytes memory initCode_ = ' + code + ';\n'
            '        bytes memory initArgs_ = ' + args + ';\n' + body.lstrip('\n'))


def helper(source):
    insert = '''    /// @notice Bind a type-name namespace to the implementation and constructor.
    /// @dev CREATE3 itself reuses occupied salts without checking their code.
    ///      Product component deployments use this salt; instance salts do not.
    function releaseSalt(bytes32 namespace_, bytes memory initCode_, bytes memory initArgs_)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(namespace_, keccak256(initCode_), keccak256(initArgs_)));
    }

'''
    return source.replace('    function _containsUnlinkedPlaceholder', insert + '    function _containsUnlinkedPlaceholder')


change('contracts/utils/foundry/ArtifactCreationCode.sol', helper)

hook_root = Path('contracts/hooks/uniswap/v4/standardExchange')
for directory, stem in [
    ('constantProduct/single', 'UniswapV4SingleStandardExchangeBufferConstantProductHook'),
    ('weighted', 'UniswapV4StandardExchangeWeightedBufferHook'),
    ('orbital', 'UniswapV4StandardExchangeOrbitalBufferHook'),
    ('stable/quad/curve', 'UniswapV4StandardExchangeCurveQuadStableBufferHook'),
]:
    path = hook_root / directory / (stem + '_FactoryService.sol')
    def update(source):
        names = re.findall(r'function (deploy\w+Facet)\(', source)
        names = [n for n in names if n != 'deployLiquidityFacet']
        source = functions(source, names, facet)
        return functions(source, ['deployPackage'], package)
    change(path, update)

common = 'contracts/vaults/detf/common/factory/'
change(common + 'DetfFacetFactoryService.sol', lambda s: functions(s, [
    'deployUniswapV4DetfBondNFTVaultFacet', 'deployRebasingClaimTokenFacet'
], facet))
change(common + 'DetfPkgFactoryService.sol', lambda s: functions(s, [
    'deployUniswapV4DetfDFPkg', 'deployUniswapV4DetfBondNFTVaultDFPkg', 'deployRebasingClaimTokenDFPkg'
], package))

universal = 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/'
change(universal + 'UniswapV4Detf_Facet_FactoryService.sol', lambda s: functions(s, [
    'deployUniswapV4Detf' + role + 'Facet'
    for role in ['Exchange', 'Bond', 'Maintenance', 'Claim', 'Query']
], facet))
change(universal + 'UniswapV4Detf_Pkg_FactoryService.sol', lambda s: functions(s, [
    'deployUniswapV4DetfDFPkg'
], package))

for stage in ['03_CpBufferHookPkg', '04_WeightedBufferHookPkg', '06_CurveQuadBufferHookPkg']:
    path = 'scripts/foundry/anvil_robinhood_main/Phase_06_Stage_' + stage + '.sol'
    def update(source):
        source = source.replace('import {IFacet}', 'import {ArtifactCreationCode} from "contracts/utils/foundry/ArtifactCreationCode.sol";\n\nimport {IFacet}', 1)
        # The init struct must be filled before it is encoded, so insert locals
        # immediately before the package deployment, not at function entry.
        start = source.index('        s.', source.index('init_.'))
        fragment = source[start:]
        transformed = package(fragment)
        source = source[:start] + transformed.lstrip('\n')
        return source
    change(path, update)

for stage in [
    '01_BondNftPkg', '02_RebasingClaimPkg', '03_CpBufferHookPkg',
    '04_WeightedBufferHookPkg', '06_CurveQuadBufferHookPkg', '07_UniswapV4DetfPkg'
]:
    path = 'scripts/foundry/anvil_robinhood_main/Phase_06_Stage_' + stage + '.s.sol'
    def update(source):
        source = re.sub(r'/// @notice Skip key: `[^`]+`\.',
                        '/// @notice Resolve the current component set through implementation-sensitive CREATE3 salts.', source)
        source, n = re.subn(
            r'        if \(_shouldSkipStage.*?\n        } else \{\n(.*?)        }\n',
            lambda m: ('        // Address records alone cannot establish release freshness.\n'
                       + ''.join(line[4:] if line.startswith('    ') else line
                                 for line in m.group(1).splitlines(True))),
            source, flags=re.S
        )
        assert n == 1, path
        return source
    change(path, update)

def stage_dependencies(source):
    source = source.replace('import {IFacet}', '''import {Vm} from "forge-std/Vm.sol";
import {VM_ADDRESS} from "@crane/contracts/constants/FoundryConstants.sol";
import {IDiamondFactoryPackage} from "@crane/contracts/interfaces/IDiamondFactoryPackage.sol";
import {IFacet}''', 1)
    marker = '        IVaultRegistryDeployment reg = '
    validation = '''        _requireCurrentDependency(
            s.bondNftVaultPkg, "UniswapV4DetfBondNFTVaultDFPkg", "UniswapV4DetfBondNFTVaultFacet"
        );
        _requireCurrentDependency(
            s.rebasingClaimTokenPkg, "RebasingClaimTokenDFPkg", "RebasingClaimTokenFacet"
        );
'''
    source = source.replace(marker, validation + marker, 1)
    marker = '    function _live('
    helper = '''    /// @dev Fail before product deployment if a skipped dependency still has old code.
    function _requireCurrentDependency(address pkg_, string memory name_, string memory facetName_) private view {
        IDiamondFactoryPackage pkg = IDiamondFactoryPackage(pkg_);
        require(keccak256(bytes(pkg.packageName())) == keccak256(bytes(name_)), "Phase 06-07: wrong dependency package");
        bytes memory expected = Vm(VM_ADDRESS).getDeployedCode(string.concat(facetName_, ".sol:", facetName_));
        require(expected.length != 0, "Phase 06-07: missing dependency artifact");
        bytes32 expectedHash = keccak256(expected);
        address[] memory facets = pkg.facetAddresses();
        for (uint256 i; i < facets.length; ++i) {
            if (facets[i].codehash == expectedHash) return;
        }
        revert("Phase 06-07: stale dependency facet; run 06-01 and 06-02");
    }

'''
    return source.replace(marker, helper + marker, 1)

change('scripts/foundry/anvil_robinhood_main/Phase_06_Stage_07_UniswapV4DetfPkg.sol', stage_dependencies)

def deployment_regressions(source):
    source = source.replace('import {IERC165}', '''import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {IUniswapV4DetfDFPkg} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {DetfFacetFactoryService} from "contracts/vaults/detf/common/factory/DetfFacetFactoryService.sol";
import {UniswapV4Detf_Pkg_FactoryService} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Pkg_FactoryService.sol";
import {IERC165}''', 1)
    marker = '    /// @notice Every independently deployed product facet'
    tests = '''    /// @notice Existing type-name deployments cannot shadow the current claim implementation.
    function test_releaseSalt_legacyFacetDoesNotShadowCurrentFacet() public {
        string memory artifact = "RebasingClaimTokenFacet.sol:RebasingClaimTokenFacet";
        IFacet legacy = create3Factory.deployFacet(
            vm.getCode(artifact), keccak256(abi.encode("RebasingClaimTokenFacet"))
        );
        IFacet current = DetfFacetFactoryService.deployRebasingClaimTokenFacet(create3Factory);
        assertTrue(address(current) != address(legacy), "release does not reuse the legacy salt");
        assertEq(address(current).code, vm.getDeployedCode(artifact), "current implementation installed");
        assertEq(
            address(DetfFacetFactoryService.deployRebasingClaimTokenFacet(create3Factory)),
            address(current), "identical release remains idempotent"
        );
    }

    /// @notice A different valid facet binding creates a new package and preserves the previous one.
    function test_releaseSalt_constructorChangeCreatesNewPackage() public {
        IUniswapV4DetfDFPkg.PkgInit memory init = _releasePkgInit();
        IVaultRegistryDeployment reg = IVaultRegistryDeployment(address(indexedexManager));
        vm.startPrank(owner);
        IUniswapV4DetfDFPkg unchanged = UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(reg, init);
        vm.stopPrank();
        assertEq(address(unchanged), address(detfPkg), "same code and constructor reuse package");

        IFacet replacement = create3Factory.deployFacet(
            vm.getCode("UniswapV4DetfBondFacet.sol:UniswapV4DetfBondFacet"),
            keccak256(abi.encode("UniswapV4DetfBondFacet", "release constructor regression"))
        );
        init.productFacets[1] = replacement;
        vm.startPrank(owner);
        IUniswapV4DetfDFPkg changed = UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(reg, init);
        IUniswapV4DetfDFPkg repeated = UniswapV4Detf_Pkg_FactoryService.deployUniswapV4DetfDFPkg(reg, init);
        vm.stopPrank();
        assertTrue(address(changed) != address(detfPkg), "constructor change gets a new package");
        assertEq(address(repeated), address(changed), "new constructor also remains idempotent");
        assertEq(changed.facetCuts()[6].facetAddress, address(replacement), "new immutable facet binding");
        assertEq(detfPkg.facetCuts()[6].facetAddress, address(detfProductFacets[1]), "old package remains intact");
    }

    function _releasePkgInit() private view returns (IUniswapV4DetfDFPkg.PkgInit memory) {
        return IUniswapV4DetfDFPkg.PkgInit({
            erc20Facet: erc20Facet,
            erc5267Facet: erc5267Facet,
            erc2612Facet: erc2612Facet,
            multiAssetBasicVaultFacet: multiAssetBasicVaultFacet,
            multiAssetStandardVaultFacet: multiAssetStandardVaultFacet,
            productFacets: detfProductFacets,
            feeOracle: IVaultFeeOracleQuery(address(indexedexManager)),
            vaultRegistryDeployment: IVaultRegistryDeployment(address(indexedexManager)),
            bondNftVaultPkg: bondNftVaultPkg,
            rebasingClaimTokenPkg: rebasingClaimTokenPkg
        });
    }

'''
    return source.replace(marker, tests + marker, 1)

change('test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_FacetPackaging.t.sol', deployment_regressions)

patch = ''.join(''.join(difflib.unified_diff(
    before.splitlines(True), after.splitlines(True),
    fromfile='a/' + path, tofile='b/' + path
)) for path, (before, after) in changes.items())
(ROOT / 'release-salts.patch').write_text(patch)
print('Prepared', len(changes), 'files; production sources unchanged.')
