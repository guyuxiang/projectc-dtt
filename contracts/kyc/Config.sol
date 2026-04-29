//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Config is Ownable {
    address public userPermission;
    address public dtt;
    address public encash;
    address public rorEnhancement;
    address public rorMarket;
    address public rorAddress;
    address public idFactoryAddress;
    address public governorAddress;
    bool public simulateTransaction;
    // mapping(address => address) public tokenOwner;
    mapping(address => address) public tokenSuspense;

    event SetSuspense(address token, address suspense);

    modifier onlyGovernor() {
        if (msg.sender != governorAddress) {
            revert("onlyGovernor");
        }
        _;
    }

    constructor(
        address _userPermission,
        address _dtt,
        address _encash,
        address _rorEnhancement,
        address _rorMarket,
        address _rorAddress,
        address _idFactoryAddress,
        address _governor
    ) Ownable(msg.sender) {
        userPermission = _userPermission;
        rorMarket = _rorMarket;
        dtt = _dtt;
        encash = _encash;
        rorEnhancement = _rorEnhancement;
        rorAddress = _rorAddress;
        idFactoryAddress = _idFactoryAddress;
        governorAddress = _governor;
    }

    function setUserPermission(address _userPermission) public onlyGovernor returns (bool) {
        userPermission = _userPermission;
        return true;
    }

    function getSuspense(address token) public view returns (address) {
        return tokenSuspense[token];
    }

    function setSuspense(address token, address suspense) public onlyGovernor returns (bool) {
        require(suspense != address(0), "suspense is zero address");
        tokenSuspense[token] = suspense;
        emit SetSuspense(token, suspense);
        return true;
    }
}
