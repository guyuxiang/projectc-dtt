const db = require("../flowCli/db");
const { deployContracts } = require("../flowCli/utl");

async function main() {
  const address = await db.read();
  console.log("all address", address);

  const envParam = await db.readConfig();
  console.log("envParam", envParam);

  const contractsParam = await db.readContractTemplate();

  await deployContracts(contractsParam);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
