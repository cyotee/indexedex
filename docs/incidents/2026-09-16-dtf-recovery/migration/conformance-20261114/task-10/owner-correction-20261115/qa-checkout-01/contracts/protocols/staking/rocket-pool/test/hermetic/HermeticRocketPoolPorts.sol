// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {ERC20} from "@crane/contracts/external/openzeppelin-contracts/token/ERC20/ERC20.sol";

/**
 * @dev Hermetic Rocket Pool-shaped ports for production-first SE tests (not mocks of the SE diamond).
 * Deposit pool: capacity-gated payable deposit mints rETH at rate (optional fee bps).
 * rETH: rate + burn against controllable collateral.
 */

contract HermeticWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {}

    function deposit() public payable virtual {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "WETH: eth transfer failed");
    }

    receive() external payable {
        _mint(msg.sender, msg.value);
    }
}

/**
 * @dev rETH-shaped token. rateWad = ETH per 1e18 rETH (default 1e18).
 *      burn pays ETH when collateral allows.
 */
contract HermeticRETH is ERC20 {
    /// @dev ETH face per 1e18 rETH.
    uint256 public rateWad = 1e18;
    /// @dev ETH collateral available for burns (protocol getTotalCollateral analogue).
    uint256 public collateralEth;

    constructor() ERC20("Rocket Pool ETH", "rETH") {}

    function setRate(uint256 rateWad_) external {
        require(rateWad_ > 0, "rate");
        rateWad = rateWad_;
    }

    function fundCollateral(uint256 amount) external payable {
        require(msg.value == amount, "value");
        collateralEth += amount;
    }

    function setCollateral(uint256 amount) external {
        // Test helper: adjust accounting; fund ETH separately if burning.
        collateralEth = amount;
    }

    /// @dev Mint rETH to `to` without ETH (deposit pool uses this after taking ETH).
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function getExchangeRate() external view returns (uint256) {
        return rateWad;
    }

    function getEthValue(uint256 rethAmount) public view returns (uint256) {
        return (rethAmount * rateWad) / 1e18;
    }

    function getRethValue(uint256 ethAmount) public view returns (uint256) {
        return (ethAmount * 1e18) / rateWad;
    }

    function getTotalCollateral() external view returns (uint256) {
        return collateralEth;
    }

    function burn(uint256 rethAmount) external {
        require(rethAmount > 0, "zero");
        uint256 ethOut = getEthValue(rethAmount);
        require(collateralEth >= ethOut, "collateral");
        collateralEth -= ethOut;
        _burn(msg.sender, rethAmount);
        (bool ok,) = msg.sender.call{value: ethOut}("");
        require(ok, "eth");
    }

    receive() external payable {
        collateralEth += msg.value;
    }
}

/**
 * @dev Deposit pool: capacity + optional deposit fee bps reduce rETH minted.
 *      deposit{value} mints rETH to msg.sender via linked HermeticRETH.
 */
contract HermeticRocketDAOProtocolSettingsDeposit {
    uint256 public minimumDeposit = 0.01 ether;
    /// @dev Bound by the first `HermeticDepositPool` constructed with these settings, so the deposit
    ///      settings the SE transition quote reads describe the same pool that executes (D46, APEX F4).
    HermeticDepositPool public pool;

    function getMinimumDeposit() external view returns (uint256) {
        return minimumDeposit;
    }

    function setMinimumDeposit(uint256 minimumDeposit_) external {
        minimumDeposit = minimumDeposit_;
    }

    function bindPool(HermeticDepositPool pool_) external {
        if (address(pool) == address(0)) pool = pool_;
    }

    /// @dev Mainnet `getAssignDepositsEnabled()`: the quote then measures capacity use as pool net balance.
    function getAssignDepositsEnabled() external pure returns (bool) {
        return true;
    }

    /// @dev Mainnet `getMaximumDepositPoolSize()`. The pool's remaining headroom plus its balance, so the
    ///      quote's `limit - used` equals the pool's `getMaximumDepositAmount()`.
    function getMaximumDepositPoolSize() external view returns (uint256) {
        if (address(pool) == address(0)) return type(uint256).max;
        uint256 remaining = pool.maxDepositAmount();
        return remaining == type(uint256).max ? remaining : remaining + pool.getBalance();
    }

    /// @dev Mainnet `getDepositFee()` is an 18-decimal fraction; the pool keeps its fee in bps.
    function getDepositFee() external view returns (uint256) {
        return address(pool) == address(0) ? 0 : uint256(pool.depositFeeBps()) * 1e14;
    }

    function getDepositEnabled() external view returns (bool) {
        return address(pool) == address(0) ? true : pool.depositsEnabled();
    }
}

