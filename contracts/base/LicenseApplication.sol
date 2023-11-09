// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "./LicensePermit.sol";
import "./Licensee.sol";

/**
 * @dev LicenseApplication handles all license applications.
 */
abstract contract LicenseApplication is LicensePermit, Licensee {

    /**
     * @dev Lists all possible application statuses.
     */
    enum ApplicationStatus { Pending, Approved, Rejected }

    /**
     * @dev a license application data instance which contains the final terms of the license agreement (before the licensee signs it).
     *
     * NOTE: {appliedTerms} contains the full applied terms of {LicensePermit - License - baseTerms}; licensees are to use this as their main reference.
     */
    struct ApplicationData {
        // the licensee's address.
        address licensee;
        // data containing the licensee's personal data.
        bytes personalData;
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
        bytes32 signature;
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

    // /**
    //  * @dev (For licensees) Submits a new license application.
    //  */
    // function submitApplication(
    //     address licensee, 
    //     bytes calldata personalData, 
    //     License memory license,
    //     uint256 licenseFee,
    //     string calldata appliedTerms,
    //     uint256 expirationDate,
    //     bytes32 signature
    // ) public onlyOwner {
    //     ApplicationData memory application = ApplicationData({
    //         licensee: licensee,
    //         personalData: personalData,
    //         license: license,
    //         licenseFee: licenseFee,
    //         appliedTerms: appliedTerms,
    //         expirationDate: expirationDate
    //     });
    // }

    // /**
    //  * @dev Signs an application to be submitted, called by the licensee. 
    //  */
    // function signApplication(
    //     address licensee,
    //     License memory license,
    //     string memory txSalt
    // ) public onlyOwnerOrLicensee()
}