const { ethers } = require("hardhat");
const hre = require("hardhat");
const ContractJSON = require("../contract.json");
const fs = require("fs");

async function main() {
  const accounts = await hre.ethers.getSigners();
  // Waggy token
  // const WaggyToken = await hre.ethers.getContractFactory("WaggyToken");
  // const waggyToken = await WaggyToken.attach(ContractJSON.waggyToken);
  // attach MasterWaggy
  const WaggyStaking = await hre.ethers.getContractFactory("WaggyStaking");
  const waggyStaking = await WaggyStaking.attach(ContractJSON.waggyStaking);

  // const WERC20 = await hre.ethers.getContractFactory("WERC20");
  // const busdToken = await WERC20.attach(ContractJSON.busdToken)
  // const daiToken = await WERC20.attach(ContractJSON.daiToken)
  // const usdtToken = await WERC20.attach(ContractJSON.usdtToken)
  // const usdcToken = await WERC20.attach(ContractJSON.usdcToken)
  // const wbnbToken = await WERC20.attach(ContractJSON.wbnbToken)

  // init pool
  // console.log("Remove pool before add.");
  // await waggyStaking.removeAllPool();
  console.log("Begin add pool");
  // await waggyStaking.add(1000,ContractJSON.wbnbToken);//1
  // await waggyStaking.add(1000,ContractJSON.busdToken);//2
  // await waggyStaking.add(1000,ContractJSON.daiToken);//3
  // await waggyStaking.add(1000,ContractJSON.usdcToken);//4
  await waggyStaking.add(1000,ContractJSON.usdtToken);//5
  console.log("AddPool success");
  // // approve token
  // await waggyToken.approve(waggyStaking.address, ethers.utils.parseEther("100000000"));
  // await busdToken.approve(waggyStaking.address, ethers.utils.parseEther("100000000"));
  // await daiToken.approve(waggyStaking.address, ethers.utils.parseEther("100000000"));
  // await usdtToken.approve(waggyStaking.address, ethers.utils.parseEther("100000000"));
  // await usdcToken.approve(waggyStaking.address, ethers.utils.parseEther("100000000"));
  // await wbnbToken.approve(waggyStaking.address, ethers.utils.parseEther("100000000"));

  // const busdBalance = await busdToken.balanceOf(accounts[0].address);
  // console.log(`BUSD Balance ${ethers.utils.formatEther(busdBalance)}`);
  // const daiBalance = await daiToken.balanceOf(accounts[0].address);
  // console.log(`DAI Balance ${ethers.utils.formatEther(daiBalance)}`);
  // const usdtBalance = await usdtToken.balanceOf(accounts[0].address);
  // console.log(`DAI Balance ${ethers.utils.formatEther(usdtBalance)}`);
  // // inital deposit
  // console.log("Approve success");
  // await waggyStaking.deposit(1, ethers.utils.parseEther("30"));
  // await waggyStaking.deposit(2, ethers.utils.parseEther("9"));
  // await waggyStaking.deposit(3, ethers.utils.parseEther("900"));
  // await waggyStaking.deposit(4, ethers.utils.parseEther("1350"));
  // await waggyStaking.deposit(5, ethers.utils.parseEther("100"));
  // console.log("Deposit success");

  // const jsonString = JSON.stringify(ContractJSON, null, 2);
  // console.log(jsonString);
  // await fs.writeFileSync("./contract.json", jsonString);
  // console.log("Update file done.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
