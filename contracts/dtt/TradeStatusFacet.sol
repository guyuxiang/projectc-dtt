//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/Constants.sol";
import "./DTTStorage.sol";
import "../kyc/Permission.sol";

import "../interfaces/IConditionCalculateFacet.sol";

contract TradeStatusFacet is DTTPermission, DTTStorage {
    function setTradeStatus(string memory businessId, SettleStatus _tradeStatus) public whenNotPaused CallDoor {
        ds.businessIndex[businessId].status = _tradeStatus;
    }

    function tradeStatus(string memory businessId) public view returns (TradeStatus) {
        if (ds.businessIndex[businessId].status == SettleStatus.SEND) {
            return TradeStatus.Realised;
        } else if (ds.businessIndex[businessId].status == SettleStatus.REFUND) {
            return TradeStatus.Void;
        } else if (ds.businessIndex[businessId].status == SettleStatus.WAIT) {
            return TradeStatus.Confirmed;
        } else if (ds.businessIndex[businessId].status == SettleStatus.INIT) {
            ConditionStatus timeConditionStatus =
                IConditionCalculateFacet(address(this)).querySCStatus(ds.businessIndex[businessId].timeScId);
            ConditionStatus conditionStatus = ConditionStatus.Met;
            if (!Strings.equal(ds.businessIndex[businessId].conditionSetId, "")) {
                conditionStatus =
                    IConditionCalculateFacet(address(this)).queryCSStatus(ds.businessIndex[businessId].conditionSetId);
            }
            // calculate tx status
            if (conditionStatus == ConditionStatus.NotMet) {
                return TradeStatus.Void;
            } else if (conditionStatus == ConditionStatus.RightNowNotMet) {
                if (timeConditionStatus == ConditionStatus.NotMet) {
                    return TradeStatus.Void;
                } else {
                    return TradeStatus.Unrealised;
                }
            } else if (conditionStatus == ConditionStatus.RightNowMet) {
                if (timeConditionStatus == ConditionStatus.RightNowNotMet) {
                    return TradeStatus.Unrealised;
                } else {
                    return TradeStatus.Realised;
                }
            } else if (conditionStatus == ConditionStatus.Met) {
                if (timeConditionStatus == ConditionStatus.RightNowNotMet) {
                    bool dateNotSet =
                        IConditionCalculateFacet(address(this)).dateNotSet(ds.businessIndex[businessId].timeScId);
                    if (dateNotSet) {
                        return TradeStatus.Unrealised;
                    } else {
                        return TradeStatus.Confirmed;
                    }
                } else {
                    return TradeStatus.Realised;
                }
            } else {
                revert(ErrorCode.SCM_DTT_tradeStatus_UNKNOWN_CONDITION_ERROR);
            }
        } else {
            revert(ErrorCode.SCM_DTT_tradeStatus_UNKNOWN_TRADE_ERROR);
        }
    }
}
