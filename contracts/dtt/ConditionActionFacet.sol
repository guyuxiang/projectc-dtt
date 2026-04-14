//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/Constants.sol";
import "./DTTStorage.sol";
import "../kyc/Permission.sol";
import "../kyc/UserPermission.sol";
import "../kyc/Config.sol";
import "../interfaces/ITradeStatusFacet.sol";
import "../interfaces/ISettleFacet.sol";
import "../interfaces/IConditionCalculateFacet.sol";
import "../interfaces/IDTTERC20.sol";

contract ConditionActionFacet is DTTPermission, DTTStorage {
    event ConditionAccept(
        string indexed businessIdHash, string businessId, string scId, string commentsHash, string[] filesHash
    );

    event ConditionReject(
        string indexed businessIdHash, string businessId, string scId, string commentsHash, string[] filesHash
    );

    event ConditionSetDate(
        string indexed businessIdHash,
        string businessId,
        string scId,
        string setValue,
        string commentsHash,
        string[] filesHash
    );

    function conditionAccept(
        string memory businessId,
        string memory scId,
        string memory commentsHash,
        string[] memory filesHash
    )
        public
        whenNotPaused
        RtSendTradeActionDoor(getUserPermission(ds.businessIndex[businessId].tokenAddr, msg.sender))
    {
        conditionAction(businessId, scId, commentsHash, filesHash, "ACCEPT");
        emit ConditionAccept(businessId, businessId, scId, commentsHash, filesHash);
    }

    function conditionReject(
        string memory businessId,
        string memory scId,
        string memory commentsHash,
        string[] memory filesHash
    )
        public
        whenNotPaused
        RtSendTradeActionDoor(getUserPermission(ds.businessIndex[businessId].tokenAddr, msg.sender))
    {
        conditionAction(businessId, scId, commentsHash, filesHash, "REJECT");
        emit ConditionReject(businessId, businessId, scId, commentsHash, filesHash);
    }

    function conditionAction(
        string memory businessId,
        string memory scId,
        string memory commentsHash,
        string[] memory filesHash,
        string memory action
    ) internal {
        // Check transaction settlement status, only allow operations on transactions with status INIT
        require(
            ds.businessIndex[businessId].status == SettleStatus.INIT,
            ErrorCode.SCM_DTT_conditionAction_SETTLE_STATUS_WRONG
        );
        // Check transaction status, only allow operations on transactions with status Unrealised
        require(
            ITradeStatusFacet(address(this)).tradeStatus(businessId) == TradeStatus.Unrealised,
            ErrorCode.SCM_DTT_conditionAction_TRADE_STATUS_WRONG
        );
        require(_scBelongsToBusiness(businessId, scId), ErrorCode.SCM_DTT_conditionAction_SCID_NOT_IN_BUSINESS);

        changeFactor(scId, action, action, commentsHash, filesHash, ds.businessIndex[businessId].timeScId, msg.sender);
        // Check transaction status, trigger settlement for Realised/Void
        TradeStatus status_get = ITradeStatusFacet(address(this)).tradeStatus(businessId);
        if ((status_get == TradeStatus.Realised || status_get == TradeStatus.Void)
            && !isBusinessTokenPaused(ds.businessIndex[businessId].tokenAddr)) {
            ISettleFacet(address(this)).settleTrade(businessId);
        }
    }

    function conditionSetDate(
        string memory businessId,
        string memory scId,
        string memory date,
        string memory commentsHash,
        string[] memory filesHash
    )
        public
        whenNotPaused
        RtSendTradeActionDoor(getUserPermission(ds.businessIndex[businessId].tokenAddr, msg.sender))
    {
        // Check transaction settlement status, only allow operations on transactions with status INIT
        require(
            ds.businessIndex[businessId].status == SettleStatus.INIT,
            ErrorCode.SCM_DTT_conditionSetDate_SETTLE_STATUS_WRONG
        );
        // Check transaction status, only allow operations on transactions with status Unrealised
        require(
            ITradeStatusFacet(address(this)).tradeStatus(businessId) == TradeStatus.Unrealised,
            ErrorCode.SCM_DTT_conditionSetDate_TRADE_STATUS_WRONG
        );
        require(_scBelongsToBusiness(businessId, scId), ErrorCode.SCM_DTT_conditionSetDate_SCID_NOT_IN_BUSINESS);
        // Call condition contract to change the condition factor
        string memory timeScId = ds.businessIndex[businessId].timeScId;
        changeFactor(scId, "DATE", date, commentsHash, filesHash, timeScId, msg.sender);
        // Time range validation
        IConditionCalculateFacet(address(this)).timeRangeValidate(
            timeScId, ds.conditionSetIndex[ds.businessIndex[businessId].conditionSetId].scIDs
        );
        // Check transaction status, trigger settlement for Realised/Void
        TradeStatus status_get = ITradeStatusFacet(address(this)).tradeStatus(businessId);
        if ((status_get == TradeStatus.Realised || status_get == TradeStatus.Void)
            && !isBusinessTokenPaused(ds.businessIndex[businessId].tokenAddr)) {
            ISettleFacet(address(this)).settleTrade(businessId);
        }
        emit ConditionSetDate(businessId, businessId, scId, date, commentsHash, filesHash);
    }

    function changeFactor(
        string memory scID,
        string memory factorName,
        string memory value,
        string memory commentsHash,
        string[] memory filesHash,
        string memory txTimeScID,
        address applier
    ) internal {
        // validate before update
        require(!Strings.equal(ds.singleConditionIndex[scID].id, ""), ErrorCode.SCM_CDN_changeFactor_INVALID_SCID);
        uint256 factorIndex = IConditionCalculateFacet(address(this)).queryFactorIndex(
            ds.singleConditionIndex[scID].dynamicFactors, factorName
        );
        require(
            ds.singleConditionIndex[scID].dynamicFactors.length > factorIndex,
            ErrorCode.SCM_CDN_changeFactor_INVALID_INDEX
        );
        require(
            ds.singleConditionIndex[scID].dynamicFactors[factorIndex].changeAble,
            ErrorCode.SCM_CDN_changeFactor_INVALID_CHANGEABLE
        );
        require(
            !ds.singleConditionIndex[scID].dynamicFactors[factorIndex].changeFlag,
            ErrorCode.SCM_CDN_changeFactor_INVALID_CHANGEFLAG
        );
        require(
            ds.singleConditionIndex[scID].dynamicFactors[factorIndex].changeAddr == applier,
            ErrorCode.SCM_CDN_changeFactor_INVALID_CHANGEADDR
        );
        (bool actionTimeIfExistsTimeRange,,) =
            IConditionCalculateFacet(address(this)).calculateTimeRange(ds.singleConditionIndex[scID]);
        if (actionTimeIfExistsTimeRange) {
            require(
                block.timestamp >= ds.singleConditionIndex[scID].dynamicFactors[factorIndex].beginTime
                    && block.timestamp <= ds.singleConditionIndex[scID].dynamicFactors[factorIndex].endTime,
                ErrorCode.SCM_CDN_changeFactor_INVALID_TIME
            );
        } else {
            // must be DATE change when DATE not set
            require(
                Strings.equal(ds.singleConditionIndex[scID].dynamicFactors[factorIndex].name, "DATE"),
                ErrorCode.SCM_CDN_changeFactor_NO_DATE
            );
        }

        // update this factor
        ds.singleConditionIndex[scID].dynamicFactors[factorIndex].value = value;
        ds.singleConditionIndex[scID].dynamicFactors[factorIndex].changeFlag = true;
        ds.singleConditionIndex[scID].dynamicFactors[factorIndex].changeAble = false;
        ds.singleConditionIndex[scID].dynamicFactors[factorIndex].commentsHash = commentsHash;
        ds.singleConditionIndex[scID].dynamicFactors[factorIndex].filesHash = filesHash;
        // when setting date, validate and update
        if (!actionTimeIfExistsTimeRange) {
            (, uint256 actionTimeBeginAfterUpdate, uint256 actionTimeEndAfterUpdate) =
                IConditionCalculateFacet(address(this)).calculateTimeRange(ds.singleConditionIndex[scID]);
            require(actionTimeEndAfterUpdate > block.timestamp, ErrorCode.SCM_CDN_changeFactor_ACTIONTIME_ERROR);
            (bool txTimeIfExistsTimeRange,, uint256 txTimeEnd) =
                IConditionCalculateFacet(address(this)).calculateTimeRange(ds.singleConditionIndex[txTimeScID]);
            if (txTimeIfExistsTimeRange) {
                require(actionTimeBeginAfterUpdate < txTimeEnd, ErrorCode.SCM_CDN_changeFactor_ACTIONTIME_ERROR2);
            }
            for (uint256 k = 0; k < ds.singleConditionIndex[scID].dynamicFactors.length; k++) {
                // when setting date, change other dynamic factors' changeAble/beginTime/endTime
                if (k != factorIndex) {
                    ds.singleConditionIndex[scID].dynamicFactors[k].changeAble = true;
                    ds.singleConditionIndex[scID].dynamicFactors[k].beginTime = actionTimeBeginAfterUpdate;
                    ds.singleConditionIndex[scID].dynamicFactors[k].endTime = actionTimeEndAfterUpdate;
                }
            }
        }
    }

    function _scBelongsToBusiness(string memory businessId, string memory scId) internal view returns (bool) {
        if (Strings.equal(scId, ds.businessIndex[businessId].timeScId)) {
            return true;
        }

        return _conditionSetContainsSc(ds.businessIndex[businessId].conditionSetId, scId);
    }

    function _conditionSetContainsSc(string memory csId, string memory scId) internal view returns (bool) {
        if (Strings.equal(csId, "")) {
            return false;
        }

        ConditionSet storage conditionSet = ds.conditionSetIndex[csId];
        if (Strings.equal(conditionSet.id, "")) {
            return false;
        }

        for (uint256 i = 0; i < conditionSet.scIDs.length; i++) {
            if (Strings.equal(conditionSet.scIDs[i], scId)) {
                return true;
            }
        }

        for (uint256 i = 0; i < conditionSet.csIDs.length; i++) {
            if (_conditionSetContainsSc(conditionSet.csIDs[i], scId)) {
                return true;
            }
        }

        return false;
    }
}
