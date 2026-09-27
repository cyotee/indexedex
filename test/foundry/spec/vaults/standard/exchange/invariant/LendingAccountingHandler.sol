// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20} from "@crane/contracts/external/openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IReentrancyLock} from "@crane/contracts/access/reentrancy/IReentrancyLock.sol";
import {IStandardExchangeIn} from "contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "contracts/interfaces/IStandardExchangeOut.sol";
import {
    StandardExchangeAccountingHandler
} from "test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol";

interface ILendingAccountingHost {
    function fundBase(address, uint256) external;
    function custodyCash() external view returns (uint256);
    function accountingState() external view returns (bytes32);
    function accrueYield(uint256) external returns (uint256);
    function setFee(uint256) external;
    function feeTo() external view returns (address);
    function collectFee(address, uint256) external;
}

/// @dev External token dependency only; the production SE, protocol and fee collector remain real.
contract LendingAccountingToken is ERC20 {
    address public target;
    bytes internal payload;
    uint256 public attempts;
    bool public nestedSuccess;
    bytes4 public nestedError;
    constructor() ERC20("Accounting asset", "ACC") {}

    function mint(address to_, uint256 amount_) external {
        _mint(to_, amount_);
    }

    function arm(address target_, bytes calldata payload_) external {
        target = target_;
        payload = payload_;
        attempts = 0;
        nestedSuccess = false;
        nestedError = bytes4(0);
    }

    function _callback() internal {
        if (target == address(0)) return;
        address called = target;
        target = address(0);
        ++attempts;
        bytes memory result;
        (nestedSuccess, result) = called.call(payload);
        if (result.length >= 4) {
            bytes4 selector;
            assembly ("memory-safe") { selector := mload(add(result, 32)) }
            nestedError = selector;
        }
    }

    function transfer(address to_, uint256 amount_) public override returns (bool) {
        bool result = super.transfer(to_, amount_);
        _callback();
        return result;
    }

    function transferFrom(address from_, address to_, uint256 amount_) public override returns (bool) {
        bool result = super.transferFrom(from_, to_, amount_);
        _callback();
        return result;
    }
}

