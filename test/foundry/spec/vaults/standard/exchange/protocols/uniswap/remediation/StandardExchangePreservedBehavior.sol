// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangePretransfer as IPretransfer} from "contracts/vaults/standard/exchange/protocols/uniswap/IStandardExchangePretransfer.sol";

// The same assertions run against independently deployed V3 and V4 diamonds.
abstract contract StandardExchangePreservedBehavior is Test {
    IStandardExchangeProxy internal subject;
    IERC20 internal asset0;
    IERC20 internal asset1;
    address internal constant FALSE_DEPOSITOR = address(0xBAD);

    function _trade(bool zeroForOne, uint256 amount) internal virtual;
    function _deployed() internal view virtual returns (uint256, uint256);
    function _rebalance() internal virtual;

    function _fund(IERC20 token, address recipient, uint256 amount) internal {
        ERC20PermitMintableStub(address(token)).mint(recipient, amount);
    }

    function _bootstrap() internal {
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(asset0); tokens[1] = address(asset1);
        amounts[0] = 1000 ether; amounts[1] = 1000 ether;
        _fund(asset0, address(this), amounts[0]);
        _fund(asset1, address(this), amounts[1]);
        asset0.approve(address(subject), amounts[0]);
        asset1.approve(address(subject), amounts[1]);
        IStandardExchangeInMulti(address(subject)).exchangeInManyToOne(
            tokens, amounts, IERC20(address(subject)), 0, address(this), false, block.timestamp
        );
        (uint256 deployed0, uint256 deployed1) = _deployed();
        assertGt(deployed0, 0, "armed token0 position");
        assertGt(deployed1, 0, "armed token1 position");
        assertGt(asset0.balanceOf(address(subject)), 0, "token0 sleeve");
        assertGt(asset1.balanceOf(address(subject)), 0, "token1 sleeve");
    }

    function _depositCall(IERC20 token, uint256 amount, address recipient) internal view returns (bytes memory) {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (token, amount, IERC20(address(subject)), 0, recipient, true, block.timestamp));
    }

    function _prepare(IERC20 token, uint256 amount, bytes memory data) internal {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(token); amounts[0] = amount;
        IPretransfer(address(subject)).preparePretransfer(tokens, amounts, keccak256(data));
    }

    function _execute(bytes memory data) internal returns (uint256 result) {
        (bool success, bytes memory returned) = address(subject).call(data);
        if (!success) assembly ("memory-safe") { revert(add(returned, 32), mload(returned)) }
        result = abi.decode(returned, (uint256));
    }

    function _reject(bytes memory data, bytes memory expected) internal {
        uint256 supply = subject.totalSupply();
        uint256 balance0 = asset0.balanceOf(address(subject));
        uint256 balance1 = asset1.balanceOf(address(subject));
        uint256 holder = subject.balanceOf(address(this));
        (bool success, bytes memory returned) = address(subject).call(data);
        assertFalse(success, "unfunded/invalid operation succeeded");
        assertEq(returned, expected, "specific delivery error");
        assertEq(subject.totalSupply(), supply, "supply unchanged");
        assertEq(subject.balanceOf(address(this)), holder, "holder shares unchanged");
        assertEq(asset0.balanceOf(address(subject)), balance0, "token0 unchanged");
        assertEq(asset1.balanceOf(address(subject)), balance1, "token1 unchanged");
    }

    function test_preserved_phantomMintAndRedemption_token0() public { _demonstrate(true); }
    function test_preserved_phantomMintAndRedemption_token1() public { _demonstrate(false); }
    function _demonstrate(bool zeroForOne) internal {
        _bootstrap();
        (uint256 before0, uint256 before1) = _deployed();
        _trade(zeroForOne, 100 ether);
        (uint256 after0, uint256 after1) = _deployed();
        assertGt(zeroForOne ? after0 : after1, zeroForOne ? before0 : before1);
        IERC20 token = zeroForOne ? asset0 : asset1;
        IERC20 output = zeroForOne ? asset1 : asset0;
        assertEq(token.balanceOf(FALSE_DEPOSITOR), 0, "false depositor starts empty");
        uint256 supply = subject.totalSupply();
        vm.startPrank(FALSE_DEPOSITOR);
        uint256 minted = _execute(_depositCall(token, 25 ether, FALSE_DEPOSITOR));
        assertGt(minted, 0, "preserved implementation mints for no transfer");
        assertEq(token.balanceOf(FALSE_DEPOSITOR), 0, "false depositor spent no input");
        assertEq(subject.totalSupply(), supply + minted);
        subject.approve(address(subject), minted);
        uint256 redeemed = subject.exchangeIn(IERC20(address(subject)), minted, output, 0, FALSE_DEPOSITOR, false, block.timestamp);
        vm.stopPrank();
        assertGt(redeemed, 0, "phantom shares redeem real inventory");
        assertEq(output.balanceOf(FALSE_DEPOSITOR), redeemed);
        emit log_named_uint("phantom shares", minted);
        emit log_named_uint("redeemed tokens", redeemed);
    }
}
