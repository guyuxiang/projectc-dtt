require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("@nomicfoundation/hardhat-ethers");
require("hardhat-forta");
require("dotenv").config();
require("hardhat-diamond-abi");
require("hardhat-storage-layout-changes");
require("@nomicfoundation/hardhat-verify");
require("hardhat-gas-reporter");

// tdly.setup();
task(
  "hello",
  "Prints 'Hello, World!'",
  async function (taskArguments, hre, runSuper) {
    console.log("Hello, World!");
  },
);

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
      },
      viaIR: true,
    },
  },
  diamondAbi: {
    // (required) The name of your DigitalTokenTradeDiamond ABI.
    name: "DigitalTokenTradeDiamondFull",
    // (optional) An array of strings, matched against fully qualified contract names, to
    // determine which contracts are included in your DigitalTokenTradeDiamond ABI.
    include: [
      "ConditionActionFacet",
      "ConditionCalculateFacet",
      "ConditionCreateFacet",
      "SendFacet",
      "SettleFacet",
      "TradeStatusFacet",
      "VerifyFacet",
    ],
    exclude: [
      "IConditionActionFacet",
      "IConditionCalculateFacet",
      "IConditionCreateFacet",
      "ISendFacet",
      "ISettleFacet",
      "ITradeStatusFacet",
    ],
    filter:
      "function (abiElement, index, fullAbi, fullyQualifiedName) {return abiElement.name !== 'ds';}",
    strict: false,
  },
  networks: {
    hardhat: {},
    sepolia: {
      url: "https://ethereum-sepolia-rpc.publicnode.com",
      chainId: 11155111,
      accounts: [
        "1111111111111111111111111111111111111111111111111111111111111111",
      ],
    }
  }
};
