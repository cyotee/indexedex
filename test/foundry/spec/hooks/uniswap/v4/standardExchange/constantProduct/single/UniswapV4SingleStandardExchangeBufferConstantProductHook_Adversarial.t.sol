// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";
import {SimpleYieldERC4626} from "contracts/test/stubs/SimpleYieldERC4626.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";
import {BetterEfficientHashLib} from "@crane/contracts/utils/BetterEfficientHashLib.sol";

/**
 * @title Adversarial DoD: reentrancy, donation, feeTo, SE mid-zap rollback (O16 / N1–N4).
 */
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_Adversarial_Test is TestBase {
    using BetterEfficientHashLib for bytes;

    function test_N2_donationDilutesLps_accepted() public {
        _seedLiveLiquidity();
        uint256 userLp = IERC20(hook).balanceOf(user);
        uint256 claimBefore = single.seClaimSupply();
        pairToken.mint(user, 50 ether);
        vm.startPrank(user);
        pairToken.approve(se, type(uint256).max);
        uint256 seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(address(pairToken)),
            50 ether,
            IERC20(se),
            0,
            user,
            false,
            block.timestamp
        );
        IERC20(se).transfer(hook, seOut);
        vm.stopPrank();
        assertEq(IERC20(hook).balanceOf(user), userLp);
        assertGe(single.seClaimSupply(), claimBefore);
    }

    /// @notice N1: hostile raw ERC20 reenters deposit mid transferFrom → nested call cannot succeed.
    function test_N1_hostileRaw_reentrancy_onDeposit() public {
        HostileRawToken hostile = new HostileRawToken();
        SimpleYieldERC4626 pVault = new SimpleYieldERC4626(pairToken);
        address se2 = _deployERC4626SE(address(pVault));

        IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs memory args =
            IUniswapV4SingleStandardExchangeBufferConstantProductHookPackage.PkgArgs({
                poolManager: address(pm),
                feeOracle: address(indexedexManager),
                standardExchange: se2,
                pairToken: address(pairToken),
                rawToken: address(hostile)
            });
        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, args);
        address hHook = PkgFactory.deployHook(hookPkg, args, mineNonce);
        IHook h = IHook(hHook);

        address alice = address(0xA11CE);
        hostile.mint(alice, 1_000_000 ether);
        pairToken.mint(alice, 1_000_000 ether);
        vm.startPrank(alice);
        hostile.approve(hHook, type(uint256).max);
        pairToken.approve(hHook, type(uint256).max);
        vm.stopPrank();

        // Seed live book (disarmed)
        {
            uint256 d0 = h.currency0() == address(hostile) ? 100 ether : 100 ether;
            uint256 d1 = h.currency1() == address(hostile) ? 100 ether : 100 ether;
            // map raw/pair correctly into pool order
            d0 = h.currency0() == address(hostile) ? 100 ether : 100 ether;
            d1 = h.currency1() == address(hostile) ? 100 ether : 100 ether;
            if (h.currency0() == address(hostile)) {
                d0 = 100 ether;
                d1 = 100 ether; // pair is currency1
            } else {
                d0 = 100 ether; // pair is currency0
                d1 = 100 ether; // hostile is currency1
            }
            vm.prank(alice);
            h.deposit(d0, d1, alice, 0, block.timestamp + 1);
        }
        assertTrue(h.isLive());

        // Arm: any transferFrom of hostile while spender/to involves hook reenters deposit
        hostile.arm(hHook, alice);
        assertTrue(hostile.armed());

        uint256 d0b = h.currency0() == address(hostile) ? 5 ether : 5 ether;
        uint256 d1b = h.currency1() == address(hostile) ? 5 ether : 5 ether;
        d0b = 5 ether;
        d1b = 5 ether;

        vm.prank(alice);
        try h.deposit(d0b, d1b, alice, 0, block.timestamp + 1) {} catch {}

        assertGe(hostile.reentryAttempts(), 1, "nested reentry must be attempted");
        assertFalse(hostile.nestedSucceeded(), "nested deposit must not succeed while locked");
    }

    /// @notice N4: SE exchangeIn reverts mid buffer during deposit → full rollback (no LP mint, no inventory).
    function test_N4_seRevertMidBuffer_fullRollback() public {
        _seedLiveLiquidity();
        uint256 supplyBefore = IERC20(hook).totalSupply();
        uint256 userLpBefore = IERC20(hook).balanceOf(user);
        uint256 rawUserBefore = rawToken.balanceOf(user);
        uint256 pairUserBefore = pairToken.balanceOf(user);
        uint256 hookRawBefore = rawToken.balanceOf(hook);
        uint256 hookSeBefore = IERC20(se).balanceOf(hook);

        // Only exchangeIn reverts (buffer path). Preview still works.
        vm.mockCallRevert(
            se,
            abi.encodeWithSelector(IStandardExchangeIn.exchangeIn.selector),
            abi.encodeWithSignature("Error(string)", "SE_DOWN")
        );

        uint256 a0 = _amountForCurrency(single.currency0(), 10 ether, 10 ether);
        uint256 a1 = _amountForCurrency(single.currency1(), 10 ether, 10 ether);
        vm.prank(user);
        vm.expectRevert();
        single.deposit(a0, a1, user, 0, block.timestamp + 1);

        // Full rollback
        assertEq(IERC20(hook).totalSupply(), supplyBefore, "no LP mint");
        assertEq(IERC20(hook).balanceOf(user), userLpBefore, "user LP unchanged");
        assertEq(rawToken.balanceOf(user), rawUserBefore, "user raw refunded");
        assertEq(pairToken.balanceOf(user), pairUserBefore, "user pair refunded");
        assertEq(rawToken.balanceOf(hook), hookRawBefore, "hook raw unchanged");
        assertEq(IERC20(se).balanceOf(hook), hookSeBefore, "hook SE unchanged");
    }

    /// @notice N3: protocol growth mint is pure ERC20 storage credit — non-receivable feeTo cannot
    /// revert the mint. Document product limitation (D75 / ERC20Repo._mint has no receiver callback).
    /// Equivalent exercised path: fee-on + yield growth + feeTo = contract that reverts on receive ETH
    /// still completes deposit and credits LP to feeTo balance.
    function test_N3_feeToNonReceivable_erc20MintCannotRevert() public {
        NonReceivableFeeTo badFeeTo = new NonReceivableFeeTo();
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(address(badFeeTo)));
        _enableProtocolFee(0.05e18);
        _seedLiveLiquidity();

        // Grow k via yield so next deposit mints protocol LP
        pairToken.mint(address(this), 20 ether);
        pairToken.approve(address(pairProtocolVault), 20 ether);
        pairProtocolVault.simulateYield(20 ether);

        uint256 feeLpBefore = IERC20(hook).balanceOf(address(badFeeTo));
        _depositBoth(10 ether, 10 ether);
        // Pure ERC20 mint succeeds even though feeTo reverts on native receive
        assertGt(IERC20(hook).balanceOf(address(badFeeTo)), feeLpBefore, "protocol LP credited via storage mint");
    }

    function test_I4_depositWithoutInit_ok() public {
        uint256 lp = _depositBoth(50 ether, 50 ether);
        assertGt(lp, 0);
        assertTrue(single.isLive());
    }
}

