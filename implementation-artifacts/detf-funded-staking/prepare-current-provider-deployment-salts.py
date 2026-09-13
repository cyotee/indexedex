"""Bind changed collector/rate-provider deployments to current bytecode and constructor arguments."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
changes = []

def stage(relative, transform):
    path = root / relative
    before = path.read_text()
    after = transform(before)
    assert before != after, relative
    changes.append((path, before, after))

def rate_providers(source):
    for name in ['StandardExchangeRateProviderFacet', 'WrappedStandardExchangeRateProviderFacet']:
        old = f'''        instance = create3Factory.deployFacet(
            ArtifactCreationCode.creationCode("{name}.sol:{name}"),
            abi.encode("{name}")._hash()
        );'''
        new = f'''        bytes memory code_ = ArtifactCreationCode.creationCode("{name}.sol:{name}");
        instance = create3Factory.deployFacet(
            code_, ArtifactCreationCode.releaseSalt(abi.encode("{name}")._hash(), code_, bytes(""))
        );'''
        assert old in source, name
        source = source.replace(old, new, 1)
    for name, interface in [('StandardExchangeRateProviderDFPkg', 'IStandardExchangeRateProviderDFPkg'), ('WrappedStandardExchangeRateProviderDFPkg', 'IWrappedStandardExchangeRateProviderDFPkg')]:
        start = source.index(f'    function deploy{name}(')
        end = source.find('\n    function ', start + 1)
        if end < 0: end = source.rindex('\n}')
        body = source[start:end]
        anchor = f'        instance = {interface}('
        assert anchor in body
        body = body.replace(anchor,
            f'        bytes memory code_ = ArtifactCreationCode.creationCode("{name}.sol:{name}");\n        bytes memory args_ = abi.encode(pkgInit);\n\n' + anchor, 1)
        old = f'''                    ArtifactCreationCode.creationCode("{name}.sol:{name}"),
                    abi.encode(pkgInit),
                    abi.encode("{name}")._hash()'''
        new = f'''                    code_, args_,
                    ArtifactCreationCode.releaseSalt(abi.encode("{name}")._hash(), code_, args_)'''
        assert old in body
        body = body.replace(old, new, 1)
        source = source[:start] + body + source[end:]
    return source

def collector(source):
    old = '''        facet = factory.deployFacet(
            ArtifactCreationCode.creationCode("FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet"), abi.encode("FeeCollectorManagerFacet")._hash()
        );'''
    new = '''        bytes memory code_ = ArtifactCreationCode.creationCode("FeeCollectorManagerFacet.sol:FeeCollectorManagerFacet");
        facet = factory.deployFacet(
            code_, ArtifactCreationCode.releaseSalt(abi.encode("FeeCollectorManagerFacet")._hash(), code_, bytes(""))
        );'''
    assert old in source
    source = source.replace(old, new, 1)
    anchor = '        dfpkg = IFeeCollectorDFPkg('
    assert anchor in source
    source = source.replace(anchor,
        '        bytes memory code_ = ArtifactCreationCode.creationCode("FeeCollectorDFPkg.sol:FeeCollectorDFPkg");\n        bytes memory args_ = abi.encode(pkgInitArgs);\n\n' + anchor, 1)
    old = '''                    ArtifactCreationCode.creationCode("FeeCollectorDFPkg.sol:FeeCollectorDFPkg"),
                    abi.encode(pkgInitArgs),
                    abi.encode("FeeCollectorDFPkg", pkgInitArgs)._hash()'''
    new = '''                    code_, args_,
                    ArtifactCreationCode.releaseSalt(abi.encode("FeeCollectorDFPkg", pkgInitArgs)._hash(), code_, args_)'''
    assert old in source
    return source.replace(old, new, 1)

stage('contracts/fee/collector/FeeCollectorFactoryService.sol', collector)
stage('contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProvider_FactoryService.sol', rate_providers)
if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    for path, before, after in changes:
        assert path.read_text() == before
        path.write_text(after)
report = {
    'status': 'applied; validation pending' if args.apply else 'prepared, not applied while Solidity compiles',
    'problem': 'Crane CREATE3 returns existing code at an occupied namespace without comparing implementation or constructor. Fixed namespaces would reuse old Fee Collector and SE rate-provider components on the existing core.',
    'resolution': 'Use the existing ArtifactCreationCode.releaseSalt convention for the changed collector manager, both SE rate facets, and their packages; instance identity rules and existing deployments remain unchanged.',
    'scope': 'Fee Collector and unrelated SE rate providers used by V4; no Balancer-hosted DETF functional change and no Slipstream edit.',
    'files': [{'path': str(path.relative_to(root)), 'before_sha256': hashlib.sha256(before.encode()).hexdigest(), 'after_sha256': hashlib.sha256(after.encode()).hexdigest()} for path, before, after in changes],
}
(artifacts / 'current-provider-deployment-salts.patch').write_text(''.join(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))) for path, before, after in changes))
(artifacts / 'current-provider-deployment-salts.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
