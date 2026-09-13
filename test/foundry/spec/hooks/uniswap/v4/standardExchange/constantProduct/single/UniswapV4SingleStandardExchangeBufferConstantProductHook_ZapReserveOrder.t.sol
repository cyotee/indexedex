// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals as TestBase
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook_Decimals.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService as PkgFactory
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapReserveOrder_Test
/// @notice Single deposits reconstruct raw reserves in the correct units in both currency orders.
contract UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapReserveOrder_Test is TestBase {
    bytes32 internal constant TRANSFER_TOPIC = keccak256("Transfer(address,address,uint256)");
    bytes32 internal constant ZAP_TOPIC = keccak256("ZapSwap(address,address,address,uint256,uint256)");

    struct BeforeZap {
        uint256 raw;
        uint256 pair;
        uint256 supply;
        uint256 feeLp;
        uint256 userLp;
        uint256 userInput;
    }

    struct ZapObservation {
        uint256 sold;
        uint256 received;
        uint256 pairIntake;
        bool sawZap;
        bool sawMint;
    }

    /// @dev The production package requires the DETF/raw leg to use eighteen decimals.
    function _rawDecimals() internal pure override returns (uint8) {
        return 18;
    }

    /// @dev Keep pair units different while the real SE wraps at a one-to-one atomic rate.
    function _pairDecimals() internal pure override returns (uint8) {
        return 6;
    }

    /// @notice Raw input with raw as currency0 uses the retained raw amount in reserve reconstruction.
    function test_zapRaw_currency0_independentLpAccounting() public {
        _checkZap(true, true);
    }

    /// @notice Pair input with raw as currency0 subtracts purchased raw, not retained pair units.
    function test_zapPair_rawCurrency0_independentLpAccounting() public {
        _checkZap(true, false);
    }

    /// @notice Raw input with raw as currency1 subtracts retained raw, not purchased pair units.
    function test_zapRaw_currency1_independentLpAccounting() public {
        _checkZap(false, true);
    }

    /// @notice Pair input with raw as currency1 uses the purchased raw amount in reserve reconstruction.
    function test_zapPair_rawCurrency1_independentLpAccounting() public {
        _checkZap(false, false);
    }

    /// @dev Reuse the registered package and real SE; only the non-SUT raw token address is selected.
    function _seedOrderedHook(bool rawFirst) internal {
        bytes32 initHash = keccak256(
            abi.encodePacked(type(MintableERC20Decimals).creationCode, abi.encode("Ordered raw", "oRAW", uint8(18)))
        );
        bool found;
        for (uint256 nonce; nonce < 256; ++nonce) {
            bytes32 salt = bytes32(nonce);
            address predicted = vm.computeCreate2Address(salt, initHash, address(this));
            if (predicted == address(pairToken) || (predicted < address(pairToken)) != rawFirst) continue;
            rawToken = new MintableERC20Decimals{salt: salt}("Ordered raw", "oRAW", 18);
            assertEq(address(rawToken), predicted, "selected raw address");
            found = true;
            break;
        }
        assertTrue(found, "raw address with requested currency order");

        uint256 mineNonce = PkgFactory.findMineNonce(hookFactory, hookPkg, _defaultPkgArgs());
        hook = PkgFactory.deployHook(hookPkg, _defaultPkgArgs(), mineNonce);
        _ensureProductDoorsAndFinalize(hook);
        single = IHook(hook);
        _bindProductPoolKey();
        assertEq(_isRawCurrency0(), rawFirst, "requested currency order is deployed");
        rawToken.mint(user, _uRaw(1_000));
        vm.startPrank(user);
        rawToken.approve(hook, type(uint256).max);
        pairToken.approve(hook, type(uint256).max);
        vm.stopPrank();
        // A zero vault override falls back to the global usage fee in this fixture.
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(se, 0);
        vm.stopPrank();
        assertEq(IVaultFeeOracleQuery(address(indexedexManager)).usageFeeOfVault(se), 0, "fee-free SE fixture");
        _enableProtocolFee(0.05e18);
        _depositBoth(_uRaw(300), _uPair(900));
        assertEq(single.rawReserve(), _uRaw(300), "initial raw book");
        assertEq(single.seClaimSupply(), _uPair(900), "one-to-one initial pair claim");
    }

    /// @dev Observe the internal swap, then derive the intake and LP independently in raw/pair units.
    function _checkZap(bool rawFirst, bool rawInput) internal {
        _seedOrderedHook(rawFirst);
        IERC20 input = IERC20(rawInput ? address(rawToken) : address(pairToken));
        uint256 amount = rawInput ? _uRaw(30) : _uPair(90);
        BeforeZap memory before_ = BeforeZap({
            raw: single.rawReserve(),
            pair: single.seClaimSupply(),
            supply: IERC20(hook).totalSupply(),
            feeLp: IERC20(hook).balanceOf(_feeTo()),
            userLp: IERC20(hook).balanceOf(user),
            userInput: input.balanceOf(user)
        });
        uint256 preview = single.previewDepositSingle(address(input), amount);
        vm.recordLogs();
        vm.prank(user);
        uint256 minted = single.depositSingle(address(input), amount, user, preview, block.timestamp);
        ZapObservation memory observed = _observeZap(vm.getRecordedLogs(), address(input));
        uint256 expected = _expectedLp(before_, observed, amount, rawInput, rawFirst);

        assertGt(expected, 0, "positive independent LP expectation");
        assertEq(minted, expected, "LP uses post-swap reserves in matching token units");
        assertEq(preview, expected, "preview matches independent post-swap accounting");
        assertEq(IERC20(hook).balanceOf(user) - before_.userLp, expected, "recipient LP credit");
        assertEq(IERC20(hook).totalSupply(), before_.supply + expected, "only depositor LP minted");
        assertEq(IERC20(hook).balanceOf(_feeTo()), before_.feeLp, "new capital creates no prior-growth fee");
        assertEq(before_.userInput - input.balanceOf(user), amount, "input debit");
        assertEq(single.rawReserve(), before_.raw + (rawInput ? amount : 0), "raw dust remains in inventory");
    }

    /// @dev Pair transfers after ZapSwap and before depositor LP mint are the proportional intake.
    ///      Later pair-dust buffering is deliberately excluded from the mint-time delta.
    function _observeZap(Vm.Log[] memory logs, address input) internal view returns (ZapObservation memory observed) {
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory entry = logs[i];
            if (entry.topics.length == 0) continue;
            if (entry.emitter == hook && entry.topics[0] == ZAP_TOPIC) {
                assertFalse(observed.sawZap, "one internal swap");
                address tokenIn;
                address tokenOut;
                (tokenIn, tokenOut, observed.sold, observed.received) =
                    abi.decode(entry.data, (address, address, uint256, uint256));
                assertEq(tokenIn, input, "observed swap input");
                assertEq(tokenOut, input == address(rawToken) ? address(pairToken) : address(rawToken), "swap output");
                observed.sawZap = true;
            }
            if (!observed.sawZap || entry.topics.length != 3 || entry.topics[0] != TRANSFER_TOPIC) continue;
            address from = address(uint160(uint256(entry.topics[1])));
            address to = address(uint160(uint256(entry.topics[2])));
            if (entry.emitter == hook && from == address(0) && to == user) {
                observed.sawMint = true;
                break;
            }
            if (entry.emitter == address(pairToken) && from == hook && to == se) {
                observed.pairIntake += abi.decode(entry.data, (uint256));
            }
        }
        assertTrue(observed.sawZap, "internal swap observed");
        assertTrue(observed.sawMint, "depositor LP mint observed");
        assertGt(observed.pairIntake, 0, "proportional pair intake observed");
    }

    /// @dev Ratios cancel the decimal scale within each leg. No production reserve/mint helper or
    ///      single-deposit preview supplies this expectation. The fixture has no SE yield or fees.
    function _expectedLp(
        BeforeZap memory before_,
        ZapObservation memory observed,
        uint256 amount,
        bool rawInput,
        bool rawFirst
    ) internal pure returns (uint256) {
        assertGt(observed.sold, 0, "positive internal sale");
        assertLt(observed.sold, amount, "retained input remains");
        uint256 rawAfterSwap = rawInput ? before_.raw + observed.sold : before_.raw - observed.received;
        uint256 pairAfterSwap = rawInput ? before_.pair - observed.received : before_.pair + observed.sold;
        uint256 addedRaw = rawInput ? amount - observed.sold : observed.received;
        uint256 offeredPair = rawInput ? observed.received : amount - observed.sold;

        // Currency0 is the initial budget. Currency1 is floored to its matching reserve ratio;
        // when that exceeds the available currency1, its budget instead limits currency0.
        uint256 expectedPairIntake;
        if (rawFirst) {
            uint256 pairForRaw = addedRaw * pairAfterSwap / rawAfterSwap;
            expectedPairIntake = pairForRaw < offeredPair ? pairForRaw : offeredPair;
        } else {
            uint256 rawForPair = offeredPair * rawAfterSwap / pairAfterSwap;
            expectedPairIntake = rawForPair <= addedRaw ? offeredPair : addedRaw * pairAfterSwap / rawAfterSwap;
        }
        assertEq(observed.pairIntake, expectedPairIntake, "independent proportional pair budget");

        // The existing dust policy keeps all added raw in the hook, including unused raw budget.
        uint256 rawLp = addedRaw * before_.supply / rawAfterSwap;
        uint256 pairLp = expectedPairIntake * before_.supply / pairAfterSwap;
        return rawLp < pairLp ? rawLp : pairLp;
    }
}
