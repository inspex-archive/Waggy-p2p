const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer, feeCollector] = await hre.ethers.getSigners();

  // verify waggy token
  //  console.log(`Start verify ${merchantAddress} with address ${targetToken}`);
  //  await hre.run("verify:verify", {
  //    address: "0x7492a84a5cc192af72b2686329bf82a2c5d7618a",
  //    contract: "contracts/p2p/WaggyToken.sol:WaggyToken",
  //    constructorArguments: [],
  //  });
  // verify merchant
  // console.log(`Start verify ${merchantAddress} with address ${targetToken}`);
  // await hre.run("verify:verify", {
  //   address: "0xecc9325d3cd3a1badb69d680ed4a66c7f7e69004",
  //   contract: "contracts/p2p/Merchant.sol:Merchant",
  //   constructorArguments: [],
  // });
  await hre.run("verify:verify", {
    address: "0xae7d83baf44055cd29df5199a58371fb32fde9c9",
    contract: "contracts/p2p/MerchantMultiToken.sol:MerchantMultiToken",
    constructorArguments: [],
  });

  // await hre.run("verify:verify", {
  //   address: "0x6b6e983a10b2c814db720C8ee837ECED1B648bdB",
  //   contract: "contracts/p2p/WNativeRelayer.sol:WNativeRelayer",
  //   constructorArguments: [
  //     "0xdf032bc4b9dc2782bb09352007d4c57b75160b15"
  //   ],
  // });

  // await hre.run("verify:verify", {
  //   address: "0x3b53a1ab77104c846d64e32f47cee60a61f32a61",
  //   contract: "contracts/p2p/WaggyToken.sol:WaggyToken",
  //   constructorArguments: [],
  // });

  //   await hre.run("verify:verify", {
  //   address: "0x810e84ad66fbf8fbbe1073653800e4d8092f9e04",
  //   contract: "contracts/p2p/QuickSwap.sol:QuickSwap",
  //   constructorArguments: [],
  // });

  console.log("verify merchant done.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
