import { createWalletClient, custom, formatEther, http, parseEther, toBytes, toHex, keccak256, hexToBigInt, formatUnits } from "viem";
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
        "0xb73C4B0a333c203D0DBc38892DA371408C626a0d",
        { walletClient }
    );

    // const checkUsable = await license.read.isLicenseUsable([
    //     "0x460107fAB29D57a6926DddC603B7331F4D3bCA05",
    //     "0x0c3a296c09e59240e2a877ed16764d8c9175dd20bebe4d5f9c734dfa1e34b1df"
    // ]);

    // console.log(checkUsable);

    // const licenseRecord = await license.read.getLicenseRecord([
    //     "0x460107fAB29D57a6926DddC603B7331F4D3bCA05",
    //     "0x0c3a296c09e59240e2a877ed16764d8c9175dd20bebe4d5f9c734dfa1e34b1df"
    // ]);

    // console.log(licenseRecord);

    const approveReport = await license.write.approveReport([
        "0x460107fAB29D57a6926DddC603B7331F4D3bCA05",
        "0x0c3a296c09e59240e2a877ed16764d8c9175dd20bebe4d5f9c734dfa1e34b1df",
        BigInt(1),
        BigInt(1702155330),
        BigInt("30000000000000000")
    ]);

    console.log(approveReport);

    // const addLicense = await license.write.addLicense([
    //     keccak256(toHex("Asset Modification")),
    //     "https://webapp.nbcompany.io/licensing/terms/asset-modification",
    // ]);

    // const addLicense2 = await license.write.addLicense([
    //     keccak256(toHex("Existing Asset Usage")),
    //     "https://webapp.nbcompany.io/licensing/terms/existing-asset-usage",
    // ]);

    // const addLicense3 = await license.write.addLicense([
    //     keccak256(toHex("Asset Creation")),
    //     "https://webapp.nbcompany.io/licensing/terms/asset-creation",
    // ]);

    // const approveAccount = await license.write.approveAccounts([
    //     [
    //         "0x460107fAB29D57a6926DddC603B7331F4D3bCA05",
    //     ]
    // ]);

    // console.log(approveAccount);


    // const checkAccount = await license.read.getAccount([
    //     "0x460107fAB29D57a6926DddC603B7331F4D3bCA05"
    // ]);

    // console.log(checkAccount);

    // const checkLicenseAgreement = await license.read.getLicenseAgreement([
    //     "0x460107fAB29D57a6926DddC603B7331F4D3bCA05",
    //     "0x0c3a296c09e59240e2a877ed16764d8c9175dd20bebe4d5f9c734dfa1e34b1df"
    // ]);

    // console.log(checkLicenseAgreement);

    // const checkLicenseFee = await license.read.getLicenseFee([
    //     "0x460107fAB29D57a6926DddC603B7331F4D3bCA05",
    //     "0xf0d7702d60c0d6b829889faaf8e2cfb30035a723fdc14eeeeae941737cd3dfe9"
    // ]);

    // console.log(checkLicenseFee);

    // const getApplication = await license.read.getLicenseAgreement([
    //     "0x460107fAB29D57a6926DddC603B7331F4D3bCA05",
    //     "0x0c3a296c09e59240e2a877ed16764d8c9175dd20bebe4d5f9c734dfa1e34b1df"
    // ]);

    // console.log(getApplication);

    // const approveApplication = await license.write.approveApplication([
    //     "0x460107fAB29D57a6926DddC603B7331F4D3bCA05",
    //     "0x0c3a296c09e59240e2a877ed16764d8c9175dd20bebe4d5f9c734dfa1e34b1df"
    // ]);

    // console.log(approveApplication);


    // const getAcc = await license.read.getAccount([
    //     "0x8FbFE537A211d81F90774EE7002ff784E352024a"
    // ]);

    // console.log(getAcc);

    // const testGetPackedData = await license.read.getPackedData([
    //     BigInt(1701694186),
    //     BigInt(0),
    //     BigInt(1701694186 + 31536000),
    //     BigInt("9000000000000000000"),
        // BigInt(7890000),
        // BigInt(1209600),
        // BigInt(1209600),
        // BigInt(0),
        // BigInt(0),
        // BigInt(0)
    // ]);

    // console.log("testGetPackedData: ", testGetPackedData);

    // const APPROVAL_DATE_BITPOS = BigInt(40);
    // const EXPIRATION_DATE_BITPOS = BigInt(80);
    // const LICENSE_FEE_BITPOS = BigInt(120);
    // const REPORTING_GRACE_PERIOD_BITPOS = BigInt(32);
    // const ROYALTY_GRACE_PERIOD_BITPOS = BigInt(64);
    // const UNTIMELY_REPORTS_BITPOS = BigInt(96);
    // const UNTIMELY_ROYALTY_PAYMENTS_BITPOS = BigInt(104);
    // const EXTRA_DATA_BITPOS = BigInt(112);

    // const firstPackedData = BigInt("11963051962064242856136358889246292050172797013625522922");
    // const secondPackedData = BigInt("22313181636754266083845200");

    // const FIRST_PACKED_DATA_ENTRY_BITMASK = BigInt("1099511627775");
    // const SECOND_PACKED_DATA_ENTRY_BITMASK = BigInt("4294967295");
    // const ROYALTY_GRACE_PERIOD_COMPLEMENT_BITMASK = BigInt("18446744073709551615");
    // const UNTIMELY_REPORTS_COMPLEMENT_BITMASK = BigInt("79228162514264337593543950335");
    // const UNTIMELY_ROYALTY_PAYMENTS_COMPLEMENT_BITMASK = BigInt("340282366920938463463374607431768211455");
    // const EXTRA_DATA_COMPLEMENT_BITMASK = BigInt("1329227995784915872903807060280344575");

    // const submissionDate = firstPackedData & FIRST_PACKED_DATA_ENTRY_BITMASK;
    // const approvalDate = (firstPackedData >> APPROVAL_DATE_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;
    // const expirationDate = (firstPackedData >> EXPIRATION_DATE_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;
    // const licenseFee = (firstPackedData >> LICENSE_FEE_BITPOS);
    // const reportingFrequency = secondPackedData & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const reportingGracePeriod = (secondPackedData >> REPORTING_GRACE_PERIOD_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const royaltyGracePeriod = (secondPackedData >> ROYALTY_GRACE_PERIOD_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const untimelyReports = (secondPackedData >> UNTIMELY_REPORTS_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const untimelyRoyaltyPayments = (secondPackedData >> UNTIMELY_ROYALTY_PAYMENTS_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const extraData = (secondPackedData >> EXTRA_DATA_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;

    // console.log("submissionDate: ", submissionDate);
    // console.log("approvalDate: ", approvalDate);
    // console.log("expirationDate: ", expirationDate);
    // console.log("licenseFee: ", licenseFee);
    // console.log("reportingFrequency: ", reportingFrequency);
    // console.log("reportingGracePeriod: ", reportingGracePeriod);
    // console.log("royaltyGracePeriod: ", royaltyGracePeriod);
    // console.log("untimelyReports: ", untimelyReports);
    // console.log("untimelyRoyaltyPayments: ", untimelyRoyaltyPayments);
    // console.log("extraData: ", extraData);

    // // test reporting grace period change
    // let newData = secondPackedData & ~(SECOND_PACKED_DATA_ENTRY_BITMASK << REPORTING_GRACE_PERIOD_BITPOS);
    // newData |= (BigInt(999600) << REPORTING_GRACE_PERIOD_BITPOS) & (SECOND_PACKED_DATA_ENTRY_BITMASK << REPORTING_GRACE_PERIOD_BITPOS);


    // const reportingFrequencyNew = newData & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const reportingGracePeriodNew = (newData >> REPORTING_GRACE_PERIOD_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const royaltyGracePeriodNew = (newData >> ROYALTY_GRACE_PERIOD_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const untimelyReportsNew = (newData >> UNTIMELY_REPORTS_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const untimelyRoyaltyPaymentsNew = (newData >> UNTIMELY_ROYALTY_PAYMENTS_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    // const extraDataNew = (newData >> EXTRA_DATA_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;

    // console.log("reportingFrequencyNew: ", reportingFrequencyNew);
    // console.log("reportingGracePeriodNew: ", reportingGracePeriodNew);
    // console.log("royaltyGracePeriodNew: ", royaltyGracePeriodNew);
    // console.log("untimelyReportsNew: ", untimelyReportsNew);
    // console.log("untimelyRoyaltyPaymentsNew: ", untimelyRoyaltyPaymentsNew);
    // console.log("extraDataNew: ", extraDataNew);
    

    // test approval date change
    // const currentTimestamp = 1701718371;
    // // let newData = firstPackedData;
    // let newData = firstPackedData & ~(FIRST_PACKED_DATA_ENTRY_BITMASK << APPROVAL_DATE_BITPOS);
    // newData |= (BigInt(currentTimestamp) << APPROVAL_DATE_BITPOS) & (FIRST_PACKED_DATA_ENTRY_BITMASK << APPROVAL_DATE_BITPOS);

    // const submissionDateNew = newData & FIRST_PACKED_DATA_ENTRY_BITMASK;
    // const approvalDateNew = (newData >> APPROVAL_DATE_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;
    // const expirationDateNew = (newData >> EXPIRATION_DATE_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;
    // const licenseFeeNew = (newData >> LICENSE_FEE_BITPOS);

    // console.log("first packed data: ", firstPackedData);
    // console.log("newData: ", newData);

    // console.log("submissionDateNew: ", submissionDateNew);
    // console.log("approvalDateNew: ", approvalDateNew);
    // console.log("expirationDateNew: ", expirationDateNew);
    // console.log("licenseFeeNew: ", licenseFeeNew);

    // const getAccount = await license.read.getAccount(
    //     ["0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"]
    // );

    // console.log(getAccount);

    // await license.write.approveAccounts([
    //     ["0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"]
    // ]).then((hash) => console.log(hash));

    // test register licensee account
    // const data = toHex(
    //     "0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15|Test User|2000-01-01T00:00:00+00:00|Test Address|test@gmail.com|+1 234 567 8901|None|United States|United States"
    // );

    // const registerAccount = await license.write.registerAccount([
    //     data
    // ]);

    // // console.log(registerAccount);

    // // const deleteAcc = await license.write.removeAccounts(
    // //     [
    // //         [
    // //             "0x2c8bb107Ca119A4C39B8174AA5333F741fb57C15"
    // //         ]
    // //     ]
    // // );

    // // console.log(deleteAcc);

    // // const checkHash = await license.read.getLicenseHash([
    // //     "Asset Modification"
    // // ]);

    // // console.log(checkHash);

    // // const checkHashViem = keccak256(toHex("Asset Modification"));

    // // console.log(checkHashViem);
    

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });