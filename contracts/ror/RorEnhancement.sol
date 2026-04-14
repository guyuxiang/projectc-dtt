//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../libraries/Constants.sol";
import "../kyc/Config.sol";
import "./RorMarket.sol";
import "../interfaces/IRORERC721.sol";
import "../interfaces/IDTTERC20.sol";

contract RorEnhancement is OwnableUpgradeable, UUPSUpgradeable {
    struct RegisterRorInfo {
        uint256 id;
        string sendRefId;
        address dttAddress;
        uint256 amount;
        uint256 parentId;
        bool toPay;
        uint256 startAmountLine;
        uint256 endAmountLine;
        uint256 weight;
    }

    struct SettleInfo {
        uint256 id;
        address owner;
        address dttAddress;
        uint256 amount;
    }

    event RorSplit(
        address rorAddress,
        uint256 rorId,
        address rorOwner,
        uint256 rorValue,
        uint256 splitRorId,
        uint256 splitRorValue,
        uint256 remainRorId,
        uint256 remainRorValue,
        SplitType splitType
    );

    event RorSendMint(
        address rorAddress,
        uint256 rorId,
        address owner,
        uint256 value,
        uint256 startAmountLine,
        uint256 endAmountLine,
        string sendRefId
    );

    event RorSendRelationChange(address rorAddress, uint256 rorId, string oldSendRefId, string newSendRefId);

    event setConfigEvent(address configContract);

    address rorAddress;

    Config public config;

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

    // ror index
    mapping(uint256 => RegisterRorInfo) RorIndex;
    // mapping (address => mapping())
    // sendRefId reletion ror list
    mapping(string => RegisterRorInfo[]) sendRefIdIndex;

    // sendRefId start amount line
    mapping(string => uint256) sendRefIdStartAmountLine;

    enum SplitType {
        PARTIAL_ACCEPT,
        PARTIAL_TRANSFER
    }

    function initialize(address _rorAddress) public initializer {
        rorAddress = _rorAddress;
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

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

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function getStartLine(string memory sendRefId) public view returns (uint256) {
        return sendRefIdStartAmountLine[sendRefId];
    }

    function getSendRorList(string memory sendRefId) public view returns (RegisterRorInfo[] memory) {
        return sendRefIdIndex[sendRefId];
    }

    function getRor(uint256 rorId) public view returns (RegisterRorInfo memory) {
        return RorIndex[rorId];
    }

    function getRorSendInfo(uint256 tokenId) public view returns (string memory, address) {
        return (RorIndex[tokenId].sendRefId, RorIndex[tokenId].dttAddress);
    }

    function send(string memory sendRefId, address dttAddr, uint256 amount, address receipt)
        public
        whenNotPaused
        returns (uint256)
    {
        require(msg.sender == config.dtt(), ErrorCode.SCM_RorEnhancement_send_CALLER_ERROR);
        uint256 tokenId = _mint(receipt, sendRefId, dttAddr, amount, 0);
        RegisterRorInfo memory ror = RegisterRorInfo(tokenId, sendRefId, dttAddr, amount, tokenId, true, 0, amount, 1);
        emit RorSendMint(rorAddress, tokenId, receipt, amount, 0, amount, sendRefId);
        RorIndex[tokenId] = ror;
        sendRefIdIndex[sendRefId].push(ror);
        return tokenId;
    }

    function partialAccept(string memory sendRefId, string memory subSendRefId, uint256 amount) public whenNotPaused {
        require(msg.sender == config.dtt(), ErrorCode.SCM_RorEnhancement_partialAccept_CALLER_ERROR);
        uint256 oldSendRefIdStartAmountLine = sendRefIdStartAmountLine[sendRefId];
        uint256 newSendRefIdStartAmountLine = oldSendRefIdStartAmountLine + amount;
        uint256 splitAmountLine = 0;
        sendRefIdStartAmountLine[subSendRefId] = oldSendRefIdStartAmountLine;
        sendRefIdStartAmountLine[sendRefId] = newSendRefIdStartAmountLine;
        for (uint256 i = 0; i < sendRefIdIndex[sendRefId].length; i++) {
            if (!sendRefIdIndex[sendRefId][i].toPay) {
                continue;
            }
            if (
                sendRefIdIndex[sendRefId][i].startAmountLine >= oldSendRefIdStartAmountLine
                    && sendRefIdIndex[sendRefId][i].endAmountLine <= newSendRefIdStartAmountLine
                    && sendRefIdIndex[sendRefId][i].toPay
            ) {
                RegisterRorInfo memory ror3 = RegisterRorInfo(
                    sendRefIdIndex[sendRefId][i].id,
                    subSendRefId,
                    sendRefIdIndex[sendRefId][i].dttAddress,
                    sendRefIdIndex[sendRefId][i].amount,
                    sendRefIdIndex[sendRefId][i].parentId,
                    sendRefIdIndex[sendRefId][i].toPay,
                    sendRefIdIndex[sendRefId][i].startAmountLine,
                    sendRefIdIndex[sendRefId][i].endAmountLine,
                    sendRefIdIndex[sendRefId][i].weight
                );
                RorIndex[sendRefIdIndex[sendRefId][i].id] = ror3;
                sendRefIdIndex[subSendRefId].push(ror3);
                sendRefIdIndex[sendRefId][i].toPay = false;
                splitAmountLine += sendRefIdIndex[sendRefId][i].amount;
                emit RorSendRelationChange(rorAddress, sendRefIdIndex[sendRefId][i].id, sendRefId, subSendRefId);
            }
        }

        for (uint256 i = 0; i < sendRefIdIndex[sendRefId].length; i++) {
            if (!sendRefIdIndex[sendRefId][i].toPay) {
                continue;
            }
            if (
                sendRefIdIndex[sendRefId][i].startAmountLine < newSendRefIdStartAmountLine
                    && sendRefIdIndex[sendRefId][i].endAmountLine > newSendRefIdStartAmountLine
            ) {
                // 暂停交易
                uint256 rorId = sendRefIdIndex[sendRefId][i].id;
                RorMarket(config.rorMarket()).settleReject(rorId);
                _splitRor(
                    sendRefIdIndex[sendRefId][i],
                    subSendRefId,
                    rorId,
                    SplitType.PARTIAL_ACCEPT,
                    amount - splitAmountLine
                );
            }
        }
    }

    function settle(string memory sendRefId) public whenNotPaused returns (SettleInfo[] memory) {
        require(msg.sender == config.dtt(), ErrorCode.SCM_RorEnhancement_settle_CALLER_ERROR);
        uint256 count = 0;
        for (uint256 i = 0; i < sendRefIdIndex[sendRefId].length; i++) {
            if (sendRefIdIndex[sendRefId][i].toPay) {
                count++;
            }
        }
        SettleInfo[] memory rorList = new SettleInfo[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < sendRefIdIndex[sendRefId].length; i++) {
            if (sendRefIdIndex[sendRefId][i].toPay) {
                RorMarket(config.rorMarket()).settleReject(sendRefIdIndex[sendRefId][i].id);
                rorList[j++] = SettleInfo(
                    sendRefIdIndex[sendRefId][i].id,
                    IRORERC721(rorAddress).ownerOf(sendRefIdIndex[sendRefId][i].id),
                    sendRefIdIndex[sendRefId][i].dttAddress,
                    sendRefIdIndex[sendRefId][i].amount
                );
                IRORERC721(rorAddress).burn(sendRefIdIndex[sendRefId][i].id);
            }
        }
        return rorList;
    }

    function verifySettle(string memory sendRefId) public view whenNotPaused returns (SettleInfo[] memory) {
        require(msg.sender == config.dtt(), ErrorCode.SCM_RorEnhancement_settle_CALLER_ERROR);
        uint256 count = 0;
        for (uint256 i = 0; i < sendRefIdIndex[sendRefId].length; i++) {
            if (sendRefIdIndex[sendRefId][i].toPay) {
                count++;
            }
        }
        SettleInfo[] memory rorList = new SettleInfo[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < sendRefIdIndex[sendRefId].length; i++) {
            if (sendRefIdIndex[sendRefId][i].toPay) {
                address owner = RorMarket(config.rorMarket()).verifySettleReject(sendRefIdIndex[sendRefId][i].id);
                rorList[j++] = SettleInfo(
                    sendRefIdIndex[sendRefId][i].id,
                    owner,
                    sendRefIdIndex[sendRefId][i].dttAddress,
                    sendRefIdIndex[sendRefId][i].amount
                );
            }
        }
        return rorList;
    }

    function transferRor(uint256 rorId, uint256 amount) public whenNotPaused returns (uint256) {
        require(msg.sender == config.rorMarket(), ErrorCode.SCM_RorEnhancement_transferRor_CALLER_ERROR);
        string memory sendRefId = RorIndex[rorId].sendRefId;
        uint256 rorId1;
        uint256 rorId2;
        for (uint256 i = 0; i < sendRefIdIndex[sendRefId].length; i++) {
            if (sendRefIdIndex[sendRefId][i].id != rorId) {
                continue;
            }
            (rorId2, rorId1) =
                _splitRor(sendRefIdIndex[sendRefId][i], sendRefId, rorId, SplitType.PARTIAL_TRANSFER, amount);
            break;
        }
        return rorId1;
    }

    function verifyTransferRor(uint256 rorId, uint256 amount) public view whenNotPaused {
        require(msg.sender == config.rorMarket(), ErrorCode.SCM_RorEnhancement_transferRor_CALLER_ERROR);
        string memory sendRefId = RorIndex[rorId].sendRefId;
        uint256 rorId1;
        uint256 rorId2;
        for (uint256 i = 0; i < sendRefIdIndex[sendRefId].length; i++) {
            if (sendRefIdIndex[sendRefId][i].id != rorId) {
                continue;
            }
            require(sendRefIdIndex[sendRefId][i].toPay, ErrorCode.SCM_RorEnhancement_splitRor_NOT_TOPAID);
            require(sendRefIdIndex[sendRefId][i].amount > amount, ErrorCode.SCM_RorEnhancement_splitRor_AMOUNT_EXCEED);
            IRORERC721 ror = IRORERC721(rorAddress);
            ror.verifyCreditDoorNFTMint(ror.ownerOf(rorId));
            ror.verifyCreditDoorNFTMint(config.rorMarket());
            break;
        }
    }

    function _splitRor(
        RegisterRorInfo storage sendRefRor,
        string memory subSendRefId,
        uint256 rorId,
        SplitType splitType,
        uint256 amount
    ) private returns (uint256, uint256) {
        require(sendRefRor.toPay, ErrorCode.SCM_RorEnhancement_splitRor_NOT_TOPAID);
        require(sendRefRor.amount > amount, ErrorCode.SCM_RorEnhancement_splitRor_AMOUNT_EXCEED);
        string memory sendRefId = sendRefRor.sendRefId;
        // uint256 oldSendRefIdStartAmountLine = sendRefIdStartAmountLine[sendRefId];
        // uint256 newSendRefIdStartAmountLine = oldSendRefIdStartAmountLine + amount;
        uint256 newSendRefIdStartAmountLine = sendRefRor.startAmountLine + amount;
        IRORERC721 ror = IRORERC721(rorAddress);
        address parentRorOwner = ror.ownerOf(rorId);
        address splitRorOwner;
        if (splitType == SplitType.PARTIAL_ACCEPT) {
            splitRorOwner = parentRorOwner;
        } else {
            splitRorOwner = config.rorMarket();
        }

        _burn(rorId);
        uint256 rorId2 = _mint(parentRorOwner, sendRefId, sendRefRor.dttAddress, sendRefRor.amount - amount, rorId);
        uint256 rorId1 = _mint(splitRorOwner, subSendRefId, sendRefRor.dttAddress, amount, rorId);

        RegisterRorInfo memory ror1 = RegisterRorInfo(
            rorId1,
            subSendRefId,
            sendRefRor.dttAddress,
            amount,
            sendRefRor.parentId,
            true,
            sendRefRor.startAmountLine,
            newSendRefIdStartAmountLine,
            1
        );
        RorIndex[rorId1] = ror1;
        sendRefIdIndex[subSendRefId].push(ror1);
        emit RorSendMint(
            rorAddress,
            rorId1,
            ror.ownerOf(rorId1),
            amount,
            sendRefRor.startAmountLine,
            newSendRefIdStartAmountLine,
            subSendRefId
        );

        RegisterRorInfo memory ror2 = RegisterRorInfo(
            rorId2,
            sendRefId,
            sendRefRor.dttAddress,
            sendRefRor.amount - amount,
            sendRefRor.parentId,
            true,
            newSendRefIdStartAmountLine,
            sendRefRor.endAmountLine,
            1
        );
        sendRefRor.toPay = false;
        RorIndex[rorId2] = ror2;
        sendRefIdIndex[sendRefId].push(ror2);
        emit RorSendMint(
            rorAddress,
            rorId2,
            ror.ownerOf(rorId2),
            sendRefRor.amount - amount,
            newSendRefIdStartAmountLine,
            sendRefRor.endAmountLine,
            sendRefId
        );
        emit RorSplit(
            rorAddress,
            sendRefRor.id,
            parentRorOwner,
            sendRefRor.amount,
            ror1.id,
            amount,
            ror2.id,
            ror2.amount,
            splitType
        );
        return (rorId2, rorId1);
    }

    function _mint(address receipt, string memory refId, address ERC20Address, uint256 amount, uint256 parentTokenId)
        private
        returns (uint256)
    {
        try IRORERC721(rorAddress).mint(receipt) returns (uint256 _tokenId) {
            IRORERC721(rorAddress).setTokenProperties(
                _tokenId,
                refId,
                IDTTERC20(ERC20Address).symbol(),
                ERC20Address,
                amount / (10 ** IDTTERC20(ERC20Address).decimals()),
                parentTokenId,
                "",
                ""
            );
            return _tokenId;
        } catch Error(string memory reason) {
            if (Strings.equal(reason, ErrorCode.SCM_Permission_NFT_Mint_ERROR)) {
                revert(ErrorCode.SCM_RorEnhancement_mint_MintPermissionError);
            } else {
                revert(reason);
            }
        }
    }

    function _burn(uint256 rorId) private {
        try IRORERC721(rorAddress).burn(rorId) {}
        catch Error(string memory reason) {
            if (Strings.equal(reason, ErrorCode.SCM_ERC721_modifer_OnlyRorEnhancement)) {
                revert(ErrorCode.SCM_RorEnhancement_burn_REVERT_ERROR);
            } else {
                revert(reason);
            }
        }
    }
}
