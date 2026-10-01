// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@crane/contracts/external/openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    StandardExchangeAccountingHandler
} from "test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol";

interface IAccountingPair is IERC20 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256, uint256, uint256);
    function getAmountOut(uint256, address) external view returns (uint256);
    function mint(address) external returns (uint256);
    function swap(uint256, uint256, address, bytes calldata) external;
}

/// @dev Only external ERC20 dependencies provide callbacks. Pools, vaults and registry facets are production.
contract AccountingPoolToken is ERC20 {
    address public target;
    bytes internal payload;
    bool internal armed;
    uint256 public attempts;
    bool public nestedSuccess;
    bytes4 public nestedError;
    constructor(string memory symbol_) ERC20(symbol_, symbol_) {}

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_);
    }

    function arm(address target_, bytes calldata payload_) external {
        target = target_;
        payload = payload_;
        armed = true;
        attempts = 0;
        nestedSuccess = false;
        nestedError = bytes4(0);
    }

    function _callback() internal {
        if (!armed || msg.sender != target) return;
        armed = false;
        ++attempts;
        bytes memory result;
        (nestedSuccess, result) = target.call(payload);
        if (result.length >= 4) {
            bytes4 selector;
            assembly ("memory-safe") { selector := mload(add(result, 32)) }
            nestedError = selector;
        }
    }

    function transferFrom(address from_, address to_, uint256 amount_) public override returns (bool) {
        bool result = super.transferFrom(from_, to_, amount_);
        _callback();
        return result;
    }

    function transfer(address to_, uint256 amount_) public override returns (bool) {
        bool result = super.transfer(to_, amount_);
        _callback();
        return result;
    }
}

