"""Migrate retained weighted deployment/range tests after the active Forge invocation exits."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
record = artifacts / 'multi-funded-deployment-test-migration.json'
assert not record.exists(), 'Already applied; preserve original provenance.'
directory = Path('test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted')
base_path = Path('contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol')
suite_path = Path('test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol')
staged = {}
base = (root / base_path).read_text()
assert 'function _assertInert' not in base
index = base.rfind('\n}')
base = base[:index] + '''
    function _assertInert(address instance_) internal view {
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        assertFalse(info_.isReserveLive(), "reserve inert until first bond");
        assertEq(IERC20(instance_).totalSupply(), 0, "unfunded DETF cannot be issued");
        assertEq(info_.epochAnchor(), 0, "epoch clock has not started");
    }

    function _assertLive(address instance_) internal view {
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        assertTrue(info_.isReserveLive(), "reserve live after first bond");
        assertGt(IERC20(instance_).totalSupply(), 0, "funded DETF issued");
        assertGt(IERC20(info_.reservePool()).balanceOf(info_.bondNftVault()), 0, "protocol owns reserve LP");
        assertGt(info_.epochAnchor(), 0, "first bond starts fixed clock");
    }
''' + base[index:]
staged[base_path] = base
deploy = '''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {TestBase_MultiVaultWeightedDetf} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol";
import {IMultiVaultWeightedDetfDFPkg} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol";
import {IMultiVaultWeightedDetfInfo} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfInfoTarget.sol";
import {DETFThresholdPolicy} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";

contract MultiVaultWeightedDetf_Deploy_Test is TestBase_MultiVaultWeightedDetf {
    function test_deploy_inert_n1() public view {
        _assertInert(detf);
        assertEq(detfInfo.vaultCount(), 1, "vault count");
        assertTrue(detfInfo.reservePool() != address(0), "reserve pool");
        assertEq(detfInfo.underlyingVaults()[0], address(seVaults[0]), "vault0");
        (uint256 weight_, uint256[] memory weights_) = detfInfo.weights();
        assertGt(weight_, 0, "detf weight");
        assertGt(weights_[0], 0, "vault weight");
        assertEq(weight_ + weights_[0], 1e18, "weights sum");
        assertEq(detfInfo.mintThreshold(), DETFThresholdPolicy.DEFAULT_MINT_THRESHOLD);
        assertEq(detfInfo.burnThreshold(), DETFThresholdPolicy.DEFAULT_BURN_THRESHOLD);
        assertFalse(detfInfo.isMintingAllowed());
        assertFalse(detfInfo.isBurningAllowed());
        assertEq(IERC20Metadata(detf).decimals(), 9);
        assertEq(IERC20Metadata(detfInfo.rebasingClaimToken()).decimals(), 9);
        assertEq(IERC20Metadata(detfInfo.rawSY()).decimals(), 9);
        assertEq(IERC20Metadata(detfInfo.stakingSY()).decimals(), 9);
    }

    function test_deploy_n2_disparate_rateAssets() public {
        address instance_ = _deployDetfN(2, 0, 0, true);
        IMultiVaultWeightedDetfInfo info_ = IMultiVaultWeightedDetfInfo(instance_);
        _assertInert(instance_);
        assertEq(info_.vaultCount(), 2);
        address[] memory assets_ = info_.rateAssets();
        assertEq(assets_[0], address(rateAssets[0]));
        assertEq(assets_[1], address(rateAssets[1]));
        assertTrue(assets_[0] != assets_[1], "actual disparate rate assets");
    }

    function test_deploy_reverts_invalid_weights() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(1, 0, 0, true);
        args_.weightDetf = 0.8e18;
        args_.vaultWeights[0] = 0.1e18;
        vm.expectRevert();
        _deployWithArgs(args_);
    }

    function test_deploy_reverts_duplicate_vault() public {
        IMultiVaultWeightedDetfDFPkg.PkgArgs memory args_ = _buildPkgArgs(2, 0, 0, true);
        args_.vaults[1] = args_.vaults[0];
        args_.vaultShares[1] = args_.vaultShares[0];
        args_.rateAssets[1] = args_.rateAssets[0];
        vm.expectRevert();
        _deployWithArgs(args_);
    }
}
'''
staged[directory / 'MultiVaultWeightedDetf_Deploy.t.sol'] = deploy
range_path = directory / 'MultiVaultWeightedDetf_NRange.t.sol'
source = (root / range_path).read_text()
source = source.replace('Deploy + first BPT bond → live for every N in 1..7.', 'Deploy + fully funded first bond → live for every N in 1..7.')
source = source.replace('_goLiveViaBptBond(instance_, alice, 500e18)', '_bootstrapDetf(instance_, alice, 500e18)')
source = source.replace('"bpt principal"', '"protocol reserve LP"')
staged[range_path] = source
suite = (root / suite_path).read_text()
for path in (directory / 'MultiVaultWeightedDetf_Deploy.t.sol', range_path):
    assert str(path) not in suite
    suite += '\nimport "' + str(path) + '";\n'
staged[suite_path] = suite
rows = []
for path, after in staged.items():
    before = (root / path).read_text()
    assert before != after, path
    rows.append({'path': str(path), 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                 'after_sha256': hashlib.sha256(after.encode()).hexdigest()})
for path, after in staged.items():
    (root / path).write_text(after)
record.write_text(json.dumps({'status': 'applied; validation pending', 'rows': rows,
    'preserved': 'All four deployment assertions and every one-through-seven actual weighted reserve deployment/bootstrap; no LP-only purchase regression retired.',
    'changed': 'Mandatory default gates and native nine-decimal metadata replace the removed mode getter; funded bootstrap replaces the obsolete helper name.'}, indent=2) + '\n')
print('Migrated retained weighted deployment/range tests; validation pending.')
