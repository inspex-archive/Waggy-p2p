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
const { ethers } = require("ethers");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  await hre.run("compile");
  const accounts = await hre.ethers.getSigners();

  // Waggy token
  const WaggyStaking = await hre.ethers.getContractFactory("WaggyStaking");
// Deploy
  const waggyStaking = await hre.upgrades.deployProxy(WaggyStaking, [
    ContractJSON.busdToken,
    accounts[0].address,
    ContractJSON.waggyToken
  ]);
  await waggyStaking.deployed();

  // upgrade 
  console.log(">> Start Upgrade Contract");
  // const waggyStaking = await hre.upgrades.upgradeProxy(ContractJSON.waggyStaking,WaggyStaking);

  // await waggyStaking.deployed();

  ContractJSON.waggyStaking = waggyStaking.address;
  console.log(`waggyStaking address: ${waggyStaking.address}`);

  // await hre.run("verify:verify", {
  //   address: '0xa0c7ad2f5490e0884c5fa4f75c90f8dba4594f5d',
  //   contract: "contracts/farm/WaggyStaking.sol:WaggyStaking",
  //   constructorArguments: [],
  // });

  // console.log("✅ Done Verify Contract");

  const jsonString = JSON.stringify(ContractJSON, null, 2);
  console.log(jsonString);
  await fs.writeFileSync(`./${fileName}`, jsonString);
  console.log("Update file done.");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
