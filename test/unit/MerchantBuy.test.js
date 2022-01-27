const { BigNumber, Signer } = require("ethers");
const { expect } = require("chai");
const { ethers,upgrades } = require("hardhat");

const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

describe("Merchant Buyer", () => {
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
    [deployer, merchantSeller, buyer, eve,governor] = await ethers.getSigners();

    const WaggyToken = await hre.ethers.getContractFactory("WaggyToken");
    waggyToken = await hre.upgrades.deployProxy(WaggyToken,[governor.address,9544751,9944721]);

    await waggyToken.deployed();

    // deploy reward calculator
    const RewardCalculator = await hre.ethers.getContractFactory("RewardCalculator");
    const rewardCalculator = await RewardCalculator.deploy();

    await rewardCalculator.deployed();

    // deploy fee calculator
    const FeeCalculator = await hre.ethers.getContractFactory("FeeCalculator");
    const feeCalculator = await FeeCalculator.deploy();
    await feeCalculator.deployed();

    // deploy fee calculator
    const BlackListUser = await hre.ethers.getContractFactory(
      "BlackListUser"
    );
    const blackListUser = await BlackListUser.deploy();
    await blackListUser.deployed();

    console.log("Black list address",blackListUser.address)

    // deploy merchant

    const BUSD = await hre.ethers.getContractFactory("WERC20");
    wbusd = await BUSD.deploy("BUSD", "Binacne USD");
    await wbusd.deployed();

    console.log(`WBUSD address ${wbusd.address}`);
  
    const BUSDAddress = wbusd.address;
    const Merchant = await ethers.getContractFactory("Merchant");
    merchant = await upgrades.deployProxy(Merchant,[
      BUSDAddress,
      waggyToken.address,
      rewardCalculator.address,
      feeCalculator.address,
      deployer.address,
      blackListUser.address,
    ])
    await merchant.deployed();

    await blackListUser.setAdmins([merchant.address]);

    
    // const estimateGas = await p2pfactory.estimateGas.createNewMerchant(
    //   BUSDAddress,
    //   waggyToken.address,
    //   rewardCalculator.address,
    //   feeCalculator.address,
    //   blackListUser.address,
    //   {
    //     from: deployer.address,
    //   }
    // );
    // console.log(`estimateGas used ${estimateGas}`);
    // const tx = await p2pfactory.createNewMerchant(
    //   BUSDAddress,
    //   waggyToken.address,
    //   rewardCalculator.address,
    //   feeCalculator.address,
    //   feeCalculator.address,
    //   { from: deployer.address, gasLimit: estimateGas.add(200000) }
    // );
    // await tx.wait(1);
    // const merchantsAddress = await p2pfactory.getMerchantByToken(BUSDAddress);

    // deploy fee calculator
    // const Merchant = await hre.ethers.getContractFactory("Merchant");
    // merchant = await Merchant.attach(merchantsAddress);
    // setup fund for testing
    console.log("Setup fund")
    await wbusd.connect(deployer).transfer(merchantSeller.address, ethers.utils.parseEther("10000"));
    const sellerBalance = await wbusd.balanceOf(merchantSeller.address)
    console.log(`Seller balance ${ethers.utils.formatEther(sellerBalance)}`)

    await merchant.connect(deployer).setBlackList(blackListUser.address);

    await waggyToken.setMinter([deployer.address,merchant.address]);
    // redeem reward.
    await waggyToken.connect(deployer).mint(merchant.address,ethers.utils.parseEther("100000"))
    // open shop for seller
    wbusd.connect(merchantSeller).approve(merchant.address, ethers.utils.parseEther("10000"));
    const allowance = await wbusd.connect(merchantSeller).allowance(merchantSeller.address,merchant.address)
    console.log(`Allowance this contracte : ${ethers.utils.formatEther(allowance)}`)
    await merchant.connect(merchantSeller).deposit(ethers.utils.parseEther("2000"));
    console.log('open shop done.');
    const balanceOf = await  wbusd.connect(merchantSeller).balanceOf(merchantSeller.address)
    let shopBalance = await merchant.connect(merchantSeller).shopBalance(merchantSeller.address);

   

    // check balance after open shop
    expect(ethers.utils.formatEther(balanceOf)).equal("8000.0")
    expect(ethers.utils.formatEther(shopBalance)).equal("2000.0")
  });

   it("buy" , async()=>{
    await merchant.connect(merchantSeller).approveTransaction(ethers.utils.parseEther('1'),buyer.address);

    await merchant.connect(merchantSeller).releaseTokenBySeller(buyer.address);

    const balanceOfBuyer = await  wbusd.connect(buyer).balanceOf(buyer.address);
    console.log("Buyer amount ",ethers.utils.formatEther(balanceOfBuyer));
   });

  // it("Withdraw" , async()=>{
  //   let shopBalance = await merchant.connect(merchantSeller).shopBalance(merchantSeller.address);
  //   console.log(`Shop balance ${ethers.utils.formatEther(shopBalance)}`)
  //   await merchant.connect(merchantSeller).withdraw(ethers.utils.parseEther("200"));
  //   shopBalance = await merchant.connect(merchantSeller).shopBalance(merchantSeller.address);
  //   console.log(`Shop balance ${ethers.utils.formatEther(shopBalance)}`)
  // })
  // it("Buy token happy case", async () => {
  //   // buyer want to buy 1000 BUSD wait merchant approve
  //   await merchant.connect(merchantSeller).approveTransaction(ethers.utils.parseEther("1000.0"), buyer.address);
    
  //   let amountToApprove = await await merchant.connect(deployer).getApproveTransaction(buyer.address,merchantSeller.address,ethers.utils.parseEther("1000.0"))
  //   shopBalance = await merchant.connect(merchantSeller).getShopBalance(merchantSeller.address);
  //   expect(ethers.utils.formatEther(shopBalance)).equal("1000.0")
  //   expect(ethers.utils.formatEther(amountToApprove)).equal("1000.0")
    
  //   //after buyer transfer fait success merchant should be release token to buyer
  //   await merchant.connect(merchantSeller).releaseToken(merchantSeller.address,buyer.address,ethers.utils.parseEther("1000.0"))
  //   const buyerTokenBalance = await wbusd.connect(buyer).balanceOf(buyer.address);
  //   shopBalance = await merchant.connect(merchantSeller).getShopBalance(merchantSeller.address);
  //   let rewardBalance = await waggyToken.connect(merchantSeller).balanceOf(merchantSeller.address);
  //   expect(ethers.utils.formatEther(rewardBalance)).equal("80.0") //reward 8%
  //   expect(ethers.utils.formatEther(shopBalance)).equal("1000.0")
  //   expect(ethers.utils.formatEther(buyerTokenBalance)).equal("997.5") // fee 0.25
  //   console.log('Close shop')
  //   await merchant.connect(merchantSeller).deleteShop();
  //   shopBalance = await merchant.connect(merchantSeller).getShopBalance(merchantSeller.address);
  //   expect(ethers.utils.formatEther(shopBalance)).equal("0.0")
  // });

  it("Sell token had cancel transaction", async () => {
    // buyer want to buy 1000 BUSD wait merchant approve
    shopBalance = await merchant.connect(merchantSeller).shopBalance(merchantSeller.address);
    await merchant.connect(merchantSeller).approveTransaction(ethers.utils.parseEther("1000.0"), buyer.address);
    // let amountToApprove = await await merchant.connect(deployer).getApproveTransaction(buyer.address,merchantSeller.address,ethers.utils.parseEther("1000.0"))
    shopBalance = await merchant.connect(merchantSeller).shopBalance(merchantSeller.address);
    expect(ethers.utils.formatEther(shopBalance)).equal("1000.0")
    // expect(ethers.utils.formatEther(amountToApprove)).equal("1000.0")
    //after buyer transfer fait success merchant should be release token to buyer
    await merchant.connect(buyer).cancelTransactionSeller(merchantSeller.address,"Timeout")
    const {status,amount,remark,lockAmount,createdAt,updateAt} = await merchant.getBuyerTransaction(merchantSeller.address,buyer.address);
    const buyerTokenBalance = await wbusd.connect(buyer).balanceOf(buyer.address);
    shopBalance = await merchant.connect(merchantSeller).shopBalance(merchantSeller.address);
    expect(ethers.utils.formatEther(shopBalance)).equal("1000.0")
    expect(remark).equal("Timeout")
    expect(status).equal("3")
    expect(ethers.utils.formatEther(buyerTokenBalance)).equal("0.0")
  });
});
