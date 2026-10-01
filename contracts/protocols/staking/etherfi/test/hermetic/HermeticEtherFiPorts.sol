// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";
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

/// @dev Native shares are stored in the ERC20 ledger. Nominal transfers floor at the
/// current pooled/share ratio, as EETH does; the virtual base bootstraps an empty pool.
contract HermeticEETH is ERC20 {
    uint256 private pooled = 1 ether;
    constructor() ERC20("ether.fi ETH", "eETH") {}

    function mint(address to, uint256 amount) external {
        uint256 minted = balanceToShares(amount);
        pooled += amount;
        _mint(to, minted);
    }

    function burn(address from, uint256 amount) external {
        uint256 burned = balanceToShares(amount);
        pooled -= amount;
        _burn(from, burned);
    }

    function setRate(uint256 rate) external {
        require(rate > 0, "rate");
        pooled = Math.mulDiv(totalShares(), rate, 1 ether);
    }

    function getTotalShares() external view returns (uint256) {
        return totalShares();
    }

    function getTotalPooledEther() external view returns (uint256) {
        return pooled;
    }

    function totalShares() public view returns (uint256) {
        return 1 ether + super.totalSupply();
    }

    function totalSupply() public view override returns (uint256) {
        return sharesToBalance(super.totalSupply());
    }

    function shares(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    function balanceOf(address user) public view override returns (uint256) {
        return sharesToBalance(super.balanceOf(user));
    }

    function sharesToBalance(uint256 amount) public view returns (uint256) {
        return Math.mulDiv(amount, pooled, totalShares());
    }

    function balanceToShares(uint256 amount) public view returns (uint256) {
        return Math.mulDiv(amount, totalShares(), pooled);
    }

    function _update(address from, address to, uint256 amount) internal override {
        super._update(from, to, from == address(0) || to == address(0) ? amount : balanceToShares(amount));
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
        eEthToken.setRate(rateWad_);
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
        return eEthToken.balanceToShares(eETHAmount);
    }

    /// @dev amountForShare: floor(we * rate / 1e18)
    function getEETHByWeETH(uint256 weETHAmount) public view returns (uint256) {
        return eEthToken.sharesToBalance(weETHAmount);
    }

    function getRate() external view returns (uint256) {
        return eEthToken.sharesToBalance(1 ether);
    }

    function eETH() external view returns (address) {
        return address(eEthToken);
    }
}

contract HermeticBlacklister {
    mapping(address => uint256) public blacklistedUntil;

    error BlacklistedUser(address user);

    function setBlacklistedUntil(address user, uint256 until_) external {
        blacklistedUntil[user] = until_;
    }

    function nonBlacklisted(address user) public view {
        if (blacklistedUntil[user] > block.timestamp) revert BlacklistedUser(user);
    }
}

contract HermeticLiquidityPool {
    HermeticEETH public immutable eETHToken;
    HermeticWeETH public weETHToken;
    HermeticWithdrawRequestNFT public withdrawNFT;
    HermeticBlacklister public immutable blacklister;
    bool public paused;
    uint256 public pausedUntil;

    error ContractPaused();
    error ContractPausedUntil(uint256 until_);

    constructor(HermeticEETH eETH_) {
        eETHToken = eETH_;
        blacklister = new HermeticBlacklister();
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

    /// @dev Deposits add nominal pooled ETH and mint floor native shares at the pre-deposit ratio.
    function getTotalPooledEther() external view returns (uint256) {
        return eETHToken.getTotalPooledEther();
    }

    /// @dev Mainnet `LiquidityPool.totalValueInLp()`: ETH held liquid in the pool. Deposits stay on
    ///      this stub, so its balance is the liquid value (D46 fixture, APEX F4).
    function totalValueInLp() external view returns (uint256) {
        return address(this).balance;
    }

    function sharesForAmount(uint256 amount) external view returns (uint256) {
        return eETHToken.balanceToShares(amount);
    }

    function amountForShare(uint256 shares) external view returns (uint256) {
        return eETHToken.sharesToBalance(shares);
    }

    /// @dev Ceiling shares for withdrawal face (protocol-favoring).
    function sharesForWithdrawalAmount(uint256 amount) external view returns (uint256) {
        return Math.mulDiv(amount, eETHToken.totalShares(), eETHToken.getTotalPooledEther(), Math.Rounding.Ceil);
    }

    function setPaused(bool paused_) external {
        paused = paused_;
    }

    function setPausedUntil(uint256 until_) external {
        pausedUntil = until_;
    }

    function _requireDepositOpen() internal view {
        if (paused) revert ContractPaused();
        if (pausedUntil >= block.timestamp) revert ContractPausedUntil(pausedUntil);
        blacklister.nonBlacklisted(msg.sender);
    }

    function deposit() external payable returns (uint256) {
        _requireDepositOpen();
        require(msg.value > 0, "ZERO_DEPOSIT");
        eETHToken.mint(msg.sender, msg.value);
        return msg.value;
    }

    function deposit(address) external payable returns (uint256) {
        _requireDepositOpen();
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

    /// @dev Mainnet `EtherFiRedemptionManager.tokenToRedemptionInfo(token)` as the SE transition quote
    ///      reads it (seven words): bucket capacity, remaining units, last refill timestamp, refill rate
    ///      per second, treasury split (bps), exit fee (bps), low watermark (bps). Units are 1e12 wei.
    ///      This stub has no refill and no low watermark; paused publishes zero units (D46, APEX F4).
    function tokenToRedemptionInfo(address)
        external
        view
        returns (
            uint256 capacity,
            uint256 remaining,
            uint256 lastRefill,
            uint256 refillRate,
            uint256 treasurySplit,
            uint256 exitFee,
            uint256 lowWatermark
        )
    {
        uint256 units = paused ? 0 : capacityEth / 1e12;
        return (units, units, block.timestamp, 0, 0, exitFeeBps, 0);
    }

    function canRedeem(
        uint256 amount,
        address /*token*/
    )
        external
        view
        returns (bool)
    {
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
