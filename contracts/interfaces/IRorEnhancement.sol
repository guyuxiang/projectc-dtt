//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IRorEnhancement {
    function getStartLine(string memory sendRefId) external;

    function getSendRorList(string memory sendRefId) external;

    function getRor(uint256 rorId) external;

    function getRorSendInfo(uint256 tokenId) external;

    function send(string memory sendRefId, address dttAddr, uint256 amount, address receipt) external;

    function partialAccept(string memory sendRefId, string memory subSendRefId, uint256 amount) external;

    function settle(string memory sendRefId) external;

    function transferRor(uint256 rorId, uint256 amount) external;
}
