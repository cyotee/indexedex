// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {VmSafe} from "forge-std/Vm.sol";
import {TestBase_UniswapV4PairTokenStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/test/bases/TestBase_UniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {IUniswapV4PairTokenStandardExchangeVaultDFPkg as IPackage} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVaultDFPkg.sol";
import {UniswapV4PairTokenStandardExchangeVaultExecution as Execution} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol";
import {UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService as Components} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultComponent_FactoryService.sol";
import {IWETH} from "@crane/contracts/interfaces/protocols/tokens/wrappers/weth/v9/IWETH.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";
import {ModifyLiquidityParams, SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IBasicVault} from "contracts/vaults/basic/IBasicVault.sol";
import {PoolActor} from "./harness/PoolActor.sol";

/// @notice Real ERC20 balances with a controllable transfer callback, not a vault or manager double.
contract PairTokenSecurityToken is IERC20Metadata {
    string public name = "Callback currency";
    string public symbol = "CALL";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address public immutable controller;
    address public vault;
    address public mutationTarget;
    bytes public mutation;
    bytes[] private probes;
    bool[] public successes;
    bytes[] public replies;
    bool public armed;
    bool public onPull;
    bool public onSend;

    constructor() { controller = msg.sender; }

    function mint(address to_, uint256 amount_) external returns (bool) {
        require(msg.sender == controller, "controller");
        totalSupply += amount_;
        balanceOf[to_] += amount_;
        emit Transfer(address(0), to_, amount_);
        return true;
    }

    function approve(address spender_, uint256 amount_) external returns (bool) {
        allowance[msg.sender][spender_] = amount_;
        emit Approval(msg.sender, spender_, amount_);
        return true;
    }

    function transfer(address to_, uint256 amount_) external returns (bool) {
        _move(msg.sender, to_, amount_);
        if (onSend) _probe();
        return true;
    }

    function transferFrom(address from_, address to_, uint256 amount_) external returns (bool) {
        if (allowance[from_][msg.sender] != type(uint256).max) allowance[from_][msg.sender] -= amount_;
        _move(from_, to_, amount_);
        if (onPull) _probe();
        return true;
    }

    function configure(address vault_, bytes[] memory probes_, address target_, bytes memory mutation_, bool pull_, bool send_)
        external
    {
        require(msg.sender == controller, "controller");
        vault = vault_;
        probes = probes_;
        mutationTarget = target_;
        mutation = mutation_;
        onPull = pull_;
        onSend = send_;
        delete successes;
        delete replies;
        armed = true;
    }

    function resultCount() external view returns (uint256) { return replies.length; }

    function _move(address from_, address to_, uint256 amount_) private {
        balanceOf[from_] -= amount_;
        balanceOf[to_] += amount_;
        emit Transfer(from_, to_, amount_);
    }

    function _probe() internal {
        if (!armed || msg.sender != vault) return;
        armed = false;
        if (mutationTarget != address(0)) {
            (bool ok_, bytes memory data_) = mutationTarget.call(mutation);
            if (!ok_) assembly ("memory-safe") { revert(add(data_, 32), mload(data_)) }
        }
        for (uint256 i_ = 0; i_ < probes.length; ++i_) {
            (bool ok_, bytes memory data_) = vault.call(probes[i_]);
            successes.push(ok_);
            replies.push(data_);
        }
    }
}

/// @notice A negative boundary wrapper with real one-to-one deposits and withdrawals.
/// @dev Only a controller-armed callback is added; no vault or manager behavior is mocked.
contract PairTokenSecurityWrapper is PairTokenSecurityToken {
    function deposit() external payable {
        balanceOf[msg.sender] += msg.value;
        totalSupply += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
        _probe();
    }

    function withdraw(uint256 amount_) external {
        balanceOf[msg.sender] -= amount_;
        totalSupply -= amount_;
        emit Transfer(msg.sender, address(0), amount_);
        (bool success_,) = msg.sender.call{value: amount_}("");
        require(success_, "wrapper payout");
        _probe();
    }
}

/// @notice A genuine outside-manager unlock context with no fabricated pool state.
contract PairTokenUnlockedCaller is IUnlockCallback {
    IPoolManager private immutable manager;
    bool public success;
    bytes public result;

    constructor(IPoolManager manager_) { manager = manager_; }

    function attempt(address vault_, bytes memory call_) external {
        manager.unlock(abi.encode(vault_, call_));
    }

    function unlockCallback(bytes calldata data_) external returns (bytes memory) {
        require(msg.sender == address(manager), "manager");
        (address vault_, bytes memory call_) = abi.decode(data_, (address, bytes));
        (success, result) = vault_.call(call_);
        return "";
    }
}

/// @notice C/N/H: callback read policy, cross-entry guards and immutable-plan rollback.
/// @dev All vault operations use a real registered diamond and real manager.
// tag::UniswapV4PairTokenStandardExchangeVaultSecurityTest[]
contract UniswapV4PairTokenStandardExchangeVaultSecurityTest is TestBase_UniswapV4PairTokenStandardExchangeVault {
    using PoolIdLibrary for PoolKey;
    PairTokenSecurityToken private probe;

    function _probePool() private {
        probe = new PairTokenSecurityToken();
        token0 = ERC20PermitMintableStub(address(probe));
        token1 = new ERC20PermitMintableStub("Other currency", "OTHER", 18, address(this), 0);
        if (address(token0) > address(token1)) (token0, token1) = (token1, token0);
        key = PoolKey(Currency.wrap(address(token0)), Currency.wrap(address(token1)), 3000, 60, IHooks(address(0)));
        pool.initialize(key, uint160(1) << 96);
        poolActor = new PoolActor(pool);
        IPackage.PkgArgs memory args_ = _defaultArgs(key, address(token0), "Callback vault");
        args_.maxZapTickMove = 2000;
        vault = _deployVault(args_);
        _bootstrap(1e18, 1e18, address(this));
    }

    function test_SEC_CallbackEconomicReadMatrixAndCommittedBook() public {
        _probePool();
        bytes memory committed_ = abi.encode(IBasicVault(address(vault)).reserves());
        bytes memory supply_ = abi.encode(IERC20(address(vault)).totalSupply());
        bytes memory domain_ = abi.encode(IERC20Permit(address(vault)).DOMAIN_SEPARATOR());
        bytes[] memory calls_ = new bytes[](17);
        calls_[0] = abi.encodeCall(IVault.positionLiquidity, ());
        calls_[1] = abi.encodeCall(IVault.localReserves, ());
        calls_[2] = abi.encodeCall(IVault.basket, ());
        calls_[3] = abi.encodeCall(IVault.previewDepositPair, (1, 1));
        calls_[4] = abi.encodeCall(IVault.previewRedeemPair, (1));
        calls_[5] = abi.encodeCall(IVault.previewWithdrawalMode, (1, true, address(0)));
        calls_[6] = abi.encodeCall(IVault.previewZapCredit, (address(token0), 1));
        calls_[7] = abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (IERC20(address(token0)), 1, IERC20(address(vault))));
        calls_[8] = abi.encodeCall(IStandardizedYield.previewDeposit, (address(token0), 1));
        calls_[9] = abi.encodeCall(IStandardizedYield.previewRedeem, (address(token1), 1));
        calls_[10] = abi.encodeCall(IStandardizedYield.exchangeRate, ());
        calls_[11] = abi.encodeCall(IStandardizedYield.previewDeposit, (address(123), 1));
        calls_[12] = abi.encodeCall(IStandardizedYield.previewRedeem, (address(123), 1));
        calls_[13] = abi.encodeCall(IBasicVault.reserves, ());
        calls_[14] = abi.encodeCall(IERC20.totalSupply, ());
        calls_[15] = abi.encodeCall(IERC20Permit.DOMAIN_SEPARATOR, ());
        calls_[16] = abi.encodeCall(IVault.poolManager, ());
        probe.configure(address(vault), calls_, address(0), "", true, false);
        _fund(address(this), 1e12, 1e12);
        vault.depositPair(1e12, 1e12, 0, address(this), block.timestamp);
        assertEq(probe.resultCount(), 17);
        for (uint256 i_ = 0; i_ < 13; ++i_) {
            assertFalse(probe.successes(i_));
            assertEq(probe.replies(i_), abi.encodeWithSelector(IVault.ReentrantOperation.selector));
        }
        for (uint256 i_ = 13; i_ < 17; ++i_) assertTrue(probe.successes(i_));
        assertEq(probe.replies(13), committed_);
        assertEq(probe.replies(14), supply_);
        assertEq(probe.replies(15), domain_);
        assertEq(probe.replies(16), abi.encode(pool));
    }

    function test_SEC_CrossFacetMoneyReentryAndUnconditionalOut() public {
        _probePool();
        bytes[] memory calls_ = new bytes[](9);
        calls_[0] = abi.encodeCall(IVault.compound, ());
        calls_[1] = abi.encodeCall(IVault.donate, (address(token0), 1));
        calls_[2] = abi.encodeCall(IVault.depositPair, (1, 1, 0, address(this), block.timestamp));
        calls_[3] = abi.encodeCall(IVault.redeemPair, (1, 0, 0, address(this), block.timestamp));
        calls_[4] = abi.encodeCall(IStandardExchangeIn.exchangeIn, (IERC20(address(token0)), 1, IERC20(address(vault)), 0, address(this), false, block.timestamp));
        calls_[5] = abi.encodeCall(IStandardizedYield.deposit, (address(this), address(token0), 1, 0));
        calls_[6] = abi.encodeCall(IStandardExchangeOut.previewExchangeOut, (IERC20(address(0)), IERC20(address(0)), 0));
        calls_[7] = abi.encodeCall(IStandardExchangeOut.exchangeOut, (IERC20(address(0)), 0, IERC20(address(0)), 0, address(0), true, 0));
        calls_[8] = abi.encodeCall(IUnlockCallback.unlockCallback, (hex"deadbeef"));
        probe.configure(address(vault), calls_, address(0), "", true, false);
        _fund(address(this), 1e12, 1e12);
        vault.depositPair(1e12, 1e12, 0, address(this), block.timestamp);
        assertEq(probe.resultCount(), calls_.length);
        for (uint256 i_ = 0; i_ < calls_.length; ++i_) {
            assertFalse(probe.successes(i_));
            bytes4 expected_ = i_ < 6 ? IVault.ReentrantOperation.selector
                : i_ < 8 ? IStandardExchangeOut.ExchangeOutNotAvailable.selector : Execution.InvalidCallback.selector;
            assertEq(probe.replies(i_), abi.encodeWithSelector(expected_));
        }
    }

    function test_SEC_AlreadyUnlockedManagerRejectsBeforeNestedUnlock() public {
        PairTokenUnlockedCaller caller_ = new PairTokenUnlockedCaller(pool);
        caller_.attempt(address(vault), abi.encodeCall(IVault.compound, ()));
        assertFalse(caller_.success());
        assertEq(caller_.result(), abi.encodeWithSelector(IVault.ManagerAlreadyUnlocked.selector));
        assertEq(IERC20(address(vault)).totalSupply(), 0);
    }

    function test_SEC_UnsolicitedAndReplayedCallbackPayloadsReject() public {
        bytes[] memory payloads_ = new bytes[](3);
        payloads_[0] = "";
        payloads_[1] = hex"deadbeef";
        payloads_[2] = abi.encode(uint256(5), bytes("wrong operation"));
        for (uint256 i_ = 0; i_ < payloads_.length; ++i_) {
            vm.expectRevert(Execution.InvalidCallback.selector);
            IUnlockCallback(address(vault)).unlockCallback(payloads_[i_]);
            vm.prank(address(pool));
            vm.expectRevert(Execution.InvalidCallback.selector);
            IUnlockCallback(address(vault)).unlockCallback(payloads_[i_]);
        }
        _bootstrap(1e18, 1e18, address(this));
        vm.prank(address(pool));
        vm.expectRevert(Execution.InvalidCallback.selector);
        IUnlockCallback(address(vault)).unlockCallback(payloads_[2]);
        vault.compound();
    }

    function test_SEC_PullPriceMutationInvalidatesAndRollsBack() public {
        _probePool();
        _fund(address(poolActor), 1e18, 1e18);
        bytes memory mutation_ = abi.encodeCall(PoolActor.swap, (
            key, SwapParams(true, -int256(1e12), TickMath.MIN_SQRT_PRICE + 1)
        ));
        _mutationRollback(mutation_, false);
    }

    /// @notice A39: replay the actual authenticated manager calldata, not an invented payload.
    /// @dev The canonical hookless manager returns the committed bytes unchanged,
    /// and the commitment is consumed before any token callback can run.
    function test_SEC_ActualManagerCallbackCannotBeReplayedOrModified() public {
        vm.startStateDiffRecording();
        _bootstrap(1e18, 1e18, address(this));
        VmSafe.AccountAccess[] memory accesses_ = vm.stopAndReturnStateDiff();
        bytes memory callback_;
        for (uint256 i_; i_ < accesses_.length; ++i_) {
            if (
                accesses_[i_].kind == VmSafe.AccountAccessKind.Call
                    && accesses_[i_].accessor == address(pool)
                    && accesses_[i_].account == address(vault)
                    && accesses_[i_].data.length >= 4
                    && bytes4(accesses_[i_].data) == IUnlockCallback.unlockCallback.selector
            ) {
                callback_ = accesses_[i_].data;
                break;
            }
        }
        assertGt(callback_.length, 4, "real manager callback not captured");
        uint256 supply_ = IERC20(address(vault)).totalSupply();
        uint128 liquidity_ = vault.positionLiquidity();
        for (uint256 i_; i_ < 2; ++i_) {
            if (i_ == 1) callback_[callback_.length - 1] ^= bytes1(uint8(1));
            vm.prank(address(pool));
            (bool success_, bytes memory result_) = address(vault).call(callback_);
            assertFalse(success_);
            assertEq(result_, abi.encodeWithSelector(Execution.InvalidCallback.selector));
            assertEq(IERC20(address(vault)).totalSupply(), supply_);
            assertEq(vault.positionLiquidity(), liquidity_);
        }
    }

    function test_SEC_FutureOnlyBitmapMutationInvalidatesWithoutPriceMove() public {
        _probePool();
        _fund(address(poolActor), 1e18, 1e18);
        bool input0_ = address(probe) == address(token0);
        int24 lower_ = input0_ ? int24(-600) : int24(540);
        int24 upper_ = lower_ + 60;
        bytes memory mutation_ = abi.encodeCall(PoolActor.modifyLiquidity, (
            key, ModifyLiquidityParams(lower_, upper_, 1e15, bytes32(0))
        ));
        _mutationRollback(mutation_, true);
    }

    function test_SEC_FutureOnlyTickMutationInvalidatesAtUnchangedBitmap() public {
        _probePool();
        _fund(address(poolActor), 1e18, 1e18);
        bool input0_ = address(probe) == address(token0);
        int24 lower_ = input0_ ? int24(-600) : int24(540);
        int24 upper_ = lower_ + 60;
        poolActor.modifyLiquidity(key, ModifyLiquidityParams(lower_, upper_, 1e15, bytes32(0)));
        bytes memory mutation_ = abi.encodeCall(PoolActor.modifyLiquidity, (
            key, ModifyLiquidityParams(lower_, upper_, 1e15, bytes32(0))
        ));
        _mutationRollback(mutation_, true);
    }

    function test_SEC_WrapperUnwrapMutationInvalidatesWithoutRetry() public {
        PairTokenSecurityWrapper wrapper_ = _wrapperPool();
        vm.deal(address(this), address(this).balance + 1e15);
        wrapper_.deposit{value: 1e15}();
        wrapper_.approve(address(vault), 1e15);
        uint256 supply_ = IERC20(address(vault)).totalSupply();
        uint128 liquidity_ = vault.positionLiquidity();
        (uint160 price_,,,) = StateLibrary.getSlot0(pool, key.toId());
        _armWrapper(wrapper_);
        vm.expectRevert(IVault.EconomicStateChanged.selector);IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(wrapper_)), 1e15, IERC20(address(vault)), 0, address(this), false, block.timestamp
        );
        assertEq(wrapper_.balanceOf(address(this)), 1e15);
        assertEq(wrapper_.balanceOf(address(vault)), 0);
        assertEq(wrapper_.allowance(address(this), address(vault)), 1e15);
        assertEq(IERC20(address(vault)).totalSupply(), supply_);
        assertEq(vault.positionLiquidity(), liquidity_);
        (uint160 afterPrice_,,,) = StateLibrary.getSlot0(pool, key.toId());
        assertEq(afterPrice_, price_);
        assertTrue(wrapper_.armed());
    }

    function test_SEC_WrapperWrapMutationRollsBackBurnAndSale() public {
        PairTokenSecurityWrapper wrapper_ = _wrapperPool();
        uint256 supply_ = IERC20(address(vault)).totalSupply();
        uint128 liquidity_ = vault.positionLiquidity();
        uint256 native_ = address(vault).balance;
        uint256 token_ = token1.balanceOf(address(vault));
        (uint160 price_,,,) = StateLibrary.getSlot0(pool, key.toId());
        _armWrapper(wrapper_);
        vm.expectRevert(IVault.EconomicStateChanged.selector);
        IStandardizedYield(address(vault)).redeem(address(this), supply_ / 10, address(wrapper_), 0, false);
        assertEq(IERC20(address(vault)).totalSupply(), supply_);
        assertEq(IERC20(address(vault)).balanceOf(address(this)), supply_);
        assertEq(vault.positionLiquidity(), liquidity_);
        assertEq(address(vault).balance, native_);
        assertEq(token1.balanceOf(address(vault)), token_);
        assertEq(wrapper_.balanceOf(address(this)), 0);
        assertEq(wrapper_.balanceOf(address(vault)), 0);
        (uint160 afterPrice_,,,) = StateLibrary.getSlot0(pool, key.toId());
        assertEq(afterPrice_, price_);
        assertTrue(wrapper_.armed());
    }

    function _wrapperPool() private returns (PairTokenSecurityWrapper wrapper_) {
        assertTrue(vm.revertToState(packageDeploymentSnapshot));
        wrapper_ = new PairTokenSecurityWrapper();
        wrappedNative = IWETH(address(wrapper_));
        pkgInit.wrappedNative = wrappedNative;
        vm.prank(owner);
        pairTokenPackage = Components.deployUniswapV4PairTokenStandardExchangeVaultDFPkg(indexedexManager, pkgInit);
        _deployPool(true, 18, 18);
        vault = _deployVault(_defaultArgs(key, address(wrapper_), "Callback wrapper vault"));
        _bootstrap(1e18, 1e18, address(this));
        _fund(address(poolActor), 1e18, 1e18);
    }

    function _armWrapper(PairTokenSecurityWrapper wrapper_) private {
        wrapper_.configure(address(vault), new bytes[](0), address(poolActor),
            abi.encodeCall(PoolActor.swap, (key, SwapParams(true, -int256(1e12), TickMath.MIN_SQRT_PRICE + 1))),
            false, false);
    }

    function _mutationRollback(bytes memory mutation_, bool zap_) private {
        uint256 supply_ = IERC20(address(vault)).totalSupply();
        uint128 liquidity_ = vault.positionLiquidity();
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        (uint160 price_, int24 tick_,,) = StateLibrary.getSlot0(pool, key.toId());
        _fund(address(this), 1e17, 1e17);
        uint256 balance0_ = token0.balanceOf(address(this));
        uint256 balance1_ = token1.balanceOf(address(this));
        uint256 allowance_ = probe.allowance(address(this), address(vault));
        probe.configure(address(vault), new bytes[](0), address(poolActor), mutation_, true, false);
        vm.expectRevert(IVault.EconomicStateChanged.selector);
        if (zap_) {IStandardExchangeIn(address(vault)).exchangeIn(IERC20(address(probe)), 9e16, IERC20(address(vault)), 0, address(this), false, block.timestamp
            );
        } else {
            vault.depositPair(1e12, 1e12, 0, address(this), block.timestamp);
        }
        assertEq(IERC20(address(vault)).totalSupply(), supply_);
        assertEq(vault.positionLiquidity(), liquidity_);
        (uint256 after0_, uint256 after1_) = vault.localReserves();
        assertEq(after0_, book0_); assertEq(after1_, book1_);
        (uint160 afterPrice_, int24 afterTick_,,) = StateLibrary.getSlot0(pool, key.toId());
        assertEq(afterPrice_, price_); assertEq(afterTick_, tick_);
        assertEq(token0.balanceOf(address(this)), balance0_);
        assertEq(token1.balanceOf(address(this)), balance1_);
        assertEq(probe.allowance(address(this), address(vault)), allowance_);
        assertTrue(probe.armed());
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultSecurityTest[]
