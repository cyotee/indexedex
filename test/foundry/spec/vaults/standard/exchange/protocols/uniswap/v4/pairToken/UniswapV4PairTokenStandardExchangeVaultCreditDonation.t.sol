// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {PairTokenIOTestBase, PairTokenIOCreditRouter} from "./UniswapV4PairTokenStandardExchangeVaultStandardExchange.t.sol";
import {IUniswapV4PairTokenStandardExchangeVault as IVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/interfaces/IUniswapV4PairTokenStandardExchangeVault.sol";
import {UniswapV4PairTokenStandardExchangeVaultExecution as Execution} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/pairToken/UniswapV4PairTokenStandardExchangeVaultExecution.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IVaultRegistryDisableManager} from "contracts/interfaces/IVaultRegistryDisableManager.sol";
import {NativeStandardYieldErrors} from "contracts/vaults/standard/sy/NativeStandardYieldErrors.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolActor} from "./harness/PoolActor.sol";

/// @notice Boundary-only token. A genuine short transfer burns one raw unit.
/// @dev The vault, registry, wrapper and PoolManager remain production contracts.
contract PairTokenIONegativeToken {
    string public constant name = "I/O negative currency";
    string public constant symbol = "ION";
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    bool public shortPull;
    bool public shortPayout;
    address public shortPayoutSender;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function configure(bool pull_, bool payout_) external {
        shortPull = pull_;
        shortPayout = payout_;
    }

    function configurePayoutSender(address sender_) external {
        shortPayoutSender = sender_;
    }

    function mint(address receiver_, uint256 amount_) external returns (bool) {
        totalSupply += amount_;
        balanceOf[receiver_] += amount_;
        emit Transfer(address(0), receiver_, amount_);
        return true;
    }

    function approve(address spender_, uint256 amount_) external returns (bool) {
        allowance[msg.sender][spender_] = amount_;
        emit Approval(msg.sender, spender_, amount_);
        return true;
    }

    function transfer(address receiver_, uint256 amount_) external returns (bool) {
        _transfer(msg.sender, receiver_, amount_,
            shortPayout && (shortPayoutSender == address(0) || shortPayoutSender == msg.sender));
        return true;
    }

    function transferFrom(address sender_, address receiver_, uint256 amount_) external returns (bool) {
        uint256 allowed_ = allowance[sender_][msg.sender];
        if (allowed_ != type(uint256).max) allowance[sender_][msg.sender] = allowed_ - amount_;
        _transfer(sender_, receiver_, amount_, shortPull);
        return true;
    }

    function _transfer(address sender_, address receiver_, uint256 amount_, bool short_) private {
        balanceOf[sender_] -= amount_;
        uint256 received_ = short_ && amount_ != 0 ? amount_ - 1 : amount_;
        balanceOf[receiver_] += received_;
        totalSupply -= amount_ - received_;
        emit Transfer(sender_, receiver_, received_);
        if (received_ != amount_) emit Transfer(sender_, address(0), 1);
    }
}

/// @notice Calls from a constructor have no bytecode, just like an EOA.
contract PairTokenIOConstructionCaller {
    constructor(address vault_, address token_, address out_) {IStandardExchangeIn(vault_).exchangeIn(IERC20(token_), 1, IERC20(out_), 0, msg.sender, true, block.timestamp);
    }
}

