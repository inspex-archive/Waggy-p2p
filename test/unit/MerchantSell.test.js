const { BigNumber, Signer } = require("ethers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

describe("Merchant Seller", () => {
  // MasterWaggy instances
  let merchant;
  let waggyToken;
  // Accounts
  let deployer;
  let merchantSeller;
  let buyer;
  let eve;
  let wbusd;

  beforeEach(async () => {
    [deployer, merchantSeller, buyer, eve, userSeller] = await ethers.getSigners();

    const WaggyToken = await hre.ethers.getContractFactory("WaggyToken");
    waggyToken = await WaggyToken.deploy();

    await waggyToken.deployed();

    //deploy Factory storage
    const FactoryStorage = await hre.ethers.getContractFactory("FactoryStorage");
    const factoryStorage = await FactoryStorage.deploy();

    await factoryStorage.deployed();
    // deploy Factory
    const P2PFactory = await hre.ethers.getContractFactory("P2PFactory");
    const p2pfactory = await P2PFactory.deploy(factoryStorage.address, deployer.address);

    await p2pfactory.deployed();
    // deploy reward calculator
    const RewardCalculator = await hre.ethers.getContractFactory("RewardCalculator");
    const rewardCalculator = await RewardCalculator.deploy();

    await rewardCalculator.deployed();

    // deploy fee calculator
    const FeeCalculator = await hre.ethers.getContractFactory("FeeCalculator");
    const feeCalculator = await FeeCalculator.deploy();

    await feeCalculator.deployed();
    // deploy merchant

    const BUSD = await hre.ethers.getContractFactory("WERC20");
    wbusd = await BUSD.deploy("BUSD", "Binacne USD");
    await wbusd.deployed();

    console.log(`WBUSD address ${wbusd.address}`);

    await factoryStorage.transferOwnership(p2pfactory.address);
    const BUSDAddress = wbusd.address;
    const estimateGas = await p2pfactory.estimateGas.createNewMerchant(
      BUSDAddress,
      waggyToken.address,
      rewardCalculator.address,
      feeCalculator.address,
      {
        from: deployer.address,
      }
    );
    console.log(`estimateGas used ${estimateGas}`);
    const tx = await p2pfactory.createNewMerchant(
      BUSDAddress,
      waggyToken.address,
      rewardCalculator.address,
      feeCalculator.address,
      { from: deployer.address, gasLimit: estimateGas.add(200000) }
    );
    await tx.wait(1);
    const merchantsAddress = await p2pfactory.getMerchantByToken(BUSDAddress);

    // deploy fee calculator
    const Merchant = await hre.ethers.getContractFactory("Merchant");
    merchant = await Merchant.attach(merchantsAddress);
    // setup fund for testing
    console.log("Setup fund");
    await wbusd.connect(deployer).transfer(merchantSeller.address, ethers.utils.parseEther("10000"));
    await wbusd.connect(deployer).transfer(userSeller.address, ethers.utils.parseEther("10000"));

    const sellerBalance = await wbusd.balanceOf(merchantSeller.address);
    console.log(`Seller balance ${ethers.utils.formatEther(sellerBalance)}`);

    // redeem reward.
    await waggyToken.connect(deployer).transfer(merchant.address, ethers.utils.parseEther("100000"));
    // open shop for seller
    await wbusd.connect(merchantSeller).approve(merchant.address, ethers.utils.parseEther("10000"));
    const allowance = await wbusd.connect(merchantSeller).allowance(merchantSeller.address, merchant.address);
    console.log(`Allowance this contracte : ${ethers.utils.formatEther(allowance)}`);
    // await merchant.connect(merchantSeller).setupShop(ethers.utils.parseEther("2000"));

    // const balanceOf = await  wbusd.connect(merchantSeller).balanceOf(merchantSeller.address)
    // let shopBalance = await merchant.connect(merchantSeller).getShopBalance(merchantSeller.address);
    // check balance after open shop
    // expect(ethers.utils.formatEther(balanceOf)).equal("8000.0")
    // expect(ethers.utils.formatEther(shopBalance)).equal("2000.0")
  });

  it("Sell token happy case", async () => {
    // approve token
    await wbusd.connect(userSeller).approve(merchant.address, ethers.utils.parseEther("10000"));
    // user want to sell BUSD 1000
    await merchant.connect(userSeller).sellerDeposit(merchantSeller.address, ethers.utils.parseEther("1000"));
    const sellerDepositAmount = await merchant
      .connect(deployer)
      .getSellerDeposit(userSeller.address, merchantSeller.address);
    expect(ethers.utils.formatEther(sellerDepositAmount)).equal("1000.0");
    // // Merchant transfer fait to user
    const sellerBUSDBalance = await wbusd.balanceOf(userSeller.address);
    let contractBalance = await wbusd.balanceOf(merchant.address);
    expect(ethers.utils.formatEther(sellerBUSDBalance)).equal("9000.0");
    expect(ethers.utils.formatEther(contractBalance)).equal("1000.0");

    //after merchant transfer fait success user should be release token to buyer
    await merchant
      .connect(userSeller)
      .sellerReleaseToken(userSeller.address, merchantSeller.address, ethers.utils.parseEther("1000.0"));
    const merchantTokenBalance = await wbusd.balanceOf(merchantSeller.address);
    contractBalance = await wbusd.balanceOf(merchant.address);
    let rewardBalance = await waggyToken.balanceOf(merchantSeller.address);
    expect(ethers.utils.formatEther(rewardBalance)).equal("80.0"); //reward 8%
    expect(ethers.utils.formatEther(contractBalance)).equal("0.0");
    expect(ethers.utils.formatEther(merchantTokenBalance)).equal("10997.5"); // fee 0.25
  });

  it("Sell token had cancel transaction", async () => {
    // approve token
    await wbusd.connect(userSeller).approve(merchant.address, ethers.utils.parseEther("10000"));
    // user want to sell BUSD 1000
    await merchant.connect(userSeller).sellerDeposit(merchantSeller.address, ethers.utils.parseEther("1000"));
    const sellerDepositAmount = await merchant
      .connect(deployer)
      .getSellerDeposit(userSeller.address, merchantSeller.address);
    expect(ethers.utils.formatEther(sellerDepositAmount)).equal("1000.0");
    // // Merchant transfer fait to user
    let sellerBUSDBalance = await wbusd.balanceOf(userSeller.address);
    let contractBalance = await wbusd.balanceOf(merchant.address);
    expect(ethers.utils.formatEther(sellerBUSDBalance)).equal("9000.0");
    expect(ethers.utils.formatEther(contractBalance)).equal("1000.0");

    //after merchant transfer fait success user should be release token to buyer
    await merchant
      .connect(userSeller)
      .cancelSellTransaction(userSeller.address, merchantSeller.address, ethers.utils.parseEther("1000.0"),"Timeout");
    const merchantTokenBalance = await wbusd.balanceOf(merchantSeller.address);
    contractBalance = await wbusd.balanceOf(merchant.address);
    sellerBUSDBalance  = await wbusd.balanceOf(userSeller.address);
    let rewardBalance = await waggyToken.balanceOf(merchantSeller.address);
    expect(ethers.utils.formatEther(rewardBalance)).equal("0.0"); //reward 8%
    expect(ethers.utils.formatEther(contractBalance)).equal("0.0");
    expect(ethers.utils.formatEther(sellerBUSDBalance)).equal("10000.0");
    expect(ethers.utils.formatEther(merchantTokenBalance)).equal("10000.0"); // fee 0.25
  });

  it("Appeal transaction", async () => {
    // approve token
    await wbusd.connect(userSeller).approve(merchant.address, ethers.utils.parseEther("10000"));
    // user want to sell BUSD 1000
    await merchant.connect(userSeller).sellerDeposit(merchantSeller.address, ethers.utils.parseEther("1000"));
    const sellerDepositAmount = await merchant
      .connect(deployer)
      .getSellerDeposit(userSeller.address, merchantSeller.address);
    expect(ethers.utils.formatEther(sellerDepositAmount)).equal("1000.0");
    // // Merchant transfer fait to user
    let sellerBUSDBalance = await wbusd.balanceOf(userSeller.address);
    let contractBalance = await wbusd.balanceOf(merchant.address);
    expect(ethers.utils.formatEther(sellerBUSDBalance)).equal("9000.0");
    expect(ethers.utils.formatEther(contractBalance)).equal("1000.0");

    //after merchant transfer fait success user should be release token to buyer
    await merchant
      .connect(userSeller)
      .cancelSellTransaction(userSeller.address, merchantSeller.address, ethers.utils.parseEther("1000.0"),"Timeout");
    const merchantTokenBalance = await wbusd.balanceOf(merchantSeller.address);
    contractBalance = await wbusd.balanceOf(merchant.address);
    sellerBUSDBalance  = await wbusd.balanceOf(userSeller.address);
    let rewardBalance = await waggyToken.balanceOf(merchantSeller.address);
    expect(ethers.utils.formatEther(rewardBalance)).equal("0.0"); //reward 8%
    expect(ethers.utils.formatEther(contractBalance)).equal("0.0");
    expect(ethers.utils.formatEther(sellerBUSDBalance)).equal("10000.0");
    expect(ethers.utils.formatEther(merchantTokenBalance)).equal("10000.0"); // fee 0.25
  });
});
