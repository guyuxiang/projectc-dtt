//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../dtt/DTTStorage.sol";

interface ISendFacet {
    function sendRealisedToken(
        address to,
        address erc20Address,
        uint256 amount,
        DTTStorage.SingleCondition[] memory scs,
        DTTStorage.ConditionSet[] memory css,
        string memory timeScId, // Condition ID for transaction time
        string memory csId, // Condition set ID for transaction operations
        bool partialAcceptEnable,
        address partialAcceptAddress,
        string memory partialAcceptScId,
        uint256 deadline,
        uint256 guaranteeAmount,
        string memory extension,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function conditionPartialAccept(
        string memory businessId,
        uint256 amount,
        uint256 guaranteeAmount,
        string memory commentsHash,
        string[] memory filesHash
    ) external;

    function setConfig(address _config) external;
}
