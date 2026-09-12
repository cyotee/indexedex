"""Preserve the initiating caller across an internal-balance SY redemption, with no added public permission."""
from pathlib import Path
import hashlib,json
changes=[]
def save(p,s):
 old=p.read_text() if p.exists() else '';p.write_text(s)
 changes.append({'path':str(p),'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(s.encode()).hexdigest()})
p=Path('contracts/vaults/standard/sy/NativeStandardYieldTarget.sol')
s='''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TransientSlot} from "@crane/contracts/utils/TransientSlot.sol";

/// @notice The initiating caller during an internal-balance native SY redemption.
/// @dev Used only to preserve existing removal authorization across the proxy's
/// self-call. The context cannot authorize additions or spending another LP owner.
library NativeStandardYieldContextRepo {
    using TransientSlot for *;
    bytes32 private constant CALLER_SLOT = keccak256("indexedex.native.sy.internal.redemption.caller");
    error NestedInternalSYRedemption();

    function _initiator() internal view returns (address) { return CALLER_SLOT.asAddress().tload(); }

    function _begin() internal {
        if (_initiator() != address(0)) revert NestedInternalSYRedemption();
        CALLER_SLOT.asAddress().tstore(msg.sender);
    }

    function _end() internal { CALLER_SLOT.asAddress().tstore(address(0)); }
}
''';context=s[s.index('/// @notice'):];s=p.read_text().replace('import {IERC20}', 'import {TransientSlot} from "@crane/contracts/utils/TransientSlot.sol";\nimport {IERC20}',1)+'\n'+context
old='''        if (internal_) (ok_, result_) = address(this).call(data_);
        else (ok_, result_) = address(this).delegatecall(data_);''';assert old in s
s=s.replace(old,'''        if (internal_) {
            NativeStandardYieldContextRepo._begin();
            (ok_, result_) = address(this).call(data_);
            NativeStandardYieldContextRepo._end();
        } else (ok_, result_) = address(this).delegatecall(data_);''');save(p,s)
p=Path('contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol');s=p.read_text().replace('import {MultiStepOwnableRepo}', '''import {NativeStandardYieldContextRepo} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {MultiStepOwnableRepo}''',1)
old='''        if (restricted && msg.sender != feeRecipient) MultiStepOwnableRepo._onlyOwner();''';assert old in s
s=s.replace(old,'''        if (!restricted) return;
        address actor = msg.sender;
        if (actor == address(this)) {
            address initiator = NativeStandardYieldContextRepo._initiator();
            if (initiator != address(0)) actor = initiator;
        }
        if (actor != feeRecipient && actor != MultiStepOwnableRepo._owner()) {
            revert IMultiStepOwnable.NotOwner(actor);
        }''');save(p,s)
for file,contract,seed in (
('SingleConstantProductHookNativeSY.t.sol','SingleConstantProductHookRestrictedSYTest','_seedLiveLiquidity();'),
('WeightedBufferHookNativeSY.t.sol','WeightedBufferHookRestrictedSYTest','_seedFullBook(1_000 ether);'),
('CurveQuadBufferHookNativeSY.t.sol','CurveQuadBufferHookRestrictedSYTest','_seedFullBook(1_000 ether);')):
 p=Path('test/foundry/spec/vaults/standard/sy')/file;s=p.read_text();start=s.index('contract '+contract);mark=s.index('    function test_',start)
 method='''    function test_restrictedSYInternalRedemptionPreservesCallerAndClearsAuthorization() public {
        SEED
        IStandardizedYield sy = IStandardizedYield(hook);
        uint256 shares = sy.balanceOf(user) / 100;
        vm.prank(user); sy.transfer(hook, shares * 2);
        address output = sy.getTokensOut()[0];
        address outsider = makeAddr("unauthorized internal SY redeemer");
        vm.expectRevert(); vm.prank(outsider); sy.redeem(outsider, shares, output, 0, true);
        assertEq(sy.balanceOf(hook), shares * 2);
        uint256 quoted = sy.previewRedeem(output, shares);
        uint256 before = IERC20(output).balanceOf(user);
        vm.prank(user); uint256 received = sy.redeem(user, shares, output, quoted, true);
        assertEq(IERC20(output).balanceOf(user) - before, received);
        assertEq(sy.balanceOf(hook), shares);
        vm.expectRevert(); vm.prank(outsider); sy.redeem(outsider, shares, output, 0, true);
        assertEq(sy.balanceOf(hook), shares, "owner's completed call leaves no public removal authority");
    }

'''.replace('SEED',seed)
 s=s[:mark]+method+s[mark:];save(p,s)
Path('implementation-artifacts/detf-funded-staking/restricted-native-sy-context-sources.json').write_text(json.dumps(changes,indent=2)+'\n')
