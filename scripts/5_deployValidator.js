// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const networkName = hre.network.name
const fileName = `${networkName}-contract.json`
const ContractJSON = require(`../${fileName}`);
const fs = require("fs");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled

  await hre.run("compile");
  const accounts = await hre.ethers.getSigners();
  // console.log(">> Start Deploy Contract");
  // // Validator token
  const Validator = await hre.ethers.getContractFactory("Validator");
  const validator = await Validator.deploy(
      ContractJSON.waggyToken,
      20,
      5,
      20
  );

  await validator.setAdmin("0x8E5D815c295881e7f4964CD46214f7E7F2aE9C99",true);
  // await validator.setAdmin("0x727618192f7E29721cbd2a518DFc0A3B66720829",true);

  ContractJSON.validator = validator.address;
  console.log("Creat Validator done.");
  const jsonString = JSON.stringify(ContractJSON, null, 2);
  console.log(jsonString);
  await fs.writeFileSync(`./${fileName}`, jsonString);
  console.log("write file done.");
  console.log("Validator Validator address : ", validator.address);

  console.log("✅ Done deploying a Validator");
  console.log(">> Start Verify Contract");
  await hre.run("verify:verify", {
    address: validator.address,
    contract: "contracts/Validator.sol:Validator",
    constructorArguments: [
      ContractJSON.waggyToken,
      20,
      5,
      20
    ],
  });
  
  console.log("✅ Done Verify Contract");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
