// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {DeliveryTestToken} from "../remediation/DeliveryTestToken.sol";
import {
    TestBase_UniswapV3FullSpreadAccounting
} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadAccounting.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {FullMath} from "@crane/contracts/protocols/dexes/uniswap/libraries/FullMath.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {IUniswapV3FullSpreadStandardExchangeVault as IMaintenance} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/interfaces/IUniswapV3FullSpreadStandardExchangeVault.sol";
import {StandardExchangeHandler, ISequenceEnvironment} from "./StandardExchangeHandler.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";

contract UniswapV3FullSpreadStandardExchangeVault_Invariant is
    TestBase_UniswapV3FullSpreadAccounting,
    ISequenceEnvironment
{
    IERC20 internal asset0;
    IERC20 internal asset1;
    StandardExchangeHandler internal handler;

    function setUp() public override {
        super.setUp();
        address a = address(new DeliveryTestToken("A", "A", 18, address(this), 0));
        address b = address(new DeliveryTestToken("B", "B", 18, address(this), 0));
        // Only the external assets differ from the canonical accounting fixture:
        // their callback proves the production reentrancy lock.
        pool = _createPoolOneToOne(a, b, FEE_MEDIUM);
        token0 = ERC20PermitMintableStub(pool.token0());
        token1 = ERC20PermitMintableStub(pool.token1());
        asset0 = IERC20(address(token0));
        asset1 = IERC20(address(token1));
        lower = TickMath.minUsableTick(pool.tickSpacing());
        upper = TickMath.maxUsableTick(pool.tickSpacing());
        _seedExternalLiquidity(pool, EXTERNAL_LIQUIDITY);
        vault = _deployVault(pool);
        _fundAccount(address(this));
        _bundleIn(address(this), 1e15, 1e15);
        _setFeeRecipient(address(this));
        handler = new StandardExchangeHandler(this, vault, asset0, asset1);
        uint256 holderShares = vault.balanceOf(address(this)) / 4;
        for (uint256 i; i < 3; ++i) {
            address actor = address(handler.actors(i));
            vault.transfer(actor, holderShares);
            DeliveryTestToken(address(asset0)).mint(actor, 1e18);
            DeliveryTestToken(address(asset1)).mint(actor, 1e18);
        }
        assertEq(handler.steps(), 0, "setup does not count as campaign coverage");
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = StandardExchangeHandler.step.selector;
        targetContract(address(handler));
        string[] memory artifacts = new string[](1);
        artifacts[0] = "StandardExchangeHandler.sol:StandardExchangeHandler";
        targetInterface(FuzzInterface(address(handler), artifacts));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function trade(bool zeroForOne, uint256 amount) external {
        require(msg.sender == address(handler));
        _externalSwapExactIn(pool, zeroForOne, amount);
    }

    function custodyAddresses() external view returns (address[3] memory) {
        return [address(pool), address(0), address(this)];
    }

    function maintain(IERC20 token, uint256 amount) external {
        require(msg.sender == address(handler));
        uint256 before0 = asset0.balanceOf(address(this));
        uint256 before1 = asset1.balanceOf(address(this));
        IMaintenance(address(vault)).donate(address(token), amount, false);
        IMaintenance(address(vault)).compound();
        // The live owner can grant either global or selector-scoped maintenance.
        IMaintenance(address(vault)).setOperator(address(handler), true);
        vm.prank(address(handler));
        IMaintenance(address(vault)).compound();
        IMaintenance(address(vault)).setOperator(address(handler), false);
        IMaintenance(address(vault)).setOperatorFor(IMaintenance.compound.selector, address(handler), true);
        vm.prank(address(handler));
        IMaintenance(address(vault)).compound();
        IMaintenance(address(vault)).setOperatorFor(IMaintenance.compound.selector, address(handler), false);
        assertEq(asset0.balanceOf(address(this)), before0 - (address(token) == address(asset0) ? amount : 0),
            "maintenance owner receives no token0 payout");
        assertEq(asset1.balanceOf(address(this)), before1 - (address(token) == address(asset1) ? amount : 0),
            "maintenance owner receives no token1 payout");
    }

    function booked() external view returns (uint256, uint256) {
        return _booked();
    }

    function positionLiquidity() external view returns (uint256) {
        return _positionLiquidity();
    }

    /// @notice Independent exit entitlement: burn principal plus separately floored fee and book claims.
    function bundleClaim(uint256 shares) external view returns (uint256 amount0, uint256 amount1) {
        uint256 supply = vault.totalSupply();
        (uint160 price,,,,,,) = pool.slot0();
        uint128 removed = uint128(FullMath.mulDiv(_positionLiquidity(), shares, supply));
        (amount0, amount1) = _amounts(price, removed, false);
        (uint256 fees0, uint256 fees1) = _unpaidFees();
        (uint256 book0, uint256 book1) = _booked();
        amount0 += FullMath.mulDiv(fees0, shares, supply) + FullMath.mulDiv(book0, shares, supply);
        amount1 += FullMath.mulDiv(fees1, shares, supply) + FullMath.mulDiv(book1, shares, supply);
    }

    /// @notice Include pool pricing, fee checkpoints, books and unsettled custody in rollback proofs.
    function positionDigest() external view returns (bytes32) {
        _assertSettled();
        (uint160 price, int24 tick,,,,, bool unlocked) = pool.slot0();
        bytes32 digest = keccak256(abi.encode(price, tick, unlocked, pool.liquidity()));
        (uint128 liquidity, uint256 last0, uint256 last1, uint128 owed0, uint128 owed1) =
            pool.positions(_positionKey());
        digest = keccak256(abi.encode(digest, liquidity, last0, last1, owed0, owed1));
        (uint256 book0, uint256 book1) = _booked();
        return keccak256(abi.encode(digest, pool.feeGrowthGlobal0X128(), pool.feeGrowthGlobal1X128(), book0, book1));
    }

    /// @notice Reserves contain position principal and unpaid fees, never local custody or books.
    function assertPositionAccounting() external view {
        _assertSettled();
        (uint160 price, int24 tick,,,,,) = pool.slot0();
        // Campaign budgets keep the real full-spread position active; do not silently
        // apply an inside-growth formula after leaving its range.
        assertGe(tick, lower);
        assertLt(tick, upper);
        (uint256 principal0, uint256 principal1) = _amounts(price, _positionLiquidity(), false);
        (uint256 fee0, uint256 fee1) = _unpaidFees();
        assertEq(vault.reserveOfToken(address(asset0)), principal0 + fee0, "token0 position plus unpaid fees");
        assertEq(vault.reserveOfToken(address(asset1)), principal1 + fee1, "token1 position plus unpaid fees");
        assertEq(vault.reserveOfToken(address(vault)), 0, "shares are not underlying reserves");
        (uint256 book0, uint256 book1) = _booked();
        assertLe(book0, asset0.balanceOf(address(vault)), "token0 book backed by local custody");
        assertLe(book1, asset1.balanceOf(address(vault)), "token1 book backed by local custody");
    }

    function _unpaidFees() internal view returns (uint256 fee0, uint256 fee1) {
        (uint128 liquidity, uint256 last0, uint256 last1, uint128 owed0, uint128 owed1) =
            pool.positions(_positionKey());
        (,, uint256 lower0, uint256 lower1,,,,) = pool.ticks(lower);
        (,, uint256 upper0, uint256 upper1,,,,) = pool.ticks(upper);
        unchecked {
            fee0 = owed0 + FullMath.mulDiv(
                pool.feeGrowthGlobal0X128() - lower0 - upper0 - last0, liquidity, 1 << 128);
            fee1 = owed1 + FullMath.mulDiv(
                pool.feeGrowthGlobal1X128() - lower1 - upper1 - last1, liquidity, 1 << 128);
        }
    }

    /// forge-config: default.invariant.runs = 256
    /// forge-config: default.invariant.depth = 64
    /// forge-config: default.invariant.fail-on-revert = true
    function invariant_APEX_allInputsSharesAndCustodyReconcile() public view {
        handler.assertAccounting();
        _assertCustody(asset0);
        _assertCustody(asset1);
    }

    function afterInvariant() public view {
        handler.assertCampaignCoverage();
        invariant_APEX_allInputsSharesAndCustodyReconcile();
    }

    function _assertCustody(IERC20 token) internal view {
        uint256 custody = token.balanceOf(address(this)) + token.balanceOf(address(vault))
            + token.balanceOf(address(handler)) + token.balanceOf(address(pool))
            + token.balanceOf(address(0)) + token.balanceOf(address(handler.attacker()))
            + token.balanceOf(handler.EOA_ATTACKER());
        for (uint256 i; i < 3; ++i) {
            custody += token.balanceOf(address(handler.actors(i)));
        }
        assertEq(custody, token.totalSupply(), "all assets across holders, vault and pool reconciled");
    }

    function test_APEX_deterministicSequenceExercisesEveryHandler() public {
        for (uint256 i; i < 64; ++i) {
            handler.step(uint256(keccak256(abi.encode("FullSpread lifecycle", i))));
            invariant_APEX_allInputsSharesAndCustodyReconcile();
        }
        afterInvariant();
        for (uint256 i; i < handler.ACTIONS(); ++i) {
            string memory action = string.concat("action ", vm.toString(i));
            emit log_named_uint(string.concat(action, " attempted"), handler.attempted(i));
            emit log_named_uint(string.concat(action, " succeeded"), handler.succeeded(i));
            emit log_named_uint(string.concat(action, " expected reverts"), handler.expectedReverts(i));
            emit log_named_uint(string.concat(action, " unexpected reverts"), handler.unexpectedReverts(i));
        }
    }
}
