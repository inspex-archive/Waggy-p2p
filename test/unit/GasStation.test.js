const { expectRevert, time } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");
const { ethers,upgrades } = require("hardhat");

describe("GasStation", () => {
  // instances
  let gasStation;
  let waggyToken;
  let avatarNFT;

  // Accounts
  let deployer;
  let alice;
  let bob;
  let eve;

  let lp1;
  let lp2;
  let lp3;

  beforeEach(async () => {
    [deployer, alice, bob, eve] = await ethers.getSigners();

    const WERC20 = await ethers.getContractFactory("WERC20");
    busdToken = await WERC20.deploy("BUSD Token", "BUSD");
    const AvatarNFT = await ethers.getContractFactory("AvatarNFT");
    avatarNFT = await AvatarNFT.deploy("Avatar NFT","ANFT");

    await busdToken.mint(deployer.address,ethers.utils.parseEther("1000"));

    await avatarNFT.setPrice(ethers.utils.parseEther('0.01'));
    await avatarNFT.mint(deployer.address,{value:ethers.utils.parseEther('0.01')});
    await avatarNFT.connect(alice).mint(alice.address,{value:ethers.utils.parseEther('0.01')});
    await avatarNFT.connect(bob).mint(bob.address,{value:ethers.utils.parseEther('0.01')});

    const GasStation = await ethers.getContractFactory("GasStation");
    gasStation = await upgrades.deployProxy(GasStation,[busdToken.address]); 



  });

  it("alice staking/leaveStaking", async () => {

    await busdToken.approve(gasStation.address, ethers.utils.parseEther("1000"));

    await avatarNFT.connect(alice).approve(gasStation.address,1);
    await avatarNFT.connect(bob).approve(gasStation.address, 2);

    let balance = await avatarNFT.balanceOf(alice.address);
    console.log("Alice balance of before stake ",balance)

    const days = 10 * 24 * 60 * 60;
    await ethers.provider.send('evm_increaseTime', [days]); 
    await ethers.provider.send('evm_mine');

    await gasStation.connect(alice).stake(avatarNFT.address,1);
    balance = await avatarNFT.balanceOf(alice.address);
    console.log("Alice balance of after stake",balance)

    await ethers.provider.send('evm_increaseTime', [days]); 
    await ethers.provider.send('evm_mine');

    await gasStation.refillPool(ethers.utils.parseEther("100"));
    let pendingReward = await gasStation.connect(alice).pendingReward(alice.address);
    console.log("Pendding reward "+ ethers.utils.formatEther(pendingReward));

    await gasStation.connect(alice).unStake(avatarNFT.address,1);
    balance = await avatarNFT.balanceOf(alice.address);
    console.log("Alice balance of after unstake",balance);
   
  });
});
