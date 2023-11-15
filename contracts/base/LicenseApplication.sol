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
     * @dev Throws when trying to approve an application when the licensee has no applications.
     */
    error LicenseeNoApplications(address licensee);

    /**
     * @dev Throws when trying to approve an application when the application doesn't exist.
     */
    error ApplicationNotFound(address licensee, bytes32 applicationHash);

    /**
     * @dev Throws when trying to approve an application whose status is not {ApplicationStatus.Pending}.
     */
    error ApplicationNotPending(address licensee, bytes32 applicationHash, ApplicationStatus status);

    /**
     * @dev Throws when trying to approve an application when the licensee hasn't paid the license fee.
     */
    error ApplicationNotPaid(address licensee, bytes32 applicationHash);

    /**
     * @dev Throws when caller is neither one of the owners nor a licensee that owns the specified license application.
     */
    error NotOwnerOrOwnedLicensee(address caller, bytes32 applicationHash);

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

    // maps from a licensee's address to all the final agreements they have signed and submitted given the application hash for each.
    mapping (address => mapping (bytes32 => FinalAgreement)) private licenseApplications;

    event ApplicationSubmitted(address indexed licensee, bytes32 applicationHash);
    event ApplicationApproved(address indexed licensee, bytes32 applicationHash);
    event ApplicationRejected(address indexed licensee, bytes32 applicationHash);
    event ApplicationRemoved(address indexed licensee, bytes32 applicationHash, string reason);

    // this modifier checks if an application exists given the licensee's address and the application hash.
    modifier applicationExists(address licensee, bytes32 _applicationHash) {
        _checkApplicationExists(licensee, _applicationHash);
        _;
    }

    // this modifier checks if an application is pending given the licensee's address and the application hash.
    modifier applicationNotPending(address licensee, bytes32 _applicationHash) {
        _checkApplicationPending(licensee, _applicationHash);
        _;
    }

    // this modifier checks if the caller is either one of the owners or a licensee that owns the specified license application.
    modifier onlyOwnerOrOwnedLicensee(address licensee, bytes32 _applicationHash) {
        if (licenseApplications[licensee][_applicationHash].applicationData.licensee != _msgSender() && !_isOwner()) {
            revert NotOwnerOrLicensee(_msgSender());
        }
        _;
    }

    /**
     * @dev Gets the license application given the licensee's address and the application hash.
     * Can only be called by either one of the owners or the licensee that owns the specified license application.
     */
    function getApplication(address licensee, bytes32 _applicationHash) 
        public 
        onlyOwnerOrOwnedLicensee(licensee, _applicationHash)
        applicationExists(licensee, _applicationHash)
        view 
        returns (FinalAgreement memory) 
    {
        return licenseApplications[licensee][_applicationHash];
    }

    /**
     * @dev Approves a licensee's application given its {_applicationHash}. Can only be called by the owner (i.e. the licensor).
     *
     * NOTE: this function is invoked primarily once payment has been paid and proof of payment has been verified.
     * Therefore, no checks to see if {FinalAgreement - paymentPaid} is true are done here.
     *
     * Requirements:
     * - Checks if the application exists, else function reverts.
     * - Checks if the application is pending, else function reverts.
     */
    function approveApplication(address licensee, bytes32 _applicationHash) 
        public 
        applicationExists(licensee, _applicationHash)
        applicationNotPending(licensee, _applicationHash) 
        onlyOwner   
    {
        // gets the final agreement of the application.
        FinalAgreement storage finalAgreement = licenseApplications[licensee][_applicationHash];

        finalAgreement.paymentPaid = true;
        finalAgreement.status = ApplicationStatus.Approved;
        finalAgreement.licenseUsable = true;

        emit ApplicationApproved(licensee, _applicationHash);
    }

    /**
     * @dev Updates the license's modifications parameter with {modifications}. Can only be called by the owner (i.e. the licensor).
     *
     * If the license's modifications already exist (i.e. not empty/null), then it will be overwritten by {modifications}.
     */
    function addModifications(address licensee, bytes32 _applicationHash, bytes calldata modifications) 
        public 
        applicationExists(licensee, _applicationHash)
        onlyOwner 
    {
        FinalAgreement storage finalAgreement = licenseApplications[licensee][_applicationHash];

        if (finalAgreement.applicationData.licensee == address(0)) {
            revert ApplicationNotFound(licensee, _applicationHash);
        }

        finalAgreement.modifications = modifications;
    }

    /**
     * @dev Updates the {licenseUsable} parameter of the license application to its opposite. Can only be called by the owner (i.e. the licensor).
     * i.e. if {licenseUsable} was true, then {updateLicenseUsable} will convert it to false and vice versa.
     *
     * This method saves the trouble of having to create two separate functions; one to disable and one to enable.
     */
    function updateLicenseUsable(address licensee, bytes32 _applicationHash) 
        public
        applicationExists(licensee, _applicationHash)
        onlyOwner 
    {
        FinalAgreement storage finalAgreement = licenseApplications[licensee][_applicationHash];

        finalAgreement.licenseUsable = !finalAgreement.licenseUsable;
    }

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
        licenseApplications[_msgSender()][_applicationHash] = finalAgreement;

        emit ApplicationSubmitted(_msgSender(), _applicationHash);
    }

    /**
     * @dev Removes and/or terminates an existing license application from {licenseApplications}. 
     * Once removed, license is no longer valid.
     *
     * Can be called by either one of the owners or the licensee that owns the specified license application.
     */
    function removeApplication(address licensee, bytes32 _applicationHash, string memory reason) 
        public 
        applicationExists(licensee, _applicationHash)
        onlyOwnerOrOwnedLicensee(licensee, _applicationHash)
    {
        delete licenseApplications[licensee][_applicationHash];
        emit ApplicationRemoved(licensee, _applicationHash, reason);
    }

    /**
     * @dev Checks whether an application exists, else reverts.
     */
    function _checkApplicationExists(address licensee, bytes32 _applicationHash) private view {
        if (licenseApplications[licensee][_applicationHash].applicationData.licensee == address(0)) {
            revert ApplicationNotFound(licensee, _applicationHash);
        }
    }

    /**
     * @dev Checks if a given application is in a pending status, else reverts.
     */
    function _checkApplicationPending(address licensee, bytes32 _applicationHash) private view {
        if (licenseApplications[licensee][_applicationHash].status != ApplicationStatus.Pending) {
            revert ApplicationNotPending(licensee, _applicationHash, licenseApplications[licensee][_applicationHash].status);
        }
    }

    /**
     * @dev Goes through a few checks to ensure that the given parameters for {submitApplication} are valid.
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
        if (licenseApplications[_msgSender()][licenseHash].applicationData.license.licenseHash == licenseHash) {
            revert AlreadyAppliedForLicense(_msgSender(), licenseHash);
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