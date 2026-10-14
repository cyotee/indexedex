// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice RC-04: exact-output quote rejection, post-swap settlement, and funded fill on the FullSpread proxy.
/// @dev Quote-stage cases below do not reach the post-swap output-delta guard.
///      The settlement witness is a separate case on this proxy.
contract UniswapV3FullSpreadExactOutputFill_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    QuietUnlessArmedInputToken internal pullToken;
    ERC20PermitMintableStub internal counterparty;
    address internal payer;
    address internal recipient;
    int24 internal positionLower;
    int24 internal positionUpper;

    /// @notice Use the production manager package and real V3 liquidity fixture.
    function setUp() public override {
        super.setUp();
        pullToken = new QuietUnlessArmedInputToken();
        counterparty = new ERC20PermitMintableStub("Token B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(pullToken), address(counterparty), FEE_MEDIUM);
        _seedPullOwnedLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool);
        payer = makeAddr("v3ExactOutputPayer");
        recipient = makeAddr("v3ExactOutputRecipient");
        vm.label(address(pullToken), "pullToken");
    }

    /// @notice Both directions reject the raw quoter's incomplete result at the vault preview.
    function test_RC04_unfilledQuoteAndPreview_revert(bool zeroForOne_) public {
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        uint256 requested_ = output_.balanceOf(address(pool)) + 1;
        UniswapV3Quoter.SwapQuoteResult memory quote_ = _quote(zeroForOne_, requested_);
        assertEq(quote_.fullyFilled, false, "fixture quote is incomplete");
        assertEq(quote_.amountOut < requested_, true, "quote reports actual partial output");
        vm.expectRevert(_notFilled(requested_, quote_.amountOut));
        vault.previewExchangeOut(input_, output_, requested_);
    }

    /// @notice An incomplete execution quote leaves input, payout, pool and vault balances unchanged.
    function test_RC04_unfilledExecutionQuote_preservesBalances(bool zeroForOne_) public {
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        uint256 requested_ = output_.balanceOf(address(pool)) + 1;
        UniswapV3Quoter.SwapQuoteResult memory quote_ = _quote(zeroForOne_, requested_);
        assertEq(quote_.fullyFilled, false);
        ERC20PermitMintableStub(address(input_)).mint(payer, 1 ether);
        vm.prank(payer);
        input_.approve(address(vault), 1 ether);
        uint256[4] memory balances_ = [input_.balanceOf(address(pool)), output_.balanceOf(address(pool)),
            input_.balanceOf(address(vault)), output_.balanceOf(address(vault))];

        vm.prank(payer);
        vm.expectRevert(_notFilled(requested_, quote_.amountOut));
        vault.exchangeOut(input_, 1 ether, output_, requested_, recipient, false, block.timestamp + 1 hours);

        assertEq(input_.balanceOf(payer), 1 ether, "no input spent");
        assertEq(input_.allowance(payer, address(vault)), 1 ether, "allowance unchanged");
        assertEq(output_.balanceOf(recipient), 0, "no payout");
        assertEq(input_.balanceOf(address(pool)), balances_[0]);
        assertEq(output_.balanceOf(address(pool)), balances_[1]);
        assertEq(input_.balanceOf(address(vault)), balances_[2]);
        assertEq(output_.balanceOf(address(vault)), balances_[3]);
    }

    /// @notice A funded request pays exactly its output and pulls only the quoted input in either direction.
    /// @dev The non-SUT input token stays quiet, so this is not the short-payment case.
    function test_RC04_fillableExactOutput_paysRequestedOutputWithinMaximum(bool zeroForOne_) public {
        assertEq(pullToken.armed(), false);
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        uint256 requested_ = 1 ether;
        UniswapV3Quoter.SwapQuoteResult memory quote_ = _quote(zeroForOne_, requested_);
        assertEq(quote_.fullyFilled, true);
        assertEq(quote_.amountOut, requested_);
        uint256 quotedInput_ = vault.previewExchangeOut(input_, output_, requested_);
        assertEq(quotedInput_, quote_.amountIn);
        uint256 maximum_ = quotedInput_ + 1 ether;
        ERC20PermitMintableStub(address(input_)).mint(payer, maximum_);
        vm.prank(payer);
        input_.approve(address(vault), maximum_);
        uint256 poolInputBefore_ = input_.balanceOf(address(pool));
        uint256 poolOutputBefore_ = output_.balanceOf(address(pool));

        vm.prank(payer);
        uint256 used_ = vault.exchangeOut(input_, maximum_, output_, requested_, recipient, false, block.timestamp + 1 hours);

        assertEq(used_, quotedInput_);
        assertEq(used_ <= maximum_, true, "input ceiling respected");
        assertEq(input_.balanceOf(payer), maximum_ - used_, "unused maximum stays with payer");
        assertEq(output_.balanceOf(recipient), requested_);
        assertEq(input_.balanceOf(address(pool)) - poolInputBefore_, used_);
        assertEq(poolOutputBefore_ - output_.balanceOf(address(pool)), requested_);
        assertEq(input_.balanceOf(address(vault)), 0);
        assertEq(output_.balanceOf(address(vault)), 0);
    }

    /// @notice An accepted quote whose later pool payment is short reverts at settlement and restores the caller.
    /// @dev The revert data is the post-swap comparison, not the pre-swap quote. This is not the single-asset path.
    function test_RC04_acceptedQuote_shortPayment_revertsSettlementAndRestoresCaller() public {
        bool zeroForOne_ = address(pullToken) == pool.token0();
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        assertEq(address(input_), address(pullToken));
        assertEq(address(output_) == address(vault), false);
        uint256 requested_ = 1 ether;
        UniswapV3Quoter.SwapQuoteResult memory quote_ = _quote(zeroForOne_, requested_);
        assertEq(quote_.fullyFilled, true);
        assertEq(quote_.amountOut, requested_);
        uint256 quotedInput_ = vault.previewExchangeOut(input_, output_, requested_);
        assertEq(quotedInput_, quote_.amountIn);
        assertEq(quotedInput_ > 0, true);
        (uint128 liquidity_,,,,) = pool.positions(_positionKey(address(pullToken), positionLower, positionUpper));
        assertEq(liquidity_ > 0, true);

        uint256 maximum_ = quotedInput_ + 1 ether;
        pullToken.mint(payer, maximum_);
        vm.prank(payer);
        input_.approve(address(vault), maximum_);
        uint256 payerBefore_ = input_.balanceOf(payer);
        pullToken.arm(pool, positionLower, positionUpper);

        vm.prank(payer);
        vm.expectRevert(_notFilled(requested_, 0));
        vault.exchangeOut(input_, maximum_, output_, requested_, recipient, false, block.timestamp + 1 hours);

        assertEq(input_.balanceOf(payer), payerBefore_, "pull rolled back");
        assertEq(input_.allowance(payer, address(vault)), maximum_, "allowance unchanged");
        assertEq(output_.balanceOf(recipient), 0, "no payout");
    }

    /// @notice The zero-output preview remains zero in both directions.
    function test_RC04_zeroOutputPreview_returnsZero(bool zeroForOne_) public {
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        assertEq(vault.previewExchangeOut(input_, output_, 0), 0);
    }

    function _tokens(bool zeroForOne_) internal view returns (IERC20 input_, IERC20 output_) {
        return zeroForOne_ ? (IERC20(pool.token0()), IERC20(pool.token1())) : (IERC20(pool.token1()), IERC20(pool.token0()));
    }

    function _quote(bool zeroForOne_, uint256 requested_) internal view returns (UniswapV3Quoter.SwapQuoteResult memory) {
        return UniswapV3Quoter.quoteExactOutput(UniswapV3Quoter.SwapQuoteParams({
            pool: pool, zeroForOne: zeroForOne_, amount: requested_,
            sqrtPriceLimitX96: zeroForOne_ ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            maxSteps: 0
        }));
    }

    function _notFilled(uint256 requested_, uint256 delivered_) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            UniswapV3FullSpreadStandardExchangeVaultCommon.UniswapV3Exchange_ExactOutputNotFilled.selector,
            requested_, delivered_
        );
    }

    function _seedPullOwnedLiquidity(IUniswapV3Pool pool_, uint128 liquidity_) internal {
        int24 spacing_ = pool_.tickSpacing();
        positionLower = (-887220 / spacing_) * spacing_;
        positionUpper = (887220 / spacing_) * spacing_;
        if (positionLower >= positionUpper) {
            positionLower = -spacing_ * 1000;
            positionUpper = spacing_ * 1000;
        }
        pullToken.mint(address(this), 100_000_000 ether);
        counterparty.mint(address(this), 100_000_000 ether);
        uint128 liquidityToMint_ = liquidity_ < 1e18 ? 50_000_000e18 : liquidity_;
        pool_.mint(address(pullToken), positionLower, positionUpper, liquidityToMint_, abi.encode(address(this)));
    }

    function _positionKey(address owner_, int24 lower_, int24 upper_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner_, lower_, upper_));
    }
}

