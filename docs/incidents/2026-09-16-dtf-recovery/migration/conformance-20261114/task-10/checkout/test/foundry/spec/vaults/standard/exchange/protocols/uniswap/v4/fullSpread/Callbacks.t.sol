// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IUniswapV4FullSpreadStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault, IFullSpreadVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {TransientStateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TransientStateLibrary.sol";
import {IUniswapV4FullSpreadStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol";
import {UnlockedExchangeCaller} from "./AlreadyUnlocked.t.sol";
import {Vm} from "forge-std/Vm.sol";
import {UniswapV4FullSpreadStandardExchangeVaultRepo as Repo} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultRepo.sol";

interface IFullSpreadCallback {
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}

interface ISettlementObserver {
    function observeSettlement(address from_, uint256 amount_) external;
}

/// @notice Non-SUT funding token; real transfers probe the live vault during action settlement.
contract CallbackProbeToken is MintableERC20Decimals {
    address public observer;
    address public vault;
    address public manager;

    constructor() MintableERC20Decimals("Callback probe", "PROBE", 18) {}

    function arm(address observer_, address vault_, address manager_) external {
        observer = observer_;
        vault = vault_;
        manager = manager_;
    }

    function transfer(address to_, uint256 amount_) external override returns (bool) {
        _transfer(msg.sender, to_, amount_);
        if (observer != address(0) && ((msg.sender == vault && to_ == manager) || (msg.sender == manager && to_ == vault))) {
            ISettlementObserver(observer).observeSettlement(msg.sender, amount_);
        }
        return true;
    }
}

contract UniswapV4FullSpreadStandardExchangeVault_Callbacks_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    CallbackProbeToken internal probe;
    uint256 internal observed;
    uint128 internal priorLiquidity;
    bool internal minting;
    bool internal borrowed;

    function setUp() public override {
        super.setUp();
        probe = new CallbackProbeToken();
        token0 = ERC20PermitMintableStub(address(probe));
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        key.currency0 = Currency.wrap(address(token0));
        key.currency1 = Currency.wrap(address(token1));
        pool.initialize(key, uint160(1) << 96);
        vault = IFullSpreadVault(package.deployVault(IPackage.PkgArgs(key)));
        probe.mint(address(this), 1_000_000 ether);
        ERC20PermitMintableStub(address(token0) == address(probe) ? address(token1) : address(token0))
            .mint(address(this), 1_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        vault.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
    }

    function test_strangerCallbackReverts() public {
        bytes32 before_ = _callbackState();
        vm.expectRevert(IVault.SettlementMismatch.selector);
        IFullSpreadCallback(address(vault)).unlockCallback("");
        assertEq(_callbackState(), before_, "stranger callback restores custody and position");
    }

    function test_uncommittedPayloadReverts() public {
        bytes32 before_ = _callbackState();
        bytes memory payload_ = abi.encode(uint8(0), false, uint256(0), int256(0));
        vm.prank(address(pool));
        vm.expectRevert(IVault.SettlementMismatch.selector);
        IFullSpreadCallback(address(vault)).unlockCallback(payload_);
        assertEq(_callbackState(), before_, "uncommitted callback restores custody and position");
    }

    /// @dev Observe live custody and the complete family book without modifying SUT storage.
    function _callbackState() internal view returns (bytes32) {
        bytes32[6] memory slots_;
        for (uint256 i_; i_ < slots_.length; ++i_) {
            slots_[i_] = vm.load(address(vault), bytes32(uint256(Repo.STORAGE_SLOT) + i_));
        }
        return keccak256(abi.encode(
            vault.totalSupply(), vault.balanceOf(address(this)), vault.positionLiquidity(),
            token0.balanceOf(address(this)), token1.balanceOf(address(this)),
            token0.balanceOf(address(vault)), token1.balanceOf(address(vault)),
            token0.balanceOf(address(pool)), token1.balanceOf(address(pool)), slots_,
            TransientStateLibrary.currencyDelta(pool, address(vault), key.currency0),
            TransientStateLibrary.currencyDelta(pool, address(vault), key.currency1)
        ));
    }

    /// @notice M19: a real two-action mint consumes each commitment once and keeps the guard held.
    function test_lockedMintOneUnlockAndConsumedCallbackPerAction() public {
        minting = true;
        _arm();
        _expectTwoLockedActions();
        vm.startStateDiffRecording();
        (uint256 shares_,) = vault.exchangeIn(
            address(probe), 100 ether, address(vault), 0, address(this), false, block.timestamp
        );
        _assertGuardAndCommitmentLifetime();
        assertGt(shares_, 0);
        assertEq(observed, 2, "swap settlement and add settlement were both probed");
        assertFalse(TransientStateLibrary.isUnlocked(pool), "manager relocked");
    }

    /// @notice M19: removal and opposing-claim swap each consume their own callback on withdrawal.
    function test_lockedExitOneUnlockAndConsumedCallbackPerAction() public {
        _arm();
        _expectTwoLockedActions();
        address wanted_ = address(probe) == address(token0) ? address(token1) : address(token0);
        uint256 before_ = IERC20(wanted_).balanceOf(address(this));
        vm.startStateDiffRecording();
        (uint256 receipt_,) = vault.exchangeIn(
            address(vault), 100 ether, wanted_, 0, address(this), false, block.timestamp
        );
        _assertGuardAndCommitmentLifetime();
        assertGt(receipt_, 0);
        assertEq(IERC20(wanted_).balanceOf(address(this)) - before_, receipt_);
        assertEq(observed, 2, "remove settlement and swap settlement were both probed");
        assertFalse(TransientStateLibrary.isUnlocked(pool));
    }

    /// @notice M19: the equivalent borrowed mint performs no vault-started unlock or callback.
    function test_borrowedMintDoesNotDispatchUnlockOrCallback() public {
        UnlockedExchangeCaller caller_ = new UnlockedExchangeCaller();
        probe.mint(address(caller_), 100 ether);
        vm.prank(address(caller_));
        IERC20(address(probe)).approve(address(vault), type(uint256).max);
        minting = true;
        borrowed = true;
        _arm();
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(1));
        vm.expectCall(address(vault), abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector), uint64(0));
        bytes memory ret_ = caller_.run(pool, address(vault), abi.encodeWithSelector(
            IFullSpreadVault.exchangeIn.selector,
            address(probe), 100 ether, address(vault), 0, address(caller_), false, block.timestamp
        ));
        (uint256 shares_,) = abi.decode(ret_, (uint256, uint256));
        assertEq(vault.balanceOf(address(caller_)), shares_);
        assertGt(shares_, 0);
        assertEq(observed, 2);
    }

    /// @notice Observe actual transfer settlement, never a replaced manager or a patched vault.
    function observeSettlement(address from_, uint256 amount_) external {
        assertEq(msg.sender, address(probe));
        bool swap_ = minting ? observed == 0 : observed == 1;
        uint128 liquidity_ = vault.positionLiquidity();
        bytes memory payload_ = swap_
            ? abi.encode(uint8(1), address(probe) == address(token0), amount_, int256(0))
            : abi.encode(uint8(2), false, uint256(0), int256(uint256(liquidity_)) - int256(uint256(priorLiquidity)));
        if (swap_) assertEq(from_, address(vault), "opposing input is settled by the vault");
        // The public guard must still be held during settlement of both successive actions.
        (bool ok_, bytes memory reason_) = address(vault).call(abi.encodeWithSelector(
            IFullSpreadVault.exchangeIn.selector,
            address(probe), 1 ether, address(vault), 0, address(this), false, block.timestamp
        ));
        assertFalse(ok_);
        assertEq(reason_, abi.encodeWithSelector(IVault.ReentrantOperation.selector));
        if (!borrowed) {
            // Replay the exact action payload after consume, while the original guard is still held.
            vm.prank(address(pool));
            (ok_, reason_) = address(vault).call(abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector, payload_));
            assertFalse(ok_);
            assertEq(reason_, abi.encodeWithSelector(IVault.SettlementMismatch.selector));
        }
        priorLiquidity = liquidity_;
        ++observed;
    }

    function _arm() internal {
        priorLiquidity = vault.positionLiquidity();
        probe.arm(address(this), address(vault), address(pool));
    }

    function _expectTwoLockedActions() internal {
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.unlock.selector), uint64(2));
        // Two successful callbacks and two deliberately rejected replays.
        vm.expectCall(address(vault), abi.encodeWithSelector(IUnlockCallback.unlockCallback.selector), uint64(4));
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.swap.selector), uint64(1));
        vm.expectCall(address(pool), abi.encodeWithSelector(IPoolManager.modifyLiquidity.selector), uint64(1));
    }

    /// @dev Read the recorded real writes: one guard lifetime across both actions, two consumed commitments.
    function _assertGuardAndCommitmentLifetime() internal {
        Vm.StorageAccess[] memory accesses_ = vm.getStorageAccesses();
        vm.stopAndReturnStateDiff();
        bytes32 guardSlot_ = bytes32(uint256(Repo.STORAGE_SLOT) + 5);
        bytes32 hashSlot_ = bytes32(uint256(Repo.STORAGE_SLOT) + 2);
        uint256 opened_;
        uint256 closed_;
        uint256 committed_;
        uint256 consumed_;
        for (uint256 i_; i_ < accesses_.length; ++i_) {
            Vm.StorageAccess memory access_ = accesses_[i_];
            if (access_.account != address(vault) || !access_.isWrite || access_.reverted) continue;
            if (access_.slot == guardSlot_) {
                uint256 was_ = uint256(access_.previousValue) & 0xff;
                uint256 now_ = uint256(access_.newValue) & 0xff;
                if (was_ == 0 && now_ == 1) ++opened_;
                if (was_ == 1 && now_ == 0) ++closed_;
            }
            if (access_.slot == hashSlot_) {
                if (access_.previousValue == bytes32(0) && access_.newValue != bytes32(0)) ++committed_;
                if (access_.previousValue != bytes32(0) && access_.newValue == bytes32(0)) ++consumed_;
            }
        }
        assertEq(opened_, 1, "guard opens once across the whole plan");
        assertEq(closed_, 1, "guard never drops between manager actions");
        assertEq(committed_, 2, "one commitment per planned action");
        assertEq(consumed_, 2, "each callback consumes its own commitment once");
    }
}
