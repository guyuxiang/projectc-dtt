//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IConditionActionFacet {
    function conditionAccept(
        string memory businessId,
        string memory scId,
        string memory commentsHash,
        string[] memory filesHash
    ) external;
    function conditionReject(
        string memory businessId,
        string memory scId,
        string memory commentsHash,
        string[] memory filesHash
    ) external;
}
