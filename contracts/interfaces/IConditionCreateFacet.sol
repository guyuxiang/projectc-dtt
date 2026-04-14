//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "../dtt/DTTStorage.sol";

interface IConditionCreateFacet {
    function create(
        DTTStorage.SingleCondition[] memory scSet,
        DTTStorage.ConditionSet[] calldata csSet,
        string memory txTimeScID
    ) external;
    function copy(string memory csID, string memory businessID, string memory txTimeScID)
        external
        returns (DTTStorage.SingleCondition[] memory, DTTStorage.ConditionSet[] memory);
    function deleteArray() external;
}
