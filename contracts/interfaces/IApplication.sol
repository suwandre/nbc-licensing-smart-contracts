// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IApplication {
    event ApplicationSubmitted(address indexed licensee, bytes32 applicationHash, uint256 timestamp);
    event ApplicationApproved(address indexed licensee, bytes32 applicationHash, uint256 timestamp);
    event ApplicationRemoved(address indexed licensee, bytes32 applicationHash, uint256 timestamp);

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

    /**
     * @dev Gets the application's {LicenseAgreement} instance.
     */
    function getLicenseAgreement(bytes32 applicationHash) external view returns (LicenseAgreement memory);

    /**
     * @dev Gets the application's submission date.
     */
    function getSubmissionDate(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's approval date (if applicable).
     */
    function getApprovalDate(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's expiration date.
     */
    function getExpirationDate(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's license fee.
     */
    function getLicenseFee(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's reporting frequency.
     */
    function getReportingFrequency(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's reporting grace period.
     */
    function getReportingGracePeriod(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's royalty grace period.
     */
    function getRoyaltyGracePeriod(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's amount of untimely reports.
     */
    function getUntimelyReports(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's amount of untimely royalty payments.
     */
    function getUntimelyRoyaltyPayments(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the application's extra data.
     */
    function getExtraData(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the license ID.
     */
    function getLicenseId(bytes32 applicationHash) external view returns (uint256);

    /**
     * @dev Gets the licensee's signature of the application.
     */
    function getSignature(bytes32 applicationHash) external view returns (bytes memory);

    /**
     * @dev Checks whether the license is usable via {LicenseAgreement.usable}.
     */
    function isLicenseUsable(bytes32 applicationHash) external view returns (bool);

    /**
     * @dev Checks whether the licensee has paid the license fee via {LicenseAgreement.feePaid}.
     */
    function isFeePaid(bytes32 applicationHash) external view returns (bool);

    /**
     * @dev Gets the modifications of the license.
     */
    function getModifications(bytes32 applicationHash) external view returns (bytes memory);
}