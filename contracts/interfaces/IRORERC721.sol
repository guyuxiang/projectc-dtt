//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../dtt/DTTStorage.sol";

interface IRORERC721 {
    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function transferFromWithoutUserPermission(address from, address to, uint256 tokenId) external;

    function mint(address receipt) external returns (uint256);

    function burn(uint256 tokenId) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function ownerOfnotRequireOwned(uint256 tokenId) external view returns (address owner);

    function verifyCreditDoorNFTTransfer(address verifyAddress) external view;

    function verifyDebitDoorNFT(address verifyAddress) external view;

    function verifyCreditDoorNFTMint(address verifyAddress) external view;

    function setTokenProperties(
        uint256 tokenId,
        string memory refId,
        string memory currency,
        address ERC20Address,
        uint256 amount,
        uint256 parentTokenId,
        string memory executionDate,
        string memory comment
    ) external;
}
