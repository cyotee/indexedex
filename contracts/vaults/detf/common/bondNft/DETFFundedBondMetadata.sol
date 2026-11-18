// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Base64} from "@crane/contracts/utils/Base64.sol";
import {LibString} from "@crane/contracts/utils/LibString.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

/// @title DETFFundedBondMetadata
/// @notice SVG and exact JSON describe one funded position view, never LP value or projected yield.
library DETFFundedBondMetadata {
    using LibString for uint256;

    struct View {
        string detfName;
        string detfSymbol;
        uint256 tokenId;
        StakingMath.BondPosition position;
        StakingMath.BondClaim claim;
        uint256 timestamp;
        bool migrationCliff;
        bool migrationPresentation;
        bool rewardsClosed;
    }

    /// @notice Exact nine-decimal representation, including the last redeemable native unit.
    function _amount(uint256 raw_) internal pure returns (string memory) {
        string memory fraction_ = (1e9 + raw_ % 1e9).toString();
        return string.concat((raw_ / 1e9).toString(), ".", LibString.slice(fraction_, 1));
    }

    /// @notice Self-contained metadata; all dynamic text is escaped at its output boundary.
    function _uri(View memory v_) internal pure returns (string memory) {
        string memory description_ = v_.tokenId == 0
            ? "Protocol-owned reserve liquidity. This role has no purchased bond principal."
            : v_.tokenId < 3
                ? "Standing reward right. Rewards arrive as sDETF, which can be unstaked for DETF. Redeeming receipts preserves this right."
                : "Funded DETF purchase with linear principal vesting. Funded staking rewards are claimable during vesting. All claims pay sDETF.";
        if (v_.migrationCliff) {
            description_ = "Funded Migration DETF principal unlocks in full 90 days after creation. No principal vests before the cliff. Rewards accrue from creation. Before activation only principal-only claims are available after the cliff; reward and combined claims are closed. Claims pay sDETF.";
        } else if (v_.migrationPresentation && v_.tokenId >= 3) {
            description_ = "Funded Migration DETF purchase with linear principal vesting. Rewards accrue while principal vests. Before activation only vested principal can be claimed; reward and combined claims are closed. After activation rewards can also be claimed. All claims pay sDETF.";
        } else if (v_.migrationPresentation && v_.tokenId > 0 && v_.tokenId < 3) {
            description_ = "Standing reward right. Allocations made before activation stay in receipt custody for their allocation-time beneficiary, even after this NFT transfers. Reward delivery requires activation. This role has no purchased principal.";
        }
        string memory json_ = string.concat(
            '{"name":', LibString.escapeJSON(string.concat(v_.detfName, " #", v_.tokenId.toString()), true),
            ',"description":', LibString.escapeJSON(description_, true)
        );
        json_ = string.concat(json_,
            ',"image":"data:image/svg+xml;base64,', Base64.encode(bytes(_svg(v_))),
            '","attributes":[', _attributes(v_), "]}"
        );
        return string.concat("data:application/json;base64,", Base64.encode(bytes(json_)));
    }

    /// @notice Render previews with the same representation used by tokenURI.
    function _svg(View memory v_) internal pure returns (string memory) {
        string memory identity_ = string.concat(_bounded(v_.detfName, 30), " (", _bounded(v_.detfSymbol, 12), ")");
        string memory header_ = string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 440">',
            '<rect width="520" height="440" rx="20" fill="#101b2a"/>',
            '<g fill="#e5f3ef" font-family="monospace">',
            _text(identity_, 24, 34, 15),
            _text(string.concat(v_.migrationCliff ? "Migration cliff bond" : _title(v_.tokenId), " #", v_.tokenId.toString()), 24, 60, 14)
        );
        return string.concat(header_,
            v_.tokenId < 3 ? _role(v_) : _purchased(v_),
            "</g></svg>"
        );
    }

    function _purchased(View memory v_) private pure returns (string memory) {
        uint256 end_ = v_.position.startTimestamp + v_.position.vestingDuration;
        uint256 elapsed_ = v_.timestamp > v_.position.startTimestamp ? v_.timestamp - v_.position.startTimestamp : 0;
        if (elapsed_ > v_.position.vestingDuration) elapsed_ = v_.position.vestingDuration;
        uint256 progress_ = Math.mulDiv(elapsed_, 10_000, v_.position.vestingDuration);
        string memory status_ = v_.timestamp >= end_ ? "Fully vested"
            : string.concat((end_ - v_.timestamp).toString(), " seconds remaining");
        if (v_.migrationCliff) {
            progress_ = v_.timestamp >= end_ ? 10_000 : 0;
            status_ = v_.timestamp >= end_ ? "Principal unlocked"
                : string.concat("Cliff locked / ", (end_ - v_.timestamp).toString(), " seconds");
        }
        string memory progressSvg_ = string.concat(
            _text(string.concat((progress_ / 100).toString(), ".", (progress_ % 100 / 10).toString(),
                v_.migrationCliff ? "% principal unlocked" : "% vested"), 24, 94, 14),
            '<rect x="24" y="108" width="472" height="8" rx="4" fill="#304253"/>',
            '<rect x="24" y="108" width="', Math.mulDiv(progress_, 472, 10_000).toString(),
            '" height="8" rx="4" fill="#8de0c5"/>'
        );
        string memory timing_ = string.concat(
            _text(string.concat("Start ", v_.position.startTimestamp.toString(), " / Maturity ", end_.toString()), 24, 145, 11),
            _text(status_, 24, 167, 12)
        );
        return string.concat(progressSvg_, timing_,
            _positionValues(v_),
            v_.migrationPresentation
                ? _text(v_.rewardsClosed ? "Reward claims locked until activation" : "Reward claims open", 24, 389, 12)
                : "",
            _text(v_.migrationPresentation && v_.rewardsClosed
                ? "Principal-only claims pay sDETF."
                : "Claims pay sDETF. Unstake for DETF.", 24, 413, 12)
        );
    }

    function _positionValues(View memory v_) private pure returns (string memory) {
        string memory principal_ = string.concat(
            _value(v_.migrationCliff ? "Migration DETF principal" : "Purchased DETF", v_.position.principal, 24, 204),
            _value("Remaining DETF principal", v_.position.principal - v_.position.claimedPrincipal, 278, 204)
        );
        string memory claims_ = string.concat(
            _value("Claimable principal sDETF", v_.claim.principalDue, 24, 271),
            _value("Claimable rewards sDETF", _claimableRewards(v_), 278, 271)
        );
        return string.concat(principal_, claims_,
            _value("Total claimable sDETF", v_.claim.principalDue + _claimableRewards(v_), 24, 344),
            v_.migrationPresentation ? _value("Accrued rewards sDETF", v_.claim.rewardsDue, 278, 344) : ""
        );
    }

    function _value(string memory label_, uint256 amount_, uint256 x_, uint256 y_) private pure returns (string memory) {
        return string.concat(_text(label_, x_, y_, 12), _text(_displayAmount(amount_), x_, y_ + 26, 17));
    }

    function _role(View memory v_) private pure returns (string memory) {
        uint256 id_ = v_.tokenId;
        if (id_ == 0) return string.concat(
            _text("Protocol-owned reserve liquidity", 24, 133, 16),
            _text("No purchased principal or vesting.", 24, 171, 13),
            _text("Reserve custody is separate from", 24, 225, 13),
            _text("the DETF backing staking receipts.", 24, 247, 13)
        );
        if (v_.migrationPresentation) return string.concat(
            _text("Standing reward right", 24, 133, 18),
            _text(v_.rewardsClosed ? "Reward delivery locked until activation." : "Reward delivery open.", 24, 183, 13),
            _text("Past allocations keep their beneficiary.", 24, 225, 12),
            _text("Transfer conveys future allocations only.", 24, 247, 12),
            _text("No purchased principal or vesting.", 24, 297, 13)
        );
        return string.concat(
            _text("Standing reward right", 24, 133, 18),
            _text("Rewards arrive as funded sDETF.", 24, 183, 14),
            _text("Unstake delivered sDETF for DETF.", 24, 213, 14),
            _text("The right persists after unstaking.", 24, 267, 13),
            _text("No purchased principal or vesting.", 24, 297, 13)
        );
    }

    function _attributes(View memory v_) private pure returns (string memory) {
        string memory identity_ = string.concat(
            _trait("DETF name", v_.detfName), ",", _trait("DETF symbol", v_.detfSymbol), ",",
            _trait("Role", v_.migrationCliff ? "Migration cliff bond" : _title(v_.tokenId))
        );
        if (v_.tokenId < 3) return v_.migrationPresentation && v_.tokenId != 0
            ? string.concat(identity_, ",", _trait("Reward delivery", v_.rewardsClosed ? "Locked until activation" : "Open"))
            : identity_;
        string memory principal_ = string.concat(
            _trait("Purchased DETF", _amount(v_.position.principal)), ",",
            _trait("Remaining DETF principal", _amount(v_.position.principal - v_.position.claimedPrincipal)), ",",
            _trait("Claimed DETF principal", _amount(v_.position.claimedPrincipal))
        );
        return string.concat(identity_, ",", principal_, ",",
            _claimAttributes(v_), ",", _timeAttributes(v_)
        );
    }

    function _claimAttributes(View memory v_) private pure returns (string memory) {
        string memory claims_ = string.concat(
            _trait("Claimable principal sDETF", _amount(v_.claim.principalDue)), ",",
            _trait("Claimable rewards sDETF", _amount(_claimableRewards(v_))), ",",
            _trait("Total claimable sDETF", _amount(v_.claim.principalDue + _claimableRewards(v_)))
        );
        return v_.migrationPresentation ? string.concat(claims_, ",",
            _trait("Accrued rewards sDETF", _amount(v_.claim.rewardsDue)), ",",
            _trait("Reward delivery", v_.rewardsClosed ? "Locked until activation" : "Open")
        ) : claims_;
    }

    function _claimableRewards(View memory v_) private pure returns (uint256) {
        return v_.rewardsClosed ? 0 : v_.claim.rewardsDue;
    }

    function _timeAttributes(View memory v_) private pure returns (string memory) {
        uint256 end_ = v_.position.startTimestamp + v_.position.vestingDuration;
        if (v_.migrationCliff) return string.concat(
            '{"trait_type":"Cliff start","display_type":"date","value":', v_.position.startTimestamp.toString(), "},",
            '{"trait_type":"Principal unlock time","display_type":"date","value":', end_.toString(), "},",
            '{"trait_type":"Cliff duration seconds","value":', v_.position.vestingDuration.toString(), "},",
            '{"trait_type":"Principal unlocked bps","value":', v_.timestamp >= end_ ? "10000" : "0", "},",
            _trait("Principal status", v_.timestamp >= end_ ? "Unlocked" : "Cliff locked"), ",",
            _trait("Seconds remaining", (v_.timestamp >= end_ ? 0 : end_ - v_.timestamp).toString())
        );
        return string.concat(
            '{"trait_type":"Vesting start","display_type":"date","value":', v_.position.startTimestamp.toString(), "},",
            '{"trait_type":"Vesting end","display_type":"date","value":', end_.toString(), "},",
            _trait("Vesting status", v_.timestamp >= end_ ? "Fully vested" : "Vesting"), ",",
            _trait("Seconds remaining", (v_.timestamp >= end_ ? 0 : end_ - v_.timestamp).toString())
        );
    }

    function _trait(string memory key_, string memory value_) private pure returns (string memory) {
        return string.concat('{"trait_type":', LibString.escapeJSON(key_, true), ',"value":', LibString.escapeJSON(value_, true), "}");
    }

    function _title(uint256 id_) private pure returns (string memory) {
        return id_ == 0 ? "Protocol reserve" : id_ == 1 ? "Protocol fee recipient"
            : id_ == 2 ? "Creator recipient" : "Staked DETF bond";
    }

    function _bounded(string memory text_, uint256 limit_) private pure returns (string memory) {
        // The bounded SVG label is decorative; exact original text remains escaped in JSON.
        bytes memory source_ = bytes(text_);
        if (source_.length <= limit_) return text_;
        // Do not cut a UTF-8 character in half when bounding a valid Unicode name.
        while (limit_ != 0 && uint8(source_[limit_]) & 0xc0 == 0x80) --limit_;
        return string.concat(LibString.slice(text_, 0, limit_), "...");
    }

    function _displayAmount(uint256 raw_) private pure returns (string memory) {
        if (raw_ < 1e15) return _amount(raw_);
        string memory whole_ = (raw_ / 1e9).toString();
        return string.concat(
            LibString.slice(whole_, 0, 1), ".", LibString.slice(whole_, 1, 5), "e",
            (bytes(whole_).length - 1).toString()
        );
    }

    function _text(string memory text_, uint256 x_, uint256 y_, uint256 size_) private pure returns (string memory) {
        return string.concat(
            '<text x="', x_.toString(), '" y="', y_.toString(), '" font-size="', size_.toString(), '">',
            LibString.escapeHTML(text_), "</text>"
        );
    }
}
