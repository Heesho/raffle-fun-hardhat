const convert = (amount, decimals) => ethers.utils.parseUnits(amount, decimals);
const divDec = (amount, decimals = 18) => amount / 10 ** decimals;
const divDec6 = (amount, decimals = 6) => amount / 10 ** decimals;
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { execPath } = require("process");

const AddressZero = "0x0000000000000000000000000000000000000000";
const one = convert("1", 6);

let owner, multisig, treasury, user0, user1, user2, user3;
let usdc, nft;
let raffleFactory, multicall;
let raffle0;

describe("local: test0", function () {
  before("Initial set up", async function () {
    console.log("Begin Initialization");

    [owner, multisig, treasury, user0, user1, user2, user3] =
      await ethers.getSigners();

    const usdcArtifact = await ethers.getContractFactory("USDC");
    usdc = await usdcArtifact.deploy();
    console.log("- USDC Initialized");

    const nftArtifact = await ethers.getContractFactory("NFT");
    nft = await nftArtifact.deploy();
    console.log("- NFT Initialized");

    const raffleFactoryArtifact = await ethers.getContractFactory(
      "RaffleFactory"
    );
    raffleFactory = await raffleFactoryArtifact.deploy(
      usdc.address,
      AddressZero,
      3600,
      one
    );
    console.log("- RaffleFactory Initialized");

    const multicallArtifact = await ethers.getContractFactory("Multicall");
    multicall = await multicallArtifact.deploy();
    console.log("- Multicall Initialized");

    console.log("- System set up");

    console.log("Initialization Complete");
    console.log();
  });

  it("Mint USDC to users", async function () {
    console.log("******************************************************");
    const amount = convert("100000", 6);
    await usdc.connect(owner).mint(user0.address, amount);
    await usdc.connect(owner).mint(user1.address, amount);
    await usdc.connect(owner).mint(user2.address, amount);
    await usdc.connect(owner).mint(user3.address, amount);
    console.log("USDC minted to users");
  });

  it("Mint NFT to user0", async function () {
    console.log("******************************************************");
    await nft.connect(owner).mint(user0.address, "https://example.com/0");
    console.log("NFT minted to user0");
  });
});