/// @dev Mainnet `RocketMinipoolQueue.getEffectiveCapacity()`: ETH the validator queue can absorb. The
///      hermetic protocol has no minipools, so the queue is empty (D46, APEX F4).
contract HermeticRocketMinipoolQueue {
    function getEffectiveCapacity() external pure returns (uint256) {
        return 0;
    }
}

contract HermeticDepositPool {
    HermeticRETH public immutable reth;
    HermeticRocketDAOProtocolSettingsDeposit public immutable settings;
    uint256 public maxDepositAmount = type(uint256).max;
    bool public depositsEnabled = true;
    uint16 public depositFeeBps; // 0 = no fee; fee reduces eth face credited to mint

    error InsufficientDepositCapacity(uint256 maxDeposit, uint256 amount);
    error DepositsDisabled();

    constructor(HermeticRETH reth_, HermeticRocketDAOProtocolSettingsDeposit settings_) {
        reth = reth_;
        settings = settings_;
        settings_.bindPool(this);
    }

    /// @dev Mainnet deposit pool `version()`; the SE transition quote accepts 3 or 4. Version 3 needs no
    ///      network-balance or collateral-rate reads (D46, APEX F4).
    function version() external pure returns (uint8) {
        return 3;
    }

    function setMaxDepositAmount(uint256 max_) external {
        maxDepositAmount = max_;
    }

    function setDepositEnabled(bool enabled) external {
        depositsEnabled = enabled;
    }

    function setDepositFeeBps(uint16 bps) external {
        require(bps <= 10_000, "bps");
        depositFeeBps = bps;
    }

    function getMaximumDepositAmount() external view returns (uint256) {
        if (!depositsEnabled) return 0;
        return maxDepositAmount;
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getExcessBalance() external pure returns (uint256) {
        return 0;
    }

    function deposit() external payable {
        if (!depositsEnabled) revert DepositsDisabled();
        uint256 minimumDeposit = settings.getMinimumDeposit();
        require(msg.value >= minimumDeposit, "The deposited amount is less than the minimum deposit size");
        if (msg.value > maxDepositAmount) {
            revert InsufficientDepositCapacity(maxDepositAmount, msg.value);
        }
        require(msg.value > 0, "zero");
        uint256 ethNet = msg.value;
        if (depositFeeBps > 0) {
            ethNet = msg.value - (msg.value * depositFeeBps) / 10_000;
        }
        uint256 rethOut = reth.getRethValue(ethNet);
        require(rethOut > 0, "dust");
        if (maxDepositAmount != type(uint256).max) {
            maxDepositAmount -= msg.value;
        }
        reth.mint(msg.sender, rethOut);
    }

    receive() external payable {}
}

/// @dev External registry port for deployment binding only. This does not model
/// canonical deposit settings, validator queues or transition quote behavior.
contract HermeticRocketStorage {
    mapping(bytes32 => address) private addresses;
    mapping(bytes32 => uint256) private uints;

    constructor(address reth, address pool) {
        addresses[keccak256("contract.addressrocketTokenRETH")] = reth;
        addresses[keccak256("contract.addressrocketDepositPool")] = pool;
        // The SE transition quote reads the validator queue on every quote (APEX F4).
        addresses[keccak256("contract.addressrocketMinipoolQueue")] = address(new HermeticRocketMinipoolQueue());
    }

    function register(string memory name_, address addr) external {
        addresses[keccak256(abi.encodePacked("contract.address", name_))] = addr;
    }

    function getAddress(bytes32 key) external view returns (address) { return addresses[key]; }

    /// @dev Mainnet `RocketStorage.getUint`; the quote reads the rETH deposit delay and the vault's last
    ///      deposit block. Unset keys are 0, which mainnet also reports for an address that never deposited.
    function getUint(bytes32 key) external view returns (uint256) { return uints[key]; }

    /// @dev Test helper.
    function setUint(bytes32 key, uint256 value) external { uints[key] = value; }
}
