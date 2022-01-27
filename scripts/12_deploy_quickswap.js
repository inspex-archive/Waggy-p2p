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
 
  // await hre.run("compile");
  console.log(">> Start Deploy Contract");
  const [deployer, feeCollector] = await ethers.getSigners();
  const offchainAddress = "0x727618192f7E29721cbd2a518DFc0A3B66720829"//bsc
  const QuickSwap = await  hre.ethers.getContractFactory("QuickSwap");
  // console.log(`Start upgrade merchant ${merchangeName} with address ${ContractJSON[merchangeName]}`);
  // const merchant = await upgrades.upgradeProxy(ContractJSON[merchangeName], Merchant);
  // await merchant.deployed();
  // console.log(`Upgrade done at ${merchant.address}`);
  // const merchant = await Merchant.attach(ContractJSON[merchangeName]);

//   //  Deploy new merchamt contract
  const quickSwap = await upgrades.deployProxy(QuickSwap,[
    ContractJSON.waggyToken,
    ContractJSON.rewardCalculator,
    ContractJSON.feeCalculator,
    deployer.address,
    ContractJSON.blackListUser
  ])
  await quickSwap.deployed();

  await quickSwap.setValidator(ContractJSON.validator);
  await quickSwap.setAdmins([deployer.address,offchainAddress]);
  ContractJSON.quickSwap = quickSwap.address;
  console.log(`Deploy quickswap done. at address ${quickSwap.address}`);
  console.log("✅ Done Verify Contract");

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
