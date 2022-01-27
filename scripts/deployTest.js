// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

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
  const WagTest = await hre.ethers.getContractFactory("WagTest");
  const wagTest = await WagTest.deploy();

  const tx = await wagTest.deployed();


  console.log(`WagTest address: ${wagTest.address}`)
  await hre.run("verify:verify", {
    address: wagTest.address,
    contract: "contracts/WagTest.sol:WagTest",
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
