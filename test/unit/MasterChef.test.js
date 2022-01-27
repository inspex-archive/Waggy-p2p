const { expectRevert, time } = require("@openzeppelin/test-helpers");
const { expect } = require("chai");
const { ethers,upgrades } = require("hardhat");

describe("MasterChef", () => {
  // instances
  let masterChef;
  let waggyToken;
  let busdToken;

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

    const BUSD = await hre.ethers.getContractFactory("WERC20");
    busdToken = await BUSD.deploy("BUSD", "Binacne USD");
    await busdToken.deployed();

    const WERC20 = await ethers.getContractFactory("WERC20");
    lp1 = await WERC20.deploy("LP1", "LP1");
    lp2 = await WERC20.deploy("LP2", "LP2");
    lp3 = await WERC20.deploy("LP3", "LP3");

    const WaggyToken = await ethers.getContractFactory("WaggyToken");
    waggyToken = await upgrades.deployProxy(WaggyToken,[deployer.address, "0", "100000000"]); 
    await waggyToken.deployed();

    const MasterChef = await ethers.getContractFactory("MasterChef");
    masterChef = await MasterChef.deploy(waggyToken.address, deployer.address, ethers.utils.parseEther('10'), "0");

    await waggyToken.setMinter([deployer.address, masterChef.address]);
    await waggyToken.connect(deployer).mint(alice.address, ethers.utils.parseEther("1000"));
    await waggyToken.connect(deployer).mint(bob.address, ethers.utils.parseEther("1000"));
    await waggyToken.connect(deployer).mint(eve.address, ethers.utils.parseEther("1000"));

    await waggyToken.transferOwnership(masterChef.address);

    await lp1.transfer(alice.address, ethers.utils.parseEther("2000"));
    await lp2.transfer(alice.address, ethers.utils.parseEther("2000"));
    await lp3.transfer(alice.address, ethers.utils.parseEther("2000"));

    await lp1.transfer(bob.address, ethers.utils.parseEther("2000"));
    await lp2.transfer(bob.address, ethers.utils.parseEther("2000"));
    await lp3.transfer(bob.address, ethers.utils.parseEther("2000"));

    await lp1.transfer(eve.address, ethers.utils.parseEther("2000"));
    await lp2.transfer(eve.address, ethers.utils.parseEther("2000"));
    await lp3.transfer(eve.address, ethers.utils.parseEther("2000"));
  });

  it('update multiplier', async () => {
    await masterChef.add('1000', lp1.address, true);
    await masterChef.add('1000', lp2.address, true);
    await masterChef.add('1000', lp3.address, true);

    await lp1.connect(alice).approve(masterChef.address, ethers.utils.parseEther('100'));
    await lp1.connect(bob).approve(masterChef.address, ethers.utils.parseEther('100'));

    await masterChef.connect(alice).deposit(1, ethers.utils.parseEther('100'));
    await masterChef.connect(bob).deposit(1, ethers.utils.parseEther('100'));
    await masterChef.connect(alice).deposit(1, '0');
    await masterChef.connect(bob).deposit(1, '0');

    await waggyToken.connect(alice).approve(masterChef.address, ethers.utils.parseEther('100'));
    await waggyToken.connect(bob).approve(masterChef.address, ethers.utils.parseEther('100'));
    await masterChef.connect(alice).enterStaking(ethers.utils.parseEther('50'));
    await masterChef.connect(bob).enterStaking(ethers.utils.parseEther('100'));

    await masterChef.updateMultiplier(0);

    await masterChef.connect(alice).enterStaking('0');
    await masterChef.connect(bob).enterStaking('0');
    await masterChef.connect(alice).deposit(1, '0');
    await masterChef.connect(bob).deposit(1, '0');

    let aliceInfo = { amount: 0, rewardDebt: 0 }
    alice = await masterChef.userInfo(0, alice.address);
    // console.log(ethers.utils.formatEther(aliceInfo.amount),ethers.utils.formatEther(aliceInfo.rewardDebt))

    let aliceWagBalance = await waggyToken.balanceOf(alice.address)
    let bobWagBalance = await waggyToken.balanceOf(bob.address)

    expect(ethers.utils.formatEther(aliceWagBalance)).equal('950.0');
    expect(ethers.utils.formatEther(bobWagBalance)).equal('900.0');

    const days = 1 * 24 * 60 * 60;
    await ethers.provider.send('evm_increaseTime', [days]); 
    await ethers.provider.send('evm_mine');

    await masterChef.connect(alice).enterStaking('0');
    await masterChef.connect(bob).enterStaking('0');
    await masterChef.connect(alice).deposit(1, '0');
    await masterChef.connect(bob).deposit(1, '0');

    aliceWagBalance = await waggyToken.balanceOf(alice.address)
    bobWagBalance = await waggyToken.balanceOf(bob.address)

    expect(ethers.utils.formatEther(aliceWagBalance)).equal('950.0');
    expect(ethers.utils.formatEther(bobWagBalance)).equal('900.0');

    await masterChef.connect(alice).leaveStaking('50');
    await masterChef.connect(bob).leaveStaking('100');
    await masterChef.connect(alice).withdraw(1, '100');
    await masterChef.connect(bob).withdraw(1, '100');

  });

  it("bob deposit/withdraw", async () => {
    await masterChef.add("1000", lp1.address, false);
    await masterChef.add("1000", lp2.address, false);
    await masterChef.add("1000", lp3.address, false);

    await lp1.connect(bob).approve(masterChef.address, ethers.utils.parseEther("1000"));

    await masterChef.connect(bob).deposit(1, ethers.utils.parseEther("1000"));

    let userInfo = { amount: 0, reward: 0 };
    let lp1Balance = await lp1.balanceOf(bob.address);
    userInfo = await masterChef.userInfo(1, bob.address);
    expect(ethers.utils.formatEther(lp1Balance)).equal("1000.0");
    expect(ethers.utils.formatEther(userInfo.amount)).equal("1000.0");

    await masterChef.connect(bob).withdraw(1, ethers.utils.parseEther("500"));
    lp1Balance = await lp1.balanceOf(bob.address);
    userInfo = await masterChef.userInfo(1, bob.address);
    expect(ethers.utils.formatEther(lp1Balance)).equal("1500.0");
    expect(ethers.utils.formatEther(userInfo.amount)).equal("500.0");

    await masterChef.connect(bob).withdraw(1, ethers.utils.parseEther("500"));
    lp1Balance = await lp1.balanceOf(bob.address);
    userInfo = await masterChef.userInfo(1, bob.address);
    expect(ethers.utils.formatEther(lp1Balance)).equal("2000.0");
    expect(ethers.utils.formatEther(userInfo.amount)).equal("0.0");
  });

  it("alice staking/leaveStaking", async () => {
    await waggyToken.connect(alice).approve(masterChef.address, ethers.utils.parseEther("1000"));
    const days = 10 * 24 * 60 * 60;
    await ethers.provider.send('evm_increaseTime', [days]); 
    await ethers.provider.send('evm_mine');
    let userInfo = { amount: 0, reward: 0 };

    await masterChef.connect(alice).enterStaking(ethers.utils.parseEther("100"));
    let waggyBalance = await waggyToken.balanceOf(alice.address);
    userInfo = await masterChef.userInfo(0, alice.address);
    expect(ethers.utils.formatEther(waggyBalance)).equal("900.0");
    expect(ethers.utils.formatEther(userInfo.amount)).equal("100.0");

    await ethers.provider.send('evm_increaseTime', [days]); 
    await ethers.provider.send('evm_mine');

    const pendingWag = await masterChef.pendingWag(0,alice.address);
    expect(ethers.utils.formatEther(pendingWag)).equal("10.0");

    await masterChef.connect(alice).leaveStaking(ethers.utils.parseEther("100"));
    waggyBalance = await waggyToken.balanceOf(alice.address);
    userInfo = await masterChef.userInfo(0, alice.address);
    const lockBalance = await waggyToken.lockOf(alice.address)
    expect(ethers.utils.formatEther(lockBalance)).equal("18.0");
    expect(ethers.utils.formatEther(waggyBalance)).equal("1002.0");
    expect(ethers.utils.formatEther(userInfo.amount)).equal("0.0");
  });
});
