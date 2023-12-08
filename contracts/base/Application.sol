// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../interfaces/IApplication.sol";
import "../errors/LicenseErrors.sol";
import "../base/Permit.sol";
import "../base/Licensee.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @dev License application registry and management.
 */
abstract contract Application is IApplication, IApplicationErrors, Permit, Licensee {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // the address that receives royalty and other forms of payment from the licensee.
    address internal _receiver;

    // the current application's id.
    // will always increment upwards and will never reset back in case an application is removed.
    // this should be set to 1 in the constructor.
    uint256 internal _currentApplicationIndex;

    // =============================================================
    //                           CONSTANTS
    // =============================================================
    /// bit masks and positions for {IApplication - ApplicationData - firstPackedData} fields.
    // mask of an entry in {firstPackedData}. 
    uint256 internal constant FIRST_PACKED_DATA_ENTRY_BITMASK = (1 << 40) - 1;
    uint256 internal constant APPROVAL_DATE_BITPOS = 40;
    uint256 internal constant EXPIRATION_DATE_BITPOS = 80;
    uint256 internal constant LICENSE_FEE_BITPOS = 120;

    /// bit masks and positions for {IApplication - ApplicationData - secondPackedData} fields.
    // mask of an entry in {secondPackedData}.
    uint256 internal constant SECOND_PACKED_DATA_ENTRY_BITMASK = (1 << 32) - 1;
    // mask of all 256 bits in {secondPackedData} except for the 32 bits of the royalty grace period.
    uint256 internal constant ROYALTY_GRACE_PERIOD_COMPLEMENT_BITMASK = (1 << 64) - 1;
    // mask of all 256 bits in {secondPackedData} except for the 32 bits of the untimely report count.
    uint256 internal constant UNTIMELY_REPORTS_COMPLEMENT_BITMASK = (1 << 96) - 1;
    // mask of all 256 bits in {secondPackedData} except for the 32 bits of the untimely royalty payment count.
    uint256 internal constant UNTIMELY_ROYALTY_PAYMENTS_COMPLEMENT_BITMASK = (1 << 104) - 1;
    // mask of all 256 bits in {secondPackedData} except for the 144 bits of the extra data.
    uint256 internal constant EXTRA_DATA_COMPLEMENT_BITMASK = (1 << 112) - 1;
    uint256 internal constant REPORTING_GRACE_PERIOD_BITPOS = 32;
    uint256 internal constant ROYALTY_GRACE_PERIOD_BITPOS = 64;
    uint256 internal constant UNTIMELY_REPORTS_BITPOS = 96;
    uint256 internal constant UNTIMELY_ROYALTY_PAYMENTS_BITPOS = 104;
    uint256 internal constant EXTRA_DATA_BITPOS = 112;


    // a mapping from a licensee's address to an application hash to the license agreement instance.
    mapping(address => mapping(bytes32 => LicenseAgreement)) internal _licenseAgreement;

    // checks whether the caller is an owner or owns the specified license, else reverts.
    modifier onlyOwnerOrLicenseOwner(address licensee, bytes32 applicationHash) {
        _checkOwnerOrLicenseOwner(licensee, applicationHash);
        _;
    }

    // checks whether the specified application exists, else reverts.
    modifier applicationExists(address licensee, bytes32 applicationHash) {
        _checkApplicationExists(licensee, applicationHash);
        _;
    }

    // checks whether the licensee has paid the license fee, else reverts.
    modifier hasPaidFee(address licensee, bytes32 applicationHash) {
        _checkIsFeePaid(licensee, applicationHash);
        _;
    }

    // the opposite of `hasPaidFee`; checks whether the licensee has not paid the license fee, else reverts.
    // this is used purely for `payLicenseFee` to ensure that the licensee hasn't paid the license fee yet and avoid double paying.
    modifier hasNotPaidFee(address licensee, bytes32 applicationHash) {
        if (isFeePaid(licensee, applicationHash)) {
            revert ApplicationAlreadyPaid(licensee, applicationHash);
        }
        _;
    }

    // a modifier to check whether a license is usable.
    // here, we assume that a usable license means it's already approved. thus, this modifier is primarily only used to revert if the license is already usable.
    modifier onlyUnusableLicense(address licensee, bytes32 applicationHash) {
        _checkLicenseUsable(licensee, applicationHash);
        _;
    }

    // a modifier to check whether a license is usable.
    // unlike {onlyUnusableLicense}, this modifier is used to revert if the license is not usable; thus the opposite.
    modifier onlyUsableLicense(address licensee, bytes32 applicationHash) {
        if (!isLicenseUsable(licensee, applicationHash)) {
            revert LicenseNotUsable(licensee, applicationHash);
        }
        _;
    }

    /**
     * @dev (For licensors) Approves a licensee's application for a license given its {_applicationHash}.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the application must exist.
     * - the licensee must have paid the license fee.
     * - the license must not be usable.
     */
    function approveApplication(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
        hasPaidFee(licensee, applicationHash)
        onlyUnusableLicense(licensee, applicationHash)
    {
        // get the license agreement.
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // sets the license agreement's approval date to the current block timestamp.
        licenseAgreement.data.firstPackedData = (licenseAgreement.data.firstPackedData & FIRST_PACKED_DATA_ENTRY_BITMASK) | (block.timestamp << APPROVAL_DATE_BITPOS);
        licenseAgreement.usable = true;

        emit ApplicationApproved(licensee, applicationHash, block.timestamp);
    }

    /**
     * @dev Updates a license's modifications with the specified {modifications}.
     *
     * If the license's modifications already exist, then it will be overwritten by {modifications}.
     */
    function addModifications(address licensee, bytes32 applicationHash, bytes calldata modifications)
        public 
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
    {
        // get the license agreement.
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // add the modifications.
        licenseAgreement.modifications = modifications;

        emit ModificationsAdded(licensee, applicationHash, modifications, block.timestamp);
    }

    /**
     * @dev (For licensors) Updates a license's reporting frequency with the specified {newFrequency}.
     */
    function updateReportingFrequency(address licensee, bytes32 applicationHash, uint256 newFrequency)
        public
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
    {
        // get the license agreement.
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // update the reporting frequency.
        licenseAgreement.data.secondPackedData = (licenseAgreement.data.secondPackedData & SECOND_PACKED_DATA_ENTRY_BITMASK) | newFrequency;
    }

    /**
     * @dev (For licensors) Updates a license's reporting grace period with the specified {newPeriod}.
     */
    function updateReportingGracePeriod(address licensee, bytes32 applicationHash, uint256 newPeriod)
        public
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
    {
        // get the license agreement.
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // update the reporting grace period.
        licenseAgreement.data.secondPackedData = (licenseAgreement.data.secondPackedData & SECOND_PACKED_DATA_ENTRY_BITMASK) | (newPeriod << REPORTING_GRACE_PERIOD_BITPOS);
    }

    /**
     * @dev (For licensors) Updates a license's royalty grace period with the specified {newPeriod}.
     */
    function updateRoyaltyGracePeriod(address licensee, bytes32 applicationHash, uint256 newPeriod)
        public
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
    {
        // get the license agreement.
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // update the royalty grace period.
        licenseAgreement.data.secondPackedData = (licenseAgreement.data.secondPackedData & ROYALTY_GRACE_PERIOD_COMPLEMENT_BITMASK) | (newPeriod << ROYALTY_GRACE_PERIOD_BITPOS);
    }

    /**
     * @dev (For licensors) Updates the {LicenseAgreement.usable} field of a license agreement to its opposite.
     * i.e. If the license is usable, then it will be set to false; if it's not usable, then it will be set to true.
     *
     * This method saves the trouble of having to create two separate functions; one to set to true and one to set to false.
     */
    function updateLicenseUsable(address licensee, bytes32 applicationHash)
        public
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
    {
        // get the license agreement.
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // update the license's usability.
        licenseAgreement.usable = !licenseAgreement.usable;
    }

    /**
     * @dev (For licensees) Submits a license application.
     *
     * NOTE: Although any licensee can submit this application and input random parameters, checks will be done to ensure valid parameters.
     * For instance, only applications approved by the licensor will be eligible for license usage.
     * Therefore, any modified/illegitimate applications will be rejected or left unusable.
     *
     * NOTE: Although a licensee can only apply for a specific license type once, they can technically apply for multiple applications for one license type via this function.
     * However, the licensor is obliged to only approve one of the valid applications and leave the rest unusable/rejected.
     * Checks for existing applications for a license type will therefore not be done here.
     *
     * Requirements:
     * - Checks if the license hash exists, else reverts.
     * - Checks if the license fee is not 0, else reverts.
     * - Checks if the expiration date is not in the past, else reverts.
     */
    function submitApplication(
        bytes32 licenseHash,
        uint256 firstPackedData,
        uint256 secondPackedData,
        bytes calldata signature,
        bytes calldata modifications,
        string calldata hashSalt
    ) public virtual onlyLicensee {
        // get the license fee
        uint256 licenseFee = (firstPackedData >> LICENSE_FEE_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;

        // get the expiration date
        uint256 expirationDate = (firstPackedData >> EXPIRATION_DATE_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;

        // goes through a few checks to ensure that some of the parameters are valid.
        _submitApplicationCheck(licenseFee, expirationDate);

        // gets the hash of the application.
        bytes32 applicationHash = getApplicationHash(
            _msgSender(),
            licenseHash,
            firstPackedData,
            secondPackedData,
            modifications,
            hashSalt
        );

        // get the eth signed message.
        bytes32 messageHash = MessageHashUtils.toEthSignedMessageHash(applicationHash);

        // recover the licensee's address from the signature and checks whether it matches the caller's address.
        address recoveredAddress = ECDSA.recover(messageHash, signature);

        if (recoveredAddress != _msgSender()) {
            revert InvalidSignature(recoveredAddress, _msgSender());
        }

        LicenseAgreement memory licenseAgreement = LicenseAgreement({
            licensee: _msgSender(),
            id: _getCurrentIndex(),
            data: ApplicationData({
                licenseHash: licenseHash,
                firstPackedData: firstPackedData,
                secondPackedData: secondPackedData
            }),
            signature: signature,
            usable: false,
            feePaid: false,
            modifications: modifications
        });

        // add the license agreement to the mapping.
        _licenseAgreement[_msgSender()][applicationHash] = licenseAgreement;

        // increment the current application index.
        _addApplicationIndex();

        emit ApplicationSubmitted(_msgSender(), applicationHash, block.timestamp);
    }

    /**
     * @dev (For licensees) Pays the license fee to {_receiver} for a license application.
     *
     * Only available for license applications that haven't been paid for yet.
     */
    function payLicenseFee(bytes32 applicationHash)
        external
        virtual
        payable
        onlyOwnerOrLicenseOwner(_msgSender(), applicationHash)
        applicationExists(_msgSender(), applicationHash)
        hasNotPaidFee(_msgSender(), applicationHash)
    {
        // get the license fee amount
        uint256 licenseFee = _licenseAgreement[_msgSender()][applicationHash].data.firstPackedData >> LICENSE_FEE_BITPOS;

        // pay the license fee.
        payable(_receiver).transfer(licenseFee);

        // set the fee paid to true.
        _licenseAgreement[_msgSender()][applicationHash].feePaid = true;
    }

    /**
     * @dev (For licensor and license owner) Removes and/or terminates a license application made by {licensee}.
     * Once removed, license is no longer valid.
     *
     * Can either be called by an owner or the licensee that owns the specified license.

     */
    function removeApplication(address licensee, bytes32 applicationHash, string calldata reason) 
        public 
        virtual 
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
    {
        // remove the license agreement.
        delete _licenseAgreement[licensee][applicationHash];

        emit ApplicationRemoved(licensee, applicationHash, reason, block.timestamp);
    }

    /**
     * @dev (For licensees and owners) Gets {licensee}'s license agreement for the specified application.
     * NOTE: If the caller is neither an owner nor the license agreement's owner, this will revert.
     */
    function getLicenseAgreement(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view 
        returns (LicenseAgreement memory) 
    {
        return _licenseAgreement[licensee][applicationHash];
    }

    /**
     * @dev Gets the submission date for a license application.
     */
    function getSubmissionDate(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256) 
    {
        return _licenseAgreement[licensee][applicationHash].data.firstPackedData & FIRST_PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev Gets the approval date for a license application.
     */
    function getApprovalDate(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return (_licenseAgreement[licensee][applicationHash].data.firstPackedData >> APPROVAL_DATE_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev Gets the expiration date for a license application.
     */
    function getExpirationDate(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return (_licenseAgreement[licensee][applicationHash].data.firstPackedData >> EXPIRATION_DATE_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev Gets the license fee for a license application.
     */
    function getLicenseFee(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return _licenseAgreement[licensee][applicationHash].data.firstPackedData >> LICENSE_FEE_BITPOS;
    }

    /**
     * @dev Gets the reporting frequency for a license application.
     */
    function getReportingFrequency(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return _licenseAgreement[licensee][applicationHash].data.secondPackedData & SECOND_PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev Gets the reporting grace period for a license application.
     */
    function getReportingGracePeriod(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return (_licenseAgreement[licensee][applicationHash].data.secondPackedData >> REPORTING_GRACE_PERIOD_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev Gets the royalty grace period for a license application.
     */
    function getRoyaltyGracePeriod(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return (_licenseAgreement[licensee][applicationHash].data.secondPackedData >> ROYALTY_GRACE_PERIOD_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev Gets the amount of untimely reports for a license application.
     */
    function getUntimelyReports(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return (_licenseAgreement[licensee][applicationHash].data.secondPackedData >> UNTIMELY_REPORTS_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev (For licensors) Increments the {untimelyReports} field within {LicenseAgreement.data.secondPackedData} by 1.
     */
    function incrementUntimelyReports(address licensee, bytes32 applicationHash)
        public
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
    {
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // increment the untimely reports by 1.
        licenseAgreement.data.secondPackedData = 
            (licenseAgreement.data.secondPackedData & UNTIMELY_REPORTS_COMPLEMENT_BITMASK) | ((licenseAgreement.data.secondPackedData >> UNTIMELY_REPORTS_BITPOS) + 1) << UNTIMELY_REPORTS_BITPOS;
    }

    /**
     * @dev Gets the amount of untimely royalty payments for a license application.
     */
    function getUntimelyRoyaltyPayments(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return (_licenseAgreement[licensee][applicationHash].data.secondPackedData >> UNTIMELY_ROYALTY_PAYMENTS_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    }
    
    /**
     * @dev (For licensors) Increments the {untimelyRoyaltyPayments} field within {LicenseAgreement.data.secondPackedData} by 1.
     */
    function incrementUntimelyRoyaltyPayments(address licensee, bytes32 applicationHash)
        public
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
    {
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // increment the untimely royalty payments by 1.
        licenseAgreement.data.secondPackedData = (licenseAgreement.data.secondPackedData & UNTIMELY_ROYALTY_PAYMENTS_COMPLEMENT_BITMASK) | ((licenseAgreement.data.secondPackedData >> UNTIMELY_ROYALTY_PAYMENTS_BITPOS) + 1) << UNTIMELY_ROYALTY_PAYMENTS_BITPOS;
    }

    /**
     * @dev Gets the extra data for a license application.
     */
    function getExtraData(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return (_licenseAgreement[licensee][applicationHash].data.secondPackedData >> EXTRA_DATA_BITPOS) & SECOND_PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev (For licensors) Sets the extra data for a license application.
     */
    function setExtraData(address licensee, bytes32 applicationHash, uint256 extraData)
        public
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
    {
        LicenseAgreement storage licenseAgreement = _licenseAgreement[licensee][applicationHash];

        // ensure that the extra data is not greater than 2^144 - 1.
        if (extraData > ((1 << 144) - 1)) {
            revert InvalidExtraDataLength(extraData);
        }

        licenseAgreement.data.secondPackedData |= extraData << EXTRA_DATA_BITPOS;
    }

    /**
     * @dev Gets the license ID for a license application.
     */
    function getLicenseId(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        return _licenseAgreement[licensee][applicationHash].id;
    }

    /**
     * @dev Gets the licensee's signature of the application.
     */
    function getSignature(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (bytes memory)
    {
        return _licenseAgreement[licensee][applicationHash].signature;
    }

    /**
     * @dev Checks whether the license is usable via {LicenseAgreement.usable}.
     * Usability here is accountable for licenses being usable and approved. 
     * If {usable} is true, then the license is approved and usable.
     * If {usable} is false, then the license can be temporarily "unapproved" and rendered unusable.
     */
    function isLicenseUsable(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (bool)
    {
        return _licenseAgreement[licensee][applicationHash].usable;
    }

    /**
     * @dev Checks whether the licensee has paid the license fee via {LicenseAgreement.feePaid}.
     */
    function isFeePaid(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (bool)
    {
        return _licenseAgreement[licensee][applicationHash].feePaid;
    }

    /**
     * @dev Gets the modifications of a license.
     */
    function getModifications(address licensee, bytes32 applicationHash) 
        public 
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        view
        returns (bytes memory)
    {
        return _licenseAgreement[licensee][applicationHash].modifications;
    }

    /**
     * @dev Calls {isLicenseUsable} and reverts if the license is already usable. 
     * Primarily used to revert if a licensor tries to approve an already usable license.
     */
    function _checkLicenseUsable(address licensee, bytes32 applicationHash) private view {
        if (isLicenseUsable(licensee, applicationHash)) {
            revert LicenseAlreadyUsable(licensee, applicationHash);
        }
    }

    /**
     * @dev Calls {isFeePaid} and reverts if the licensee hasn't paid the license fee.
     */
    function _checkIsFeePaid(address licensee, bytes32 applicationHash) private view {
        if (!isFeePaid(licensee, applicationHash)) {
            revert ApplicationNotPaid(licensee, applicationHash);
        }
    }

    /**
     * @dev Calls {_applicationExists} and reverts if the application doesn't exist.
     */
    function _checkApplicationExists(address licensee, bytes32 applicationHash) private view {
        if (!_applicationExists(licensee, applicationHash)) {
            revert ApplicationNotFound(licensee, applicationHash);
        }
    }

    /**
     * @dev Checks whether a licensee's license agreement for the specified application exists.
     * This can be done by simply checking whether the {licensee} field of the license agreement is not `address(0)`.
     */
    function _applicationExists(address licensee, bytes32 applicationHash) private view returns (bool) {
        return _licenseAgreement[licensee][applicationHash].licensee != address(0);
    }

    /**
     * @dev Calls {_isOwnerOrLicenseOwner} and reverts if the caller is neither an owner nor the licensee who owns the specified license application.
     */
    function _checkOwnerOrLicenseOwner(address licensee, bytes32 applicationHash) private view {
        if (!_isOwnerOrLicenseOwner(licensee, applicationHash)) {
            revert NotOwnerOrLicenseOwner(_msgSender(), applicationHash);
        }
    }

    /**
     * @dev Checks whether the caller is an owner or is the licensee who owns the specified license application.s
     */
    function _isOwnerOrLicenseOwner(address licensee, bytes32 applicationHash) private view returns (bool) {
        return isOwner() || _licenseAgreement[licensee][applicationHash].licensee == _msgSender();
    }

        /**
     * @dev Multiple checks for {submitApplication} to ensure that these parameters are valid.
     */
    function _submitApplicationCheck(uint256 licenseFee, uint256 expirationDate) private view {
        // ensure that the license fee is not greater than 2^144 - 1.
        if (licenseFee > ((1 << 144) - 1)) {
            revert InvalidLicenseFee(licenseFee);
        }

        // ensure that the expiration date is not in the past or now.
        if (expirationDate <= block.timestamp) {
            revert InvalidExpirationDate(expirationDate);
        }
    }

    /**
     * @dev Generates a bytes32 hash for a license application given the specified parameters.
     */
    function getApplicationHash(
        address licensee,
        bytes32 licenseHash, 
        uint256 firstPackedData, 
        uint256 secondPackedData, 
        bytes calldata modifications, 
        string calldata hashSalt
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                licensee,
                licenseHash,
                firstPackedData, 
                secondPackedData, 
                modifications, 
                hashSalt
            )
        );
    }

    /**
     * @dev Packs the specified parameters into two uint256 variables - {firstPackedData} and {secondPackedData}.
     */
    function getPackedData(
        uint256 submissionDate,
        uint256 approvalDate,
        uint256 expirationDate,
        uint256 licenseFee,
        uint256 reportingFrequency,
        uint256 reportingGracePeriod,
        uint256 royaltyGracePeriod,
        uint256 untimelyReports,
        uint256 untimelyRoyaltyPayments,
        uint256 extraData
    ) public pure returns (uint256 firstPackedData, uint256 secondPackedData) {
        firstPackedData = 0;
        secondPackedData = 0;
        
        firstPackedData |= submissionDate;
        firstPackedData |= approvalDate << APPROVAL_DATE_BITPOS;
        firstPackedData |= expirationDate << EXPIRATION_DATE_BITPOS;
        firstPackedData |= licenseFee << LICENSE_FEE_BITPOS;

        secondPackedData |= reportingFrequency;
        secondPackedData |= reportingGracePeriod << REPORTING_GRACE_PERIOD_BITPOS;
        secondPackedData |= royaltyGracePeriod << ROYALTY_GRACE_PERIOD_BITPOS;
        secondPackedData |= untimelyReports << UNTIMELY_REPORTS_BITPOS;
        secondPackedData |= untimelyRoyaltyPayments << UNTIMELY_ROYALTY_PAYMENTS_BITPOS;
        secondPackedData |= extraData << EXTRA_DATA_BITPOS;

        return (firstPackedData, secondPackedData);
    }

    /**
     * @dev Returns {_currentApplicationIndex}.
     */
    function _getCurrentIndex() private view returns (uint256) {
        return _currentApplicationIndex;
    }

    /**
     * @dev Increments {_currentApplicationIndex} by 1.
     */
    function _addApplicationIndex() private {
        unchecked {
            _currentApplicationIndex++;
        }
    }
}