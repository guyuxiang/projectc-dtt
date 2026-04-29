//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../kyc/Config.sol";
import "../libraries/Constants.sol";
import "../dtt/DTTStorage.sol";
import "./RorEnhancement.sol";
import "../utils/TransactionIDFactory.sol";
import "../interfaces/ITradeStatusFacet.sol";
import "../interfaces/IDTTERC20.sol";
import "../interfaces/IRORERC721.sol";

contract RorMarket is OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    enum PartialType {
        FULL,
        PARTIAL
    }
    enum TransferStatus {
        INIT,
        ACCEPTED,
        REJECTED,
        EXPIRED,
        ROR_BURN
    }
    enum ConsiderationType {
        NONE,
        FT
    }

    struct RorTransfer {
        string refId;
        address transferer;
        address transferee;
        uint256 rorId;
        uint256 createTime;
        TransferStatus status;
        ConsiderationType considerationType;
        string considerationSelfConfig;
        // 新增
        address considerationDttAddr;
        uint256 considerationDttAmount;
    }
    // 业务ID

    mapping(string => RorTransfer) public rorTransferIndex;
    mapping(uint256 => string) public rorToTransferRefIdIndex;

    // 未完成的业务ID列表 - 使用 EnumerableSet 管理
    EnumerableSet.Bytes32Set private pendingRefIdsSet;

    event RorTransferStatusChange(
        string transferRefId,
        address rorAddress,
        uint256 rorId,
        address from,
        address to,
        ConsiderationType considerationType,
        address considerationAddress,
        uint256 considerationValue,
        TransferStatus transferStatus,
        string extension
    );

    event setConfigEvent(address configContract);

    address idFactoryAddress;
    address rorEnhancementAddress;
    address rorAddress;

    Config public config;

    function _permitIfNeeded(IDTTERC20 token, address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) private {
        if (token.allowance(owner, address(this)) < amount) {
            token.permit(owner, address(this), amount, deadline, v, r, s);
        }
    }

    function initialize(address _idFactoryAddr, address _rorEnhancement, address _rorAddress) public initializer {
        idFactoryAddress = _idFactoryAddr;
        rorEnhancementAddress = _rorEnhancement;
        rorAddress = _rorAddress;
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

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

    bool public paused;

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

    //难点：erc721 permit实现,erc20 permit，参数需要2套r，s，v？？？
    function transferRor(
        uint256 rorId,
        address transferee,
        address considerationDttAddr,
        uint256 considerationAmount,
        ConsiderationType considerationType,
        string memory considerationSelfConfig,
        string memory extension,
        PartialType partialType,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused {
        IRORERC721 ror = IRORERC721(rorAddress);
        RorEnhancement rorEnhancement = RorEnhancement(rorEnhancementAddress);
        (string memory sendRefId, address rorDttAddress) = rorEnhancement.getRorSendInfo(rorId);
        DTTStorage.TradeStatus sendStatus = ITradeStatusFacet(config.dtt()).tradeStatus(sendRefId);

        // todo：错误码
        require(ror.ownerOfnotRequireOwned(rorId) == msg.sender, ErrorCode.SCM_RorMarket_transferRor_CALLER_ERROR);
        require(
            sendStatus == DTTStorage.TradeStatus.Unrealised || sendStatus == DTTStorage.TradeStatus.Confirmed,
            ErrorCode.SCM_RorMarket_transferRor_TradeStatus
        );
        ror.permit(address(this), rorId, deadline, v, r, s);
        // todo
        if (partialType == PartialType.PARTIAL) {
            rorId = rorEnhancement.transferRor(rorId, amount);
        } else {
            try ror.transferFrom(msg.sender, address(this), rorId) {}
            catch Error(string memory reason) {
                revert(reason);
            }
        }
        string memory businessId =
            TransactionIDFactory(idFactoryAddress).generateTransactionID(IDTTERC20(rorDttAddress).symbol(), "TRSF");
        rorTransferIndex[businessId] = RorTransfer(
            businessId,
            msg.sender,
            transferee,
            rorId,
            block.timestamp,
            TransferStatus.INIT,
            considerationType,
            considerationSelfConfig,
            // 新增
            considerationDttAddr,
            considerationAmount
        );
        rorToTransferRefIdIndex[rorId] = businessId;
        pendingRefIdsSet.add(bytes32(bytes(businessId)));
        emit RorTransferStatusChange(
            businessId,
            rorAddress,
            rorId,
            msg.sender,
            transferee,
            considerationType,
            considerationDttAddr,
            considerationAmount,
            TransferStatus.INIT,
            extension
        );
    }

    function transfereeAccept(string memory transferRefId, string memory extension) public whenNotPaused {
        RorTransfer memory rorTransfer = rorTransferIndex[transferRefId];
        require(rorTransfer.status == TransferStatus.INIT, ErrorCode.SCM_RorMarket_transferAction_TRANS_NONINIT);
        require(
            rorTransfer.considerationType == ConsiderationType.NONE,
            ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_ConsiderationType
        );
        require(msg.sender == rorTransfer.transferee, ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_Caller_Error);
        require(
            block.timestamp < getExpireTime(rorTransfer.createTime),
            ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_CreateTime_Error
        );
        IRORERC721 ror = IRORERC721(rorAddress);
        try ror.transferFrom(address(this), rorTransfer.transferee, rorTransfer.rorId) {}
        catch Error(string memory reason) {
            revert(reason);
        }
        rorTransferIndex[transferRefId].status = TransferStatus.ACCEPTED;
        pendingRefIdsSet.remove(bytes32(bytes(transferRefId)));
        emit RorTransferStatusChange(
            transferRefId,
            rorAddress,
            rorTransfer.rorId,
            rorTransfer.transferer,
            rorTransfer.transferee,
            rorTransfer.considerationType,
            rorTransfer.considerationDttAddr,
            rorTransfer.considerationDttAmount,
            TransferStatus.ACCEPTED,
            extension
        );
    }

    function transfereeAcceptWithFN(
        string memory transferRefId,
        string memory extension,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public whenNotPaused {
        RorTransfer memory rorTransfer = rorTransferIndex[transferRefId];
        require(rorTransfer.status == TransferStatus.INIT, ErrorCode.SCM_RorMarket_transferAction_TRANS_NONINIT);
        require(
            rorTransfer.considerationType == ConsiderationType.FT,
            ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_ConsiderationType
        );
        require(msg.sender == rorTransfer.transferee, ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_Caller_Error);
        require(
            block.timestamp < getExpireTime(rorTransfer.createTime),
            ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_CreateTime_Error
        );
        IDTTERC20 erc20Token = IDTTERC20(rorTransfer.considerationDttAddr);
        // dtt到ror转让方
        _permitIfNeeded(erc20Token, msg.sender, rorTransfer.considerationDttAmount, deadline, v, r, s);
        try erc20Token.transferFrom(rorTransfer.transferee, rorTransfer.transferer, rorTransfer.considerationDttAmount)
        returns (bool success) {
            require(success, ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_Transfer_Error);
        } catch Error(string memory reason) {
            if (Strings.equal(reason, "ERC20: transfer amount exceeds balance")) {
                revert(ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_Amount_Error);
            } else {
                revert(reason);
            }
        }

        IRORERC721 ror = IRORERC721(rorAddress);
        try ror.transferFrom(address(this), rorTransfer.transferee, rorTransfer.rorId) {}
        catch Error(string memory reason) {
            revert(reason);
        }

        rorTransferIndex[transferRefId].status = TransferStatus.ACCEPTED;
        pendingRefIdsSet.remove(bytes32(bytes(transferRefId)));
        emit RorTransferStatusChange(
            transferRefId,
            rorAddress,
            rorTransfer.rorId,
            rorTransfer.transferer,
            rorTransfer.transferee,
            rorTransfer.considerationType,
            rorTransfer.considerationDttAddr,
            rorTransfer.considerationDttAmount,
            TransferStatus.ACCEPTED,
            extension
        );
    }

    function transfereeReject(string memory transferRefId, string memory extension) public whenNotPaused {
        RorTransfer memory rorTransfer = rorTransferIndex[transferRefId];
        require(rorTransfer.status == TransferStatus.INIT, ErrorCode.SCM_RorMarket_transferAction_TRANS_NONINIT);
        require(msg.sender == rorTransfer.transferee, ErrorCode.SCM_RorMarket_transfereeReject_Caller_Error);
        require(
            block.timestamp < getExpireTime(rorTransfer.createTime),
            ErrorCode.SCM_RorMarket_transfereeReject_CreateTime_Error
        );

        IRORERC721 ror = IRORERC721(rorAddress);
        try ror.transferFromWithoutUserPermission(address(this), rorTransfer.transferer, rorTransfer.rorId) {}
        catch Error(string memory reason) {
            revert(reason);
        }
        rorTransferIndex[transferRefId].status = TransferStatus.REJECTED;
        pendingRefIdsSet.remove(bytes32(bytes(transferRefId)));
        emit RorTransferStatusChange(
            transferRefId,
            rorAddress,
            rorTransfer.rorId,
            rorTransfer.transferer,
            rorTransfer.transferee,
            rorTransfer.considerationType,
            rorTransfer.considerationDttAddr,
            rorTransfer.considerationDttAmount,
            TransferStatus.REJECTED,
            extension
        );
    }

    function expire(string memory transferRefId) public whenNotPaused {
        RorTransfer memory rorTransfer = rorTransferIndex[transferRefId];
        if (rorTransfer.status == TransferStatus.EXPIRED) {
            return;
        }
        require(rorTransfer.status == TransferStatus.INIT, ErrorCode.SCM_RorMarket_transferAction_TRANS_NONINIT);
        require(
            block.timestamp >= getExpireTime(rorTransfer.createTime), ErrorCode.SCM_RorMarket_expire_CreateTime_Error
        );

        IRORERC721 ror = IRORERC721(rorAddress);
        try ror.transferFromWithoutUserPermission(address(this), rorTransfer.transferer, rorTransfer.rorId) {}
        catch Error(string memory reason) {
            revert(reason);
        }
        rorTransferIndex[transferRefId].status = TransferStatus.EXPIRED;
        pendingRefIdsSet.remove(bytes32(bytes(transferRefId)));
        emit RorTransferStatusChange(
            transferRefId,
            rorAddress,
            rorTransfer.rorId,
            rorTransfer.transferer,
            rorTransfer.transferee,
            rorTransfer.considerationType,
            rorTransfer.considerationDttAddr,
            rorTransfer.considerationDttAmount,
            TransferStatus.EXPIRED,
            ""
        );
    }

    function batchExpire(string[] memory transferRefIds) public whenNotPaused {
        for (uint256 i = 0; i < transferRefIds.length; i++) {
            expire(transferRefIds[i]);
        }
    }

    function settleReject(uint256 rorId) public whenNotPaused {
        require(msg.sender == rorEnhancementAddress, ErrorCode.SCM_RorMarket_settleReject_CALLER_ERROR);
        if (Strings.equal(rorToTransferRefIdIndex[rorId], "")) {
            return;
        }
        RorTransfer memory rorTransfer = rorTransferIndex[rorToTransferRefIdIndex[rorId]];
        if (rorTransfer.status != TransferStatus.INIT) {
            return;
        }
        IRORERC721 ror = IRORERC721(rorAddress);
        try ror.transferFromWithoutUserPermission(address(this), rorTransfer.transferer, rorTransfer.rorId) {}
        catch Error(string memory reason) {
            revert(reason);
        }
        rorTransferIndex[rorToTransferRefIdIndex[rorId]].status = TransferStatus.ROR_BURN;
        pendingRefIdsSet.remove(bytes32(bytes(rorToTransferRefIdIndex[rorId])));
        emit RorTransferStatusChange(
            rorToTransferRefIdIndex[rorId],
            rorAddress,
            rorTransfer.rorId,
            rorTransfer.transferer,
            rorTransfer.transferee,
            rorTransfer.considerationType,
            rorTransfer.considerationDttAddr,
            rorTransfer.considerationDttAmount,
            TransferStatus.ROR_BURN,
            ""
        );
    }

    function getExpireTime(uint256 createTime) private pure returns (uint256) {
        return createTime + 86400;
    }

    function verifySettleReject(uint256 rorId) public view whenNotPaused returns (address) {
        address owner = IRORERC721(rorAddress).ownerOf(rorId);
        if (Strings.equal(rorToTransferRefIdIndex[rorId], "")) {
            return owner;
        }
        RorTransfer memory rorTransfer = rorTransferIndex[rorToTransferRefIdIndex[rorId]];
        if (rorTransfer.status != TransferStatus.INIT) {
            return owner;
        }
        return rorTransfer.transferer;
    }

    function verifyTransferRor(
        uint256 rorId,
        address transferee,
        address considerationDttAddr,
        uint256 considerationAmount,
        ConsiderationType considerationType,
        string memory considerationSelfConfig,
        string memory extension,
        PartialType partialType,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view whenNotPaused {
        IRORERC721 ror = IRORERC721(rorAddress);
        RorEnhancement rorEnhancement = RorEnhancement(rorEnhancementAddress);
        (string memory sendRefId,) = rorEnhancement.getRorSendInfo(rorId);
        DTTStorage.TradeStatus sendStatus = ITradeStatusFacet(config.dtt()).tradeStatus(sendRefId);

        // todo：错误码
        require(ror.ownerOfnotRequireOwned(rorId) == msg.sender, ErrorCode.SCM_RorMarket_transferRor_CALLER_ERROR);
        require(
            sendStatus == DTTStorage.TradeStatus.Unrealised || sendStatus == DTTStorage.TradeStatus.Confirmed,
            ErrorCode.SCM_RorMarket_transferRor_TradeStatus
        );
        // todo
        if (partialType == PartialType.PARTIAL) {
            rorEnhancement.verifyTransferRor(rorId, amount);
        } else {
            ror.verifyDebitDoorNFT(msg.sender);
            ror.verifyCreditDoorNFTTransfer(address(this));
        }
    }

    function verifyTransfereeAcceptWithFN(
        string memory transferRefId,
        string memory extension,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public view whenNotPaused {
        RorTransfer memory rorTransfer = rorTransferIndex[transferRefId];
        require(rorTransfer.status == TransferStatus.INIT, ErrorCode.SCM_RorMarket_transferAction_TRANS_NONINIT);
        require(
            rorTransfer.considerationType == ConsiderationType.FT,
            ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_ConsiderationType
        );
        require(msg.sender == rorTransfer.transferee, ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_Caller_Error);
        require(
            block.timestamp < getExpireTime(rorTransfer.createTime),
            ErrorCode.SCM_RorMarket_transfereeAcceptWithFN_CreateTime_Error
        );
        IDTTERC20 erc20Token = IDTTERC20(rorTransfer.considerationDttAddr);
        {
            require(
                erc20Token.balanceOf(rorTransfer.transferee) >= rorTransfer.considerationDttAmount,
                ErrorCode.SCM_DTT_erc20Transfer_AMOUNT_WRONG
            );
            erc20Token.verifyDebitDoor(rorTransfer.transferee);
            erc20Token.verifyDebitDoor(rorTransfer.transferer);
        }
        {
            IRORERC721 ror = IRORERC721(rorAddress);
            require(ror.ownerOf(rorTransfer.rorId) == address(this), "the owner is not the contract");
            ror.ownerOf(rorTransfer.rorId);
            ror.verifyDebitDoorNFT(address(this));
            ror.verifyCreditDoorNFTTransfer(rorTransfer.transferee);
        }
    }

    function getPendingRefIds() external view returns (string[] memory) {
        bytes32[] memory data = pendingRefIdsSet.values();
        string[] memory result = new string[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            result[i] = bytes32ToString(data[i]);
        }
        return result;
    }

    function bytes32ToString(bytes32 data) public pure returns (string memory) {
        uint256 len = 0;
        while (len < 32 && data[len] != 0) {
            len++;
        }
        bytes memory bytesArray = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            bytesArray[i] = data[i];
        }
        return string(bytesArray);
    }
}
