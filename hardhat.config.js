require("@nomicfoundation/hardhat-toolbox");
const PKTestnet = "08623578f563d63af15322ea2927666c467d302fd730e7727dc7d518ec074d1a"
const PKLocal = '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d'

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