/// @notice S1-A34-A38/A42/A55, plus I/O portions of A43/A52/A54.
// tag::UniswapV4PairTokenStandardExchangeVaultCreditDonationTest[]
contract UniswapV4PairTokenStandardExchangeVaultCreditDonationTest is PairTokenIOTestBase {
    function test_CRD_FalseFlagExactPullBothCurrenciesAndAllowance() public {
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e19, 1e19);
        for (uint256 i; i < 2; ++i) {
            IERC20 token_ = IERC20(i == 0 ? address(token0) : address(token1));
            token_.approve(address(vault), 1e18);
            uint256 balance_ = token_.balanceOf(address(this));
            uint256 supply_ = _share().totalSupply();
            uint256 held_ = _share().balanceOf(address(this));(uint256 expected_,) = _se().previewExchangeIn(token_, 1e18, _share());
            (uint256 exchangeAmountOut1,) = _se().exchangeIn(token_, 1e18, _share(), expected_, address(this), false, block.timestamp);
            assertEq(exchangeAmountOut1, expected_);
            assertEq(token_.balanceOf(address(this)), balance_ - 1e18);
            assertEq(token_.allowance(address(this), address(vault)), 0);
            assertEq(_share().totalSupply(), supply_ + expected_);
            assertEq(_share().balanceOf(address(this)), held_ + expected_);
            _assertStable();
        }
    }

    function test_CRD_ShortPullCannotBorrowBackingOrUnsolicitedBalances() public {
        _negativeVault();
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e20, 1e20);
        vault.donate(address(token0), 1e18);
        token0.transfer(address(vault), 777);
        PairTokenIONegativeToken negative_ = PairTokenIONegativeToken(address(token0));
        negative_.configure(true, false);
        token0.approve(address(vault), 1e19);
        bytes32 before_ = _stateHash();
        uint256 tokenSupply_ = negative_.totalSupply();
        for (uint256 i; i < 4; ++i) {
            uint256 claimed_ = 1e18;
            if (i == 3) (, claimed_,) = vault.previewDepositPair(1e18, 1e18);
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, claimed_, claimed_ - 1));
            if (i == 0) {_se().exchangeIn(IERC20(address(token0)), claimed_, _share(), 0, address(this), false, block.timestamp);
            } else if (i == 1) {
                _sy().deposit(address(this), address(token0), claimed_, 0);
            } else if (i == 2) {
                vault.donate(address(token0), claimed_);
            } else {
                vault.depositPair(1e18, 1e18, 0, address(this), block.timestamp);
            }
            assertEq(_stateHash(), before_, "short receipt rolls back maintenance, allowances and first pull");
            assertEq(negative_.totalSupply(), tokenSupply_, "negative token burn rolled back");
            _assertUnbooked(777, 0);
        }
    }

    function test_CRD_TrueFlagEOAAndConstructionRejectionEveryInputClass() public {
        _bootstrap(1e21, 1e21, address(this));
        address[3] memory inputs_ = [address(token0), address(token1), address(vault)];
        for (uint256 i; i < inputs_.length; ++i) {
            address out_ = i == 2 ? address(token0) : address(vault);
            bytes32 before_ = _stateHash();
            vm.prank(address(0xa11ce));
            vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);_se().exchangeIn(IERC20(inputs_[i]), 1, IERC20(out_), 0, address(this), true, block.timestamp);
            vm.expectRevert(ISecurePullErrors.EOAPretransferNotAllowed.selector);
            new PairTokenIOConstructionCaller(address(vault), inputs_[i], out_);
            assertEq(_stateHash(), before_);
        }
    }

    function test_CRD_ShortSecondPairedPullRestoresFirstPullAndAllowances() public {
        _negativeVault();
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e19, 1e19);
        token0.approve(address(vault), 1e18);
        token1.approve(address(vault), 1e18);
        token0.transfer(address(vault), 777);
        token1.transfer(address(vault), 999);
        PairTokenIONegativeToken(address(token1)).configure(true, false);
        (, uint256 used0_, uint256 used1_) = vault.previewDepositPair(1e18, 1e18);
        assertGt(used0_, 0);
        assertGt(used1_, 0);
        bytes32 before_ = _stateHash();
        uint256 supply0_ = PairTokenIONegativeToken(address(token0)).totalSupply();
        uint256 supply1_ = PairTokenIONegativeToken(address(token1)).totalSupply();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, used1_, used1_ - 1));
        vault.depositPair(1e18, 1e18, 0, address(this), block.timestamp);
        assertEq(_stateHash(), before_, "second-leg failure restores first exact pull");
        assertEq(PairTokenIONegativeToken(address(token0)).totalSupply(), supply0_);
        assertEq(PairTokenIONegativeToken(address(token1)).totalSupply(), supply1_);
        _assertUnbooked(777, 999);
    }

    function test_CRD_ContractMissingShortAndExcessCreditBothCurrencies() public {
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e20, 1e20);
        PairTokenIOCreditRouter router_ = new PairTokenIOCreditRouter();
        for (uint256 i; i < 2; ++i) {
            IERC20 token_ = IERC20(i == 0 ? address(token0) : address(token1));
            vault.donate(address(token_), 1e18);
            token_.transfer(address(router_), 3e18);
            bytes32 before_ = _stateHash();
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0));
            router_.exchange(address(vault), address(token_), 0, 1e18, address(vault), address(this));
            assertEq(_stateHash(), before_, "booked backing is not credit");
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 1e18 - 1));
            router_.exchange(address(vault), address(token_), 1e18 - 1, 1e18, address(vault), address(this));
            assertEq(_stateHash(), before_, "short staging rollback");
            assertEq(token_.balanceOf(address(router_)), 3e18);(uint256 expected_,) = _se().previewExchangeIn(token_, 1e18, _share());
            uint256 supply_ = _share().totalSupply();
            uint256 shares_ = _share().balanceOf(address(this));
            assertEq(router_.exchange(address(vault), address(token_), 2e18, 1e18, address(vault), address(this)), expected_);
            assertEq(_share().totalSupply(), supply_ + expected_);
            assertEq(_share().balanceOf(address(this)), shares_ + expected_);
            assertEq(token_.balanceOf(address(router_)), 1e18, "no refund");
            assertEq(token_.allowance(address(router_), address(vault)), 0, "pretransfer never pulls");
            _assertUnbooked(1e18, i == 0 ? 0 : 1e18);
            _assertStable();
        }
    }

    function test_CRD_SharePretransferCannotBurnHolderOrExcess() public {
        _bootstrap(1e21, 1e21, address(this));
        PairTokenIOCreditRouter router_ = new PairTokenIOCreditRouter();
        bytes32 before_ = _stateHash();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0));
        router_.exchange(address(vault), address(vault), 0, 1e18, address(token0), address(this));
        assertEq(_stateHash(), before_);
        _share().transfer(address(router_), 2e18);
        before_ = _stateHash();
        vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 1e18 - 1));
        router_.exchange(address(vault), address(vault), 1e18 - 1, 1e18, address(token0), address(this));
        assertEq(_stateHash(), before_);(uint256 expected_,) = _se().previewExchangeIn(_share(), 1e18, IERC20(address(token0)));
        uint256 received_ = token0.balanceOf(address(this));
        uint256 supply_ = _share().totalSupply();
        assertEq(router_.exchange(address(vault), address(vault), 2e18, 1e18, address(token0), address(this)), expected_);
        assertEq(token0.balanceOf(address(this)), received_ + expected_);
        assertEq(_share().totalSupply(), supply_ - 1e18);
        assertEq(_share().balanceOf(address(vault)), 1e18);
        assertEq(_share().balanceOf(address(router_)), 0);
        _assertStable();
    }

    function test_CRD_DonationAndUnsolicitedRemainDistinctThroughRestart() public {
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e20, 1e20);
        token0.transfer(address(vault), 777);
        token1.transfer(address(vault), 999);
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        uint256 supply_ = _share().totalSupply();
        vm.expectEmit(true, true, false, true, address(vault));
        emit IVault.Donated(address(this), address(token0), 1e18);
        vault.donate(address(token0), 1e18);
        vm.expectEmit(true, true, false, true, address(vault));
        emit IVault.Donated(address(this), address(token1), 2e18);
        vault.donate(address(token1), 2e18);
        (uint256 donated0_, uint256 donated1_) = vault.localReserves();
        assertEq(donated0_, book0_ + 1e18);
        assertEq(donated1_, book1_ + 2e18);
        assertEq(_share().totalSupply(), supply_, "donation mints no shares");
        _assertUnbooked(777, 999);
        vault.compound();
        assertEq(_share().totalSupply(), supply_);
        _assertUnbooked(777, 999);_se().exchangeIn(IERC20(address(token0)), 1e18, _share(), 0, address(this), false, block.timestamp);
        _assertUnbooked(777, 999);
        _sy().redeem(address(this), 1e18, address(token1), 0, false);
        _assertUnbooked(777, 999);
        vault.redeemPair(_share().totalSupply(), 0, 0, address(this), block.timestamp);
        assertEq(_share().totalSupply(), 0);
        assertEq(vault.positionLiquidity(), 0);
        _assertUnbooked(777, 999);
        (book0_, book1_) = vault.localReserves();
        assertEq(book0_, 0);
        assertEq(book1_, 0);
        _bootstrap(1e18, 1e18, address(this));
        assertEq(_share().totalSupply(), 1e18);
        _assertUnbooked(777, 999);
        _assertStable();
    }

    function test_CRD_DisabledBlocksCapitalButAllowsMaintenanceAndAllExitForms() public {
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 1e20, 1e20);
        vault.donate(address(token0), 1e18);
        vm.prank(owner);
        IVaultRegistryDisableManager(address(indexedexManager)).setVaultAddressDisabled(address(vault), true);
        bytes32 before_ = _stateHash();
        vm.expectRevert(IVault.IssuanceDisabled.selector);
        vault.depositPair(1e18, 1e18, 0, address(this), block.timestamp);
        for (uint256 i; i < 2; ++i) {
            address token_ = i == 0 ? address(token0) : address(token1);
            vm.expectRevert(IVault.IssuanceDisabled.selector);_se().exchangeIn(IERC20(token_), 1e18, _share(), 0, address(this), false, block.timestamp);
            vm.expectRevert(IVault.IssuanceDisabled.selector);
            _sy().deposit(address(this), token_, 1e18, 0);
            vm.expectRevert(IVault.IssuanceDisabled.selector);
            vault.donate(token_, 1e18);
            assertEq(_stateHash(), before_);
        }
        uint256 supply_ = _share().totalSupply();
        vault.compound();
        assertEq(_share().totalSupply(), supply_);
        _assertStable();
        for (uint256 i; i < 5; ++i) {
            uint256 snapshot_ = vm.snapshotState();
            uint256 shares_ = 1e18;
            uint256 before0_ = token0.balanceOf(address(this));
            uint256 before1_ = token1.balanceOf(address(this));
            if (i == 4) {
                (uint256 expected0_, uint256 expected1_) = vault.previewRedeemPair(shares_);
                vault.redeemPair(shares_, expected0_, expected1_, address(this), block.timestamp);
                assertEq(token0.balanceOf(address(this)), before0_ + expected0_);
                assertEq(token1.balanceOf(address(this)), before1_ + expected1_);
            } else {
                address token_ = i % 2 == 0 ? address(token0) : address(token1);
                uint256 expected_ = _sy().previewRedeem(token_, shares_);
                uint256 received_ = IERC20(token_).balanceOf(address(this));
                if (i < 2) {_se().exchangeIn(_share(), shares_, IERC20(token_), expected_, address(this), false, block.timestamp);
                } else {
                    _sy().redeem(address(this), shares_, token_, expected_, false);
                }
                assertEq(IERC20(token_).balanceOf(address(this)), received_ + expected_);
            }
            assertEq(_share().totalSupply(), supply_ - shares_);
            _assertStable();
            assertTrue(vm.revertToState(snapshot_));
        }
    }

    function test_CRD_NativeAndWrappedDonationCreditOnceAndValidateValue() public {
        _deployPool(true, 18, 18);
        vault = _deployVault(_defaultArgs(key, address(wrappedNative), "native donation"));
        _bootstrap(1e21, 1e21, address(this));
        _fund(address(this), 3e18, 1e18);
        wrappedNative.deposit{value: 1e18}();
        IERC20(address(wrappedNative)).approve(address(vault), 1e18);
        uint256 snapshot_ = vm.snapshotState();
        uint256 supply_ = _share().totalSupply();
        (uint256 before0_, uint256 before1_) = vault.localReserves();
        uint256 custody_ = address(vault).balance;
        vm.expectEmit(true, true, false, true, address(vault));
        emit IVault.Donated(address(this), address(0), 1e18);
        vault.donate{value: 1e18}(address(0), 1e18);
        (uint256 raw0_, uint256 raw1_) = vault.localReserves();
        assertEq(raw0_, before0_ + 1e18);
        assertEq(raw1_, before1_);
        assertEq(address(vault).balance, custody_ + 1e18);
        assertEq(_share().totalSupply(), supply_);
        _assertStable();
        assertTrue(vm.revertToState(snapshot_));
        vm.expectEmit(true, true, false, true, address(vault));
        emit IVault.Donated(address(this), address(wrappedNative), 1e18);
        vault.donate(address(wrappedNative), 1e18);
        (uint256 wrapped0_, uint256 wrapped1_) = vault.localReserves();
        assertEq(wrapped0_, raw0_);
        assertEq(wrapped1_, raw1_);
        assertEq(address(vault).balance, custody_ + 1e18);
        assertEq(IERC20(address(wrappedNative)).balanceOf(address(vault)), 0);
        assertEq(_share().totalSupply(), supply_, "unwrap receive cannot mint/book twice");
        _assertStable();
        bytes32 before_ = _stateHash();
        vm.expectRevert(abi.encodeWithSelector(Execution.InvalidNativeValue.selector, 1e18, 0));
        vault.donate(address(0), 1e18);
        vm.expectRevert(abi.encodeWithSelector(Execution.InvalidNativeValue.selector, 0, 1));
        vault.donate{value: 1}(address(wrappedNative), 1);
        vm.expectRevert(abi.encodeWithSelector(Execution.InvalidNativeValue.selector, 0, 1));
        vault.donate{value: 1}(address(token1), 1);
        assertEq(_stateHash(), before_);
    }

    function test_CRD_DonationZeroSupplyZeroAmountAndInvalidNativeForm() public {
        _fund(address(this), 1e19, 1e19);
        _approveVault(address(vault));
        bytes32 before_ = _stateHash();
        vm.expectRevert(IVault.InvalidAccountingState.selector);
        vault.donate(address(token0), 1);
        assertEq(_stateHash(), before_);
        _bootstrap(1e21, 1e21, address(this));
        vm.deal(address(this), 1e18);
        before_ = _stateHash();
        vm.expectRevert(IVault.InvalidAccountingState.selector);
        vault.donate(address(token0), 0);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(0), address(vault)));
        vault.donate{value: 1}(address(0), 1);
        vm.expectRevert(abi.encodeWithSelector(Execution.InvalidNativeValue.selector, 0, 1));
        vault.donate{value: 1}(address(token0), 1);
        assertEq(_stateHash(), before_);
    }

    function test_CRD_ActualWETHERC20LegNeverActsAsNativeAlias() public {
        address other_ = address(token1);
        address wrapper_ = address(wrappedNative);
        key.currency0 = Currency.wrap(wrapper_ < other_ ? wrapper_ : other_);
        key.currency1 = Currency.wrap(wrapper_ < other_ ? other_ : wrapper_);
        token0 = ERC20PermitMintableStub(Currency.unwrap(key.currency0));
        token1 = ERC20PermitMintableStub(Currency.unwrap(key.currency1));
        pool.initialize(key, uint160(1) << 96);
        vault = _deployVault(_defaultArgs(key, wrapper_, "actual WETH pool leg"));
        vm.deal(address(this), 1e24);
        wrappedNative.deposit{value: 2e21}();
        ERC20PermitMintableStub(other_).mint(address(this), 2e21);
        _approveVault(address(vault));
        assertEq(vault.depositPair(1e21, 1e21, 0, address(this), block.timestamp), 1e21);
        assertFalse(_sy().isValidTokenIn(address(0)));
        assertFalse(_sy().isValidTokenOut(address(0)));
        assertTrue(_sy().isValidTokenIn(wrapper_));
        assertEq(_sy().getTokensIn().length, 2);
        uint256 eth_ = address(this).balance;
        {
            (uint256 book0_, uint256 book1_) = vault.localReserves();
            uint256 wrapperBalance_ = IERC20(wrapper_).balanceOf(address(vault));
            vault.donate(wrapper_, 1e18);
            (uint256 after0_, uint256 after1_) = vault.localReserves();
            assertEq(after0_, book0_ + (wrapper_ < other_ ? 1e18 : 0));
            assertEq(after1_, book1_ + (wrapper_ < other_ ? 0 : 1e18));
            assertEq(IERC20(wrapper_).balanceOf(address(vault)), wrapperBalance_ + 1e18, "do not unwrap real WETH currency");
        }
        assertEq(address(vault).balance, 0);
        assertEq(address(this).balance, eth_);
        {
            PairTokenIOCreditRouter router_ = new PairTokenIOCreditRouter();
            bytes32 before_ = _stateHash();
            vm.expectRevert(abi.encodeWithSelector(ISecurePullErrors.TransferDeltaInsufficient.selector, 1e18, 0));
            router_.exchange(address(vault), wrapper_, 0, 1e18, address(vault), address(this));
            assertEq(_stateHash(), before_, "actual ERC20 WETH book is not free alias credit");
        }
        _sy().deposit(address(this), wrapper_, 1e18, 0);
        _assertStable();
        uint256 supply_ = _share().totalSupply();
        (uint256 payout0_, uint256 payout1_) = vault.previewRedeemPair(supply_);
        uint256 wallet0_ = token0.balanceOf(address(this));
        uint256 wallet1_ = token1.balanceOf(address(this));
        vault.redeemPair(supply_, payout0_, payout1_, address(this), block.timestamp);
        assertEq(token0.balanceOf(address(this)), wallet0_ + payout0_);
        assertEq(token1.balanceOf(address(this)), wallet1_ + payout1_);
        assertEq(address(this).balance, eth_, "terminal ERC20 payout must not deliver ETH");
        assertEq(address(vault).balance, 0);
        assertEq(_share().totalSupply(), 0);
        _assertStable();
    }

    function test_CRD_ShortPayoutRollsBackRemovalBurnAndEarlierManagerTransfers() public {
        _negativeVault();
        _bootstrap(1e21, 1e21, address(this));
        PairTokenIONegativeToken negative_ = PairTokenIONegativeToken(address(token0));
        negative_.configure(false, true);
        bytes32 before_ = _stateHash();
        uint256 supply_ = negative_.totalSupply();
        // Manager -> vault receipt is short too, and must never be accepted as
        // the planned principal. All prior burn/removal/fee changes roll back.
        vm.expectRevert(Execution.SettlementMismatch.selector);
        vault.redeemPair(1e18, 0, 0, address(this), block.timestamp);
        assertEq(_stateHash(), before_);
        assertEq(negative_.totalSupply(), supply_);
    }

    function test_CRD_SecondPayoutShortReceiptRestoresFirstDeliveredToken() public {
        _negativeVault();
        _bootstrap(1e21, 1e21, address(this));
        PairTokenIONegativeToken negative_ = PairTokenIONegativeToken(address(token1));
        negative_.configure(false, true);
        negative_.configurePayoutSender(address(vault));
        bytes32 before_ = _stateHash();
        uint256 tokenSupply_ = negative_.totalSupply();
        vm.expectRevert(Execution.SettlementMismatch.selector);
        vault.redeemPair(1e18, 0, 0, address(this), block.timestamp);
        assertEq(_stateHash(), before_, "second payout failure restores first delivered token, burn and position");
        assertEq(negative_.totalSupply(), tokenSupply_);
    }

    function _negativeVault() internal {
        PairTokenIONegativeToken a_ = new PairTokenIONegativeToken();
        PairTokenIONegativeToken b_ = new PairTokenIONegativeToken();
        token0 = ERC20PermitMintableStub(address(a_) < address(b_) ? address(a_) : address(b_));
        token1 = ERC20PermitMintableStub(address(a_) < address(b_) ? address(b_) : address(a_));
        key.currency0 = Currency.wrap(address(token0));
        key.currency1 = Currency.wrap(address(token1));
        pool.initialize(key, uint160(1) << 96);
        poolActor = new PoolActor(pool);
        vault = _deployVault(_defaultArgs(key, address(token0), "negative-token receipt"));
    }

    function _assertUnbooked(uint256 expected0_, uint256 expected1_) internal view {
        (uint256 book0_, uint256 book1_) = vault.localReserves();
        assertEq(token0.balanceOf(address(vault)) - book0_, expected0_, "unbooked0 isolated");
        assertEq(token1.balanceOf(address(vault)) - book1_, expected1_, "unbooked1 isolated");
    }
}
// end::UniswapV4PairTokenStandardExchangeVaultCreditDonationTest[]
