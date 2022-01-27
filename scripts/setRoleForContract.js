const { ethers, upgrades } = require("hardhat");
const ContractJSON = require("../contract.json");
const fs = require("fs");

async function main() {
  console.log("Start set role");
  const [deployer] = await ethers.getSigners();
  const WaggyToken = await hre.ethers.getContractFactory("WaggyToken");
  const waggyToken = WaggyToken.attach(ContractJSON.waggyToken);
  //
  console.log("Set merchant minter role");

  await waggyToken.setMinter([
    ContractJSON.merchantWBNB,
    ContractJSON.merchantBUSD,
    ContractJSON.merchantUSDT,
    ContractJSON.merchantUSDC,
    ContractJSON.merchantDAI,
    ContractJSON.waggyStaking,
    deployer.address
  ]);
  console.log("Set minter done")

  const BlackListUser = await hre.ethers.getContractFactory("BlackListUser");
  const blackListUser = BlackListUser.attach(ContractJSON.blackListUser);
  console.log("Set Backlist admin")
  await blackListUser.setAdmins([
    ContractJSON.merchantWBNB,
    ContractJSON.merchantBUSD,
    ContractJSON.merchantUSDT,
    ContractJSON.merchantUSDC,
    ContractJSON.merchantDAI,
  ]);
 
  console.log("Set Role done.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
