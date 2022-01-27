const { ethers, upgrades } = require("hardhat");
const networkName = hre.network.name
const fileName = `${networkName}-contract.json`
const ContractJSON = require(`../${fileName}`);
const fs = require("fs");

async function main() {
  console.log(`Start deploy merchant on chain ${networkName}`);
  const [deployer, feeCollector] = await ethers.getSigners();
  // const wbnbAddress = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";//testnet
  const wbnbAddress = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";//mainnet
  // const wbnbAddress = "0xdf032bc4b9dc2782bb09352007d4c57b75160b15";//rinkeby
 

  // const WNativeRelayer = await ethers.getContractFactory("WNativeRelayer");
  // const wnativeRelayer = await WNativeRelayer.deploy(wbnbAddress);
  // const wnativeRelayer = await WNativeRelayer.attach(ContractJSON.wnativeRelayer);
  // await wnativeRelayer.deployed();

  // ContractJSON.wnativeRelayer = wnativeRelayer.address
 
  // deploy merchant
  const deployMerchant = async (targetToken, merchangeName) => {
    //  Upgrade Merchant contract
    // const offchainAddress = "0xE8F81573e8A77cD4ee490999d70cB5BB303861c8"//rinkeby
    const offchainAddress = "0x727618192f7E29721cbd2a518DFc0A3B66720829"//bsc
    const Merchant = await ethers.getContractFactory("Merchant");
    // console.log(`Start upgrade merchant ${merchangeName} with address ${ContractJSON[merchangeName]}`);
    // const merchant = await upgrades.upgradeProxy(ContractJSON[merchangeName], Merchant);
    // await merchant.deployed();
    // console.log(`Upgrade done at ${merchant.address}`);
    // const merchant = await Merchant.attach(ContractJSON[merchangeName]);

    // const Merchant = await ethers.getContractFactory("Merchant");
  //   //  Deploy new merchamt contract
    const merchant = await upgrades.deployProxy(Merchant,[
      targetToken,
      ContractJSON.waggyToken,
      ContractJSON.rewardCalculator,
      ContractJSON.feeCalculator,
      deployer.address,
      ContractJSON.blackListUser
    ])
    await merchant.deployed();

    await merchant.setValidator(ContractJSON.validator);
    await merchant.setWNativeRelayer(ContractJSON.wnativeRelayer);
    await merchant.setWBNB(wbnbAddress);
    await merchant.setAdmins([deployer.address,offchainAddress]);
    const merchantsAddress = merchant.address;
    ContractJSON[merchangeName] = merchantsAddress;
    console.log(`Deploy merchant done. at address ${merchant.address}`);
  };

  const tokenData = {
    merchantONE: ContractJSON.oneToken,
    // merchantWBNB: ContractJSON.wbnbToken,
    // merchantBUSD: ContractJSON.busdToken,
    // merchantUSDT: ContractJSON.usdtToken,
    // merchantUSDC: ContractJSON.usdcToken,
    // merchantDAI: ContractJSON.daiToken,
  };
  // console.log("start factory merchant");
  // for (const key in tokenData) {
  //   try {
  //     await deployMerchant(tokenData[key], key);
  //   } catch (error) {
  //     console.log(`Can't create merchant ${key}
  //     with address ${tokenData[key]}
  //     with error ${JSON.stringify(error, null, 2)}`);
  //   }
  // }
  // console.log("Creat merchant done.");
  // const jsonString = JSON.stringify(ContractJSON, null, 2);
  // console.log(jsonString);
  // await fs.writeFileSync(`./${fileName}`, jsonString);
  // console.log("write file done.");

  // const WaggyToken = await hre.ethers.getContractFactory("WaggyToken");
  // const waggyToken = WaggyToken.attach(ContractJSON.waggyToken);
  // //
  // console.log("Set merchant minter role");

  // await waggyToken.setMinter([
  //   ContractJSON.merchantWBNB,
  //   ContractJSON.merchantBUSD,
  //   ContractJSON.merchantUSDT,
  //   ContractJSON.merchantUSDC,
  //   ContractJSON.merchantDAI,
  //   ContractJSON.merchantONE,
  //   ContractJSON.waggyStaking,
  //   ContractJSON.validator,
  //   deployer.address
  // ]);
  // console.log("Set minter done")

  const BlackListUser = await hre.ethers.getContractFactory("BlackListUser");
  const blackListUser = BlackListUser.attach(ContractJSON.blackListUser);
  console.log("Set Backlist admin")
  await blackListUser.setAdmins([
    ContractJSON.merchantWBNB,
    ContractJSON.merchantBUSD,
    ContractJSON.merchantUSDT,
    ContractJSON.merchantUSDC,
    ContractJSON.merchantONE,
    ContractJSON.merchantDAI,
  ]);


  // await wnativeRelayer.setCallerOk([
  //   ContractJSON.merchantWBNB,
  //   ContractJSON.merchantBUSD,
  //   ContractJSON.merchantUSDT,
  //   ContractJSON.merchantUSDC,
  //   ContractJSON.merchantDAI,
  //   ContractJSON.merchantONE,
  // ],true);

  
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