abstract contract LendingAccountingHandler is StandardExchangeAccountingHandler {
    enum LendingAction {
        Yield,
        FeeMint,
        FeeCollect,
        ReenterIn,
        Redeem,
        ReenterOut
    }
    mapping(LendingAction => Counts) public lendingCounts;
    ILendingAccountingHost public immutable host;
    uint256 public immutable initialCash;
    uint256 public funded;
    uint256 public yieldFunding;

    struct FeeCheckpoint {
        uint256 assets;
        uint256 shares;
        uint256 quote;
        uint256 supply;
        uint256 feeBefore;
        uint256 fee;
    }

    constructor(address se_, address base_, ILendingAccountingHost host_, address a0_, address a1_, address attacker_)
        StandardExchangeAccountingHandler(
            IStandardExchangeIn(se_), IERC20(base_), IERC20(se_), true, a0_, a1_, attacker_
        )
    {
        host = host_;
        initialCash = _cash();
    }

    function _cash() internal view returns (uint256 cash) {
        cash = host.custodyCash() + base.balanceOf(address(this)) + base.balanceOf(address(integrator))
            + base.balanceOf(attacker);
        for (uint256 i; i < 3; ++i) {
            cash += base.balanceOf(actors[i]);
        }
    }

    function _fund(address actor_, uint256 amount_) internal override {
        uint256 before_ = base.balanceOf(actor_);
        host.fundBase(actor_, amount_);
        assertEq(base.balanceOf(actor_) - before_, amount_, "fixture adds funding without erasing wallet principal");
        funded += amount_;
    }

    function _state() internal view override returns (bytes32) {
        return keccak256(abi.encode(super._state(), host.accountingState()));
    }

    function _additionalActions(address actor_, uint256 seed_) internal override {
        ++lendingCounts[LendingAction.Yield].attempted;
        uint256 supply = share.totalSupply();
        yieldFunding += host.accrueYield(bound(seed_, 1e9, 1e12));
        assertEq(share.totalSupply(), supply, "protocol yield creates no SE shares");
        ++lendingCounts[LendingAction.Yield].succeeded;
        _feeDeposit(actor_);
        _redeemCallback(actor_);
    }

    function _feeDeposit(address actor_) internal {
        ++lendingCounts[LendingAction.FeeMint].attempted;
        ++lendingCounts[LendingAction.ReenterIn].attempted;
        uint256 amount = 1e16;
        _fund(actor_, amount);
        host.setFee(1e16);
        FeeCheckpoint memory before_;
        before_.assets = base.balanceOf(actor_);
        before_.shares = share.balanceOf(actor_);
        before_.quote = seIn.previewExchangeIn(base, amount, share);
        before_.supply = share.totalSupply();
        before_.feeBefore = share.balanceOf(host.feeTo());
        before_.fee = before_.quote / 100;
        assertGt(before_.fee, 0, "actual nonzero dilution fee");
        vm.prank(actor_);
        base.approve(address(seIn), amount);
        _arm(false);
        vm.prank(actor_);
        uint256 issued = seIn.exchangeIn(base, amount, share, before_.quote, actor_, false, block.timestamp + 1 hours);
        _assertReentry(LendingAction.ReenterIn);
        assertEq(issued, before_.quote, "funded fee mint honors quote");
        assertEq(before_.assets - base.balanceOf(actor_), amount, "fee route debits only principal");
        assertEq(share.balanceOf(actor_) - before_.shares, issued, "fee does not reduce user issuance");
        assertEq(share.balanceOf(host.feeTo()) - before_.feeBefore, before_.fee, "independent WAD dilution fee");
        assertEq(share.totalSupply() - before_.supply, issued + before_.fee, "user plus fee supply increase");
        ++lendingCounts[LendingAction.FeeMint].succeeded;
        ++lendingCounts[LendingAction.FeeCollect].attempted;
        host.collectFee(actor_, before_.fee);
        host.setFee(0);
        assertEq(share.balanceOf(host.feeTo()), before_.feeBefore, "authorized collector releases exactly accrued fees");
        assertEq(
            share.balanceOf(actor_) - before_.shares, issued + before_.fee, "collected fee reaches honest recipient"
        );
        mintedShares += issued + before_.fee;
        ++lendingCounts[LendingAction.FeeCollect].succeeded;
    }

    function _redeemCallback(address actor_) internal {
        ++lendingCounts[LendingAction.Redeem].attempted;
        ++lendingCounts[LendingAction.ReenterOut].attempted;
        uint256 amount = share.balanceOf(actor_) / 20;
        Checkpoint memory before_ =
            Checkpoint(base.balanceOf(actor_), share.balanceOf(actor_), seIn.previewExchangeIn(share, amount, base));
        assertGt(before_.quote, 0, "callback withdrawal pays nonzero assets");
        vm.prank(actor_);
        share.approve(address(seIn), amount);
        _arm(true);
        vm.prank(actor_);
        uint256 paid = seIn.exchangeIn(share, amount, base, before_.quote, actor_, false, block.timestamp + 1 hours);
        _assertReentry(LendingAction.ReenterOut);
        assertEq(paid, before_.quote, "withdrawal honors quote after protocol yield");
        assertEq(base.balanceOf(actor_) - before_.assets, paid, "withdrawal pays once");
        assertEq(before_.shares - share.balanceOf(actor_), amount, "withdrawal burns once");
        burnedShares += amount;
        ++lendingCounts[LendingAction.Redeem].succeeded;
    }

    function _arm(bool outgoing_) internal {
        bytes memory payload = outgoing_
            ? abi.encodeCall(
                IStandardExchangeOut.exchangeOut,
                (share, uint256(1), base, uint256(1), attacker, false, block.timestamp + 1 hours)
            )
            : abi.encodeCall(
                IStandardExchangeIn.exchangeIn,
                (base, uint256(1), share, uint256(0), attacker, true, block.timestamp + 1 hours)
            );
        LendingAccountingToken(address(base)).arm(address(seIn), payload);
    }

    function _assertReentry(LendingAction action_) internal {
        LendingAccountingToken token = LendingAccountingToken(address(base));
        assertEq(token.attempts(), 1, "operative token callback reached");
        assertFalse(token.nestedSuccess(), "nested money operation rejected");
        assertEq(token.nestedError(), IReentrancyLock.IsLocked.selector, "exact production guard boundary");
        ++lendingCounts[action_].expectedRevert;
    }

    function assertLendingAccounting() external view {
        assertEq(
            _cash(),
            initialCash + funded + yieldFunding,
            "independent native asset conservation across wallets and protocol custody"
        );
        for (uint8 i; i < 6; ++i) {
            Counts memory c = lendingCounts[LendingAction(i)];
            assertEq(c.attempted, cycles / 4, "every applicable supplementary action reached");
            assertEq(c.succeeded + c.expectedRevert, cycles / 4, "no swallowed supplementary failure");
            assertEq(c.unexpectedRevert, 0);
        }
        assertEq(base.balanceOf(attacker), 0, "attacker obtains no principal");
    }
}
