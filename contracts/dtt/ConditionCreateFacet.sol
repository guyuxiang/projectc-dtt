//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/Constants.sol";
import "../libraries/StringContains.sol";
import "./DTTStorage.sol";
import "../kyc/Permission.sol";
import "../interfaces/IConditionCalculateFacet.sol";

contract ConditionCreateFacet is DTTPermission, DTTStorage {
    function create(SingleCondition[] memory scSet, ConditionSet[] calldata csSet, string memory txTimeScID) public whenNotPaused CallDoor {
        // get txSc
        SingleCondition memory txSc;
        for (uint256 i = 0; i < scSet.length; i++) {
            if (Strings.equal(scSet[i].id, txTimeScID)) {
                txSc = scSet[i];
            }
        }
        // txSc must exist in input scSet
        if (Strings.equal(txSc.id, "")) {
            revert(ErrorCode.SCM_CDN_create_INVALID_TIMESCID);
        }
        // txTimeEnd validation
        (bool txTimeIfExistsTimeRange, , uint256 txTimeEnd) = IConditionCalculateFacet(address(this)).calculateTimeRange(txSc);
        if (txTimeIfExistsTimeRange) {
            require(block.timestamp < txTimeEnd, ErrorCode.SCM_CDN_create_INVALID_TIMEEND);
        }
        // scSet validation
        for (uint256 i = 0; i < scSet.length; i++) {
            require(Strings.equal(ds.singleConditionIndex[scSet[i].id].id, ""), ErrorCode.SCM_CDN_create_ALREADY_EXISTED);
            require(scSet[i].fixFactors.length + scSet[i].dynamicFactors.length > 0, ErrorCode.SCM_CDN_create_EMPTY_FACTORS_ERROR);
            if (StringContains.contains(scSet[i].conditionType, "v2")) {
                require(
                    stringToUint(IConditionCalculateFacet(address(this)).queryFactor(scSet[i].fixFactors, "START_DATE").value) <=
                        stringToUint(IConditionCalculateFacet(address(this)).queryFactor(scSet[i].fixFactors, "END_DATE").value),
                    ErrorCode.SCM_CDN_create_FIXFACTORS_DATE_ERROR
                );
            }
            // fix factors validation
            for (uint256 j = 0; j < scSet[i].fixFactors.length; j++) {
                require(!Strings.equal(scSet[i].fixFactors[j].name, ""), ErrorCode.SCM_CDN_create_FIXFACTORS_NAME_ERROR);
                require(!Strings.equal(scSet[i].fixFactors[j].value, ""), ErrorCode.SCM_CDN_create_FIXFACTORS_VALUE_ERROR);
                require(scSet[i].fixFactors[j].changeAble == false, ErrorCode.SCM_CDN_create_FIXFACTORS_CHANGEBLE_ERROR);
            }
            // dynamic factors validation
            for (uint256 j = 0; j < scSet[i].dynamicFactors.length; j++) {
                require(!Strings.equal(scSet[i].dynamicFactors[j].name, ""), ErrorCode.SCM_CDN_create_DYNAMICFACTORS_NAME_ERROR);
                if (scSet[i].dynamicFactors[j].changeAble) {
                    require(scSet[i].dynamicFactors[j].endTime > block.timestamp, ErrorCode.SCM_CDN_create_DYNAMICFACTORS_ENDTIME_ERROR);
                    if (txTimeIfExistsTimeRange) {
                        require(scSet[i].dynamicFactors[j].beginTime <= txTimeEnd, ErrorCode.SCM_CDN_create_DYNAMICFACTORS_BEGINTIME_ERROR);
                    }
                }
            }
        }
        // csSet validation
        for (uint256 i = 0; i < csSet.length; i++) {
            require(Strings.equal(ds.conditionSetIndex[csSet[i].id].id, ""), ErrorCode.SCM_CDN_create_CSSET_REPEAT);
            require(csSet[i].scIDs.length + csSet[i].csIDs.length > 0, ErrorCode.SCM_CDN_create_SET_EMPTY_ERROR);
            require(csSet[i].join == JoinType.AND || csSet[i].join == JoinType.OR, ErrorCode.SCM_CDN_create_JOIN_ERROR);
        }
        // create sc
        for (uint256 i = 0; i < scSet.length; i++) {
            SingleCondition memory sc = scSet[i];
            string memory scID = scSet[i].id;
            ds.singleConditionIndex[scID].id = sc.id;
            ds.singleConditionIndex[scID].conditionType = sc.conditionType;
            ds.singleConditionIndex[scID].description = sc.description;
            for (uint256 j = 0; j < sc.fixFactors.length; j++) {
                ds.singleConditionIndex[scID].fixFactors.push(sc.fixFactors[j]);
            }
            for (uint256 k = 0; k < sc.dynamicFactors.length; k++) {
                ds.singleConditionIndex[scID].dynamicFactors.push(sc.dynamicFactors[k]);
            }
        }
        // create cs
        for (uint256 i = 0; i < csSet.length; i++) {
            ds.conditionSetIndex[csSet[i].id] = csSet[i];
        }
    }

    function copy(string memory csID, string memory businessID, string memory txTimeScID) public whenNotPaused CallDoor returns (SingleCondition[] memory, ConditionSet[] memory) {
        ConditionSet memory cs = ds.conditionSetIndex[csID];
        uint256 scSetLength = ds.scArray.length;
        for (uint256 i = 0; i < cs.scIDs.length; i++) {
            SingleCondition memory sc = ds.singleConditionIndex[cs.scIDs[i]];
            ds.scMap[cs.scIDs[i]].id = sc.id;
            ds.scMap[cs.scIDs[i]].conditionType = sc.conditionType;
            ds.scMap[cs.scIDs[i]].description = sc.description;
            for (uint256 j = 0; j < sc.fixFactors.length; j++) {
                ds.scMap[cs.scIDs[i]].fixFactors.push(sc.fixFactors[j]);
            }
            for (uint256 k = 0; k < sc.dynamicFactors.length; k++) {
                ds.scMap[cs.scIDs[i]].dynamicFactors.push(sc.dynamicFactors[k]);
            }
            ds.scArray.push(ds.scMap[cs.scIDs[i]]);
            delete ds.scMap[cs.scIDs[i]];
            ds.scArray[scSetLength + i].id = string(abi.encodePacked(cs.scIDs[i], "_", businessID));
            cs.scIDs[i] = string(abi.encodePacked(cs.scIDs[i], "_", businessID));
        }
        for (uint256 i = 0; i < cs.csIDs.length; i++) {
            copy(cs.csIDs[i], businessID, txTimeScID);
            cs.csIDs[i] = string(abi.encodePacked(cs.csIDs[i], "_", businessID));
        }
        cs.id = string(abi.encodePacked(cs.id, "_", businessID));
        ds.csArray.push(cs);
        bool existTxTimeSc = false;
        string memory txID = string(abi.encodePacked(txTimeScID, "_", businessID));
        for (uint256 i = 0; i < ds.scArray.length; i++) {
            if (Strings.equal(ds.scArray[i].id, txID)) {
                existTxTimeSc = true;
            }
        }
        if (!existTxTimeSc) {
            SingleCondition memory sc = ds.singleConditionIndex[txTimeScID];
            ds.scMap[txID].id = txID;
            ds.scMap[txID].conditionType = sc.conditionType;
            ds.scMap[txID].description = sc.description;
            for (uint256 j = 0; j < sc.fixFactors.length; j++) {
                ds.scMap[txID].fixFactors.push(sc.fixFactors[j]);
            }
            for (uint256 k = 0; k < sc.dynamicFactors.length; k++) {
                ds.scMap[txID].dynamicFactors.push(sc.dynamicFactors[k]);
            }
            ds.scArray.push(ds.scMap[txID]);
            delete ds.scMap[txID];
        }
        return (ds.scArray, ds.csArray);
    }

    function deleteArray() public whenNotPaused CallDoor {
        delete ds.scArray;
        delete ds.csArray;
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
