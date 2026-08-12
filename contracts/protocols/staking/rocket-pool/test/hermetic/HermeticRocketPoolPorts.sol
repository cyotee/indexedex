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
contract HermeticDepositPool {
    HermeticRETH public immutable reth;
    uint256 public maxDepositAmount = type(uint256).max;
    bool public depositsEnabled = true;
    uint16 public depositFeeBps; // 0 = no fee; fee reduces eth face credited to mint

    error InsufficientDepositCapacity(uint256 maxDeposit, uint256 amount);
    error DepositsDisabled();

    constructor(HermeticRETH reth_) {
        reth = reth_;
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
        reth.mint(msg.sender, rethOut);
    }

    receive() external payable {}
}
