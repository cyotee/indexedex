// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3FlashCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3FlashCallback.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/SqrtPriceMath.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {IStandardExchangeBundleIn, IStandardExchangeBundleOut} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/interfaces/IUniswapV4FullSpreadStandardExchangeVault.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from "./TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice Real manager/registry proxy and pool fixture. No SUT storage writes or mocks.
/// @dev Expected mint liquidity is independently maximized from pool callback debts.
abstract contract TestBase_UniswapV3FullSpreadAccounting is
    TestBase_UniswapV3FullSpreadStandardExchangeVault, IUniswapV3FlashCallback
{
    uint128 internal constant SEED = 1e12;
    uint128 internal constant EXTERNAL_LIQUIDITY = 1e18;
    uint160 internal constant Q96 = uint160(1) << 96;
    bytes32 internal constant SWAP_TOPIC = keccak256("Swap(address,address,int256,int256,uint160,uint128,int24)");
    bytes32 internal constant MINT_TOPIC = keccak256("Mint(address,address,int24,int24,uint128,uint256,uint256)");

    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    ERC20PermitMintableStub internal token0;
    ERC20PermitMintableStub internal token1;
    address internal alice;
    address internal bob;
    address internal recipient;
    int24 internal lower;
    int24 internal upper;

    struct PoolTrace {
        uint256 swaps;
        uint256 mints;
        int256 delta0;
        int256 delta1;
        uint128 mintedLiquidity;
        uint256 mint0;
        uint256 mint1;
    }

    /// @notice Start with an empty vault, a real external LP, and funded independent users.
    function setUp() public virtual override {
        super.setUp();
        alice = makeAddr("accounting-alice");
        bob = makeAddr("accounting-bob");
        recipient = makeAddr("accounting-recipient");
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultUsageFee(0);
        _freshMarket(true);
    }

    function _freshMarket(bool externalLiquidity_) internal {
        ERC20PermitMintableStub a_ = new ERC20PermitMintableStub("Accounting A", "AA", 18, address(this), 0);
        ERC20PermitMintableStub b_ = new ERC20PermitMintableStub("Accounting B", "AB", 18, address(this), 0);
        pool = _createPoolOneToOne(address(a_), address(b_), FEE_MEDIUM);
        token0 = ERC20PermitMintableStub(pool.token0());
        token1 = ERC20PermitMintableStub(pool.token1());
        lower = TickMath.minUsableTick(pool.tickSpacing());
        upper = TickMath.maxUsableTick(pool.tickSpacing());
        if (externalLiquidity_) _seedExternalLiquidity(pool, EXTERNAL_LIQUIDITY);
        vault = _deployVault(pool);
        _fundAccount(alice);
        _fundAccount(bob);
        _fundAccount(recipient);
        _fundAccount(address(this));
    }

    function _fundAccount(address account_) internal {
        token0.mint(account_, 1e42);
        token1.mint(account_, 1e42);
        vm.startPrank(account_);
        token0.approve(address(vault), type(uint256).max);
        token1.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _seedVault(uint128 liquidity_) internal returns (uint256 shares_) {
        (shares_,) = _bundleIn(alice, liquidity_, liquidity_);
    }

    function _amountArray(uint256 amount0_, uint256 amount1_) internal pure returns (uint256[] memory amounts_) {
        amounts_ = new uint256[](2);
        amounts_[0] = amount0_;
        amounts_[1] = amount1_;
    }

    function _tokensOut() internal view returns (address[] memory tokens_) {
        tokens_ = new address[](2);
        tokens_[0] = address(token0);
        tokens_[1] = address(token1);
    }

    function _bundleIn(address caller_, uint256 amount0_, uint256 amount1_)
        internal
        returns (uint256 shares_, uint256[] memory refunds_)
    {
        vm.prank(caller_);
        return IStandardExchangeBundleIn(address(vault)).exchangeBundleInForSingleOut(
            _amountArray(amount0_, amount1_), address(vault), 0, caller_, false, block.timestamp
        );
    }

    function _bundleOut(address caller_, uint256 shares_, address recipient_, bool pretransferred_)
        internal
        returns (uint256[] memory amounts_)
    {
        vm.prank(caller_);
        (amounts_,) = IStandardExchangeBundleOut(address(vault)).exchangeBundleOut(
            address(vault), shares_, _tokensOut(), _amountArray(0, 0), recipient_, pretransferred_, block.timestamp
        );
    }

    function _positionKey() internal view returns (bytes32) {
        return keccak256(abi.encodePacked(address(vault), lower, upper));
    }

    function _positionLiquidity() internal view returns (uint128 liquidity_) {
        (liquidity_,,,,) = pool.positions(_positionKey());
    }

    /// @dev Read-only ledger observation; no state is manufactured for the SUT.
    function _booked() internal view returns (uint256 booked0_, uint256 booked1_) {
        uint256 slot_ = uint256(keccak256("indexedex.protocols.dexes.uniswap.v3.vault"));
        booked0_ = uint256(vm.load(address(vault), bytes32(slot_ + 1)));
        booked1_ = uint256(vm.load(address(vault), bytes32(slot_ + 2)));
    }

    function _assertSettled() internal view {
        uint256 slot_ = uint256(keccak256("indexedex.protocols.dexes.uniswap.v3.vault"));
        for (uint256 i_ = 3; i_ <= 6; ++i_) {
            assertEq(vm.load(address(vault), bytes32(slot_ + i_)), bytes32(0), "operation custody remains reserved");
        }
    }

    function _setUsageFee(uint256 fee_) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(address(vault), fee_);
    }

    function _setFeeRecipient(address feeTo_) internal {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setFeeTo(IFeeCollectorProxy(feeTo_));
    }

    function _amounts(uint160 price_, uint128 liquidity_, bool up_)
        internal
        view
        returns (uint256 amount0_, uint256 amount1_)
    {
        uint160 a_ = TickMath.getSqrtRatioAtTick(lower);
        uint160 b_ = TickMath.getSqrtRatioAtTick(upper);
        if (price_ <= a_) amount0_ = SqrtPriceMath.getAmount0Delta(a_, b_, liquidity_, up_);
        else if (price_ >= b_) amount1_ = SqrtPriceMath.getAmount1Delta(a_, b_, liquidity_, up_);
        else {
            amount0_ = SqrtPriceMath.getAmount0Delta(price_, b_, liquidity_, up_);
            amount1_ = SqrtPriceMath.getAmount1Delta(a_, price_, liquidity_, up_);
        }
    }

    /// @dev Independent test oracle: binary maximization of actual pool debts.
    /// Production uses an algebraic inverse; no production planner/math is called here.
    function _expectedLiquidity(uint160 price_, uint256 budget0_, uint256 budget1_) internal view returns (uint128) {
        (uint128 loGross_,,,,,,,) = pool.ticks(lower);
        (uint128 hiGross_,,,,,,,) = pool.ticks(upper);
        uint256 lo_;
        uint256 hi_ = pool.maxLiquidityPerTick() - (loGross_ > hiGross_ ? loGross_ : hiGross_);
        while (lo_ < hi_) {
            uint256 mid_ = lo_ + (hi_ - lo_ + 1) / 2;
            (uint256 debt0_, uint256 debt1_) = _amounts(price_, uint128(mid_), true);
            if (debt0_ <= budget0_ && debt1_ <= budget1_) lo_ = mid_;
            else hi_ = mid_ - 1;
        }
        return uint128(lo_);
    }

    /// @dev Create fees through a real zero-borrow flash. Call at a fresh fee checkpoint.
    function _poolFees(uint256 paid0_, uint256 paid1_) internal returns (uint256 fee0_, uint256 fee1_) {
        uint128 active_ = pool.liquidity();
        uint128 own_ = _positionLiquidity();
        fee0_ = FullMath.mulDiv(FullMath.mulDiv(paid0_, uint256(1) << 128, active_), own_, uint256(1) << 128);
        fee1_ = FullMath.mulDiv(FullMath.mulDiv(paid1_, uint256(1) << 128, active_), own_, uint256(1) << 128);
        pool.flash(address(this), 0, 0, abi.encode(paid0_, paid1_));
    }

    /// @notice Pay a real pool flash donation, without mocking any pool or vault state.
    function uniswapV3FlashCallback(uint256 fee0_, uint256 fee1_, bytes calldata data_) external override {
        require(msg.sender == address(pool), "foreign flash callback");
        require(fee0_ == 0 && fee1_ == 0, "fixture borrows nothing");
        (uint256 paid0_, uint256 paid1_) = abi.decode(data_, (uint256, uint256));
        if (paid0_ != 0) token0.transfer(msg.sender, paid0_);
        if (paid1_ != 0) token1.transfer(msg.sender, paid1_);
    }

    function _swapTo(uint160 price_) internal {
        (uint160 current_,,,,,,) = pool.slot0();
        pool.swap(address(this), price_ < current_, 1e40, price_, abi.encode(address(this)));
        (uint160 after_,,,,,,) = pool.slot0();
        assertEq(after_, price_, "fixture reaches the requested real pool price");
    }

    function _poolTrace(Vm.Log[] memory logs_) internal view returns (PoolTrace memory trace_) {
        for (uint256 i_; i_ < logs_.length; ++i_) {
            if (logs_[i_].emitter != address(pool) || logs_[i_].topics.length == 0) continue;
            if (logs_[i_].topics[0] == SWAP_TOPIC) {
                ++trace_.swaps;
                (trace_.delta0, trace_.delta1,,,) =
                    abi.decode(logs_[i_].data, (int256, int256, uint160, uint128, int24));
            } else if (
                logs_[i_].topics[0] == MINT_TOPIC
                    && address(uint160(uint256(logs_[i_].topics[1]))) == address(vault)
            ) {
                ++trace_.mints;
                (, trace_.mintedLiquidity, trace_.mint0, trace_.mint1) =
                    abi.decode(logs_[i_].data, (address, uint128, uint256, uint256));
            }
        }
    }
}
