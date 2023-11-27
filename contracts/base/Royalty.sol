// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../interfaces/IRoyalty.sol";
import "../errors/LicenseErrors.sol";
import "./Application.sol";

/**
 * @dev License revenue report, royalty statement and payment management.
 */
abstract contract Royalty is IRoyalty, IRoyaltyErrors, Application {
    // the address that receives royalty from the licensee.
    address internal _receiver;

    // a mapping from a licensee's address to the application hash to a {LicenseRecord} instance.
    mapping(address => mapping(bytes32 => LicenseRecord)) private _licenseRecord;

    // =============================================================
    //                           CONSTANTS
    // =============================================================
    // bit masks and positions for {Report.packedData} fields.
    uint256 internal constant SUBMISSION_TIMESTAMP_BITMASK = (1 << 40) - 1;
    uint256 internal constant APPROVAL_TIMESTAMP_BITMASK = ((1 << 40) - 1) << 40;
    uint256 internal constant ROYALTY_PAYMENT_DEADLINE_BITMASK = ((1 << 40) - 1) << 80;
    uint256 internal constant ROYALTY_PAYMENT_TIMESTAMP_BITMASK = ((1 << 40) - 1) << 120;
    uint256 internal constant REPORT_CHANGE_TIMESTAMP_BITMASK = ((1 << 40) - 1) << 160;
    uint256 internal constant EXTRA_DATA_BITMASK = ((1 << 56) - 1) << 200;

    uint256 internal constant SUBMISSION_TIMESTAMP_BITPOS = 0;
    uint256 internal constant APPROVAL_TIMESTAMP_BITPOS = 40;
    uint256 internal constant ROYALTY_PAYMENT_DEADLINE_BITPOS = 80;
    uint256 internal constant ROYALTY_PAYMENT_TIMESTAMP_BITPOS = 120;
    uint256 internal constant REPORT_CHANGE_TIMESTAMP_BITPOS = 160;
    uint256 internal constant EXTRA_DATA_BITPOS = 200;

    // checks whether a licensee is allowed to submit a new report for a license, else reverts.
    modifier newReportAllowed(address licensee, bytes32 applicationHash) {
        _checkNewReportAllowed(licensee, applicationHash);
        _;
    }

    // checks whether a licensee is allowed to change the latest report for a license, else reverts.
    modifier reportChangeable(address licensee, bytes32 applicationHash) {
        _checkReportChangeable(licensee, applicationHash);
        _;
    }

    /**
     * @dev Gets the {_reciever} address.
     */
    function getReceiver() public view virtual returns (address) {
        return _receiver;
    }

    /**
     * @dev Sets (or changes) the {_receiver} address to {newReceiver}.
     */
    function setReceiver(address receiver) public virtual onlyOwner {
        if (receiver == address(0)) {
            revert InvalidReceiverAddress(receiver);
        }

        if (_receiver == receiver) {
            revert SameReceiverAddress();
        }

        _receiver = receiver;
    }

    /**
     * @dev (For licensors and license owners) Submits a revenue report for {licensee} for a specific license with the given {applicationHash}.
     */
    function submitReport(address licensee, bytes32 applicationHash, string calldata url)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        onlyUsableLicense(licensee, applicationHash)
        newReportAllowed(licensee, applicationHash)
    {
        // firstly, check whether the report was submitted on time. if not, then increment the untimely report count.
        // a report is considered untimely if it has passed the reporting frequency + reporting grace period.
        LicenseRecord storage licenseRecord = _licenseRecord[licensee][applicationHash];
        // check if there were previous reports before the new one is submitted.
        // if there is, then we check whether the previous report was submitted on time.
        if (licenseRecord.reports.length > 0) {
            // get the previous report
            Report memory previousReport = licenseRecord.reports[licenseRecord.reports.length - 1];

            // get the previous report's submission timestamp
            uint256 previousSubmissionTimestamp = (previousReport.packedData >> SUBMISSION_TIMESTAMP_BITPOS) & SUBMISSION_TIMESTAMP_BITMASK;

            // get the reporting frequency
            uint256 reportingFrequency = getReportingFrequency(licensee, applicationHash);

            // get the reporting grace period
            uint256 reportingGracePeriod = getReportingGracePeriod(licensee, applicationHash);

            // if the previous report's submission timestamp is not 0, then we check whether the report was submitted on time.
            // if it's not, then we increment the untimely report count.
            if (previousSubmissionTimestamp + reportingFrequency + reportingGracePeriod < block.timestamp) {
                // increment the untimely report count
                incrementUntimelyReports(licensee, applicationHash);

                emit UntimelyReport(licensee, applicationHash, licenseRecord.reports.length - 1, block.timestamp);
            }
        }

        uint256 submissionTimestamp = block.timestamp;
        uint256 approvalTimestamp = 0;
        uint256 royaltyPaymentDeadline = 0;
        uint256 royaltyPaymentTimestamp = 0;
        uint256 reportChangeTimestamp = 0;
        uint256 extraData = 0;

        // initialize packedData; store all the values above into packedData
        uint256 packedData = 0;
        packedData |= submissionTimestamp;
        packedData |= approvalTimestamp << APPROVAL_TIMESTAMP_BITPOS;
        packedData |= royaltyPaymentDeadline << ROYALTY_PAYMENT_DEADLINE_BITPOS;
        packedData |= royaltyPaymentTimestamp << ROYALTY_PAYMENT_TIMESTAMP_BITPOS;
        packedData |= reportChangeTimestamp << REPORT_CHANGE_TIMESTAMP_BITPOS;
        packedData |= extraData << EXTRA_DATA_BITPOS;

        licenseRecord.reports.push(Report({
            amountDue: 0,
            url: url,
            packedData: packedData
        }));

        emit ReportSubmitted(licensee, applicationHash, licenseRecord.reports.length - 1, submissionTimestamp);
    }

    /**
     * @dev (For licensors and license owners) Changes the report URL for a specific report of index {reportIndex} for a specific license.
     * NOTE: Can only be done if the current report has not been approved yet.
     */
    function changeReport(address licensee, bytes32 applicationHash, uint256 reportIndex, string calldata newUrl)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        onlyUsableLicense(licensee, applicationHash)
        reportChangeable(licensee, applicationHash)
    {
        LicenseRecord storage licenseRecord = _licenseRecord[licensee][applicationHash];
        Report storage report = licenseRecord.reports[reportIndex];

        uint256 reportChangeTimestamp = block.timestamp;

        // update the report's URL
        report.url = newUrl;

        // update the report's change timestamp
        report.packedData |= reportChangeTimestamp << REPORT_CHANGE_TIMESTAMP_BITPOS;

        emit ReportChanged(licensee, applicationHash, reportIndex, reportChangeTimestamp);
    }

    /**
     * @dev (For licensors) Approves a revenue report submitted by {licensee} for a specific license.
     * Also sets the payment deadline and the royalty amount due.
     */
    function approveReport(
        address licensee,
        bytes32 applicationHash,
        uint256 reportIndex,
        uint256 paymentDeadline,
        uint256 amountDue
    )
        public
        virtual
        onlyOwner
        applicationExists(licensee, applicationHash)
        onlyUsableLicense(licensee, applicationHash)
    {
        LicenseRecord storage licenseRecord = _licenseRecord[licensee][applicationHash];
        Report storage report = licenseRecord.reports[reportIndex];

        uint256 approvalTimestamp = block.timestamp;

        // update the report's approval timestamp
        report.packedData |= approvalTimestamp << APPROVAL_TIMESTAMP_BITPOS;

        // update the report's payment deadline
        report.packedData |= paymentDeadline << ROYALTY_PAYMENT_DEADLINE_BITPOS;

        // update the report's royalty amount due
        report.amountDue = amountDue;

        emit ReportApproved(licensee, applicationHash, reportIndex, approvalTimestamp);
    }

    /**
     * @dev (For license owners) Pays the royalty due for a specific report of the specific license to the licensor.
     */
    function payRoyalty(bytes32 applicationHash, uint256 reportIndex, uint256 amount)
        public
        virtual
        onlyOwnerOrLicenseOwner(_msgSender(), applicationHash)
        applicationExists(_msgSender(), applicationHash)
        onlyUsableLicense(_msgSender(), applicationHash)
    {
        // goes through a few checks before royalty payment can proceed.
        _payRoyaltyChecks(applicationHash, reportIndex, amount);

        LicenseRecord storage licenseRecord = _licenseRecord[_msgSender()][applicationHash];
        Report storage report = licenseRecord.reports[reportIndex];

        _transferRoyalty(applicationHash, amount, reportIndex);

        // update the report's royalty payment timestamp
        report.packedData |= block.timestamp << ROYALTY_PAYMENT_TIMESTAMP_BITPOS;

        // check the royalty payment deadline.
        uint256 paymentDeadline = (report.packedData >> ROYALTY_PAYMENT_DEADLINE_BITPOS) & ROYALTY_PAYMENT_DEADLINE_BITMASK;
        // get the royalty grace period.
        uint256 royaltyGracePeriod = getRoyaltyGracePeriod(_msgSender(), applicationHash);

        // checks whether the royalty payment is untimely. if it is, then increment the untimely royalty payment count.
        // a payment is considered untimely if it has passed the royalty payment deadline + royalty grace period.
        if (block.timestamp > paymentDeadline + royaltyGracePeriod) {
            // increment the untimely royalty payment count
            incrementUntimelyRoyaltyPayments(_msgSender(), applicationHash);

            emit UntimelyRoyaltyPayment(_msgSender(), applicationHash, reportIndex, block.timestamp);
        }
    }

    /**
     * @dev A few checks to go through for {payRoyalty} before the licensee successfully pays the royalty.
     */
    function _payRoyaltyChecks(bytes32 applicationHash, uint256 reportIndex, uint256 amount) private view {
        LicenseRecord memory record = _licenseRecord[_msgSender()][applicationHash];
        Report memory report = record.reports[reportIndex];

        // checks whether the report has been approved by checking for the approval timestamp. if it's 0, reverts.
        if ((report.packedData >> APPROVAL_TIMESTAMP_BITPOS) & APPROVAL_TIMESTAMP_BITMASK == 0) {
            revert ReportNotYetApproved(_msgSender(), applicationHash, reportIndex);
        }

        // check whether the royalty has already been paid by checking for the payment timestamp. if it's != 0, revert.
        if ((report.packedData >> ROYALTY_PAYMENT_TIMESTAMP_BITPOS) & ROYALTY_PAYMENT_TIMESTAMP_BITMASK != 0) {
            revert RoyaltyAlreadyPaid(_msgSender(), applicationHash, reportIndex);
        }

        // check whether the amount to pay (i.e {amount}) is the same as the amount due, else reverts.
        if (report.amountDue != amount) {
            revert RoyaltyAmountMismatch(_msgSender(), applicationHash, reportIndex, report.amountDue, amount);
        }
    }

    /**
     * @dev Transfers the royalty amount due to the licensor.
     */
    function _transferRoyalty(bytes32 applicationHash, uint256 amount, uint256 reportIndex) private {
        // transfer the royalty amount to the licensor
        payable(_receiver).transfer(amount);

        emit RoyaltyPaid(_msgSender(), applicationHash, reportIndex, block.timestamp);
    }

    /**
     * @dev Checks whether {licensee} is allowed to change the latest report for a license.
     */
    function _checkReportChangeable(address licensee, bytes32 applicationHash) private view {
        LicenseRecord memory record = _licenseRecord[licensee][applicationHash];
        Report memory report = record.reports[record.reports.length - 1];

        // check for the approval timestamp. if it's not 0, then revert.
        if ((report.packedData >> APPROVAL_TIMESTAMP_BITPOS) & APPROVAL_TIMESTAMP_BITMASK != 0) {
            revert ReportAlreadyApproved(licensee, applicationHash, record.reports.length - 1);
        }
    }

    /**
     * @dev Checks whether {licensee} is allowed to submit a new report for {applicationHash}.
     */
    function _checkNewReportAllowed(address licensee, bytes32 applicationHash) private view {
        LicenseRecord memory record = _licenseRecord[licensee][applicationHash];
        Report memory report = record.reports[record.reports.length - 1];

        // get the timestamp of {report}'s submission
        uint256 submissionTimestamp = (report.packedData >> SUBMISSION_TIMESTAMP_BITPOS) & SUBMISSION_TIMESTAMP_BITMASK;

        // get the reporting frequency
        uint256 reportingFrequency = getReportingFrequency(licensee, applicationHash);

        // if submission timestamp is not 0, we check whether the licensee is allowed to submit a new report.
        if (submissionTimestamp != 0) {
            // if the current timestamp has not exceeded {submissionTimestamp} + {reportingFrequency}, then licensee is not allowed to submit a new report.
            if (submissionTimestamp + reportingFrequency > block.timestamp) {
                revert NewReportNotYetAllowed(licensee, applicationHash);
            }
        }
    }
}