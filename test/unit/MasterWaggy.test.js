const { BigNumber, Signer } = require("ethers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");


describe("MasterWaggy", () => {
  // MasterWaggy instances
  let masterWagggy;
  let waggyToken;
  let busdToken;

  // Accounts
  let deployer;
  let alice;
  let bob;
  let eve;


  beforeEach(async () => {
    [deployer, alice, bob, eve] = await ethers.getSigners();

    const BUSD = await hre.ethers.getContractFactory("WERC20");
    busdToken = await BUSD.deploy("BUSD", "Binacne USD");

    await busdToken.deployed()

    const WaggyToken = await ethers.getContractFactory("WaggyToken");
    waggyToken = await WaggyToken.deploy();

    const WAGBalance = await waggyToken.balanceOf(deployer.address);
    console.log(`Wag balance : ${ethers.utils.formatEther(WAGBalance)}`)

    const MasterWaggy = await ethers.getContractFactory("MasterWaggy");
    masterWagggy = await MasterWaggy.deploy(waggyToken.address);
    await masterWagggy.addPool(busdToken.address);

    await waggyToken.transfer(alice.address,ethers.utils.parseEther("1000"));
    await waggyToken.transfer(bob.address,ethers.utils.parseEther("1000"));
    await waggyToken.transfer(eve.address,ethers.utils.parseEther("1000"));

    console.log(alice.address)
    await waggyToken.approve(masterWagggy.address,ethers.utils.parseEther("2000"));
    await waggyToken.connect(alice).approve(masterWagggy.address,ethers.utils.parseEther("2000"));
    await waggyToken.connect(bob).approve(masterWagggy.address,ethers.utils.parseEther("2000"));
    await waggyToken.connect(eve).approve(masterWagggy.address,ethers.utils.parseEther("2000"));

    await busdToken.approve(masterWagggy.address,ethers.utils.parseEther("2000"));
  });

  it("pool exist" ,async()=>{
    const {lastRewardBlock,users,totalDeposit,fund} = await masterWagggy.getPoolInfo(busdToken.address);
    console.log(ethers.utils.formatEther(lastRewardBlock))
    console.log(users)
    console.log(ethers.utils.formatEther(totalDeposit))
    console.log(ethers.utils.formatEther(fund))
  })

  it("Deposit Wag",async ()=>{
    const depositAmount = "1.0";
    await masterWagggy.deposit(busdToken.address, ethers.utils.parseEther(depositAmount),{from:deployer.address});
    const WAGBalance = await waggyToken.balanceOf(deployer.address);
    console.log(`Wag balance : ${ethers.utils.formatEther(WAGBalance)}`)
    const {lastRewardBlock,users, totalDeposit, fund} = await masterWagggy.getPoolInfo(busdToken.address);
    const {totalStaking,rewardDebt,depositTime} = await masterWagggy.getUserStakeInfo(deployer.address,busdToken.address);
    expect(users[0]).equal(deployer.address);
    expect(ethers.utils.formatEther(totalStaking)).equal(depositAmount);
  })

  it("Distribute Reward",async ()=>{
    await masterWagggy.connect(eve).deposit(busdToken.address, ethers.utils.parseEther('0.005'));
    await masterWagggy.connect(bob).deposit(busdToken.address, ethers.utils.parseEther('10.0'));
    await masterWagggy.connect(alice).deposit(busdToken.address, ethers.utils.parseEther('50.0'));
    await masterWagggy.deposit(busdToken.address, ethers.utils.parseEther('10.0'),{from:deployer.address});
    const days = 1 * 24 * 60 * 60;
    await ethers.provider.send('evm_increaseTime', [days]); 
    await ethers.provider.send('evm_mine');
    await masterWagggy. distributeReward(busdToken.address,ethers.utils.parseEther('1.0'));
    const {totalStaking,rewardDebt,depositTime} = await masterWagggy.getUserStakeInfo(deployer.address,busdToken.address);
    console.log(`Staking : ${ethers.utils.formatEther(totalStaking)}`) 
    console.log(`RewardDebt : ${ethers.utils.formatEther(rewardDebt)}`)
  })
});