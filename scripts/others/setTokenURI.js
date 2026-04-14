const { ethers } = require("hardhat");
const db = require("../flowCli/db.js");

async function getContractInstance(contractName, contractAddress) {
  const Contract = await ethers.getContractAt(contractName, contractAddress);
  return Contract;
}

async function main() {
  const address = await db.read();
  console.log("all address", address);

  console.log("start");

  const RORTokenC = await getContractInstance(
    "RORERC721",
    address["RORERC721"].address,
  );
  var tx = await RORTokenC.setDescription(
    "ROR (Right of Receive) is a unique digital representation of the recipient’s right to receive DTT automatically once the specified payment conditions are fulfilled. Each ROR is identifiable by its Token ID, which can be used to query the corresponding details.",
  );
  // 等待交易被包含在区块链中
  let receipt = await tx.wait();

  if (receipt.status === 1) {
    console.log("setDescription successful!");
  } else {
    console.log("setDescription failed.");
  }

  var tx = await RORTokenC.setSVGTemplate(
    "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' x='0px' y='0px' width='270px' height='270px' viewBox='0 0 270 270' xml:space='preserve'><rect width='100%' height='100%' fill='#DBEAFE' /><image id='image0' width='270' height='270' x='0' y='0' />",
  );
  // 等待交易被包含在区块链中
  receipt = await tx.wait();

  if (receipt.status === 1) {
    console.log("setSVGTemplate successful!");
  } else {
    console.log("setSVGTemplate failed.");
  }

  var tx = await RORTokenC.setSVGText(
    "<text x='35%' y='50%' font-family='Inter' font-weight='700' font-size='20' fill='#0053F2' dominant-baseline='middle'>",
  );
  // 等待交易被包含在区块链中
  receipt = await tx.wait();

  if (receipt.status === 1) {
    console.log("setSVGText successful!");
  } else {
    console.log("setSVGText failed.");
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
