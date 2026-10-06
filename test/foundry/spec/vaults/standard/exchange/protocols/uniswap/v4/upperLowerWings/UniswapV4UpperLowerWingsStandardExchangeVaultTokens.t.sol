// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ERC20} from "@crane/contracts/external/openzeppelin-contracts-v5/token/ERC20/ERC20.sol";
import {UniswapV4UpperLowerWingsStandardExchangeVaultRebalanceFixture as Fixture} from "./UniswapV4UpperLowerWingsStandardExchangeVaultRebalance.t.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVault as Vault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVault.sol";
import {IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg as Package} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/interfaces/IUniswapV4UpperLowerWingsStandardExchangeVaultDFPkg.sol";

/// @dev Hostile underlying only. Vault, package, manager, registry and oracle remain real production contracts.
contract UniswapV4UpperLowerWingsStandardExchangeVaultHostileToken is ERC20 {
    bool public paused;
    address public blocked;
    bool public tax;
    address public callback;
    bytes public payload;
    bool public attempted;
    bool public succeeded;
    constructor() ERC20("Hostile underlying", "HOST") {}
    function mint(address to_, uint256 amount_) external { _mint(to_, amount_); }
    function shrink(address from_, uint256 amount_) external { _burn(from_, amount_); }
    function configure(bool paused_, address blocked_, bool tax_) external { paused = paused_; blocked = blocked_; tax = tax_; }
    function arm(address callback_, bytes calldata payload_) external { callback = callback_; payload = payload_; attempted = false; }
    function _update(address from_, address to_, uint256 amount_) internal override {
        if (from_ != address(0) && to_ != address(0)) {
            require(!paused && from_ != blocked && to_ != blocked, "token transfer disabled");
            if (callback != address(0) && !attempted) { attempted = true; (succeeded,) = callback.call(payload); }
            if (tax && amount_ > 1) { super._update(from_, address(0), 1); --amount_; }
        }
        super._update(from_, to_, amount_);
    }
}
contract UniswapV4UpperLowerWingsStandardExchangeVaultTokensTest is Fixture {
    UniswapV4UpperLowerWingsStandardExchangeVaultHostileToken internal hostile;
    Vault internal hostileVault;
    function setUp() public override {
        super.setUp();
        hostile = new UniswapV4UpperLowerWingsStandardExchangeVaultHostileToken();
        PoolKey memory hostileKey = PoolKey(
            Currency.wrap(address(hostile) < address(token0) ? address(hostile) : address(token0)),
            Currency.wrap(address(hostile) < address(token0) ? address(token0) : address(hostile)), 3000, 60, IHooks(address(0)));
        pool.initialize(hostileKey, uint160(1) << 96);
        hostileVault = Vault(wingsPackage.deployVault(Package.PkgArgs(hostileKey, address(hostile))));
        hostile.mint(address(this), 1e18);
        hostile.approve(address(hostileVault), type(uint256).max);
    }
    function _hostileDeposit() private {
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostile)), 1e12, IERC20(address(hostileVault)), 0, address(this), false, block.timestamp);
    }
    function test_feeOnTransferInboundRollsBackWholeOperation() public {
        hostile.configure(false, address(0), true);
        vm.expectRevert(); _hostileDeposit();
        assertEq(IERC20(address(hostileVault)).totalSupply(), 0);
        assertEq(hostile.balanceOf(address(this)), 1e18);
        assertEq(hostile.balanceOf(address(hostileVault)), 0);
    }
    function test_feeOnTransferOutboundCannotUnderpayQuotedTarget() public {
        _hostileDeposit();
        hostile.configure(false, address(0), true);
        vm.expectRevert();
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp);
        assertEq(IERC20(address(hostileVault)).totalSupply(), 1e12);
    }
    function test_pausedAndBlacklistedDeliveryRollsBackThenCanResume() public {
        _hostileDeposit();
        hostile.configure(true, address(0), false);
        vm.expectRevert();
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp);
        hostile.configure(false, address(this), false);
        vm.expectRevert();
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp);
        hostile.configure(false, address(0), false);
        assertGt(IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp), 0);
    }
    function test_underlyingCallbackCannotReenterMoneyOrObserveEconomicRate() public {
        hostile.arm(address(hostileVault), abi.encodeCall(IStandardExchangeIn.exchangeIn,
            (IERC20(address(hostile)), 1, IERC20(address(hostileVault)), 0, address(this), false, block.timestamp)));
        _hostileDeposit(); assertTrue(hostile.attempted()); assertFalse(hostile.succeeded());
        hostile.arm(address(hostileVault), abi.encodeCall(Vault.liquidationValue, ()));
        _hostileDeposit(); assertTrue(hostile.attempted()); assertFalse(hostile.succeeded());
        assertGt(IERC20(address(hostileVault)).totalSupply(), 1e12);
    }
    function test_negativeRebaseCannotSilentlySpendOtherBacking() public {
        _hostileDeposit();
        hostile.shrink(address(hostileVault), 1);
        vm.expectRevert();
        IStandardExchangeIn(address(hostileVault)).exchangeIn(IERC20(address(hostileVault)), 1000, IERC20(address(hostile)), 0, address(this), false, block.timestamp);
        assertEq(IERC20(address(hostileVault)).totalSupply(), 1e12);
    }
}
