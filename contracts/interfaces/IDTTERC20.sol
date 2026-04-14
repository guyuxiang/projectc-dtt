//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "../dtt/DTTStorage.sol";

interface IDTTERC20 {
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function owner() external view returns (address);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function paused() external view returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function nonces(address owner) external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function getIssuer() external view returns (address);

    function burn(uint256 amount, string memory txID) external;

    function mint(address recipient, uint256 amount, string memory txID) external;

    function verifyCreditDoorTransfer(address verifyAddress) external view;

    function verifyCreditDoorMint(address verifyAddress) external view;

    function verifyDebitDoor(address verifyAddress) external view;
}
