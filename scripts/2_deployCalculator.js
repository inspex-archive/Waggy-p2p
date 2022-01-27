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
  await hre.run("compile");
  const accounts = await hre.ethers.getSigners();
  console.log(">> Start Deploy Contract");

  // deploy reward calculator
  const RewardCalculator = await hre.ethers.getContractFactory("RewardCalculator");
  const rewardCalculator = await RewardCalculator.deploy();

  await rewardCalculator.deployed();

  ContractJSON.rewardCalculator = rewardCalculator.address;

  // deploy fee calculator
  const FeeCalculator = await hre.ethers.getContractFactory("FeeCalculator");
  const feeCalculator = await FeeCalculator.deploy();

  await feeCalculator.deployed();

  ContractJSON.feeCalculator = feeCalculator.address;
  // deploy BlackListuser
  const BlackListUser = await hre.ethers.getContractFactory("BlackListUser");
  const blackListUser = await BlackListUser.deploy();
  await blackListUser.deployed();

  ContractJSON.blackListUser = blackListUser.address;

  console.log("Reward Calculator address : ", rewardCalculator.address);
  console.log("Fee Calculator address : ", feeCalculator.address);
  console.log("BlackListUser address : ", blackListUser.address);

  console.log("✅ Done deploying a Factory");
  console.log(">> Start Verify Contract");

  const jsonString = JSON.stringify(ContractJSON, null, 2);
  console.log(jsonString);
  await fs.writeFileSync(`./${fileName}`, jsonString);
  console.log("write file done.");

  await hre.run("verify:verify", {
    address: rewardCalculator.address,
    contract: "contracts/p2p/RewardCalculator.sol:RewardCalculator",
    constructorArguments: [],
  });
  await hre.run("verify:verify", {
    address: feeCalculator.address,
    contract: "contracts/p2p/FeeCalculator.sol:FeeCalculator",
    constructorArguments: [],
  });
  await hre.run("verify:verify", {
    address: blackListUser.address,
    contract: "contracts/BlackListUser.sol:BlackListUser",
    constructorArguments: [],
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
