const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path")

async function main() {

  const contractOwner = await ethers.getSigners();
  console.log(`Deploying contract from: ${contractOwner[0].address}`);

  const _callService = '0x5Ebb7aCB7bCaf7C1ADeFcF9660D39AC07d432904'
  const _currentNetwork = '0x61.bsc'
  const _iconBtpAddress = 'btp://0x7.icon/cx36d80a09c8928ba0e564eb4cec5aa79a642c17d2'
  const _prices = [ethers.parseUnits("0.35",18), ethers.parseUnits("0.30",18), ethers.parseUnits("0.23",18), ethers.parseUnits("0.08",18) ]
  const ONS = await ethers.getContractFactory("ONSProxy");
  const ons = await ONS.deploy();
  console.log("ONS deployed to:", await ons.getAddress());

  function sleep(ms) {
      return new Promise(resolve => setTimeout(resolve, ms));
  };

  await sleep(5000);
  // const ONS = await ethers.getContractFactory("ONSProxy");
  // const ons = await ONS.attach('0x3bb3eFfE5F0E92477743136d63C73Fada668cB42');

  await ons.initialize(_callService, _currentNetwork, _iconBtpAddress, _prices);
  console.log("ONS initialized");
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
