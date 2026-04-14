//SPDX-License-Identifier: UNLICENSED

// Solidity files must start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/Constants.sol";
import "../libraries/StringContains.sol";
import "./DTTStorage.sol";
import "../kyc/Permission.sol";

contract ConditionCalculateFacet is DTTPermission, DTTStorage {
    function queryCSStatus(string memory csID) public view returns (ConditionStatus res) {
        ConditionSet memory conditionSet = ds.conditionSetIndex[csID];
        require(!Strings.equal(conditionSet.id, ""), ErrorCode.SCM_CDN_queryCSStatus_INVALID_CSID);
        if (conditionSet.join == JoinType.AND) {
            res = ConditionStatus.Met;
        } else {
            res = ConditionStatus.NotMet;
        }
        for (uint256 i = 0; i < conditionSet.scIDs.length; i++) {
            res = mergeStatus(conditionSet.join, res, querySCStatus(conditionSet.scIDs[i]));
        }
        for (uint256 i = 0; i < conditionSet.csIDs.length; i++) {
            res = mergeStatus(conditionSet.join, res, queryCSStatus(conditionSet.csIDs[i]));
        }
        return res;
    }

    function querySCStatus(string memory scID) public view returns (ConditionStatus) {
        SingleCondition memory singleCondition = ds.singleConditionIndex[scID];
        require(!Strings.equal(singleCondition.id, ""), ErrorCode.SCM_CDN_querySCStatus_INVALID_SCID);
        string memory conditionType = singleCondition.conditionType;
        if (StringContains.contains(conditionType, "T")) {
            (bool ifExistsTimeRange, uint256 beginTime, uint256 endTime) = calculateTimeRange(singleCondition);
            if (!ifExistsTimeRange) {
                return ConditionStatus.RightNowNotMet;
            } else if (block.timestamp >= beginTime && block.timestamp <= endTime) {
                return ConditionStatus.RightNowMet;
            } else if (block.timestamp > endTime) {
                return ConditionStatus.NotMet;
            } else {
                return ConditionStatus.RightNowNotMet;
            }
        } else if (StringContains.contains(conditionType, "A1") || StringContains.contains(conditionType, "A2")) {
            ConditionFactor memory acceptFactor = queryFactor(singleCondition.dynamicFactors, "ACCEPT");
            if (acceptFactor.changeFlag) {
                return ConditionStatus.Met;
            } else {
                if (factorFutureChangeChance(singleCondition, acceptFactor)) {
                    return ConditionStatus.RightNowNotMet;
                } else {
                    return ConditionStatus.NotMet;
                }
            }
        } else if (StringContains.contains(conditionType, "A3") || StringContains.contains(conditionType, "A4")) {
            ConditionFactor memory rejectFactor = queryFactor(singleCondition.dynamicFactors, "REJECT");
            if (rejectFactor.changeFlag) {
                return ConditionStatus.NotMet;
            } else {
                if (factorFutureChangeChance(singleCondition, rejectFactor)) {
                    return ConditionStatus.RightNowMet;
                } else {
                    return ConditionStatus.Met;
                }
            }
        } else {
            revert(ErrorCode.SCM_CDN_querySCStatus_INVALID_CONDITIONTYPE);
        }
    }

    /// @dev return if there is a not set date dynamic factor
    function dateNotSet(string memory scID) public view returns (bool) {
        SingleCondition memory singleCondition = ds.singleConditionIndex[scID];
        for (uint256 i = 0; i < singleCondition.dynamicFactors.length; i++) {
            if (Strings.equal(singleCondition.dynamicFactors[i].name, "DATE")) {
                if (!singleCondition.dynamicFactors[i].changeFlag) {
                    return true;
                }
            }
        }
        return false;
    }

    /// @dev revert if the input scIds (within one trade) time range validate not pass
    function timeRangeValidate(string memory txTimeScID, string[] memory actionScIDs) public view {
        (bool txTimeIfExistsTimeRange, , uint256 txTimeEnd) = calculateTimeRange(ds.singleConditionIndex[txTimeScID]);
        if (!txTimeIfExistsTimeRange) {
            return;
        }
        for (uint256 i = 0; i < actionScIDs.length; i++) {
            string memory actionScID = actionScIDs[i];
            (bool actionTimeIfExistsTimeRange, uint256 actionTimeBegin, ) = calculateTimeRange(ds.singleConditionIndex[actionScID]);
            if (actionTimeIfExistsTimeRange) {
                ConditionStatus status = querySCStatus(actionScID);
                if (status == ConditionStatus.RightNowMet || status == ConditionStatus.RightNowNotMet) {
                    require(actionTimeBegin <= txTimeEnd, ErrorCode.SCM_CDN_timeRangeValidate_INVALID_TIME);
                }
            }
        }
    }

    /// @param factor must be included in singleCondition's dynamicFactors
    /// @dev return if there is a chance to change the factor at now or in the future
    /// this function is used to calculate a single SC status, without considering any other SC (such as txTimeCondition)
    function factorFutureChangeChance(SingleCondition memory singleCondition, ConditionFactor memory factor) private view returns (bool) {
        // any factor should be changed only once
        if (factor.changeFlag) {
            return false;
        }
        // can be changed before endTime
        if (factor.changeAble) {
            return block.timestamp < factor.endTime;
        }
        // both changeFlag and changeAble are false, date not set
        for (uint256 i = 0; i < singleCondition.dynamicFactors.length; i++) {
            if (Strings.equal(singleCondition.dynamicFactors[i].name, "DATE")) {
                if (!singleCondition.dynamicFactors[i].changeFlag) {
                    return true;
                }
            }
        }
        // fallback
        revert(ErrorCode.SCM_CDN_factorFutureChangeChance_INVALID_LOGIC);
    }

    /// @dev timeCondition's range, or actionCondition's action time range
    /// when dynamic factor `DATE` not configured, return (false, 0, 0)
    /// @return (bool ifExistsTimeRange, begin, end)
    function calculateTimeRange(SingleCondition memory singleCondition) public pure returns (bool, uint256, uint256) {
        ConditionFactor memory dateFactor;
        uint256 dateFactorValue;
        string memory conditionType = singleCondition.conditionType;
        // :v2
        if (StringContains.contains(conditionType, "v2")) {
            return (true, stringToUint(queryFactor(singleCondition.fixFactors, "START_DATE").value), stringToUint(queryFactor(singleCondition.fixFactors, "END_DATE").value) + 1 days);
        }
        // T1
        else if (StringContains.contains(conditionType, "T1") || StringContains.contains(conditionType, ".1")) {
            dateFactor = queryFactor(singleCondition.dynamicFactors, "DATE");
            if (!dateFactor.changeFlag) {
                return (false, 0, 0);
            }
            dateFactorValue = stringToUint(dateFactor.value);
            uint256 xFactorValue = stringToUint(queryFactor(singleCondition.fixFactors, "X").value);
            return (true, dateFactorValue + xFactorValue * 1 days, dateFactorValue + xFactorValue * 1 days + 1 days);
        }
        // other T
        else {
            dateFactor = queryFactor(singleCondition.fixFactors, "DATE");
            dateFactorValue = stringToUint(dateFactor.value);
            // T2
            if (StringContains.contains(conditionType, "T2") || StringContains.contains(conditionType, ".2")) {
                return (true, 0, dateFactorValue + 1 days);
            }
            // T3
            else if (StringContains.contains(conditionType, "T3") || StringContains.contains(conditionType, ".3")) {
                return (true, dateFactorValue, dateFactorValue + 1 days);
            }
            // T4
            else if (StringContains.contains(conditionType, "T4") || StringContains.contains(conditionType, ".4")) {
                return (true, dateFactorValue, 253402243200);
            }
            // fallback
            else {
                revert(ErrorCode.SCM_CDN_calculateTimeRange_INVALID_TYPE);
            }
        }
    }

    function queryFactor(ConditionFactor[] memory factors, string memory name) public pure returns (ConditionFactor memory res) {
        for (uint256 i = 0; i < factors.length; i++) {
            if (Strings.equal(factors[i].name, name)) {
                res = factors[i];
                return res;
            }
        }
        revert(ErrorCode.SCM_CDN_queryFactor_NOSUCH_FACTOR);
    }

    function queryFactorIndex(ConditionFactor[] memory factors, string memory name) public pure returns (uint256) {
        uint256 index;
        for (uint256 i = 0; i < factors.length; i++) {
            if (Strings.equal(factors[i].name, name)) {
                index = i;
                return index;
            }
        }
        revert(ErrorCode.SCM_CDN_queryFactorIndex_NOSUCH_FACTOR);
    }

    function mergeStatus(JoinType join, ConditionStatus status1, ConditionStatus status2) private pure returns (ConditionStatus) {
        if (join == JoinType.AND) {
            if (status1 < status2) {
                return status2;
            }
            return status1;
        } else {
            if (status1 > status2) {
                return status2;
            }
            return status1;
        }
    }

    // Iterate through cs, accept parameters prefix or suffix, and reassemble the ids inside, returning the new cs
    function refactorCsId(ConditionSet memory cs, string memory addContent) public pure returns (ConditionSet memory) {
        cs.id = string(abi.encodePacked(addContent, "_", cs.id));
        for (uint256 i = 0; i < cs.scIDs.length; i++) {
            cs.scIDs[i] = string(abi.encodePacked(addContent, "_", cs.scIDs[i]));
        }
        for (uint256 i = 0; i < cs.csIDs.length; i++) {
            cs.csIDs[i] = string(abi.encodePacked(addContent, "_", cs.csIDs[i]));
        }

        return cs;
    }

    function changeFactorWhenPartialAccept(
        SingleCondition[] memory scs,
        string memory partialAcceptScId,
        address changeAddr,
        string memory commentsHash,
        string[] memory filesHash
    ) public view returns (SingleCondition[] memory) {
        for (uint256 i = 0; i < scs.length; i++) {
            if (Strings.equal(scs[i].id, partialAcceptScId)) {
                for (uint256 j = 0; j < scs[i].dynamicFactors.length; j++) {
                    if (Strings.equal(scs[i].dynamicFactors[j].name, "ACCEPT")) {
                        require(scs[i].dynamicFactors[j].changeAble, ErrorCode.SCM_CDN_changeFactorWhenPartialAccept_INVALID_STATUS);
                        require(
                            scs[i].dynamicFactors[j].beginTime <= block.timestamp && scs[i].dynamicFactors[j].endTime >= block.timestamp,
                            ErrorCode.SCM_CDN_changeFactorWhenPartialAccept_INVALID_TIME
                        );
                        require(changeAddr == scs[i].dynamicFactors[j].changeAddr, ErrorCode.SCM_CDN_changeFactorWhenPartialAccept_INVALID_CHANGEADDR);
                        scs[i].dynamicFactors[j].value = "ACCEPT";
                        scs[i].dynamicFactors[j].changeFlag = true;
                        scs[i].dynamicFactors[j].changeAble = false;
                        scs[i].dynamicFactors[j].commentsHash = commentsHash;
                        scs[i].dynamicFactors[j].filesHash = filesHash;
                        return scs;
                    }
                }
                // fallback
                revert(ErrorCode.SCM_CDN_changeFactorWhenPartialAccept_NO_ACCEPT_FACTOR);
            }
        }
        // fallback
        revert(ErrorCode.SCM_CDN_changeFactorWhenPartialAccept_NO_PARTIALSC);
    }

    function checkPartialAcceptSc(SingleCondition[] memory scs, string memory partialAcceptScId, address partialAcceptAddress) public pure {
        require(partialAcceptAddress != address(0), ErrorCode.SCM_CDN_checkPartialAcceptSc_INVALID_ADDRESS);
        require(bytes(partialAcceptScId).length > 0, ErrorCode.SCM_CDN_checkPartialAcceptSc_INVALID_SCID);
        // Iterate through SCS, confirm that the sc corresponding to partialAcceptScId has a type of A1.x or A2.x
        for (uint256 i = 0; i < scs.length; i++) {
            if (Strings.equal(scs[i].id, partialAcceptScId)) {
                if (StringContains.contains(scs[i].conditionType, "A1") || StringContains.contains(scs[i].conditionType, "A2")) {
                    return;
                } else {
                    revert(ErrorCode.SCM_CDN_checkPartialAcceptSc_TYPE_WRONG);
                }
            }
        }
        revert(ErrorCode.SCM_CDN_checkPartialAcceptSc_NO_PARTIALSC);
    }

    function stringToUint(string memory str) private pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < bytes(str).length; i++) {
            require((uint256(uint8(bytes(str)[i])) >= 48) && (uint256(uint8(bytes(str)[i])) <= 57), ErrorCode.SCM_CDN_stringToUint_INVALID_STRING);
            result = result * 10 + (uint256(uint8(bytes(str)[i])) - 48);
        }
        return result;
    }
}
