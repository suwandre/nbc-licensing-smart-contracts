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
        "0xaEdde0A764553081aBf8a88Fa990fdFFD96A68E2",
        { walletClient }
    );

    // const getAccount = await license.read.getAccount(
    //     ["0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"]
    // );

    // console.log(getAccount);

    // await license.write.approveAccounts([
    //     ["0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"]
    // ]).then((hash) => console.log(hash));

    // test register licensee account
    const data = toHex(
        "0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15|Test User|2000-01-01T00:00:00+00:00|Test Address|test@gmail.com|+1 234 567 8901|None|Germany|Germany"
    );

    const registerAccount = await license.write.registerAccount([
        data
    ]);

    console.log(registerAccount);

    // const deleteAcc = await license.write.removeAccounts(
    //     [
    //         [
    //             "0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"
    //         ]
    //     ]
    // );

    // console.log(deleteAcc);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });