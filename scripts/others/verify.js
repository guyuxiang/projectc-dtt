const path = require("path");
const db = require("../flowCli/db");
const { reOrganizeTokens, verifyContracts } = require("../flowCli/utl");

async function main() {
  const address = await db.read();
  console.log("all address", address);

  const envParam = await db.readConfig();
  console.log("envParam", envParam);

  const verifyTemplatePath = path.join(__dirname, "verify.json");
  const contractsParam = await db.readContractTemplate(verifyTemplatePath);

  await verifyContracts(contractsParam);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
