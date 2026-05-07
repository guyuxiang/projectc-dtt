//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "../utils/TransactionIDFactory.sol";
import "../interfaces/IDTTERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../kyc/UserPermission.sol";
import "../kyc/Permission.sol";
import "../kyc/Config.sol";
import "../libraries/Constants.sol";

contract Encash is EncashPermission, Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

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

    function _permitIfNeeded(IDTTERC20 token, address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) private {
        if (token.allowance(owner, address(this)) < amount) {
            token.permit(owner, address(this), amount, deadline, v, r, s);
        }
    }

    function _encashRecipient(address tokenAddress, address recipient, uint256 amount, string memory businessId) private returns (address) {
        IDTTERC20 token = IDTTERC20(tokenAddress);
        uint256 permission = UserPermission(config.userPermission()).getPermission(token.getIssuer(), recipient);
        if (permission % 10 <= 1) {
            emit EncashSuspenseAccountReceived(
                tokenAddress,
                businessId,
                amount,
                recipient,
                permission,
                "encash"
            );
            return config.getSuspense(tokenAddress);
        }
        return recipient;
    }

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
        require(token.balanceOf(msg.sender) >= value, ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
        _permitIfNeeded(token, msg.sender, value, deadline, v, r, s);
        string memory businessId = IDFactory.generateTransactionID(token.symbol(), "ENCASH");
        // Encash now exposes the underlying token/SafeERC20 revert instead of remapping to legacy ENC codes.
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), value);
        encashInfos[businessId] = EncashInfo(tokenAddress, msg.sender, value, ENCASH_INIT);
        emit EncashEvent(businessId, businessId, tokenAddress, msg.sender, value, ENCASH_INIT, extension);
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
        require(token.balanceOf(address(this)) >= encashInfo.value, ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG);
        address dest = _encashRecipient(encashInfo.tokenAddress, encashInfo.encasher, encashInfo.value, businessId);
        // Reject follows the same rule so both encash directions share one transfer/error surface.
        IERC20(encashInfo.tokenAddress).safeTransfer(dest, encashInfo.value);
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