/// @notice Non-SUT input token. Quiet unless armed. An armed pull changes the already deployed pool.
contract QuietUnlessArmedInputToken {
    string public constant name = "Pull Token";
    string public constant symbol = "PULL";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IUniswapV3Pool public pool;
    int24 public tickLower;
    int24 public tickUpper;
    bool public armed;
    bool internal _changingPool;

    function mint(address account_, uint256 amount_) external returns (bool) {
        totalSupply += amount_;
        balanceOf[account_] += amount_;
        emit Transfer(address(0), account_, amount_);
        return true;
    }

    function approve(address spender_, uint256 amount_) external returns (bool) {
        allowance[msg.sender][spender_] = amount_;
        emit Approval(msg.sender, spender_, amount_);
        return true;
    }

    function transfer(address to_, uint256 amount_) external returns (bool) {
        _move(msg.sender, to_, amount_);
        return true;
    }

    function transferFrom(address from_, address to_, uint256 amount_) external returns (bool) {
        uint256 allowed_ = allowance[from_][msg.sender];
        if (allowed_ != type(uint256).max) {
            allowance[from_][msg.sender] = allowed_ - amount_;
        }
        if (armed && !_changingPool) {
            _changingPool = true;
            armed = false;
            _changeDeployedPool();
            _changingPool = false;
        }
        _move(from_, to_, amount_);
        return true;
    }

    function arm(IUniswapV3Pool pool_, int24 lower_, int24 upper_) external {
        pool = pool_;
        tickLower = lower_;
        tickUpper = upper_;
        armed = true;
    }

    function _changeDeployedPool() internal {
        IUniswapV3Pool pool_ = pool;
        bytes32 key_ = keccak256(abi.encodePacked(address(this), tickLower, tickUpper));
        (uint128 liquidity_,,,,) = pool_.positions(key_);
        if (liquidity_ > 0) {
            pool_.burn(tickLower, tickUpper, liquidity_);
        }
    }

    function _move(address from_, address to_, uint256 amount_) internal {
        balanceOf[from_] -= amount_;
        balanceOf[to_] += amount_;
        emit Transfer(from_, to_, amount_);
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
