//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "../utils/TransactionIDFactory.sol";
import "../interfaces/IDTTERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../kyc/UserPermission.sol";
import "../kyc/Permission.sol";
import "../kyc/Config.sol";
import "../libraries/Constants.sol";

contract Encash is EncashPermission, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    function initialize(address IDFactoryAddr) public initializer {
        IDFactory = TransactionIDFactory(IDFactoryAddr);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    TransactionIDFactory IDFactory;

    string constant ENCASH_INIT = "INIT";
    string constant ENCASH_ACCEPT = "ACCEPT";
    string constant ENCASH_REJECT = "REJECT";

    struct EncashInfo {
        address tokenAddress;
        address encasher;
        uint256 value;
        string state;
    }

    mapping(string => EncashInfo) public encashInfos;

    Config public config;

    bool public paused;

    event setConfigEvent(address configContract);

    function setConfig(address _config) public {
        if (address(config) == address(0)) {
            if (msg.sender != Config(_config).governorAddress()) {
                revert("onlyGovernor");
            }
        } else {
            if (msg.sender != config.governorAddress()) {
                revert("onlyGovernor");
            }
        }
        config = Config(_config);
        emit setConfigEvent(_config);
    }

    function pause() public virtual onlyGovernor {
        paused = true;
    }

    function unpause() public virtual onlyGovernor {
        paused = false;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert("Pausable: paused");
        }
        _;
    }

    modifier onlyGovernor() {
        if (msg.sender != config.governorAddress()) {
            revert("onlyGovernor");
        }
        _;
    }

    event EncashEvent(
        string indexed businessIdHash,
        string businessId,
        address tokenAddress,
        address encasher,
        uint256 value,
        string state,
        string extension
    );

    event EncashSuspenseAccountReceived(
        address tokenContractAddress,
        string businessID,
        uint256 amount,
        address receiverAddress,
        uint256 receiverPermission,
        string reason
    );

    function encash(
        address tokenAddress,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string memory extension
    )
        public
        whenNotPaused
        EncashDoor(UserPermission(config.userPermission()).getPermission(IDTTERC20(tokenAddress).getIssuer(), msg.sender))
    {
        IDTTERC20 token = IDTTERC20(tokenAddress);
        token.permit(msg.sender, address(this), value, deadline, v, r, s);
        string memory businessId = IDFactory.generateTransactionID(token.symbol(), "ENCASH");
        try token.transferFrom(msg.sender, address(this), value) {
            encashInfos[businessId] = EncashInfo(tokenAddress, msg.sender, value, ENCASH_INIT);
            emit EncashEvent(businessId, businessId, tokenAddress, msg.sender, value, ENCASH_INIT, extension);
        } catch Error(string memory reason) {
            // If the call is unsuccessful
            if (Strings.equal(reason, ErrorCode.SCM_Permission_Token_Transfer_ERROR)) {
                revert(ErrorCode.SCM_RealisedTokenEncash_encash_EncashContractPermissionError);
            } else {
                revert(reason);
            }
        }
    }

    function accept(string memory businessId, string memory extension)
        public
        whenNotPaused
        EncashDoor(
            UserPermission(config.userPermission()).getPermission(
                IDTTERC20(encashInfos[businessId].tokenAddress).getIssuer(), encashInfos[businessId].encasher
            )
        )
    {
        EncashInfo memory encashInfo = encashInfos[businessId];
        require(encashInfo.tokenAddress != address(0), ErrorCode.SCM_RealisedTokenEncash_accept_EncashInfoNotFound);
        require(
            Strings.equal(encashInfo.state, ENCASH_INIT),
            ErrorCode.SCM_RealisedTokenEncash_accept_EncashInfoNotSupportAccept
        );
        IDTTERC20 token = IDTTERC20(encashInfo.tokenAddress);
        require(msg.sender == token.getIssuer(), ErrorCode.SCM_RealisedTokenEncash_accept_OnlyIssuerOperate);
        token.burn(encashInfo.value, businessId);
        encashInfos[businessId].state = ENCASH_ACCEPT;
        emit EncashEvent(
            businessId,
            businessId,
            encashInfo.tokenAddress,
            encashInfo.encasher,
            encashInfo.value,
            ENCASH_ACCEPT,
            extension
        );
    }

    function reject(string memory businessId, string memory extension) public whenNotPaused {
        EncashInfo memory encashInfo = encashInfos[businessId];
        require(encashInfo.tokenAddress != address(0), ErrorCode.SCM_RealisedTokenEncash_reject_EncashInfoNotFound);
        require(
            Strings.equal(encashInfo.state, ENCASH_INIT),
            ErrorCode.SCM_RealisedTokenEncash_reject_EncashInfoNotSupportReject
        );
        IDTTERC20 token = IDTTERC20(encashInfo.tokenAddress);
        require(msg.sender == token.getIssuer(), ErrorCode.SCM_RealisedTokenEncash_reject_OnlyIssuerOperate);

        try token.transfer(encashInfo.encasher, encashInfo.value) {}
        catch Error(string memory reason) {
            // If the call is unsuccessful
            if (Strings.equal(reason, ErrorCode.SCM_Permission_Token_Transfer_ERROR)) {
                require(
                    token.transfer(config.getSuspense(encashInfo.tokenAddress), encashInfo.value),
                    ErrorCode.SCM_RealisedTokenEncash_reject_TransferSuspenseFailed
                );
                emit EncashSuspenseAccountReceived(
                    encashInfo.tokenAddress,
                    businessId,
                    encashInfo.value,
                    encashInfo.encasher,
                    UserPermission(config.userPermission()).getPermission(token.getIssuer(), encashInfo.encasher),
                    "encash"
                );
            } else if (Strings.equal(reason, ErrorCode.SCM_Permission_Token_Debit_ERROR)) {
                revert(ErrorCode.SCM_RealisedTokenEncash_reject_EncashContractPermissionError);
            } else {
                revert(reason);
            }
        }
        encashInfos[businessId].state = ENCASH_REJECT;
        emit EncashEvent(
            businessId,
            businessId,
            encashInfo.tokenAddress,
            encashInfo.encasher,
            encashInfo.value,
            ENCASH_REJECT,
            extension
        );
    }

    function verifyEncash(
        address tokenAddress,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        string memory extension
    )
        public
        view
        whenNotPaused
        EncashDoor(UserPermission(config.userPermission()).getPermission(IDTTERC20(tokenAddress).getIssuer(), msg.sender))
    {
        IDTTERC20 token = IDTTERC20(tokenAddress);
        require(token.balanceOf(msg.sender) >= value, ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
        token.verifyDebitDoor(msg.sender);
        token.verifyCreditDoorTransfer(address(this));
    }
}
