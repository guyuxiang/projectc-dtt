//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../dtt/DTTStorage.sol";

interface IConditionCalculateFacet {
    function queryCSStatus(string memory csID) external view returns (DTTStorage.ConditionStatus res);
    function querySCStatus(string memory scID) external view returns (DTTStorage.ConditionStatus);
    function dateNotSet(string memory scID) external view returns (bool);
    function timeRangeValidate(string memory txTimeScID, string[] memory actionScIDs) external view;
    function refactorCsId(DTTStorage.ConditionSet memory cs, string memory addContent)
        external
        returns (DTTStorage.ConditionSet memory);
    function changeFactorWhenPartialAccept(
        DTTStorage.SingleCondition[] memory scs,
        string memory partialAcceptScId,
        address changeAddr,
        string memory commentsHash,
        string[] memory filesHash
    ) external returns (DTTStorage.SingleCondition[] memory);
    function checkPartialAcceptSc(
        DTTStorage.SingleCondition[] memory scs,
        string memory partialAcceptScId,
        address partialAcceptAddress
    ) external;
    function calculateTimeRange(DTTStorage.SingleCondition memory singleCondition)
        external
        returns (bool, uint256, uint256);
    function queryFactorIndex(DTTStorage.ConditionFactor[] memory factors, string memory name)
        external
        returns (uint256);
    function queryFactor(DTTStorage.ConditionFactor[] memory factors, string memory name)
        external
        returns (DTTStorage.ConditionFactor memory res);
}
