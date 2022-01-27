const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");
const { BigNumber } = require("ethers");

describe("P2PFactory", function() {

  const gov = "0xce87e814755f6ac4a532ef5a7995ab7b9785605d";

  let owner;
  let account1;
  let account2;
  let feeCollector;
  let factoryStorage;
  let p2pFactory;
  let waggyToken;
  let busdToken;
  let rewardCalculator;
  let feeCalculator;

  beforeEach(async function () {
    [owner,account1,account2,feeCollector] = await ethers.getSigners();

    const BUSD = await ethers.getContractFactory("WERC20");
    busdToken  = await BUSD.deploy();

    const WaggyToken = await ethers.getContractFactory("WaggyToken");
    waggyToken  = await WaggyToken.deploy();
  
    const FactoryStorage = await ethers.getContractFactory("FactoryStorage");
    factoryStorage = await FactoryStorage.deploy();

    const P2PFactory = await ethers.getContractFactory("P2PFactory");
    p2pFactory = await P2PFactory.deploy(factoryStorage.address,feeCollector.address);

    factoryStorage.transferOwnership(p2pFactory.address);

    const RewardCalculator = await ethers.getContractFactory(
      "RewardCalculator"
    );
    rewardCalculator = await RewardCalculator.deploy();

    const FeeCalculator = await ethers.getContractFactory(
      "FeeCalculator"
    );
    feeCalculator = await FeeCalculator.deploy();

    await p2pFactory.createNewMerchant(
      busdToken.address,
      waggyToken.address,
      rewardCalculator.address,
      feeCalculator.address
    );
    const merchantTokenAddress = await p2pFactory.getMerchantByToken(busdToken.address);
   
    await waggyToken.transfer(merchantTokenAddress,ethers.utils.parseEther('100000000'))
    // await busdToken.transfer(owner.address,BigNumber.from('100000000000000000000000'));
    // await busdToken.transfer(account1.address,BigNumber.from('10000000000000000000'));
  });

  it("check busd balance",async () =>{
    const ownerBalance = await busdToken.balanceOf(owner.address);
    expect(ownerBalance.toString()).equal(ethers.utils.parseEther('100000000').toString())
  });

  it("Should can create merchant", async () => {
    const merchantTokenAddress = await p2pFactory.getMerchantByToken(busdToken.address);
    const merchantAdddress = await factoryStorage.getMerchantsAddress();
    expect(merchantTokenAddress).equal(merchantAdddress[0]);
    console.log(`Merchant Address => ${merchantTokenAddress}`)
    const factoryStorageAddress = await p2pFactory.getFactoryStorage();
    expect(factoryStorageAddress).equal(factoryStorage.address);
  });

  it("Open shop BUSD", async () =>{
    const depositTargetBalance = '1';
    const merchantTokenAddress = await p2pFactory.getMerchantByToken(busdToken.address);
    const Merchant = await ethers.getContractFactory("Merchant");
    const merchant = await Merchant.attach(merchantTokenAddress);

    await busdToken.approve(merchant.address,BigNumber.from('10'))

    await merchant.setupShop(BigNumber.from(depositTargetBalance));
    const depositBalance = await merchant.getShopBalance(owner.address)

    expect(depositBalance.toString()).equal(depositTargetBalance)
  });

  it("Open shop then selled success ", async ()=>{
    const depositTargetBalance = '100';
    const sellAmount = '1';
    const merchantTokenAddress = await p2pFactory.getMerchantByToken(busdToken.address);
    const Merchant = await ethers.getContractFactory("Merchant");
    const merchant = await Merchant.attach(merchantTokenAddress);
// deposit
    await busdToken.approve(merchant.address,ethers.utils.parseEther(depositTargetBalance))
    await merchant.setupShop(ethers.utils.parseEther(depositTargetBalance));
// request sell
    await merchant.approveTransaction(ethers.utils.parseEther(sellAmount));
// release token 
    await merchant.releaseToken(account2.address,ethers.utils.parseEther(sellAmount));
// check reward
    const receiveReward = await waggyToken.balanceOf(owner.address);
    const reward = await rewardCalculator.calculateReward(ethers.utils.parseEther(sellAmount));
    const account2balance = await busdToken.balanceOf(account2.address);
// Fee
    const fee = await feeCalculator.calculateFee(ethers.utils.parseEther(sellAmount));
    console.log(ethers.utils.formatEther(fee))
    const feeBalance = await busdToken.balanceOf(feeCollector.address);
// Actual receive
    const actualReceive = ethers.utils.parseEther(sellAmount).sub(fee);
    expect(fee.toString()).equal(feeBalance.toString())
// expected
    expect(receiveReward.toString()).equal(reward.toString())
    expect(account2balance.toString()).equal(actualReceive.toString())
  })

  it("sell order then cancel", async ()=>{
    const depositTargetBalance = '100.0';
    const sellAmount = '1';
    const merchantTokenAddress = await p2pFactory.getMerchantByToken(busdToken.address);
    const Merchant = await ethers.getContractFactory("Merchant");
    const merchant = await Merchant.attach(merchantTokenAddress);
// deposit
    await busdToken.approve(merchant.address,ethers.utils.parseEther(depositTargetBalance))
    await merchant.setupShop(ethers.utils.parseEther(depositTargetBalance));
// request sell
    await merchant.approveTransaction(ethers.utils.parseEther(sellAmount));
// cancel
    await merchant.cancelTransaction(owner.address, ethers.utils.parseEther(sellAmount));
    const shopBalance = await merchant.getShopBalance(owner.address,{from:owner.address});

    expect(ethers.utils.formatEther(shopBalance.toString())).equal(depositTargetBalance);
  })
});
