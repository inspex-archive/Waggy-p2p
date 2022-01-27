const { BigNumber, Signer } = require("ethers");
const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");


describe("Validator", () => {
  // MasterWaggy instances
  let validator;

  // Accounts
  let deployer;
  let alice;
  let bob;
  let eve;
  let busdToken;

  beforeEach(async () => {
    [deployer, alice, bob, eve] = await ethers.getSigners();

    const BUSD = await ethers.getContractFactory("WERC20");
    busdToken = await BUSD.deploy("BUSD", "BUSD");

    await busdToken.mint(deployer.address, ethers.utils.parseEther("100000000"));
    await busdToken.mint(alice.address, ethers.utils.parseEther("100000000"));
    const balance = await busdToken.balanceOf(deployer.address)

    const Validator = await ethers.getContractFactory("Validator");
    validator  = await Validator.deploy(
        30,
        10,
        20
    );

    await validator.setAdmin(deployer.address,true);

    await busdToken.approve(validator.address, ethers.utils.parseEther("100000000"));
    await busdToken.connect(alice).approve(validator.address, ethers.utils.parseEther("100000000"));
  });
  
  it("add case", async()=>{
    const txId = "20211124000022"
    let tx = await validator.addCase(busdToken.address,txId,alice.address,bob.address,0,ethers.utils.parseEther("1000"));
    let receipt = await tx.wait(1);
    let eventParam = receipt.events.filter((x) => {return x.event == "AddCase"})[0].args;
   
    console.log("Answer1 ",ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`SELLER${eventParam.txKey}${deployer.address.toLowerCase()}`)));
     await validator.connect(deployer).play(
      eventParam.txKey,
      ethers.utils.parseEther("300"),
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`BUYER${eventParam.txKey}${deployer.address.toLowerCase()}`)),
      ""
     );
     console.log("Answer2 ",ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`BUYER${eventParam.txKey}${deployer.address.toLowerCase()}`)));
     await validator.connect(alice).play(
      eventParam.txKey,
      ethers.utils.parseEther("200"),
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`SELLER${eventParam.txKey}${deployer.address.toLowerCase()}`)),
      ""
     );
      // BUYER858198231832945349695818494933510392654199138793427791174822910477932914313480xCB950adCa1d67749486D65311Aba5efdA8351bD3
    const key = "85819823183294534969581849493351039265419913879342779117482291047793291431348"
     console.log("key ",eventParam.txKey);
    console.log("Before ",`${"BUYER"}${eventParam.txKey}${deployer.address.toLowerCase()}`)
   
    console.log("OffChain ",ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`BUYER${key}${"0xCB950adCa1d67749486D65311Aba5efdA8351bD3".toLowerCase()}`)));
    const devAnswer =  await validator.encode(eventParam.txKey);
    console.log("OnChain ",devAnswer);

    tx = await validator.evaluate(eventParam.txKey);
    receipt = await tx.wait(1);
    eventParam = receipt.events.filter((x) => {return x.event == "EvaluateResult"})[0].args;
    console.log(eventParam.result)
     console.log(ethers.utils.formatEther(eventParam.buyerAmount))
     console.log(ethers.utils.formatEther(eventParam.sellerAmount))
    //  console.log(buyyerValueCount)
    //  console.log(sellerValueCount)


  })

  it("encode", async()=>{
    const address = '0xCB950adCa1d67749486D65311Aba5efdA8351bD3'
    const key =
        '107195793141418576347547854098649660642013457272121104316908365683629193414336'
        const vote = 'BUYER'
      //   console.log("AA")
      //  console.log( ethers.utils.keccak256(ethers.utils.toUtf8Bytes(`${vote}${key}${address}`)));

  })
});