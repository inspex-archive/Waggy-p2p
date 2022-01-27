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
  console.log(">> Start Deploy Contract");
  // Waggy token
  const WaggyNFT = await hre.ethers.getContractFactory("WaggyNFT");
  const waggyNFT = await WaggyNFT.attach('0xC09015c73e6d19a849d922d475A597be3dad0BA4');
  // const waggyNFT = await WaggyNFT.deploy("WaggyNFT", "WNFT",{gasPrice:ethers.utils.parseUnits('6','gwei')});
  await waggyNFT.deployed();

  // ContractJSON.waggyNFT = waggyNFT.address;
  // console.log(`WaggyNFT address: ${waggyNFT.address}`);
  // await waggyNFT.setOldAvatar('0xb2Fa3D1A6aA2375c0366c31086Becb28db9b0C22',{gasPrice:ethers.utils.parseUnits('6','gwei')});
  // console.log('Set Old avatar success');
  await waggyNFT.setPrice(ethers.utils.parseEther('0.1'),{gasPrice:ethers.utils.parseUnits('6','gwei')});
  await waggyNFT.setApprovalForAll(waggyNFT.address,true,{gasPrice:ethers.utils.parseUnits('6','gwei')});
  await waggyNFT.setAllowTransfer(ContractJSON.gasStation,true,{gasPrice:ethers.utils.parseUnits('6','gwei')});
// 
console.log("initial value done.")
  const jsonString = JSON.stringify(ContractJSON, null, 2);
  console.log(jsonString);
  await fs.writeFileSync(`./${fileName}`, jsonString);
  console.log("Update file done.");

  await hre.run("verify:verify", {
    address: waggyNFT.address,
    contract: "contracts/farm/WaggyNFT.sol:WaggyNFT",
    constructorArguments: ["WaggyNFT", "WNFT"],
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
