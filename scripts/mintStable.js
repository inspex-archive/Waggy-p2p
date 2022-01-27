const { ethers, upgrades } = require("hardhat");
const ContractJSON = require("../contract.json");
const fs = require("fs");

async function main() {
  console.log("Start deploy");
  const WERC20 = await hre.ethers.getContractFactory("WERC20");
  const [deployer, feeCollector] = await ethers.getSigners();
  // deploy merchant
  const addressUsers = [
    //  "0xCB950adCa1d67749486D65311Aba5efdA8351bD3",
    //  "0x4A921631F66c066eabc36670E7411da58C2855C3", 
    //  "0x070F5CbD8B01eCA3992d09F837BC761fAA1d2E47",
    "0x9d5540a8FC339ee934f40F0a0E5ec5d80A0DB9eD",
    // "0x9a195A6a5Ed40337Ac804939A7875D61AFe3f7CB"
  ];
  let address = "0xAf3F13983E9a95115fD704A82CCEe71eCD8b251A"
  //  const mintToken = async (address) => {
     try {
      const txCount = await (await ethers.getSigner()).getTransactionCount();
      
      console.log(`Start mint for address ${address} nonce ${txCount}`);
      const busdToken = await WERC20.attach(ContractJSON.busdToken);
      let gas =  await busdToken.estimateGas.mint(address, ethers.utils.parseEther("1000000"))
      console.log(gas)
      await busdToken.connect(deployer).mint(address, ethers.utils.parseEther("1000000"));
      console.log(ethers.utils.formatEther(await busdToken.balanceOf(address)));

      const usdtToken = await WERC20.attach(ContractJSON.usdtToken);
      await usdtToken.connect(deployer).mint(address, ethers.utils.parseEther("1000000"));
      console.log(ethers.utils.formatEther(await usdtToken.balanceOf(address)));

      const usdcToken = await WERC20.attach(ContractJSON.usdcToken);
      await usdcToken.connect(deployer).mint(address, ethers.utils.parseEther("1000000"));
      console.log(ethers.utils.formatEther(await usdcToken.balanceOf(address)));

      const daiToken = await WERC20.attach(ContractJSON.daiToken);
      await daiToken.connect(deployer).mint(address, ethers.utils.parseEther("1000000"));
      console.log(ethers.utils.formatEther(await daiToken.balanceOf(address)));

      const bnbToken = await WERC20.attach(ContractJSON.wbnbToken);
      await bnbToken.connect(deployer).mint(address, ethers.utils.parseEther("1000000")); 
      console.log(ethers.utils.formatEther(await bnbToken.balanceOf(address)));
    } catch (error) {
      console.log(error)
    }
  //  };

  // const tasks = addressUsers.map(async address =>{
  //    await mintToken(address);
  // })

  // await Promise.all(tasks);
  
  console.log("mint done.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
