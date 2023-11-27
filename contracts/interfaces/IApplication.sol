// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IApplication {
    event ApplicationSubmitted(address indexed licensee, bytes32 applicationHash, uint256 timestamp);
    event ApplicationApproved(address indexed licensee, bytes32 applicationHash, uint256 timestamp);
    event ApplicationRemoved(address indexed licensee, bytes32 applicationHash, string reason, uint256 timestamp);
    event ModificationsAdded(address indexed licensee, bytes32 applicationHash, bytes modifications, uint256 timestamp);

    /**
     * @dev A license application's data. Contains the final terms of the license agreement before the licensee signs it.
     *
     * NOTE: {appliedTerms} contains the full applied terms of the license's base terms, specific to the licensee; licensees are to use this as their main reference.
     * NOTE: All dates and timestamps are in UNIX time; all durations and frequencies specified are in seconds.
     */
    struct ApplicationData {
        // the license hash of the license type the licensee is applying for. see {Permit - _licenseHash}.
        bytes32 licenseHash;
        // the URL that leads to the finalized terms and conditions of the license.
        string appliedTerms;
        // a first packed data instance containing the following values via their bit layout:
        // [0 - 39] - the application's submission date.
        // [40 - 79] - the application's approval date (if approved; else 0).
        // [80 - 119] - the license's expiration date.
        // [120 - 255] - the license fee for this license.
        uint256 firstPackedData;
        // a second packed data instance containing the following values via their bit layout:
        // [0 - 31] - the reporting frequency (frequency that a licensee must submit a revenue report and subsequently pay their royalty share).
        // [32 - 63] - the reporting grace period (amount of time given to report after the reporting frequency has passed before the licensee is penalized).
        // [64 - 95] - the royalty grace period (amount of time given to pay royalty after the revenue report for that period has been approved before the licensee is penalized).
        // [96 - 103] - the amount of untimely reports (i.e. reports that were not submitted within the reporting grace period).
        // [104 - 111] - the amount of untimely royalty payments (i.e. royalty payments that were not submitted within the royalty grace period).
        // [112 - 255] - extra data (if applicable).
        uint256 secondPackedData;
    }

    /**
     * @dev The final version of {ApplicationData}, in which the licensee has confirmed and signed the license application and is now awaiting approval from the licensor.
     *
     * NOTE: Only applications that are marked as usable will be eligible for license usage.
     */
    struct LicenseAgreement {
        // the licensee's address.
        address licensee;
        // the application ID. starts from 1 and increments by 1 for each new application.
        uint256 id;
        // the {ApplicationData} instance.
        ApplicationData data;
        // the licensee's signature of the application.
        bytes signature;
        // whether the license is usable.
        // NOTE: approved licenses may also not be usable if the licensor wishes to blacklist the license.
        bool usable;
        // whether the licensee has paid the license fee.
        bool feePaid;
        // any modifications to the license, if applicable. includes restrictions.
        bytes modifications;
    }

    function approveApplication(address licensee, bytes32 applicationHash) external;
    function addModifications(address licensee, bytes32 applicationHash, bytes memory modifications) external;
    function updateReportingFrequency(address licensee, bytes32 applicationHash, uint256 newFrequency) external;
    function updateReportingGracePeriod(address licensee, bytes32 applicationHash, uint256 newPeriod) external;
    function updateRoyaltyGracePeriod(address licensee, bytes32 applicationHash, uint256 newPeriod) external;
    function updateLicenseUsable(address licensee, bytes32 applicationHash) external;
    function submitApplication(
        bytes32 licenseHash,
        string calldata appliedTerms,
        uint256 firstPackedData,
        uint256 secondPackedData,
        bytes calldata signature,
        bytes calldata modifications,
        string calldata hashSalt
    ) external;
    function removeApplication(address licensee, bytes32 applicationHash, string calldata reason) external;
    function getLicenseAgreement(address licensee, bytes32 applicationHash) external view returns (LicenseAgreement memory);
    function getSubmissionDate(address licensee, bytes32 applicationHash) external view returns (uint256);
    function getApprovalDate(address licensee, bytes32 applicationHash) external view returns (uint256);
    function getExpirationDate(address licensee, bytes32 applicationHash) external view returns (uint256);
    function getLicenseFee(address licensee, bytes32 applicationHash) external view returns (uint256);
    function getReportingFrequency(address licensee, bytes32 applicationHash) external view returns (uint256);
    function getReportingGracePeriod(address licensee, bytes32 applicationHash) external view returns (uint256);
    function getRoyaltyGracePeriod(address licensee, bytes32 applicationHash) external view returns (uint256);
    function getUntimelyReports(address licensee, bytes32 applicationHash) external view returns (uint256);
    function incrementUntimelyReports(address licensee, bytes32 applicationHash) external;
    function getUntimelyRoyaltyPayments(address licensee, bytes32 applicationHash) external view returns (uint256);
    function incrementUntimelyRoyaltyPayments(address licensee, bytes32 applicationHash) external;
    function getExtraData(address licensee, bytes32 applicationHash) external view returns (uint256);
    function setExtraData(address licensee, bytes32 applicationHash, uint256 extraData) external;
    function getLicenseId(address licensee, bytes32 applicationHash) external view returns (uint256);
    function getSignature(address licensee, bytes32 applicationHash) external view returns (bytes memory);
    function isLicenseUsable(address licensee, bytes32 applicationHash) external view returns (bool);
    function isFeePaid(address licensee, bytes32 applicationHash) external view returns (bool);
    function getModifications(address licensee, bytes32 applicationHash) external view returns (bytes memory);
}