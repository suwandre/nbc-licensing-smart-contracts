// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "./LicensePermit.sol";
import "./Licensee.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @dev LicenseApplication handles all license applications.
 */
abstract contract LicenseApplication is LicensePermit, Licensee {
    /**
     * @dev Lists all possible application statuses.
     */
    enum ApplicationStatus { Pending, Approved, Rejected }

    /**
     * @dev Throws if an invalid license fee is given.
     */
    error InvalidLicenseFee(uint256 licenseFee);

    /**
     * @dev Throws if an invalid expiration date is given.
     */
    error InvalidExpirationDate(uint256 expirationDate);

    /**
     * @dev Throws if the licensee applies for a license type that they already have applied for currently.
     */
    error AlreadyAppliedForLicense(address licensee, bytes32 licenseHash);

    /**
     * @dev Throws if the recovered address via {ECDSA - recover} doesn't match the licensee's address.
     */
    error InvalidSignature(address recoveredAddress, address licensee);

    /**
     * @dev a license application data instance which contains the final terms of the license agreement (before the licensee signs it).
     *
     * NOTE: {appliedTerms} contains the full applied terms of {LicensePermit - License - baseTerms}; licensees are to use this as their main reference.
     */
    struct ApplicationData {
        // the licensee's address.
        address licensee;
        // the license type that the licensee is applying for.
        License license;
        // the license fee that the licensee must pay before the license can be used.
        uint256 licenseFee;
        // the URL that leads to the applied terms.
        string appliedTerms;
        // the license's expiration date (in unix timestamp).
        uint256 expirationDate;
    }

    /**
     * @dev the final version of {ApplicationData}, in which the licensee has confirmed and signed the application and is now awaiting approval from the licensor.
     *
     * NOTE: Only applications with a status of {ApplicationStatus.Approved} will be eligible for license usage.
     */
    struct FinalAgreement {
        // the application data instance
        ApplicationData applicationData;
        // the signature containing the {ApplicationData} instance signed by the licensee.
        bytes signature;
        // the status of the application.
        ApplicationStatus status;
        // only applicable if the application is approved.
        // once approved, the licensee must pay the license fee before the license can be used.
        bool paymentPaid;
        // can only be set to true if the licensee has paid the license fee (i.e. {paymentPaid} is true)
        bool licenseUsable;
        // any modifications to the license, if applicable. this includes restrictions.
        bytes modifications;
    }

    // maps from a licensee's address to all the final agreements they have signed and submitted.
    mapping (address => FinalAgreement[]) private licenseApplications;

    event ApplicationSubmitted(address indexed licensee, uint256 applicationIndex, string licenseType);
    event ApplicationApproved(address indexed licensee, uint256 applicationIndex, string licenseType);
    event ApplicationRejected(address indexed licensee, uint256 applicationIndex, string licenseType);

    /**
     * @dev (For licensees) Submits a new license application.
     *
     * NOTE: although any licensee can submit this application and input the parameters manually, checks will be done to ensure that each application is valid.
     * For instance, only applications approved by the licensor will be eligible for license usage.
     * Therefore, any modified applications will be rejected or left pending.
     *
     * Requirements:
     * - Checks if the license type exists, else function reverts.
     * - Checks if the license fee is not 0, else function reverts.
     * - Checks if the expiration date is not in the past, else function reverts.
     * - Checks if the licensee has already submitted an application for the given license type, else function reverts.
     */
    function submitApplication(
        License memory license,
        uint256 licenseFee,
        string calldata appliedTerms,
        uint256 expirationDate,
        bytes calldata signature,
        bytes calldata modifications,
        string memory hashSalt
    ) public onlyLicensee(_msgSender()) {
        // goes through multiple checks to ensure that some of the parameters are by default valid.
        _submitApplicationCheck(license.licenseHash, licenseFee, expirationDate);

        // gets the hash of the application.
        bytes32 _applicationHash = applicationHash(
            license.licenseHash,
            licenseFee,
            appliedTerms,
            expirationDate,
            modifications,
            hashSalt
        );

        // recovers the address of the licensee from the signature and checks whether it matches the licensee's address.
        address recoveredAddress = ECDSA.recover(_applicationHash, signature);

        if (recoveredAddress != _msgSender()) {
            revert InvalidSignature(recoveredAddress, _msgSender());
        }

        FinalAgreement memory finalAgreement = FinalAgreement({
            applicationData: ApplicationData({
                licensee: _msgSender(),
                license: license,
                licenseFee: licenseFee,
                appliedTerms: appliedTerms,
                expirationDate: expirationDate
            }),
            signature: signature,
            status: ApplicationStatus.Pending,
            paymentPaid: false,
            licenseUsable: false,
            modifications: modifications
        });

        // add the final agreement to the licensee's list of applications.
        licenseApplications[_msgSender()].push(finalAgreement);

        emit ApplicationSubmitted(_msgSender(), licenseApplications[_msgSender()].length - 1, license.licenseType);
    }

    /**
     * @dev Goes through a few checks to ensure that the given parameters for {submitApplication} is valid.
     */
    function _submitApplicationCheck(
        bytes32 licenseHash,
        uint256 licenseFee,
        uint256 expirationDate
    ) private view {
        if (getIndexByLicenseHash(licenseHash) == 0) {
            revert LicenseDoesNotExist(licenseHash);
        }

        if (licenseFee == 0) {
            revert InvalidLicenseFee(licenseFee);
        }

        if (expirationDate < block.timestamp) {
            revert InvalidExpirationDate(expirationDate);
        }

        // checks if the licensee has already submitted an application for the given license type.
        if (licenseApplications[_msgSender()].length != 0) {
            for (uint256 i = 0; i < licenseApplications[_msgSender()].length; i++) {
                if (licenseApplications[_msgSender()][i].applicationData.license.licenseHash == licenseHash) {
                    revert AlreadyAppliedForLicense(_msgSender(), licenseHash);
                }
            }
        }
    }

    /**
     * @dev Generates a unique hash for a license application.
     */
    function applicationHash(
        bytes32 licenseHash,
        uint256 licenseFee,
        string memory appliedTerms,
        uint256 expirationDate,
        bytes memory modifications,
        string memory hashSalt
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            licenseHash,
            licenseFee,
            appliedTerms,
            expirationDate,
            modifications,
            hashSalt
        ));
    }
}