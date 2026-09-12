"""Prepare current Fee Collector and fourth V4 binding in the existing fork rehearsal."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--apply', action='store_true')
args = parser.parse_args()
artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
path = root / 'test/foundry/fork/robinhood_4663/RobinhoodReleaseRehearsal.t.sol'
before = path.read_text()
assert 'function _deployCurrentRehearsalCollector()' not in before
after = before.replace('import {IStandardExchangeInMulti}', '''import {IFacet} from "@crane/contracts/interfaces/IFacet.sol";
import {IVaultRegistryDeployment} from "contracts/interfaces/IVaultRegistryDeployment.sol";
import {IFeeCollectorDFPkg} from "contracts/fee/collector/FeeCollectorDFPkg.sol";
import {FeeCollectorFactoryService as CollectorFactory} from "contracts/fee/collector/FeeCollectorFactoryService.sol";
import {IUniswapV4StandardExchangeOrbitalBufferHookPackage as IOrbitalPkg} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHookPackage.sol";
import {UniswapV4StandardExchangeOrbitalBufferHook_FactoryService as OrbitalFactory} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_FactoryService.sol";
import {IStandardExchangeInMulti}''', 1)
after = after.replace('        assertGt(address(pm).code.length, 0, "live PoolManager");',
    '        assertGt(address(pm).code.length, 0, "live PoolManager");\n        _deployCurrentRehearsalCollector();', 1)
anchor = '    function _pin(string memory file, string memory key, bool codeRequired)'
helpers = '''    function _commonFacet(string memory key) private view returns (IFacet) {
        return IFacet(_pin("phase03_stage01_common_facets.json", key, true));
    }

    /// @dev Fork-local deployment and oracle rotation. Existing public-chain
    /// collectors and their standing NFT rights are never changed by this test.
    function _deployCurrentRehearsalCollector() private {
        vm.startPrank(owner);
        IFacet managerFacet = CollectorFactory.deployFeeCollectorManagerFacet(create3Factory);
        IFacet pushFacet = CollectorFactory.deployFeeCollectorSingleTokenPushFacet(create3Factory);
        IFeeCollectorDFPkg pkg = CollectorFactory.deployFeeCollectorDFPkg(
            create3Factory, _commonFacet(".diamondCutFacet"), _commonFacet(".multiStepOwnableFacet"), pushFacet, managerFacet
        );
        IFeeCollectorProxy collector = CollectorFactory.deployFeeCollector(diamondPackageFactory, pkg, owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(collector);
        vm.stopPrank();
        assertEq(address(IVaultFeeOracleQuery(address(indexedexManager)).feeTo()), address(collector));
        assertTrue(IDiamondLoupe(address(collector)).facetAddress(
            bytes4(keccak256("redeemReserveLiquidity(address,uint256,uint256[],address,uint256)"))
        ) != address(0), "current collector redemption selector installed");
    }

'''
assert anchor in after
after = after.replace(anchor, helpers + anchor, 1)
after = after.replace('    function test_cp_v2() public', '''    function test_orbital_v2() public { _rehearse(3, 0); }
    function test_orbital_v3() public { _rehearse(3, 1); }
    function test_orbital_v4() public { _rehearse(3, 2); }
    function test_orbital_morpho() public { _rehearse(3, 3); }
    function test_orbital_v4_publicLiquidity() public { _rehearse(3, 2, false); }

    function test_cp_v2() public''', 1)
after = after.replace('        for (uint256 i; i <= family; ++i) {',
    '        uint256 pairCount = family == 3 ? 2 : family + 1;\n        for (uint256 i; i < pairCount; ++i) {', 1)
after = after.replace('        else detf = _deployQuad(args);',
    '        else if (family == 2) detf = _deployQuad(args);\n        else detf = _deployOrbital(args);', 1)
after = after.replace('tokenDecimals: Decimals.tokenDecimals(tokens), seDecimals: Decimals.seDecimals(ses),',
    'tokenDecimals: Decimals.tokenDecimals(tokens, predicted), seDecimals: Decimals.seDecimals(ses),', 1)
after = after.replace('rateProviders: rates, tokenDecimals: Decimals.tokenDecimals4(tokens4),',
    'rateProviders: rates, tokenDecimals: Decimals.tokenDecimals4(tokens4, predicted),', 1)
anchor = '    function _finalizeAndDeploy(IUniswapV4Detf.PkgArgs memory args,'
helpers = '''    function _currentOrbitalPackage() private returns (IOrbitalPkg pkg) {
        IOrbitalPkg.PkgInit memory init;
        init.vaultRegistryDeployment = IVaultRegistryDeployment(address(indexedexManager));
        init.vaultFeeOracleQuery = IVaultFeeOracleQuery(address(indexedexManager));
        vm.startPrank(owner);
        init.depositFacet = OrbitalFactory.deployDepositFacet(create3Factory);
        init.depositQueryFacet = OrbitalFactory.deployDepositQueryFacet(create3Factory);
        init.depositZapFacet = OrbitalFactory.deployDepositZapFacet(create3Factory);
        init.withdrawFacet = OrbitalFactory.deployWithdrawFacet(create3Factory);
        init.seFacet = OrbitalFactory.deploySeFacet(create3Factory);
        init.hooksFacet = OrbitalFactory.deployHooksFacet(create3Factory);
        vm.stopPrank();
        init.erc20Facet = _commonFacet(".erc20Facet");
        init.erc5267Facet = _commonFacet(".erc5267Facet");
        init.erc2612Facet = _commonFacet(".erc2612Facet");
        init.multiAssetBasicVaultFacet = _commonFacet(".multiAssetBasicVaultFacet");
        init.multiAssetStandardVaultFacet = _commonFacet(".multiAssetStandardVaultFacet");
        init.multiStepOwnableFacet = _commonFacet(".multiStepOwnableFacet");
        return OrbitalFactory.deployPackage(init.vaultRegistryDeployment, owner, init, keccak256("funded.rehearsal.orbital"));
    }

    function _deployOrbital(IUniswapV4Detf.PkgArgs memory args) private returns (address) {
        address predicted = _predictDetf(args);
        (address[] memory tokens, address[] memory ses) = _sorted(predicted);
        IOrbitalPkg pkg = _currentOrbitalPackage();
        IOrbitalPkg.PkgArgs memory h;
        h.poolManager = address(pm);
        h.feeOracle = address(indexedexManager);
        h.token0 = tokens[0]; h.token1 = tokens[1]; h.token2 = tokens[2];
        h.decimals0 = Decimals.tokenDec(tokens[0], predicted);
        h.decimals1 = Decimals.tokenDec(tokens[1], predicted);
        h.decimals2 = Decimals.tokenDec(tokens[2], predicted);
        h.se0 = ses[0]; h.se1 = ses[1]; h.se2 = ses[2];
        h.ownerOnlyLiquidity = args.ownerOnlyLiquidity;
        h.owner = predicted;
        reserveHook = OrbitalFactory.deployHook(pkg, h, OrbitalFactory.findMineNonce(hookFactory, pkg, h));
        return _finalizeAndDeploy(args, predicted, tokens);
    }

'''
assert anchor in after
after = after.replace(anchor, helpers + anchor, 1)
record = {
    'status': 'applied; validation pending' if args.apply else 'prepared, not applied while Solidity compiles',
    'path': str(path.relative_to(root)),
    'scope': 'Existing Robinhood fork rehearsal; all four V4 DETF bindings, predicted native units, fresh current Fee Collector deployed through production factories and fork-local live feeTo rotation.',
    'preserved': 'Existing unrelated Balancer SE hook cases and all prior backend coverage; no public deployment or Slipstream edit.',
    'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
    'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
}
(artifacts / 'rehearsal-final-bindings.patch').write_text(''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True), fromfile=str(path.relative_to(root)), tofile=str(path.relative_to(root)))))
if args.apply:
    queue = json.loads((artifacts / 'current-implementation-queue.json').read_text())
    assert not queue.get('solidity_frozen_until_session_exits'), 'Forge still active'
    path.write_text(after)
(artifacts / 'rehearsal-final-bindings.json').write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record, indent=2))
