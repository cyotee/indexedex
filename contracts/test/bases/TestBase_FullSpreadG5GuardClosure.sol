// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Permit} from "@crane/contracts/interfaces/IERC20Permit.sol";
import {IERC2612} from "@crane/contracts/interfaces/IERC2612.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IERC165} from "@crane/contracts/interfaces/IERC165.sol";
import {IDiamondLoupe} from "@crane/contracts/interfaces/IDiamondLoupe.sol";
import {Proxy} from "@crane/contracts/proxies/Proxy.sol";
import {IReentrancyLock} from "@crane/contracts/interfaces/IReentrancyLock.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardizedYield as SY} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {StandardExchangeConstantProduct} from "contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol";
import {NativeStandardYieldTarget} from "contracts/vaults/standard/sy/NativeStandardYieldTarget.sol";
import {FullSpreadG5GuardToken} from "contracts/test/stubs/FullSpreadG5GuardToken.sol";
import {FullSpreadG5CreditHandler} from "contracts/test/stubs/FullSpreadG5CreditHandler.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";

// tag::TestBase_FullSpreadG5GuardClosure[]
/// @notice G5 guard assertions executed independently against the H and P production fixtures.
/// @dev Ordinary holder exchangeIn currently burns own shares without allowance. ERC20
/// transferFrom still requires allowance. Do not restore the obsolete legacy pull expectation.
abstract contract TestBase_FullSpreadG5GuardClosure is Test {
    IStandardExchangeProxy internal g5Vault;
    IERC20[2] internal g5Tokens;
    FullSpreadG5GuardToken internal g5Hostile;
    IPoolManager internal g5Manager;
    address internal g5Hook;
    address private g5HistoryHandler;
    address internal constant G5_RECIPIENT = address(0x65001);
    address internal constant G5_DEAD = address(0xdEaD);

    function _g5Blocked(bytes memory data_) internal virtual returns (bytes memory);
    function _g5DisablePackage(bool disabled_) internal virtual;
    function _g5HistoryTrade(bool direction_, uint256 amount_) internal virtual;
    function _g5HistorySleeve(uint256 percentage_) internal virtual;

    /// @notice Authorized handler market action using the existing actual-core fixture.
    function g5HistoryTrade(bool direction_, uint256 amount_) external {
        require(msg.sender == g5HistoryHandler, "G5 history driver");
        _g5HistoryTrade(direction_, amount_);
    }

    /// @notice Authorized handler live fee-oracle change through the fixture's real manager.
    function g5HistorySleeve(uint256 percentage_) external {
        require(msg.sender == g5HistoryHandler, "G5 history driver");
        _g5HistorySleeve(percentage_);
    }
    function _g5Initialize(IStandardExchangeProxy vault_, IERC20 token0_, IERC20 token1_, IPoolManager manager_, address hook_) internal {
        g5Vault = vault_; g5Tokens = [token0_, token1_]; g5Manager = manager_; g5Hook = hook_;
    }
    function _g5Assets() internal view returns (address[] memory values_) {
        values_ = new address[](2); values_[0] = address(g5Tokens[0]); values_[1] = address(g5Tokens[1]);
    }
    function _g5Amounts(uint256 a_, uint256 b_) internal pure returns (uint256[] memory values_) {
        values_ = new uint256[](2); values_[0] = a_; values_[1] = b_;
    }
    function _g5Join(uint256 amount_, bool blocked_) internal returns (uint256) {
        bytes memory data = abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
            (_g5Assets(), _g5Amounts(amount_, amount_), IERC20(address(g5Vault)), 0, address(this), false, block.timestamp));
        return abi.decode(_g5Execute(data, blocked_), (uint256));
    }
    function _g5Execute(bytes memory data_, bool blocked_) internal returns (bytes memory result_) {
        if (blocked_) return _g5Blocked(data_);
        bool ok; (ok, result_) = address(g5Vault).call(data_);
        if (!ok) assembly ("memory-safe") { revert(add(result_, 32), mload(result_)) }
    }
    function _g5In(IERC20 in_, uint256 amount_, IERC20 out_, uint256 min_, address to_, bool pushed_)
        internal view returns (bytes memory)
    {
        return abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (in_, amount_, out_, min_, to_, pushed_, block.timestamp));
    }
    function _g5Book() internal view {
        for (uint256 i; i < 2; ++i) {
            assertEq(g5Vault.reserveOfToken(address(g5Tokens[i])), g5Tokens[i].balanceOf(address(g5Vault)));
        }
        assertEq(g5Vault.reserveOfToken(address(g5Vault)), g5Vault.balanceOf(address(g5Vault)));
        assertEq(address(g5Vault).balance, 0);
    }
    function _g5Digest() internal view returns (bytes32) {
        (bytes memory book,) = Transition(address(g5Vault)).quoteState(address(g5Tokens[0]), address(this));
        bytes32 tokenLedger;
        for (uint256 i; i < 2; ++i) {
            IERC20 token = g5Tokens[i];
            tokenLedger = keccak256(abi.encode(tokenLedger, token.balanceOf(address(this)),
                token.balanceOf(address(g5Vault)), token.balanceOf(G5_RECIPIENT),
                token.allowance(address(this), address(g5Vault)), g5Vault.reserveOfToken(address(token))));
            tokenLedger = keccak256(abi.encode(tokenLedger, token.totalSupply(),
                token.balanceOf(address(g5Manager)), token.balanceOf(g5Hook)));
        }
        return keccak256(abi.encode(book, tokenLedger, g5Vault.totalSupply(),
            g5Vault.balanceOf(address(this)), g5Vault.balanceOf(G5_RECIPIENT),
            g5Vault.balanceOf(address(g5Hostile)), g5Vault.balanceOf(address(g5Vault)),
            g5Vault.reserveOfToken(address(g5Vault)), address(g5Vault).balance));
    }
    function _g5Reject(bytes memory data_, bytes memory error_, bool blocked_) internal {
        bytes32 beforeState = _g5Digest();
        vm.expectRevert(error_);
        // External trampoline is needed: expectRevert observes the entire real unlock,
        // rather than swallowing a nested failure in this test contract.
        this.g5ExecuteForRevert(data_, blocked_);
        assertEq(_g5Digest(), beforeState, "G5 atomic rollback");
    }
    /// @notice Test-only external boundary for exact revert and complete state checks.
    function g5ExecuteForRevert(bytes memory data_, bool blocked_) external returns (bytes memory) {
        require(msg.sender == address(this), "G5 driver only"); return _g5Execute(data_, blocked_);
    }

    /// @notice Minimum is rejected; minimum+1 mints exactly one share in idle and real blocked states.
    function test_G5_bootstrapMinimumPlusOneIdleAndBlocked() public {
        for (uint256 mode; mode < 2; ++mode) {
            uint256 restore = vm.snapshotState();
            uint256 minimum = 1e15; // Independent 18/18 decimal policy: 10^(18-3).
            bytes memory bad = abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
                (_g5Assets(), _g5Amounts(minimum, minimum), IERC20(address(g5Vault)), 0,
                address(this), false, block.timestamp));
            _g5Reject(bad, abi.encodeWithSelector(StandardExchangeConstantProduct.InsufficientMinimumLiquidity.selector,
                minimum, minimum), mode == 1);
            _g5Reject(abi.encodeCall(IStandardExchangeInMulti.previewExchangeInManyToOne,
                (_g5Assets(), _g5Amounts(minimum, minimum), IERC20(address(g5Vault)))),
                abi.encodeWithSelector(StandardExchangeConstantProduct.InsufficientMinimumLiquidity.selector,
                    minimum, minimum), mode == 1);
            bytes memory preview = abi.encodeCall(IStandardExchangeInMulti.previewExchangeInManyToOne,
                (_g5Assets(), _g5Amounts(minimum + 1, minimum + 1), IERC20(address(g5Vault))));
            assertEq(abi.decode(_g5Execute(preview, mode == 1), (uint256)), 1);
            uint256 before0 = g5Tokens[0].balanceOf(address(this));
            uint256 before1 = g5Tokens[1].balanceOf(address(this));
            assertEq(_g5Join(minimum + 1, mode == 1), 1);
            assertEq(g5Vault.balanceOf(address(this)), 1);
            assertEq(g5Vault.balanceOf(G5_DEAD), minimum);
            assertEq(g5Vault.totalSupply(), minimum + 1);
            assertEq(before0 - g5Tokens[0].balanceOf(address(this)), minimum + 1);
            assertEq(before1 - g5Tokens[1].balanceOf(address(this)), minimum + 1);
            _g5Book(); assertTrue(vm.revertToState(restore));
        }
    }

    /// @notice A real decimals dependency error propagates and a later retry activates normally.
    function test_G5_bootstrapMetadataFailureAndRetry() public {
        uint256 before0 = g5Tokens[0].balanceOf(address(this));
        uint256 before1 = g5Tokens[1].balanceOf(address(this));
        g5Hostile.setMetadataFailure(true);
        vm.expectRevert(FullSpreadG5GuardToken.G5MetadataUnavailable.selector);
        IStandardExchangeInMulti(address(g5Vault)).previewExchangeInManyToOne(
            _g5Assets(), _g5Amounts(1e18, 1e18), IERC20(address(g5Vault)));
        for (uint256 mode; mode < 2; ++mode) {
            vm.expectRevert(FullSpreadG5GuardToken.G5MetadataUnavailable.selector);
            this.g5ExecuteForRevert(abi.encodeCall(IStandardExchangeInMulti.exchangeInManyToOne,
                (_g5Assets(), _g5Amounts(1e18, 1e18), IERC20(address(g5Vault)), 0,
                address(this), false, block.timestamp)), mode == 1);
        }
        assertEq(g5Tokens[0].balanceOf(address(this)), before0);
        assertEq(g5Tokens[1].balanceOf(address(this)), before1);
        assertEq(g5Vault.totalSupply(), 0); assertEq(g5Vault.balanceOf(G5_DEAD), 0);
        assertEq(g5Tokens[0].balanceOf(address(g5Vault)), 0);
        assertEq(g5Tokens[1].balanceOf(address(g5Vault)), 0);
        g5Hostile.setMetadataFailure(false);
        assertEq(_g5Join(1e18, true), 1e18 - 1e15); _g5Book();
    }

    /// @notice Passive donations issue nothing and each donated leg remains excluded from first-minter ownership.
    function test_G5_bootstrapDonationCannotBeCaptured() public {
        for (uint256 leg; leg < 2; ++leg) {
            uint256 restore = vm.snapshotState();
            g5Tokens[leg].transfer(address(g5Vault), 10e18);
            assertEq(g5Vault.totalSupply(), 0); assertEq(g5Vault.balanceOf(address(this)), 0);
            uint256 callerShares = 1e18 - 1e15;
            assertEq(_g5Join(1e18, true), callerShares);
            uint256 residual = 10 * callerShares; // ceil(10e18 * shares / 1e18), exactly divisible.
            assertEq(g5Vault.balanceOf(G5_DEAD), 1e15 + residual);
            assertEq(g5Vault.totalSupply(), 1e18 + residual);
            for (uint256 i; i < 2; ++i) {
                assertLe(g5Tokens[i].balanceOf(address(g5Vault)) * callerShares,
                    1e18 * g5Vault.totalSupply(), "first minter captures prior assets");
            }
            _g5Book(); assertTrue(vm.revertToState(restore));
        }
    }

    /// @notice A permit authorizes exactly one spender/value; signature replay and overspending fail.
    function test_G5_sharePermitReplayAndSpentAllowance() public {
        _g5Join(1_000e18, true);
        uint256 key = 0x650A11CE;
        address holder = vm.addr(key);
        g5Vault.transfer(holder, 2e18);
        IERC20Permit permit = IERC20Permit(address(g5Vault));
        uint256 deadline = block.timestamp + 100;
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
            holder, address(this), 1e18, permit.nonces(holder), deadline));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key,
            keccak256(abi.encodePacked(hex"1901", permit.DOMAIN_SEPARATOR(), structHash)));
        permit.permit(holder, address(this), 1e18, deadline, v, r, s);
        assertEq(g5Vault.allowance(holder, address(this)), 1e18);
        vm.prank(G5_RECIPIENT);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, G5_RECIPIENT, 0, 1e18));
        g5Vault.transferFrom(holder, G5_RECIPIENT, 1e18);
        uint256 recipientBefore = g5Vault.balanceOf(address(this));
        g5Vault.transferFrom(holder, address(this), 1e18);
        assertEq(g5Vault.balanceOf(address(this)), recipientBefore + 1e18);
        assertEq(g5Vault.balanceOf(holder), 1e18);
        assertEq(g5Vault.allowance(holder, address(this)), 0); assertEq(permit.nonces(holder), 1);
        vm.expectPartialRevert(IERC2612.ERC2612InvalidSigner.selector);
        permit.permit(holder, address(this), 1e18, deadline, v, r, s);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 1e18));
        g5Vault.transferFrom(holder, address(this), 1e18);
        assertEq(g5Vault.balanceOf(holder), 1e18); assertEq(permit.nonces(holder), 1);
        _g5Book();
    }

    /// @notice Third-party ERC20 pulls need allowance; current own-share SE burns do not.
    function test_G5_ordinarySharePullNeedsAllowanceAndHolderExitUsesOwnShares() public {
        _g5Join(1_000e18, true);
        vm.prank(G5_RECIPIENT);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, G5_RECIPIENT, 0, 1e18));
        g5Vault.transferFrom(address(this), G5_RECIPIENT, 1e18);
        g5Vault.approve(G5_RECIPIENT, 1e18);
        vm.prank(G5_RECIPIENT); g5Vault.transferFrom(address(this), G5_RECIPIENT, 1e18);
        assertEq(g5Vault.allowance(address(this), G5_RECIPIENT), 0);
        assertEq(g5Vault.balanceOf(G5_RECIPIENT), 1e18);
        // No approval from this contract to the vault: current holder route is deliberate.
        assertEq(g5Vault.allowance(address(this), address(g5Vault)), 0);
        uint256 quote = g5Vault.previewExchangeIn(IERC20(address(g5Vault)), 1e18, g5Tokens[0]);
        uint256 beforeOutput = g5Tokens[0].balanceOf(G5_RECIPIENT);
        assertEq(g5Vault.exchangeIn(IERC20(address(g5Vault)), 1e18, g5Tokens[0], quote,
            G5_RECIPIENT, false, block.timestamp), quote);
        assertEq(g5Tokens[0].balanceOf(G5_RECIPIENT), beforeOutput + quote); _g5Book();
    }

    /// @notice FoT short delivery restores the entire operation and underlying token burn.
    function test_G5_feeOnTransferRollback() public {
        _g5Join(1_000e18, true);
        g5Hostile.setFee(true);
        uint256 supply = g5Hostile.totalSupply();
        _g5Reject(_g5In(IERC20(address(g5Hostile)), 1e18, IERC20(address(g5Vault)), 0, G5_RECIPIENT, false),
            abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0.99e18), true);
        assertEq(g5Hostile.totalSupply(), supply);
        g5Hostile.setFee(false);
        assertGt(abi.decode(_g5Blocked(_g5In(IERC20(address(g5Hostile)), 1e18,
            IERC20(address(g5Vault)), 0, G5_RECIPIENT, false)), (uint256)), 0); _g5Book();
    }

    /// @notice Token-held SY claims cannot escape the SE lock; propagating callbacks roll back delivery.
    function test_G5_nestedSyAndExchangeCallbackRollback() public {
        _g5Join(1_000e18, true);
        g5Vault.transfer(address(g5Hostile), 2e18);
        for (uint256 mode; mode < 2; ++mode) {
            bytes memory nested = mode == 0
                ? abi.encodeCall(SY.redeem, (G5_RECIPIENT, 1e18, address(g5Tokens[0]), 0, false))
                : _g5In(IERC20(address(g5Vault)), 1e18, g5Tokens[0], 0, G5_RECIPIENT, false);
            g5Hostile.setCallback(address(g5Vault), nested, false);
            bytes memory deposit = _g5In(IERC20(address(g5Hostile)), 1e18, IERC20(address(g5Vault)), 0, address(this), false);
            assertGt(abi.decode(_g5Blocked(deposit), (uint256)), 0);
            assertEq(g5Hostile.callbackAttempts(), 1);
            assertEq(g5Hostile.callbackError(), abi.encodeWithSelector(IReentrancyLock.IsLocked.selector));
            assertEq(g5Vault.balanceOf(address(g5Hostile)), 2e18);
            assertEq(g5Tokens[0].balanceOf(G5_RECIPIENT), 0);
            g5Hostile.setCallback(address(g5Vault), nested, true);
            _g5Reject(deposit, abi.encodeWithSelector(IReentrancyLock.IsLocked.selector), true);
            assertEq(g5Hostile.callbackAttempts(), 0, "callback write must roll back");
            assertEq(g5Vault.balanceOf(address(g5Hostile)), 2e18);
        }
        g5Hostile.setCallback(address(0), "", false); _g5Book();
    }

    /// @notice Package disable blocks both inbound interfaces while F3 and SY exits remain usable.
    function test_G5_packageDisablePreservesValidExitsAndReenable() public {
        _g5Join(1_000e18, true); _g5DisablePackage(true);
        bytes memory disabled = abi.encodeWithSelector(IVaultRegistryDisableQuery.VaultDisabled.selector, address(g5Vault));
        _g5Reject(_g5In(g5Tokens[0], 1e18, IERC20(address(g5Vault)), 0, address(this), false), disabled, true);
        _g5Reject(abi.encodeCall(SY.deposit, (address(this), address(g5Tokens[0]), 1e18, 0)), disabled, true);
        uint256 supply = g5Vault.totalSupply();
        bytes memory dual = abi.encodeCall(IStandardExchangeOutMulti.exchangeOutOneToMany,
            (IERC20(address(g5Vault)), 1e18, _g5Assets(), _g5Amounts(1e18, 1e18), G5_RECIPIENT, false, block.timestamp));
        assertEq(abi.decode(_g5Blocked(dual), (uint256)), 1e18);
        assertEq(g5Vault.totalSupply(), supply - 1e18);
        assertEq(g5Tokens[0].balanceOf(G5_RECIPIENT), 1e18);
        assertEq(g5Tokens[1].balanceOf(G5_RECIPIENT), 1e18);
        bytes memory preview = abi.encodeCall(SY.previewRedeem, (address(g5Tokens[1]), 1e18));
        uint256 quote = abi.decode(_g5Blocked(preview), (uint256));
        assertEq(abi.decode(_g5Blocked(abi.encodeCall(SY.redeem,
            (G5_RECIPIENT, 1e18, address(g5Tokens[1]), quote, false))), (uint256)), quote);
        assertEq(g5Tokens[1].balanceOf(G5_RECIPIENT), 1e18 + quote);
        assertEq(g5Vault.totalSupply(), supply - 2e18);
        _g5DisablePackage(false);
        uint256 recipientShares = g5Vault.balanceOf(G5_RECIPIENT);
        uint256 minted = abi.decode(_g5Blocked(abi.encodeCall(SY.deposit,
            (G5_RECIPIENT, address(g5Tokens[0]), 1e18, 0))), (uint256));
        assertGt(minted, 0);
        assertEq(g5Vault.balanceOf(G5_RECIPIENT), recipientShares + minted);
        assertEq(g5Vault.totalSupply(), supply - 2e18 + minted); _g5Book();
    }

    /// @notice Removed prepare and cut selectors have no loupe target and revert with exact proxy errors.
    function test_G5_removedPreparationAndDiamondCutUnavailable() public {
        bytes4 prepare = bytes4(keccak256("preparePretransfer(address[],uint256[],bytes32)"));
        bytes4 cut = bytes4(keccak256("diamondCut((address,uint8,bytes4[])[],address,bytes)"));
        for (uint256 i; i < 2; ++i) {
            bytes4 selector = i == 0 ? prepare : cut;
            assertEq(IDiamondLoupe(address(g5Vault)).facetAddress(selector), address(0));
            assertFalse(IERC165(address(g5Vault)).supportsInterface(selector));
            _g5Reject(abi.encodePacked(selector), abi.encodeWithSelector(Proxy.NoTargetFor.selector, selector), false);
        }
        assertEq(g5Vault.decimals(), 18);
    }

    /// @notice Positive-domain guard precedence and exact rollback, including SY receiver validation.
    function test_G5_zeroDeadlineUnsupportedAndRecipientGuards() public {
        _g5Join(1_000e18, true);
        _g5Reject(_g5In(g5Tokens[0], 0, IERC20(address(g5Vault)), 0, address(this), false),
            abi.encodeWithSignature("UniswapV4Exchange_ZeroAmount()"), false);
        vm.warp(block.timestamp + 10);
        _g5Reject(abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (g5Tokens[0], 1e18, IERC20(address(g5Vault)), 0, address(this), false, block.timestamp - 1)),
            abi.encodeWithSignature("UniswapV4ExchangeIn_DeadlineExceeded()"), false);
        _g5Reject(abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (g5Tokens[0], 1e18, IERC20(address(g5Vault)), 1e12, address(this), false, block.timestamp - 1)),
            abi.encodeWithSignature("UniswapV4ExchangeOut_DeadlineExceeded()"), true);
        _g5Reject(_g5In(IERC20(address(0x650BAD)), 1e18, IERC20(address(g5Vault)), 0, address(this), false),
            abi.encodeWithSelector(IStandardExchangeIn.ExchangeInNotAvailable.selector), false);
        _g5Reject(abi.encodeCall(SY.redeem, (address(0), 1e18, address(g5Tokens[0]), 0, false)),
            abi.encodeWithSelector(NativeStandardYieldTarget.InvalidSYReceiver.selector), false);
        _g5Reject(abi.encodeCall(SY.deposit, (G5_RECIPIENT, address(g5Tokens[0]), 0, 0)),
            abi.encodeWithSelector(NativeStandardYieldTarget.ZeroSYAmount.selector), false);
        _g5Reject(abi.encodeCall(SY.redeem, (G5_RECIPIENT, 1e18, address(0x650BAD), 0, false)),
            abi.encodeWithSelector(NativeStandardYieldTarget.InvalidSYToken.selector, address(0x650BAD)), false);
        _g5Book();
    }

    /// @notice Idle internal SY slippage restores context; retry burns only requested booked shares.
    function test_G5_idleSyMinimumRetryContextAndBookedSurplus() public {
        _g5Join(1_000e18, false);
        g5Vault.transfer(address(g5Vault), 3e18);
        // A funded dual join books the donated shares without treating them as join credit.
        _g5Join(1e18, false);
        assertEq(g5Vault.reserveOfToken(address(g5Vault)), 3e18);
        for (uint256 leg; leg < 2; ++leg) {
            _g5Reject(abi.encodeCall(SY.redeem,
                (G5_RECIPIENT, 1e18, address(g5Tokens[leg]), type(uint256).max, true)),
                abi.encodeWithSignature("UniswapV4ExchangeIn_SlippageExceeded()"), false);
            uint256 quote = SY(address(g5Vault)).previewRedeem(address(g5Tokens[leg]), 1e18);
            uint256 supply = g5Vault.totalSupply();
            uint256 beforeOutput = g5Tokens[leg].balanceOf(G5_RECIPIENT);
            assertEq(SY(address(g5Vault)).redeem(G5_RECIPIENT, 1e18, address(g5Tokens[leg]), quote, true), quote);
            assertEq(g5Tokens[leg].balanceOf(G5_RECIPIENT), beforeOutput + quote);
            assertEq(g5Vault.totalSupply(), supply - 1e18);
            assertEq(g5Vault.balanceOf(address(g5Vault)), (2 - leg) * 1e18);
            // An ordinary caller with no own shares cannot borrow the completed SY context.
            vm.prank(G5_RECIPIENT);
            vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, G5_RECIPIENT, 0, 1e18));
            g5Vault.exchangeIn(IERC20(address(g5Vault)), 1e18, g5Tokens[leg], 0, G5_RECIPIENT, false, block.timestamp);
            _g5Reject(_g5In(IERC20(address(g5Vault)), 1e18, g5Tokens[leg], 0, G5_RECIPIENT, true),
                abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0), false);
            _g5Book();
        }
    }

    /// @notice External idle SY failure preserves payer claims and retries without allowance or self residue.
    function test_G5_idleExternalSyMinimumRetryBothFaces() public {
        _g5Join(1_000e18, false);
        for (uint256 leg; leg < 2; ++leg) {
            _g5Reject(abi.encodeCall(SY.redeem,
                (G5_RECIPIENT, 1e18, address(g5Tokens[leg]), type(uint256).max, false)),
                abi.encodeWithSignature("UniswapV4ExchangeIn_SlippageExceeded()"), false);
            uint256 quote = SY(address(g5Vault)).previewRedeem(address(g5Tokens[leg]), 1e18);
            uint256 beforeShares = g5Vault.balanceOf(address(this));
            uint256 supply = g5Vault.totalSupply();
            uint256 beforeOutput = g5Tokens[leg].balanceOf(G5_RECIPIENT);
            assertEq(g5Vault.allowance(address(this), address(g5Vault)), 0);
            assertEq(SY(address(g5Vault)).redeem(G5_RECIPIENT, 1e18, address(g5Tokens[leg]), quote, false), quote);
            assertEq(g5Tokens[leg].balanceOf(G5_RECIPIENT), beforeOutput + quote);
            assertEq(g5Vault.balanceOf(address(this)), beforeShares - 1e18);
            assertEq(g5Vault.totalSupply(), supply - 1e18);
            assertEq(g5Vault.balanceOf(address(g5Vault)), 0); _g5Book();
        }
    }

    /// @notice Distinct stateful extension: every credit action runs for all three funded wallets.
    /// @dev Does not claim all legacy 24 actions. Existing 32-step formula campaign remains separate.
    /// forge-config: default.fuzz.runs = 128
    function testFuzz_G5_threeActorCreditHistories(uint256 seed_) public {
        FullSpreadG5CreditHandler handler = _g5StartHistory(true);
        for (uint256 step; step < 48; ++step) {
            seed_ = uint256(keccak256(abi.encode(seed_, step))); handler.step(seed_);
        }
        handler.assertCoverage(); handler.assertAccounting(); _g5Book();
    }

    /// @notice All three wallets mint, redeem, swap, survive hostile callbacks and continue using the same proxy.
    function test_G5_threeActorMixedMoneyAndReentryHistories() public {
        FullSpreadG5CreditHandler handler = _g5StartHistory(false);
        handler.runMixedHistories(g5Hostile);
        handler.assertAccounting(); _g5Book();
    }

    function _g5StartHistory(bool blocked_) private returns (FullSpreadG5CreditHandler handler) {
        _g5Join(1_000e18, blocked_);
        handler = new FullSpreadG5CreditHandler(
            g5Vault, g5Manager, g5Tokens[0], g5Tokens[1], g5Hook);
        g5HistoryHandler = address(handler);
        for (uint256 i; i < 3; ++i) {
            address actor = address(handler.actors(i));
            g5Vault.transfer(actor, 100e18);
            g5Tokens[0].transfer(actor, 100e18); g5Tokens[1].transfer(actor, 100e18);
        }
        handler.start();
    }
}
// end::TestBase_FullSpreadG5GuardClosure[]
