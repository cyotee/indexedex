// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";

import {
    TestBase_MixedLegWeightedBufferPool
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/weighted/mixedLegBuffer/bases/TestBase_MixedLegWeightedBufferPool.sol";

/**
 * @title MixedLeg_P4_Smoke
 * @notice U=0 P=4 (T=8 max) deploy + cross-pair / share↔share smoke.
 */
contract MixedLeg_P4_Smoke is TestBase_MixedLegWeightedBufferPool {
    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 0;
    }

    function _targetPairCount() internal pure override returns (uint8) {
        return 4;
    }

    function test_deploy_U0_P4() public view {
        assertEq(ml().unpairedCount(), 0);
        assertEq(ml().pairCount(), 4);
        assertEq(ml().tokenCount(), 8);
        assertEq(address(ml().bufferToken(0)), address(dai));
        assertEq(address(ml().bufferToken(1)), address(usdt));
        assertEq(address(ml().bufferToken(2)), address(weth));
        assertEq(address(ml().bufferToken(3)), address(wsteth));
    }

    function test_weights_sumToOne_P4() public view {
        uint256 sum;
        for (uint256 t; t < 8; ++t) {
            sum += ml().weight(t);
        }
        assertEq(sum, 1e18);
    }

    function test_swap_P4_crossPair_buffer0_to_share3() public {
        uint256 amt = 2e18;
        dai.mint(alice, amt);
        uint256 v0 = ml().virtualBuffer(0);
        uint256 out = swapExactIn(alice, buffer0, IERC20(address(seVault3)), amt);
        assertGt(out, 0);
        assertGt(ml().virtualBuffer(0), v0);
    }

    function test_swap_P4_share_to_share() public {
        uint256 amt = 2e18;
        mintSharesForPair(1, alice, amt * 2);
        uint256 out = swapExactIn(alice, IERC20(address(seVault1)), IERC20(address(seVault2)), amt);
        assertGt(out, 0);
    }

    function test_swap_P4_buffer_to_buffer() public {
        uint256 amt = 2e18;
        usdt.mint(alice, amt);
        uint256 v1 = ml().virtualBuffer(1);
        uint256 v2 = ml().virtualBuffer(2);
        uint256 out = swapExactIn(alice, buffer1, buffer2, amt);
        assertGt(out, 0);
        assertGt(ml().virtualBuffer(1), v1);
        assertLt(ml().virtualBuffer(2), v2);
    }
}

/**
 * @title MixedLeg_T8_U4P2_Smoke
 * @notice U=4 P=2 → T=8. Unpaired must not collide with pair buffers (DAI, USDT).
 * @dev Unpaired: USDC, WETH, WSTETH + extra mintable ERC20 deployed in setUp.
 */
contract MixedLeg_T8_U4P2_Smoke is TestBase_MixedLegWeightedBufferPool {
    // Override unpaired to avoid buffer collisions: pair buffers = dai, usdt.
    // Indices 0..2 = usdc, weth, wsteth; index 3 needs a free token.
    IERC20 internal extraUnpaired;

    function _targetUnpairedCount() internal pure override returns (uint8) {
        return 4;
    }

    function _targetPairCount() internal pure override returns (uint8) {
        return 2;
    }

    function setUp() public virtual override {
        // Deploy free ERC20 before super (pool deploy + init read _unpairedTokenAt / mint).
        extraUnpaired = IERC20(address(new ExtraUnpairedToken()));
        super.setUp();
    }

    /// @dev Permit2 must be ready before parent `_initPool` (called after `_deployBufferPool`).
    function _deployBufferPool() internal override {
        super._deployBufferPool();
        for (uint256 i; i < users.length; ++i) {
            vm.startPrank(users[i]);
            extraUnpaired.approve(address(permit2), type(uint256).max);
            permit2.approve(address(extraUnpaired), address(router), type(uint160).max, type(uint48).max);
            extraUnpaired.approve(address(router), type(uint256).max);
            vm.stopPrank();
        }
    }

    function _unpairedTokenAt(uint8 i) internal view override returns (IERC20) {
        if (i == 0) return IERC20(address(usdc));
        if (i == 1) return IERC20(address(weth));
        if (i == 2) return IERC20(address(wsteth));
        return extraUnpaired;
    }

    function _mintToken(address token, address to, uint256 amount) internal override {
        if (token == address(extraUnpaired)) {
            ExtraUnpairedToken(address(extraUnpaired)).mint(to, amount);
            return;
        }
        super._mintToken(token, to, amount);
    }

    function test_deploy_U4_P2() public view {
        assertEq(ml().unpairedCount(), 4);
        assertEq(ml().pairCount(), 2);
        assertEq(ml().tokenCount(), 8);
    }

    function test_swap_unpairedExtra_to_buffer0() public {
        uint256 amt = 2e18;
        ExtraUnpairedToken(address(extraUnpaired)).mint(alice, amt);
        vm.startPrank(alice);
        extraUnpaired.approve(address(permit2), type(uint256).max);
        permit2.approve(address(extraUnpaired), address(router), type(uint160).max, type(uint48).max);
        extraUnpaired.approve(address(router), type(uint256).max);
        vm.stopPrank();

        uint256 v0 = ml().virtualBuffer(0);
        uint256 out = swapExactIn(alice, extraUnpaired, buffer0, amt);
        assertGt(out, 0);
        assertLt(ml().virtualBuffer(0), v0);
    }
}

contract ExtraUnpairedToken {
    string public name = "ExtraUnpaired";
    string public symbol = "XUP";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
