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
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
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
         subject.transfer(address(subject), shares);
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
    function test_nativeSYInternalHolderBurnAndInsufficientBalance() public {
        _bootstrap(); subject.transfer(address(subject), 3 ether); _rebalance();
        uint256 supply = subject.totalSupply();
        uint256 received = IStandardizedYield(address(subject)).redeem(address(this), 1 ether, address(asset1), 0, true);
        assertGt(received, 0);
        assertEq(subject.totalSupply(), supply - 1 ether);
        assertEq(subject.balanceOf(address(subject)), 2 ether);
        assertEq(subject.reserveOfToken(address(subject)), 2 ether);
        bytes memory data = abi.encodeCall(IStandardizedYield.redeem, (address(this), 3 ether, address(asset1), 0, true));
        _reject(data, _deliveryError(3 ether, 2 ether));
        _reject(abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(subject)), 1 ether, asset1, 0, FALSE_DEPOSITOR, true, block.timestamp)), _deliveryError(1 ether, 0));
    }
    function test_nativeSYRequestedRecipientAndOrdinaryCallerDenied() public {
        _bootstrap(); subject.transfer(address(subject), 3 ether); _rebalance();
        uint256 received = IStandardizedYield(address(subject)).redeem(FALSE_DEPOSITOR, 1 ether, address(asset1), 0, true);
        assertEq(asset1.balanceOf(FALSE_DEPOSITOR), received);
        uint256 supply = subject.totalSupply();
        vm.startPrank(FALSE_DEPOSITOR);
        // R2.4: false depositor holds no shares/allowance -> ERC20InsufficientAllowance 0xfb8f41b2
        // (dynamic args; selector pinned). Bare expectRevert() masked the real revert.
        vm.expectPartialRevert(bytes4(0xfb8f41b2));
        subject.exchangeIn(IERC20(address(subject)), 1 ether, asset1, 0, FALSE_DEPOSITOR, false, block.timestamp);
        vm.stopPrank();
        assertEq(subject.totalSupply(), supply);
        assertEq(subject.balanceOf(address(subject)), 2 ether);
    }


    function testFuzz_deliveryAcrossSleeveRatios(bool side, uint8 pctSeed) public {
        uint256[4] memory choices = [uint256(0.02e18), 0.2e18, 0.5e18, 1e18];
        _configureSleeve(choices[pctSeed % 4]);
        // A 100% sleeve deliberately has no position; bootstrap's armed assertion
        // is not applicable, so activate first and change the placement afterward.
        _configureSleeve(0.2e18); _bootstrap(); _trade(side, 10 ether);
        _configureSleeve(choices[pctSeed % 4]); _rebalance();
        IERC20 token = side ? asset0 : asset1;
        _reject(_depositCall(token, 1 ether, FALSE_DEPOSITOR), _deliveryError(1 ether, 0));
        _fund(token, address(this), 1 ether);
        bytes memory data = _depositCall(token, 1 ether, address(this));
         token.transfer(address(subject), 1 ether);
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
        // R2.4: replaying a consumed permit recovers a wrong signer -> ERC2612InvalidSigner 0x4b800e46.
        vm.expectPartialRevert(bytes4(0x4b800e46)); permit.permit(holder, address(this), 1 ether, block.timestamp + 100, v, r, s);
        // R2.4: the 1-ether allowance was already spent -> ERC20InsufficientAllowance 0xfb8f41b2.
        vm.expectPartialRevert(bytes4(0xfb8f41b2)); subject.transferFrom(holder, address(this), 1 ether);
    }

    function test_everyTargetSelectorIsInstalledOnRegistryProxy() public view {
        string[10] memory targets = [string("InTarget"), "InQueryTarget", "InMultiTarget", "InMultiQueryTarget",
            "OutExecuteTarget", "OutQueryTarget", "OutMultiTarget", "OutMultiQueryTarget", "LiquidReserveTarget", "PositionImportTarget"];
        uint256 checked;
        for (uint256 i; i < targets.length; ++i) {
            string memory name = string.concat(_family(), "FullSpreadStandardExchangeVault", targets[i]);
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



    function test_SYFailureRollsBackAndCanRetry() public {
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
        assertEq(token.callbackError(), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
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

    function test_nativeSYInternalMinimumRollbackAndContextRestored() public {
        _bootstrap(); subject.transfer(address(subject),3 ether); _rebalance();
        bytes memory data=abi.encodeCall(IStandardizedYield.redeem,(FALSE_DEPOSITOR,1 ether,address(asset1),type(uint256).max,true));
        _reject(data,abi.encodeWithSignature(string.concat(_family(),"ExchangeIn_SlippageExceeded()")));
        uint256 received=IStandardizedYield(address(subject)).redeem(FALSE_DEPOSITOR,1 ether,address(asset1),0,true);
        assertEq(asset1.balanceOf(FALSE_DEPOSITOR),received);assertEq(subject.balanceOf(address(subject)),2 ether);
        // R2.4: false depositor holds no shares/allowance -> ERC20InsufficientAllowance 0xfb8f41b2.
        vm.prank(FALSE_DEPOSITOR);vm.expectPartialRevert(bytes4(0xfb8f41b2));
        subject.exchangeIn(IERC20(address(subject)),1 ether,asset1,0,FALSE_DEPOSITOR,false,block.timestamp);
        assertEq(subject.balanceOf(address(subject)),2 ether);
    }
}
