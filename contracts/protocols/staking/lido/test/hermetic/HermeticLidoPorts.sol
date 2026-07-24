// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ERC20} from "@crane/contracts/external/openzeppelin-contracts/token/ERC20/ERC20.sol";

/**
 * @dev Hermetic Lido-shaped ports for production-first SE tests (not mocks of the SE diamond).
 * submit 1:1 ETH→stETH; wrap/unwrap 1:1 stETH↔wstETH; queue request/claim with test finalize.
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

contract HermeticStETH is ERC20 {
    constructor() ERC20("Liquid staked Ether", "stETH") {}

    function submit(address) external payable returns (uint256) {
        require(msg.value > 0, "ZERO_DEPOSIT");
        _mint(msg.sender, msg.value);
        return msg.value;
    }

    function getPooledEthByShares(uint256 sharesAmount) external pure returns (uint256) {
        return sharesAmount;
    }

    function getSharesByPooledEth(uint256 ethAmount) external pure returns (uint256) {
        return ethAmount;
    }

    function sharesOf(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    function getTotalPooledEther() external view returns (uint256) {
        return totalSupply();
    }

    function getTotalShares() external view returns (uint256) {
        return totalSupply();
    }

    /// @dev Test helper
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract HermeticWstETH is ERC20 {
    HermeticStETH public immutable stETH;

    constructor(HermeticStETH stETH_) ERC20("Wrapped liquid staked Ether 2.0", "wstETH") {
        stETH = stETH_;
    }

    function wrap(uint256 stETHAmount) external returns (uint256) {
        require(stETHAmount > 0, "zero");
        require(stETH.transferFrom(msg.sender, address(this), stETHAmount), "xfer");
        _mint(msg.sender, stETHAmount);
        return stETHAmount;
    }

    function unwrap(uint256 wstETHAmount) external returns (uint256) {
        require(wstETHAmount > 0, "zero");
        _burn(msg.sender, wstETHAmount);
        require(stETH.transfer(msg.sender, wstETHAmount), "xfer");
        return wstETHAmount;
    }

    function getWstETHByStETH(uint256 stETHAmount) external pure returns (uint256) {
        return stETHAmount;
    }

    function getStETHByWstETH(uint256 wstETHAmount) external pure returns (uint256) {
        return wstETHAmount;
    }

    function stEthPerToken() external pure returns (uint256) {
        return 1e18;
    }

    function tokensPerStEth() external pure returns (uint256) {
        return 1e18;
    }
}

contract HermeticWithdrawalQueue {
    HermeticWstETH public immutable wstETH;
    HermeticStETH public immutable stETHToken;

    uint256 public lastRequestId;
    bool public paused;

    struct Request {
        address owner;
        uint256 amountStEth;
        bool finalized;
        bool claimed;
    }

    mapping(uint256 => Request) public requests;

    constructor(HermeticWstETH wstETH_) {
        wstETH = wstETH_;
        stETHToken = wstETH_.stETH();
    }

    function setPaused(bool p) external {
        paused = p;
    }

    function isPaused() external view returns (bool) {
        return paused;
    }

    function requestWithdrawalsWstETH(uint256[] calldata amounts, address owner)
        external
        returns (uint256[] memory requestIds)
    {
        require(!paused, "paused");
        if (owner == address(0)) owner = msg.sender;
        requestIds = new uint256[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) {
            require(wstETH.transferFrom(msg.sender, address(this), amounts[i]), "xfer");
            uint256 stAmount = wstETH.unwrap(amounts[i]);
            require(stAmount >= 100, "too small");
            require(stAmount <= 1000 ether, "too large");
            // burn stETH to simulate lock (send to dead)
            require(stETHToken.transfer(address(0xdead), stAmount), "burn");
            uint256 id = ++lastRequestId;
            requests[id] = Request({owner: owner, amountStEth: stAmount, finalized: false, claimed: false});
            requestIds[i] = id;
        }
    }

    /// @dev Test-only finalization: fund contract with ETH and mark finalized.
    function finalizeForTest(uint256 requestId) external payable {
        Request storage r = requests[requestId];
        require(r.owner != address(0), "no req");
        require(!r.finalized, "done");
        require(msg.value >= r.amountStEth, "eth");
        r.finalized = true;
    }

    function claimWithdrawal(uint256 requestId) external {
        Request storage r = requests[requestId];
        require(r.owner == msg.sender, "not owner");
        require(r.finalized, "not finalized");
        require(!r.claimed, "claimed");
        r.claimed = true;
        (bool ok,) = msg.sender.call{value: r.amountStEth}("");
        require(ok, "eth");
    }

    function isFinalized(uint256 requestId) external view returns (bool) {
        return requests[requestId].finalized;
    }

    function isClaimed(uint256 requestId) external view returns (bool) {
        return requests[requestId].claimed;
    }

    receive() external payable {}
}
