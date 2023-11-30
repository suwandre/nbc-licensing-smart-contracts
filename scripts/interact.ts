import { createWalletClient, custom, formatEther, http, parseEther, toBytes, toHex } from "viem";
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

    const license = await hre.viem.getContractAt(
        "License",
        "0xA79c91afc157AadcDA1Cf513924EA652058418Aa",
        { walletClient }
    );

    // const getAccount = await license.read.getAccount(
    //     ["0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"]
    // );

    // console.log(getAccount);

    // await license.write.approveAccounts([
    //     ["0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"]
    // ]).then((hash) => console.log(hash));

    // // test register licensee account
    // const data = toHex(
    //     "0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15 Name name@gmail.com +4900000000000 None Germany Germany"
    // );

    // const registerAccount = await license.write.registerAccount([
    //     data
    // ]);

    // console.log(registerAccount);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });