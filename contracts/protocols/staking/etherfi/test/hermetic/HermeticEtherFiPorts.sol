// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ERC20} from "@crane/contracts/external/openzeppelin-contracts/token/ERC20/ERC20.sol";

/**
 * @dev Hermetic ether.fi-shaped ports for production-first SE tests (not mocks of the SE diamond).
 * deposit 1:1 ETH→eETH; wrap/unwrap via floor rate (rateWad = eETH per 1 weETH, default 1e18);
 * queue request/claim; controllable redeem.
 * Non-1 rates catch exact-out ceil bugs that identity rates hide.
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

contract HermeticEETH is ERC20 {
    constructor() ERC20("ether.fi ETH", "eETH") {}

    /// @dev Test helper
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
    }

    /// @dev Share total for rate closed form (fixed virtual share base).
    function getTotalShares() external pure returns (uint256) {
        return 1e18;
    }

    function getTotalPooledEther() external pure returns (uint256) {
        return 1e18;
    }

    function shares(address) external pure returns (uint256) {
        return 0;
    }

    function sharesToBalance(uint256 sharesAmount) external pure returns (uint256) {
        return sharesAmount;
    }

    function balanceToShares(uint256 balance) external pure returns (uint256) {
        return balance;
    }
}

contract HermeticWeETH is ERC20 {
    HermeticEETH public immutable eEthToken;
    /// @dev eETH face per 1e18 weETH (matches live getRate). Default 1:1; tests set >1e18.
    uint256 public rateWad = 1e18;

    constructor(HermeticEETH eETH_) ERC20("Wrapped eETH", "weETH") {
        eEthToken = eETH_;
    }

    function setRate(uint256 rateWad_) external {
        require(rateWad_ > 0, "rate");
        rateWad = rateWad_;
    }

    function wrap(uint256 eETHAmount) external returns (uint256) {
        require(eETHAmount > 0, "zero");
        require(eEthToken.transferFrom(msg.sender, address(this), eETHAmount), "xfer");
        uint256 weOut = getWeETHByeETH(eETHAmount);
        require(weOut > 0, "dust");
        _mint(msg.sender, weOut);
        return weOut;
    }

    function unwrap(uint256 weETHAmount) external returns (uint256) {
        require(weETHAmount > 0, "zero");
        uint256 eOut = getEETHByWeETH(weETHAmount);
        _burn(msg.sender, weETHAmount);
        require(eEthToken.transfer(msg.sender, eOut), "xfer");
        return eOut;
    }

    /// @dev sharesForAmount: floor(e * 1e18 / rate)
    function getWeETHByeETH(uint256 eETHAmount) public view returns (uint256) {
        return (eETHAmount * 1e18) / rateWad;
    }

    /// @dev amountForShare: floor(we * rate / 1e18)
    function getEETHByWeETH(uint256 weETHAmount) public view returns (uint256) {
        return (weETHAmount * rateWad) / 1e18;
    }

    function getRate() external view returns (uint256) {
        return rateWad;
    }

    function eETH() external view returns (address) {
        return address(eEthToken);
    }
}

contract HermeticLiquidityPool {
    HermeticEETH public immutable eETHToken;
    HermeticWeETH public weETHToken;
    HermeticWithdrawRequestNFT public withdrawNFT;

    constructor(HermeticEETH eETH_) {
        eETHToken = eETH_;
    }

    function setWeETH(HermeticWeETH we_) external {
        weETHToken = we_;
    }

    function setWithdrawNFT(HermeticWithdrawRequestNFT nft_) external {
        withdrawNFT = nft_;
    }

    function eETH() external view returns (address) {
        return address(eETHToken);
    }

    /// @dev Virtual pooled ether = rateWad so T/S = rate with S=1e18.
    function getTotalPooledEther() external view returns (uint256) {
        return address(weETHToken) == address(0) ? 1e18 : weETHToken.rateWad();
    }

    function sharesForAmount(uint256 amount) external view returns (uint256) {
        uint256 rate = address(weETHToken) == address(0) ? 1e18 : weETHToken.rateWad();
        return (amount * 1e18) / rate;
    }

    function amountForShare(uint256 shares) external view returns (uint256) {
        uint256 rate = address(weETHToken) == address(0) ? 1e18 : weETHToken.rateWad();
        return (shares * rate) / 1e18;
    }

    /// @dev Ceiling shares for withdrawal face (protocol-favoring).
    function sharesForWithdrawalAmount(uint256 amount) external view returns (uint256) {
        uint256 rate = address(weETHToken) == address(0) ? 1e18 : weETHToken.rateWad();
        return (amount * 1e18 + rate - 1) / rate;
    }

    function deposit() external payable returns (uint256) {
        require(msg.value > 0, "ZERO_DEPOSIT");
        eETHToken.mint(msg.sender, msg.value);
        return msg.value;
    }

    function deposit(address) external payable returns (uint256) {
        require(msg.value > 0, "ZERO_DEPOSIT");
        eETHToken.mint(msg.sender, msg.value);
        return msg.value;
    }

    function requestWithdraw(address recipient, uint256 amount) external returns (uint256) {
        require(amount >= 100, "too small");
        require(amount <= 1000 ether, "too large");
        require(eETHToken.transferFrom(msg.sender, address(this), amount), "xfer");
        // lock eETH (burn)
        eETHToken.burn(address(this), amount);
        return withdrawNFT.mintRequest(recipient, amount);
    }

    receive() external payable {}
}

contract HermeticWithdrawRequestNFT {
    uint256 public lastRequestId;

    struct Request {
        address owner;
        uint256 amountEth;
        bool finalized;
        bool claimed;
    }

    mapping(uint256 => Request) public requests;

    function mintRequest(address owner, uint256 amountEth) external returns (uint256 id) {
        id = ++lastRequestId;
        requests[id] = Request({owner: owner, amountEth: amountEth, finalized: false, claimed: false});
    }

    /// @dev Test-only finalization: fund contract with ETH and mark finalized.
    function finalizeForTest(uint256 requestId) external payable {
        Request storage r = requests[requestId];
        require(r.owner != address(0), "no req");
        require(!r.finalized, "done");
        require(msg.value >= r.amountEth, "eth");
        r.finalized = true;
    }

    function claimWithdraw(uint256 requestId) external {
        Request storage r = requests[requestId];
        require(r.owner == msg.sender, "not owner");
        require(r.finalized, "not finalized");
        require(!r.claimed, "claimed");
        r.claimed = true;
        (bool ok,) = msg.sender.call{value: r.amountEth}("");
        require(ok, "eth");
    }

    function isFinalized(uint256 requestId) external view returns (bool) {
        return requests[requestId].finalized;
    }

    function isClaimed(uint256 requestId) external view returns (bool) {
        return requests[requestId].claimed;
    }

    function ownerOf(uint256 requestId) external view returns (address) {
        return requests[requestId].owner;
    }

    function getRequest(uint256 requestId)
        external
        view
        returns (uint96 amountOfEEth, uint96 shareOfEEth, bool isValid, uint32 feeGwei)
    {
        Request storage r = requests[requestId];
        return (uint96(r.amountEth), uint96(r.amountEth), r.owner != address(0) && !r.claimed, 0);
    }

    receive() external payable {}
}

/**
 * @dev Controllable instant redeem port. redeemWeEth burns weETH and pays ETH (minus fee).
 * capacityEth gates how much ETH face can be redeemed; 0 disables redeem.
 */
contract HermeticRedemptionManager {
    HermeticWeETH public immutable weETH;
    HermeticEETH public immutable eETHToken;
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 public capacityEth;
    /// @dev Exit fee in bps (e.g. 100 = 1%).
    uint16 public exitFeeBps;
    bool public paused;

    constructor(HermeticWeETH weETH_) {
        weETH = weETH_;
        eETHToken = weETH_.eEthToken();
    }

    function setCapacityEth(uint256 cap) external {
        capacityEth = cap;
    }

    function setExitFeeBps(uint16 bps) external {
        exitFeeBps = bps;
    }

    function setPaused(bool p) external {
        paused = p;
    }

    function canRedeem(uint256 amount, address /*token*/) external view returns (bool) {
        if (paused) return false;
        return amount <= capacityEth && amount <= address(this).balance;
    }

    function redeemWeEth(uint256 weEthAmount, address receiver, address outputToken) external {
        require(!paused, "paused");
        require(outputToken == ETH_ADDRESS, "only eth");
        require(weEthAmount > 0, "zero");
        uint256 ethFace = weEthAmount; // 1:1 hermetic
        require(ethFace <= capacityEth, "capacity");
        require(ethFace <= address(this).balance, "liq");

        require(weETH.transferFrom(msg.sender, address(this), weEthAmount), "xfer");
        // burn we by unwrap then burn e
        uint256 eOut = weETH.unwrap(weEthAmount);
        eETHToken.burn(address(this), eOut);

        capacityEth -= ethFace;
        uint256 fee = (ethFace * exitFeeBps) / 10_000;
        uint256 pay = ethFace - fee;
        (bool ok,) = receiver.call{value: pay}("");
        require(ok, "eth");
    }

    function redeemEEth(uint256 eEthAmount, address receiver, address outputToken) external {
        require(!paused, "paused");
        require(outputToken == ETH_ADDRESS, "only eth");
        require(eEthAmount <= capacityEth, "capacity");
        require(eEthAmount <= address(this).balance, "liq");
        require(eETHToken.transferFrom(msg.sender, address(this), eEthAmount), "xfer");
        eETHToken.burn(address(this), eEthAmount);
        capacityEth -= eEthAmount;
        uint256 fee = (eEthAmount * exitFeeBps) / 10_000;
        uint256 pay = eEthAmount - fee;
        (bool ok,) = receiver.call{value: pay}("");
        require(ok, "eth");
    }

    /// @dev Fund redeem liquidity.
    function fund() external payable {}

    receive() external payable {}
}
