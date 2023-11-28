// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev All errors related to the {Licensee} contract.
 */
interface ILicenseeErrors {
    /**
     * @dev Throws if the caller is neither an owner nor a licensee.
     */
    error NotOwnerOrLicensee(address caller);

    /**
     * @dev Throws if an account with the given {licensee} address already exists within {Licensee - _licenseeAccount}.
     */
    error LicenseeAlreadyExists(address licensee);

    /**
     * @dev Throws if the given {licensee} address is invalid (e.g. `address(0)`).
     */
    error InvalidLicenseeAddress(address licensee);

    /**
     * @dev Throws if the given licensee data is empty.
     */
    error EmptyLicenseeData();

    /**
     * @dev Throws if the given {data} is the same as the data inside the {Licensee - _licenseeAccount} instance.
     */
    error SameLicenseeData(bytes data);

    /**
     * @dev Throws if the licensee's account status is not {LicenseeStatus.Pending}.
     */
    error AccountStatusNotPending(address licensee);

    /**
     * @dev Throws if the given licensee account doesn't exist within {_licenseeAccount}.
     */
    error LicenseeDoesntExist(address licensee);
}

/**
 * @dev All errors related to the {Permit} contract.
 */
interface IPermitErrors {
    /**
     * @dev Throws if the base terms URL of a license to change is the same as the previous base terms URL.
     */
    error SameBaseTerms(string url);

    /**
     * @dev Throws if the given base terms URL is empty.
     */
    error EmptyBaseTerms();

    /**
     * @dev Throws if the given new terms URL is empty.
     */
    error EmptyNewTerms();

    /**
     * @dev Throws when adding, removing or updating a license when the license hash is empty or not given.
     */
    error EmptyLicenseHash();

    /**
     * @dev Throws if a license doesn't exist.
     */
    error LicenseDoesntExist(bytes32 licenseHash);

    /**
     * @dev Throws if a license already exists.
     */
    error LicenseAlreadyExists(bytes32 licenseHash);
}

/**
 * @dev All errors related to the {Application} contract.
 */
interface IApplicationErrors {
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
     * @dev Throws when trying to approve an application when the licensee has no applications.
     */
    error LicenseeNoApplications(address licensee);

    /**
     * @dev Throws when trying to approve an application when the application doesn't exist.
     */
    error ApplicationNotFound(address licensee, bytes32 applicationHash);

    /**
     * @dev Throws when trying to approve an application when the licensee hasn't paid the license fee.
     */
    error ApplicationNotPaid(address licensee, bytes32 applicationHash);

    /**
     * @dev Throws when caller is neither one of the owners nor a licensee that owns the specified license application.
     */
    error NotOwnerOrLicenseOwner(address caller, bytes32 applicationHash);

    /**
     * @dev Throws when trying to approve an application when {LicenseAgreement.usable} is already true.
     */
    error LicenseAlreadyUsable(address licensee, bytes32 applicationHash);

    /**
     * @dev Throws when trying to do certain actions on an application when {LicenseAgreement.usable} is false.
     */
    error LicenseNotUsable(address licensee, bytes32 applicationHash);

    /**
     * @dev Throws when trying to set an extra data value that's too large.
     */
    error InvalidExtraDataLength(uint256 extraData);
}

/**
 * @dev All errors related to the {Royalty} contract.
 */
interface IRoyaltyErrors {
    /**
     * @dev Throws when trying to set the receiver address to an invalid address (e.g. `address(0)`).
     */
    error InvalidReceiverAddress(address receiver);

    /**
     * @dev Throws when trying to set the receiver address to the same address as the current receiver address.
     */
    error SameReceiverAddress();

    /**
     * @dev Throws when the royalty for a specific report has already been paid.
     */
    error RoyaltyAlreadyPaid(address licensee, bytes32 applicationHash, uint256 reportIndex);

    /**
     * @dev Throws when the licensee pays a different amount than the amount due.
     */
    error RoyaltyAmountMismatch(address licensee, bytes32 applicationHash, uint256 reportIndex, uint256 royaltyDue, uint256 royaltyToPay);

    /**
     * @dev Throws when the licensee tries to pay royalty for a report that hasn't been approved yet.
     */
    error ReportNotYetApproved(address licensee, bytes32 applicationHash, uint256 reportIndex);

    /**
     * @dev Throws when trying to change a report when the report has already been approved.
     */
    error ReportAlreadyApproved(address licensee, bytes32 applicationHash, uint256 reportIndex);

    /**
     * @dev Throws when a licensee tries to report a new revenue report when not yet allowed.
     */
    error NewReportNotYetAllowed(address licensee, bytes32 applicationHash);

    /**
     * @dev Throws when trying to access or do actions when a specific report to index doesn't exist.
     */
    error ReportDoesntExist(address licensee, bytes32 applicationHash);

    /**
     * @dev Throws when a licensor wants to add an untimely report count when the report is not yet due.
     */
    error UntimelyReportNotRequired(address licensee, bytes32 applicationHash, uint256 reportIndex);

    /**
     * @dev Throws when trying to increase the untimely royalty payment count when the royalty is not yet due.
     */
    error RoyaltyPaymentNotYetNeeded(address licensee, bytes32 applicationHash, uint256 reportIndex);

    /**
     * @dev Throws when a licensor wants to add an untimely royalty payment count when the royalty is not yet due (or not yet added)
     */
    error RoyaltyNoDeadline(address licensee, bytes32 applicationHash, uint256 reportIndex);
}