/// @dev Non-SUT: mintable raw that reenters hook.deposit on transferFrom when armed.
contract HostileRawToken is SimpleMintableERC20 {
    address public targetHook;
    address public reenterCaller;
    uint256 public reentryAttempts;
    bool public nestedSucceeded;
    bool public armed;

    constructor() SimpleMintableERC20("HostileRaw", "hRAW") {}

    function arm(address hook_, address caller_) external {
        targetHook = hook_;
        reenterCaller = caller_;
        armed = true;
        nestedSucceeded = false;
        reentryAttempts = 0;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        // Trigger when hook (or its DELEGATECALL context) pulls tokens.
        if (armed && targetHook != address(0) && (to == targetHook || msg.sender == targetHook)) {
            armed = false;
            unchecked {
                reentryAttempts += 1;
            }
            IHook h = IHook(targetHook);
            allowance[reenterCaller][targetHook] = type(uint256).max;
            // Nested deposit while outer deposit still holds reentrancy lock.
            try h.deposit(1 ether, 1 ether, reenterCaller, 0, block.timestamp + 1) {
                nestedSucceeded = true;
            } catch {
                nestedSucceeded = false;
            }
        }
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }
}

/// @dev FeeTo stand-in that reverts on native receive (cannot block ERC20 storage mint).
contract NonReceivableFeeTo {
    receive() external payable {
        revert("no eth");
    }

    fallback() external payable {
        revert("no fallback");
    }
}
