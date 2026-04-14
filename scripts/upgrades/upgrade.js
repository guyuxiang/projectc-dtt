const db = require("../flowCli/db");
const { upgradeContracts } = require("../flowCli/utl");

async function main() {
  const address = await db.read();
  console.log("all address", address);

  const envParam = await db.readConfig();
  console.log("envParam", envParam);

  // 升级
  const contractsParam = [];
  await upgradeContracts(contractsParam);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
