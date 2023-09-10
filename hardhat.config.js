require("@nomicfoundation/hardhat-verify");
require('dotenv/config');
require("@nomicfoundation/hardhat-toolbox");
const PKTestnet = process.env.PKTestnet;
const PKLocal = process.env.PKLocal
const etherscanApiKey = process.env.ETHERSCAN_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: '0.8.18',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: etherscanApiKey
    }  
  },
  networks: {
    hardhat: {
      account: [`${PKLocal}`],
    },
    bscTestnet: {
      url: 'https://bsc-testnet.publicnode.com',
      chainId: 97,
      accounts: [`0x${PKTestnet}`],
    }
  },
};
