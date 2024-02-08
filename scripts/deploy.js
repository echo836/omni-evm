const { ethers, run } = require("hardhat");
const fs = require("fs");
const path = require("path")

async function main() {

  const contractOwner = await ethers.getSigners();
  console.log(`Deploying contract from: ${contractOwner[0].address}`);

  const _callService = '0x5Ebb7aCB7bCaf7C1ADeFcF9660D39AC07d432904'
  const _currentNetwork = '0x61.bsc'
  const _iconBtpAddress = 'btp://0x7.icon/cx522cd1a6d55fbb54e384f24c32cb396141d40600'
  const _prices = [ethers.parseUnits("0.35",18), ethers.parseUnits("0.30",18), ethers.parseUnits("0.23",18), ethers.parseUnits("0.08",18) ]
  const ONS = await ethers.getContractFactory("ONSProxy");
  const ons = await ONS.deploy();
  const address = await ons.getAddress()
  console.log("ONS deployed to:", address);
  
  function sleep(ms) {
      return new Promise(resolve => setTimeout(resolve, ms));
  };

  await sleep(5000);
  await ons.initialize(_callService, _currentNetwork, _iconBtpAddress, _prices);
  console.log("ONS initialized");

  await run("verify:verify", {
    address: address,
  })

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
