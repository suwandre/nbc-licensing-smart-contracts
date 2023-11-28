import { createWalletClient, custom, formatEther, http, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import hre from "hardhat";
import { bscTestnet, mainnet } from "viem/chains";
import "@nomicfoundation/hardhat-viem";

async function main() {
  const deployerWallet = privateKeyToAccount(`0x${process.env.SECONDARY_DEPLOYER_WALLET_PVT_KEY}`);

  const walletClient = createWalletClient({
    account: deployerWallet,
    chain: bscTestnet,
    transport: http("https://data-seed-prebsc-1-s1.binance.org:8545"),
  })

  const deploy = await hre.viem.deployContract("License", ["0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"], {
    walletClient
  })

  console.log(`Contract address: ${deploy.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
