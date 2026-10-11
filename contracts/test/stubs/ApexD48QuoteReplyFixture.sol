// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/// @dev Non-SUT quote dependency for D48 staticcall tests. Not an SE SUT mock.
contract ApexD48QuoteReplyFixture {
    error QuoteBoom();

    enum Reply {
        Ok32,
        RevertCustom,
        RevertString,
        Panic,
        EmptyRevert,
        OkEmpty,
        OkShort,
        OkOverlong,
        MalformedRevert
    }

    Reply public reply = Reply.Ok32;
    uint256 public okValue = 1e18;
    uint256 public failAbove;
    uint256 public failBelow;
    uint256 public zeroBelow;
    bool public supplyReverts;
    bool public decimalsReverts;
    bool public redeemReverts;
    address public asset;
    uint256 public totalSupply_ = 1e18;
    uint8 public decimals_ = 18;

    function setReply(Reply r, uint256 okValue_) external {
        reply = r;
        okValue = okValue_;
    }

    function setFailAbove(uint256 v) external {
        failAbove = v;
    }

    function setFailBelow(uint256 v) external { failBelow = v; }
    function setZeroBelow(uint256 v) external { zeroBelow = v; }
    function setRedeemDependency(address asset_, bool reverts_) external {
        asset = asset_;
        redeemReverts = reverts_;
    }
    function previewRedeem(uint256 shares) external view returns (uint256) {
        if (redeemReverts) revert QuoteBoom();
        return shares;
    }
    function setMetadataFailures(bool supply_, bool decimals_) external {
        supplyReverts = supply_;
        decimalsReverts = decimals_;
    }

    function setSupply(uint256 s, uint8 d) external {
        totalSupply_ = s;
        decimals_ = d;
    }

    function totalSupply() external view returns (uint256) {
        if (supplyReverts) revert QuoteBoom();
        return totalSupply_;
    }

    function decimals() external view returns (uint8) {
        if (decimalsReverts) revert QuoteBoom();
        return decimals_;
    }

    function previewExchangeIn(address, uint256 amount, address) external view returns (uint256) {
        return _emit(amount);
    }

    function quoteAssets(bytes calldata, uint256 shares) external view returns (uint256) {
        return _emit(shares);
    }

    bool public quoteStateReverts;
    bool public snapshotSupplyReverts;

    function setQuoteStateReverts(bool enabled) external {
        quoteStateReverts = enabled;
    }

    function setSnapshotSupplyReverts(bool enabled) external {
        snapshotSupplyReverts = enabled;
    }

    function quoteState(address, address) external view returns (bytes memory, uint256) {
        if (quoteStateReverts) revert QuoteBoom();
        return (hex"01", 0);
    }

    function quoteTotalSupply(bytes calldata state) external view returns (uint256) {
        if (state.length != 0 && snapshotSupplyReverts) revert QuoteBoom();
        return totalSupply_;
    }

    function _emit(uint256 amount) internal view returns (uint256) {
        if (amount < failBelow) revert QuoteBoom();
        if (amount < zeroBelow) return 0;
        if (failAbove != 0 && amount > failAbove) {
            revert QuoteBoom();
        }
        Reply r = reply;
        if (r == Reply.RevertCustom) revert QuoteBoom();
        if (r == Reply.RevertString) revert("quote fail");
        if (r == Reply.Panic) {
            assert(false);
        }
        if (r == Reply.EmptyRevert) {
            assembly {
                revert(0, 0)
            }
        }
        if (r == Reply.MalformedRevert) {
            assembly {
                mstore(0, 1)
                revert(0, 3)
            }
        }
        if (r == Reply.OkEmpty) {
            assembly {
                return(0, 0)
            }
        }
        if (r == Reply.OkShort) {
            assembly {
                mstore(0, 1)
                return(0, 16)
            }
        }
        if (r == Reply.OkOverlong) {
            uint256 v = okValue;
            assembly {
                mstore(0, v)
                mstore(32, 1)
                return(0, 64)
            }
        }
        return okValue;
    }
}
