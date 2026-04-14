//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../kyc/Config.sol";
import "../kyc/Permission.sol";
import "../libraries/Constants.sol";

contract TransactionIDFactory is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    error UnknowTransactionType(string transactionType);

    struct sequenceRecorder {
        uint256 currentDay;
        uint256 sequence;
    }

    mapping(string => mapping(string => sequenceRecorder)) public sequenceRecorders;

    Config public config;

    event setConfigEvent(address configContract);

    modifier TransactionIdCallerCheck() {
        require(msg.sender == config.dtt() || msg.sender == config.encash() || msg.sender == config.rorMarket(), ErrorCode.SCM_TransactionIDFactory_generateTransactionID_CALLER_ERROR);
        _;
    }

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

    function generateTransactionID(string memory tokenName, string memory transactionType) public TransactionIdCallerCheck returns (string memory transactionID) {
        transactionID = string(abi.encodePacked(Strings.toString(block.timestamp), tokenName, transactionType, toStrings6(getSequenceNumber(tokenName, transactionType))));
    }

    function generateTransactionIDByDate(string memory date, string memory tokenName, string memory transactionType) public TransactionIdCallerCheck returns (string memory transactionID) {
        transactionID = string(abi.encodePacked(date, tokenName, transactionType, toStrings6(getSequenceNumber(tokenName, transactionType))));
    }

    function getSequenceNumber(string memory tokenName, string memory transactionType) internal returns (uint256) {
        if (sequenceRecorders[tokenName][transactionType].sequence == 0) {
            sequenceRecorders[tokenName][transactionType].currentDay = block.timestamp / 1 days;
            sequenceRecorders[tokenName][transactionType].sequence = 1;
            return 1;
        }

        if (sequenceRecorders[tokenName][transactionType].currentDay != block.timestamp / 1 days) {
            sequenceRecorders[tokenName][transactionType].currentDay = block.timestamp / 1 days;
            sequenceRecorders[tokenName][transactionType].sequence = 1;
        } else {
            sequenceRecorders[tokenName][transactionType].sequence += 1;
        }

        return sequenceRecorders[tokenName][transactionType].sequence;
    }

    function toStrings6(uint256 value) internal view returns (string memory) {
        if (value > 999999) {
            return Strings.toString(value);
        }
        string memory s = Strings.toString(value + 1000000);
        return string(this.toBytes6(bytes(s)));
    }

    function toBytes6(bytes calldata b) external pure returns (bytes memory) {
        return bytes(b[1:]);
    }
}
