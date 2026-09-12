"""Apply the retained-route regressions only after the active Forge invocation exits."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[2]
artifacts = Path(__file__).resolve().parent
test_path = Path('test/foundry/spec/vaults/standard/sy/DualBufferHookNativeSY.t.sol')
suite_path = Path('test/foundry/spec/vaults/detf/common/DETFFundedStakingSuite.t.sol')
output = artifacts / 'dual-exit-regression-sources.json'
assert not output.exists(), 'Already applied; preserve original provenance.'
assert not (root / test_path).exists(), 'Do not overwrite an existing test.'

source = '''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4DualSEBCPHook} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/TestBase_UniswapV4DualSEBCPHook.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDFPkg.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookHooksFacet.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookInitFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookInitFacet.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookDepositFacet.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookWithdrawFacet.sol";
import {UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet} from "contracts/hooks/uniswap/v4/standardExchange/dual/facets/UniswapV4DualStandardExchangeBufferConstantProductHookSeFacet.sol";

/// @notice Existing single-asset LP exits must work before exposing them through native SY.
contract DualBufferHookLiquidityRegressionTest is TestBase_UniswapV4DualSEBCPHook {
    function setUp() public override {
        super.setUp();
        _depositBoth(1_000 ether, 1_000 ether);
    }

    function test_dualSingleAssetExitPaysOnlyItsOwnRawOutput() public {
        _assertRawExit(address(tokenA));
        _assertRawExit(address(tokenB));
    }

    function test_dualSingleAssetExitPreservesPreexistingRawInventory() public {
        tokenA.mint(hook, 7 ether);
        tokenB.mint(hook, 11 ether);
        uint256 beforeA_ = tokenA.balanceOf(hook);
        uint256 beforeB_ = tokenB.balanceOf(hook);
        _assertRawExit(address(tokenA));
        assertEq(tokenA.balanceOf(hook), beforeA_, "exit consumed unrelated tokenA");
        assertEq(tokenB.balanceOf(hook), beforeB_, "exit consumed unrelated tokenB");
    }

    function test_dualSingleAssetExitDeliversSelectedSeShareToken() public {
        IUniswapV4SeBufferHook host_ = IUniswapV4SeBufferHook(hook);
        uint256 shares_ = IERC20(hook).balanceOf(user) / 20;
        uint256 quote_ = host_.previewExitSingleAssetExactBptIn(seA, shares_);
        uint256 seBefore_ = IERC20(seA).balanceOf(user);
        uint256 rawBefore_ = tokenA.balanceOf(user);
        vm.prank(user);
        uint256 out_ = host_.exitSingleAssetExactBptIn(seA, shares_, user, quote_, block.timestamp);
        assertGt(out_, 0);
        assertEq(out_, quote_, "share exit preview");
        assertEq(IERC20(seA).balanceOf(user), seBefore_ + out_, "wrong payout token");
        assertEq(tokenA.balanceOf(user), rawBefore_, "share exit paid raw token");
    }

    function _assertRawExit(address out_) private {
        IUniswapV4SeBufferHook host_ = IUniswapV4SeBufferHook(hook);
        uint256 shares_ = IERC20(hook).balanceOf(user) / 20;
        uint256 quote_ = host_.previewExitSingleAssetExactBptIn(out_, shares_);
        uint256 supply_ = IERC20(hook).totalSupply();
        uint256 lpBefore_ = IERC20(hook).balanceOf(user);
        uint256 before_ = IERC20(out_).balanceOf(user);
        vm.prank(user);
        uint256 received_ = host_.exitSingleAssetExactBptIn(out_, shares_, user, quote_, block.timestamp);
        assertGt(received_, 0);
        assertEq(received_, quote_, "raw exit preview");
        assertEq(IERC20(out_).balanceOf(user), before_ + received_, "raw exit payout");
        assertEq(IERC20(hook).balanceOf(user), lpBefore_ - shares_, "actual holder burn");
        assertEq(IERC20(hook).totalSupply(), supply_ - shares_, "no fee configured");
    }
}
'''

suite = (root / suite_path).read_text()
updated = suite + '\nimport "' + str(test_path) + '";\n'
(root / test_path).write_text(source)
(root / suite_path).write_text(updated)
def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()
output.write_text(json.dumps({
    'status': 'applied; tests have not run',
    'test_source': str(test_path), 'sha256': sha(source),
    'suite_source': str(suite_path), 'suite_before_sha256': sha(suite),
    'suite_after_sha256': sha(updated),
    'scope': 'Real registered dual-buffer diamond and real ERC4626 SEs. No production changes, no SY success claim. Existing tokenA/tokenB usage fees remain enabled.'
}, indent=2) + '\n')
print('Applied three existing-route regressions; production unchanged.')
