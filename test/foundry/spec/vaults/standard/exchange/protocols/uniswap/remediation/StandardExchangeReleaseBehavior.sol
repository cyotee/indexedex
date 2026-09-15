// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {StandardExchangeDeliveryBehavior} from "./StandardExchangeDeliveryBehavior.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {DeliveryTestToken} from "./DeliveryTestToken.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IPretransfer} from "./StandardExchangeDeliveryBehavior.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";

abstract contract StandardExchangeReleaseBehavior is StandardExchangeDeliveryBehavior {
    function _family() internal pure virtual returns (string memory);
    function _disable(bool disabled, bool packageWide) internal virtual;
    function _configureSleeve(uint256 pct) internal virtual;

    function test_disabledVaultRejectsDepositButPermitsWithdrawals() public { _disabledExit(false); }
    function test_disabledPackageRejectsDepositButPermitsWithdrawals() public { _disabledExit(true); }
    function _disabledExit(bool packageWide) private {
        _bootstrap(); _disable(true, packageWide);
        _fund(asset0, address(this), 1 ether); asset0.approve(address(subject), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(subject)));
        subject.exchangeIn(asset0, 1 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp);
        uint256 shares = subject.totalSupply() / 20;
        subject.approve(address(subject), shares);
        assertGt(subject.exchangeIn(IERC20(address(subject)), shares, asset1, 0, address(this), false, block.timestamp), 0);
        bytes memory data = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(subject)), shares, asset1, 1 ether, address(this), true, block.timestamp));
        _prepare(IERC20(address(subject)), shares, data); subject.transfer(address(subject), shares);
        assertGt(_execute(data), 0);
        _disable(false, packageWide);
        assertGt(subject.exchangeIn(asset0, 1 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp), 0);
    }
    function test_nativeSYCallerRedemptionNeedsNoAllowance() public {
        _bootstrap();
        uint256 beforeShares = subject.balanceOf(address(this));
        uint256 quoted = IStandardizedYield(address(subject)).previewRedeem(address(asset1), 1 ether);
        assertEq(IStandardizedYield(address(subject)).redeem(address(this), 1 ether, address(asset1), quoted, false), quoted);
        assertEq(subject.balanceOf(address(this)), beforeShares - 1 ether);
    }
    function test_nativeSYPreparedInternalBalanceCannotClaimOldShares() public {
        _bootstrap(); subject.transfer(address(subject), 3 ether);
        bytes memory data = abi.encodeCall(IStandardizedYield.redeem, (address(this), 1 ether, address(asset1), 0, true));
        _reject(data, abi.encodeWithSelector(IPretransfer.PretransferNotPrepared.selector));
        _prepare(IERC20(address(subject)), 1 ether, data);
        subject.transfer(address(subject), 1 ether);
        assertGt(_execute(data), 0);
        assertEq(subject.balanceOf(address(subject)), 3 ether, "prior shares untouched");
        _reject(data, abi.encodeWithSelector(IPretransfer.PretransferNotPrepared.selector));
    }
    function test_nativeSYPreparedRecipientBinding() public {
        _bootstrap();
        bytes memory data = abi.encodeCall(IStandardizedYield.redeem, (address(this), 1 ether, address(asset1), 0, true));
        _prepare(IERC20(address(subject)), 1 ether, data); subject.transfer(address(subject), 1 ether);
        bytes memory changed = abi.encodeCall(IStandardizedYield.redeem, (FALSE_DEPOSITOR, 1 ether, address(asset1), 0, true));
        _reject(changed, abi.encodeWithSelector(IPretransfer.PretransferCallMismatch.selector));
        assertGt(_execute(data), 0);
    }
    function test_preparationRejectsZeroDuplicateAndUnknownTokens() public {
        address[] memory tokens = new address[](2); uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(asset0); tokens[1] = address(asset0); amounts[0] = 1; amounts[1] = 1;
        vm.expectRevert(IPretransfer.InvalidPretransfer.selector);
        IPretransfer(address(subject)).preparePretransfer(tokens, amounts, bytes32(uint256(1)));
        tokens[1] = address(asset1); amounts[1] = 0;
        vm.expectRevert(IPretransfer.InvalidPretransfer.selector);
        IPretransfer(address(subject)).preparePretransfer(tokens, amounts, bytes32(uint256(1)));
        amounts[1] = 1; tokens[1] = FALSE_DEPOSITOR;
        vm.expectRevert(IPretransfer.InvalidPretransfer.selector);
        IPretransfer(address(subject)).preparePretransfer(tokens, amounts, bytes32(uint256(1)));
        tokens[1] = address(asset1);
        vm.expectRevert(IPretransfer.InvalidPretransfer.selector);
        IPretransfer(address(subject)).preparePretransfer(tokens, amounts, bytes32(0));
    }
    function test_pendingInputCannotBeUsedByPullOrSecondPreparation() public {
        _bootstrap(); bytes memory data = _depositCall(asset0, 1 ether, address(this));
        _prepare(asset0, 1 ether, data);
        vm.expectRevert(IPretransfer.PretransferPending.selector); _prepare(asset0, 1 ether, data);
        bytes memory pull = abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (asset0, 1 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp));
        _reject(pull, abi.encodeWithSelector(IPretransfer.PretransferCallMismatch.selector));
    }
    function testFuzz_deliveryAcrossSleeveRatios(bool side, uint8 pctSeed) public {
        uint256[4] memory choices = [uint256(0.02e18), 0.2e18, 0.5e18, 1e18];
        _configureSleeve(choices[pctSeed % 4]);
        // A 100% sleeve deliberately has no position; bootstrap's armed assertion
        // is not applicable, so activate first and change the placement afterward.
        _configureSleeve(0.2e18); _bootstrap(); _trade(side, 10 ether);
        _configureSleeve(choices[pctSeed % 4]); _rebalance();
        IERC20 token = side ? asset0 : asset1;
        _reject(_depositCall(token, 1 ether, FALSE_DEPOSITOR), abi.encodeWithSelector(IPretransfer.PretransferNotPrepared.selector));
        _fund(token, address(this), 1 ether);
        bytes memory data = _depositCall(token, 1 ether, address(this));
        _prepare(token, 1 ether, data); token.transfer(address(subject), 1 ether);
        assertGt(_execute(data), 0);
    }
    function test_sharePermitAuthorizesOnlySignedSpenderAndCannotReplay() public {
        _bootstrap();
        uint256 key = 0xA11CE; address holder = vm.addr(key); subject.transfer(holder, 2 ether);
        IERC20Permit permit = IERC20Permit(address(subject));
        bytes32 structHash = keccak256(abi.encode(keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            holder, address(this), 1 ether, permit.nonces(holder), block.timestamp + 100));
        bytes32 digest = keccak256(abi.encodePacked(hex"1901", permit.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        permit.permit(holder, address(this), 1 ether, block.timestamp + 100, v, r, s);
        subject.transferFrom(holder, address(this), 1 ether);
        assertEq(subject.balanceOf(holder), 1 ether);
        assertEq(permit.nonces(holder), 1);
        vm.expectRevert(); permit.permit(holder, address(this), 1 ether, block.timestamp + 100, v, r, s);
        vm.expectRevert(); subject.transferFrom(holder, address(this), 1 ether);
    }

    function test_everyTargetSelectorIsInstalledOnRegistryProxy() public view {
        string[10] memory targets = [string("InTarget"), "InQueryTarget", "InMultiTarget", "InMultiQueryTarget",
            "OutExecuteTarget", "OutQueryTarget", "OutMultiTarget", "OutMultiQueryTarget", "LiquidReserveTarget", "PositionImportTarget"];
        uint256 checked;
        for (uint256 i; i < targets.length; ++i) {
            string memory name = string.concat(_family(), "StandardExchange", targets[i], "V2");
            string memory artifact = vm.readFile(string.concat("out/", name, ".sol/", name, ".json"));
            string[] memory signatures = vm.parseJsonKeys(artifact, ".methodIdentifiers");
            for (uint256 j; j < signatures.length; ++j) {
                bytes4 selector = bytes4(keccak256(bytes(signatures[j])));
                address implementation = IDiamondLoupe(address(subject)).facetAddress(selector);
                assertTrue(implementation.code.length > 0, signatures[j]);
                ++checked;
            }
        }
        assertGt(checked, 30, "nonempty independent Target ABI controls");
    }

    function test_preparationRejectsEmptyOversizedAndUnequalArrays() public {
        address[] memory tokens = new address[](0); uint256[] memory amounts = new uint256[](0);
        vm.expectRevert(IPretransfer.InvalidPretransfer.selector);
        IPretransfer(address(subject)).preparePretransfer(tokens, amounts, bytes32(uint256(1)));
        tokens = new address[](3); amounts = new uint256[](3);
        vm.expectRevert(IPretransfer.InvalidPretransfer.selector);
        IPretransfer(address(subject)).preparePretransfer(tokens, amounts, bytes32(uint256(1)));
        tokens = new address[](1); tokens[0] = address(asset0);
        vm.expectRevert(IPretransfer.InvalidPretransfer.selector);
        IPretransfer(address(subject)).preparePretransfer(tokens, amounts, bytes32(uint256(1)));
    }

    function test_preparedSYFailureRollsBackAndCanRetry() public {
        _bootstrap();
        uint256 supply = subject.totalSupply();
        uint256 beforeAsset = asset1.balanceOf(address(subject));
        bytes memory bad = abi.encodeCall(IStandardizedYield.redeem,
            (address(this), 1 ether, address(asset1), type(uint256).max, false));
        (bool ok,) = address(subject).call(bad);
        assertFalse(ok);
        assertEq(subject.totalSupply(), supply);
        assertEq(subject.balanceOf(address(subject)), 0);
        assertEq(asset1.balanceOf(address(subject)), beforeAsset);
        assertGt(IStandardizedYield(address(subject)).redeem(address(this), 1 ether, address(asset1), 0, false), 0);
    }

    function test_transferCallbackCannotRedeemOwnedSYClaimsMidDeposit() public {
        _bootstrap();
        DeliveryTestToken token = DeliveryTestToken(address(asset1));
        subject.transfer(address(token), 2 ether);
        token.setCallback(address(subject), abi.encodeCall(IStandardizedYield.redeem,
            (FALSE_DEPOSITOR, 1 ether, address(asset0), 0, false)));
        _fund(asset1, address(this), 10 ether); asset1.approve(address(subject), 10 ether);
        assertGt(subject.exchangeIn(asset1, 10 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp), 0);
        assertEq(token.callbackError(), abi.encodeWithSelector(IPretransfer.PretransferPending.selector));
        assertEq(subject.balanceOf(address(token)), 2 ether); assertEq(asset0.balanceOf(FALSE_DEPOSITOR), 0);
    }
    function test_transferCallbackCannotExchangeMidDeposit() public {
        _bootstrap();
        DeliveryTestToken token = DeliveryTestToken(address(asset1));
        token.setCallback(address(subject), _depositCall(asset1, 1 ether, FALSE_DEPOSITOR));
        _fund(asset1, address(this), 10 ether); asset1.approve(address(subject), 10 ether);
        assertGt(subject.exchangeIn(asset1, 10 ether, IERC20(address(subject)), 0, address(this), false, block.timestamp), 0);
        assertEq(token.callbackError(), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
        assertEq(subject.balanceOf(FALSE_DEPOSITOR), 0);
    }
}
