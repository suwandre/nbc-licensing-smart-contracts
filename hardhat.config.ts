import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import * as dotenv from 'dotenv';

dotenv.config();

const deployerWallet: string = process.env.SECONDARY_DEPLOYER_WALLET_PVT_KEY ?? '';
const wallet0x46: string = process.env.WALLET_0x46_PVT_KEY ?? '';

const config: HardhatUserConfig = {
  defaultNetwork: "bnbTestnet",
  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY,
  },
  networks: {
    bnbTestnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      accounts: [`0x${wallet0x46}`],
      gasPrice: "auto",
    }
  },
  solidity: {
    version: "0.8.22",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  }
};

export default config;