abstract contract ConstantProductAccountingHandler is StandardExchangeAccountingHandler {
    enum PoolAction {
        DirectTrade,
        SeExactIn,
        SeExactOut,
        ReenterIn,
        ReenterOut,
        CompoundFees
    }
    mapping(PoolAction => Counts) public poolCounts;
    IAccountingPair public immutable pair;
    AccountingPoolToken public immutable token0;
    AccountingPoolToken public immutable token1;
    uint256 public immutable kind;
    uint256 public immutable virtualShares;

    struct SwapCheckpoint {
        uint256 input;
        uint256 output;
        uint256 shares;
        uint256 quote;
    }

    constructor(address vault_, address pair_, uint256 kind_)
        StandardExchangeAccountingHandler(
            IStandardExchangeIn(vault_),
            IERC20(pair_),
            IERC20(vault_),
            true,
            address(0xCA1101),
            address(0xCA1102),
            address(0xBAD)
        )
    {
        pair = IAccountingPair(pair_);
        kind = kind_;
        virtualShares = kind_ == 2 ? 1 : 1e9;
        token0 = AccountingPoolToken(pair.token0());
        token1 = AccountingPoolToken(pair.token1());
    }

    function _fund(address actor_, uint256 amount_) internal override {
        (uint256 r0, uint256 r1,) = pair.getReserves();
        uint256 supply = pair.totalSupply();
        uint256 a0 = Math.mulDiv(amount_, r0, supply, Math.Rounding.Ceil) + 1;
        uint256 a1 = Math.mulDiv(amount_, r1, supply, Math.Rounding.Ceil) + 1;
        token0.mint(address(this), a0);
        token1.mint(address(this), a1);
        token0.transfer(address(pair), a0);
        token1.transfer(address(pair), a1);
        uint256 minted = pair.mint(address(this));
        assertGe(minted, amount_, "funding mints real pool liquidity");
        if (actor_ != address(this)) pair.transfer(actor_, amount_);
    }

    function _restingQuote(uint256 amount_) internal view override returns (uint256) {
        return Math.mulDiv(amount_, share.totalSupply() + virtualShares, base.balanceOf(address(seIn)) - amount_ + 1);
    }

    function _state() internal view override returns (bytes32) {
        (uint256 r0, uint256 r1,) = pair.getReserves();
        return keccak256(
            abi.encode(
                super._state(),
                r0,
                r1,
                pair.totalSupply(),
                IERC4626(address(seIn)).totalAssets(),
                token0.balanceOf(address(seIn)),
                token1.balanceOf(address(seIn)),
                token0.allowance(address(seIn), address(pair)),
                token1.allowance(address(seIn), address(pair))
            )
        );
    }

    function _additionalActions(address actor_, uint256 seed_) internal override {
        uint256 amount = bound(seed_, 1e12, 1e16);
        _directTrade(actor_, amount);
        _seSwap(actor_, amount, false);
        _seSwap(actor_, amount, true);
        if (kind == 2) _compoundFees(actor_);
    }

    function _directTrade(address actor_, uint256 amount_) internal {
        ++poolCounts[PoolAction.DirectTrade].attempted;
        (uint256 r0, uint256 r1,) = pair.getReserves();
        uint256 output =
            kind == 0
            ? Math.mulDiv(amount_ * 997, r1, r0 * 1000 + amount_ * 997)
            : pair.getAmountOut(amount_, address(token0));
        assertGt(output, 0, "direct pool output nonzero");
        uint256 beforeOut = token1.balanceOf(actor_);
        uint256 supply = share.totalSupply();
        uint256 held = pair.balanceOf(address(seIn));
        token0.mint(actor_, amount_);
        vm.prank(actor_);
        token0.transfer(address(pair), amount_);
        pair.swap(0, output, actor_, new bytes(0));
        assertEq(token1.balanceOf(actor_) - beforeOut, output, "actual direct pool payout");
        assertEq(share.totalSupply(), supply, "outside trade never issues vault shares");
        assertEq(pair.balanceOf(address(seIn)), held, "outside trade preserves vault LP principal");
        ++poolCounts[PoolAction.DirectTrade].succeeded;
    }

    function _seSwap(address actor_, uint256 amount_, bool exactOut_) internal {
        PoolAction action = exactOut_ ? PoolAction.SeExactOut : PoolAction.SeExactIn;
        PoolAction attack = exactOut_ ? PoolAction.ReenterOut : PoolAction.ReenterIn;
        ++poolCounts[action].attempted;
        ++poolCounts[attack].attempted;
        IERC20 input = IERC20(address(token0));
        IERC20 output = IERC20(address(token1));
        uint256 desired = seIn.previewExchangeIn(input, amount_, output);
        assertGt(desired, 0, "SE swap nonzero");
        uint256 needed = exactOut_
            ? IStandardExchangeOut(address(seIn)).previewExchangeOut(input, output, desired)
            : amount_;
        token0.mint(actor_, needed);
        vm.prank(actor_);
        token0.approve(address(seIn), needed);
        SwapCheckpoint memory before_ = SwapCheckpoint(
            token0.balanceOf(actor_), token1.balanceOf(actor_), share.totalSupply(), exactOut_ ? needed : desired
        );
        token0.arm(
            address(seIn),
            abi.encodeCall(
                IStandardExchangeIn.exchangeIn, (input, needed, output, 0, attacker, true, block.timestamp + 1 hours)
            )
        );
        uint256 result = _executeSwap(actor_, needed, desired, exactOut_);
        assertEq(result, before_.quote, "swap honors quote");
        assertEq(before_.input - token0.balanceOf(actor_), needed, "swap principal charged once");
        assertEq(token1.balanceOf(actor_) - before_.output, desired, "swap output paid once");
        assertEq(share.totalSupply(), before_.shares, "pass through never issues vault shares");
        assertEq(token0.attempts(), 1, "production transfer callback reached");
        assertFalse(token0.nestedSuccess(), "nested route rejected");
        assertEq(token0.nestedError(), IReentrancyLock.IsLocked.selector, "guard is exact rejecting boundary");
        assertEq(token1.balanceOf(attacker), 0, "nested route yields no value");
        ++poolCounts[action].succeeded;
        ++poolCounts[attack].expectedRevert;
    }

    function _executeSwap(address actor_, uint256 needed_, uint256 desired_, bool exactOut_)
        internal
        returns (uint256 result)
    {
        IERC20 input = IERC20(address(token0));
        IERC20 output = IERC20(address(token1));
        vm.prank(actor_);
        if (exactOut_) {
            return IStandardExchangeOut(address(seIn))
                .exchangeOut(input, needed_, output, desired_, actor_, false, block.timestamp + 1 hours);
        }
        return seIn.exchangeIn(input, needed_, output, desired_, actor_, false, block.timestamp + 1 hours);
    }

    function _compoundFees(address actor_) internal {
        ++poolCounts[PoolAction.CompoundFees].attempted;
        uint256 amount = 1e12;
        _fund(actor_, amount);
        Checkpoint memory before_ =
            Checkpoint(base.balanceOf(actor_), share.balanceOf(actor_), seIn.previewExchangeIn(base, amount, share));
        uint256 held = base.balanceOf(address(seIn));
        vm.startPrank(actor_);
        base.approve(address(seIn), amount);
        uint256 minted = seIn.exchangeIn(base, amount, share, before_.quote, actor_, false, block.timestamp + 1 hours);
        vm.stopPrank();
        assertEq(minted, before_.quote, "fee-compounding funded deposit honors quote");
        assertGt(minted, 0, "fee-compounding deposit is nonzero");
        assertEq(before_.assets - base.balanceOf(actor_), amount, "fee-compounding principal charged once");
        assertEq(share.balanceOf(actor_) - before_.shares, minted, "fee-compounding recipient issuance");
        assertGt(
            base.balanceOf(address(seIn)), held + amount, "real accrued pool fees compound to additional backing LP"
        );
        mintedShares += minted;
        ++poolCounts[PoolAction.CompoundFees].succeeded;
    }

    function assertPoolAccounting() external view {
        for (uint8 i; i < 6; ++i) {
            Counts memory c = poolCounts[PoolAction(i)];
            uint256 required = i == uint8(PoolAction.CompoundFees) && kind != 2 ? 0 : cycles / 4;
            assertEq(c.attempted, required, "all pool actions reached");
            assertEq(c.succeeded + c.expectedRevert, required, "pool action classified");
            assertEq(c.unexpectedRevert, 0, "no ignored pool failures");
        }
        (uint256 r0, uint256 r1,) = pair.getReserves();
        assertEq(token0.balanceOf(address(pair)), r0, "native pool reserve zero");
        assertEq(token1.balanceOf(address(pair)), r1, "native pool reserve one");
        assertGe(
            base.balanceOf(address(seIn)), IERC4626(address(seIn)).totalAssets(), "vault LP book backed by custody"
        );
    }
}
