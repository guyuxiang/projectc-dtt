//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "../libraries/Constants.sol";

contract UserPermission is AccessControlEnumerable {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 public constant OPERATOR = keccak256("OPERATOR");

    using Strings for uint256;
    using Strings for address;

    mapping(address => mapping(address => uint256)) public userPerMap;

    event PermissionSet(address issuerAddress, address userAddress, uint256 userPermission, string comments);
    event PermissionSetForToken(address tokenAddres, address issuerAddress, address userAddress, uint256 userPermission, string comments);

    // DEFAULT_ADMIN_ROLE是超级管理员，平时不参与具体业务角色的授权工作，OPERATOR是管理员，负责日常授权工作，但最终所有角色都受DEFAULT_ADMIN_ROLE管理
    constructor(address operator, address issuer, address[] memory _permissionList) {
        // Grant the contract deployer the default admin role, allowing them
        // to grant and revoke any roles.
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR, operator);

        for (uint256 i = 0; i < _permissionList.length; i++) {
            userPerMap[issuer][_permissionList[i]] = 9999999;
            emit PermissionSet(issuer, _permissionList[i], 9999999, "");
        }
    }

    function setPermission(address issuerAddress, address userAddress, uint256 userPermission, string memory comments)
        public
        returns (bool)
    {
        require(hasRole(ISSUER_ROLE, msg.sender), ErrorCode.SCM_UserPermission_setPermission_permission_denied);
        require(msg.sender == issuerAddress, ErrorCode.SCM_UserPermission_setPermission_OnlyIssuerOperate);
        userPerMap[issuerAddress][userAddress] = userPermission;
        emit PermissionSet(issuerAddress, userAddress, userPermission, comments);
        return true;
    }

    // TODO setPermissionForToken

    function getPermission(address issuerAddress, address userAddress) public view returns (uint256) {
        return userPerMap[issuerAddress][userAddress];
    }

    function grantRoles(bytes32 role, address account) public onlyRole(OPERATOR) {
        _grantRole(role, account);
    }
}
