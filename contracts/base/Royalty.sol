// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../interfaces/IRoyalty.sol";
import "../errors/LicenseErrors.sol";
import "./Application.sol";

/**
 * @dev License revenue report, royalty statement and payment management.
 */
abstract contract Royalty is IRoyalty, IRoyaltyErrors, Application {
    // a mapping from a licensee's address to the application hash to a {LicenseRecord} instance.
    mapping(address => mapping(bytes32 => LicenseRecord)) private _licenseRecord;

    // =============================================================
    //                           CONSTANTS
    // =============================================================
    /// bit masks and positions for {Report.packedData} fields.
    // mask of an entry in {packedData}.
    uint256 internal constant PACKED_DATA_ENTRY_BITMASK = (1 << 40) - 1;
    // mask of all 256 bits in {packedData} except for the 40 bits of the royalty payment deadline.
    uint256 internal constant ROYALTY_PAYMENT_DEADLINE_COMPLEMENT_BITMASK = (1 << 80) - 1;
    // mask of all 256 bits in {packedData} except for the 40 bits of the royalty payment timestamp.
    uint256 internal constant ROYALTY_PAYMENT_TIMESTAMP_COMPLEMENT_BITMASK = (1 << 120) - 1;
    // mask of all 256 bits in {packedData} except for the 40 bits of the report change timestamp.
    uint256 internal constant REPORT_CHANGE_TIMESTAMP_COMPLEMENT_BITMASK = (1 << 160) - 1;
    // mask of all 256 bits in {packedData} except for the 56 bits of the report extra data.
    uint256 internal constant REPORT_EXTRA_DATA_COMPLEMENT_BITMASK = (1 << 200) - 1;


    // uint256 internal constant SUBMISSION_TIMESTAMP_BITMASK = (1 << 40) - 1;
    // uint256 internal constant APPROVAL_TIMESTAMP_BITMASK = ((1 << 40) - 1) << 40;
    // uint256 internal constant ROYALTY_PAYMENT_DEADLINE_BITMASK = ((1 << 40) - 1) << 80;
    // uint256 internal constant ROYALTY_PAYMENT_TIMESTAMP_BITMASK = ((1 << 40) - 1) << 120;
    // uint256 internal constant REPORT_CHANGE_TIMESTAMP_BITMASK = ((1 << 40) - 1) << 160;
    // uint256 internal constant REPORT_EXTRA_DATA_BITMASK = ((1 << 56) - 1) << 200;

    uint256 internal constant SUBMISSION_TIMESTAMP_BITPOS = 0;
    uint256 internal constant APPROVAL_TIMESTAMP_BITPOS = 40;
    uint256 internal constant ROYALTY_PAYMENT_DEADLINE_BITPOS = 80;
    uint256 internal constant ROYALTY_PAYMENT_TIMESTAMP_BITPOS = 120;
    uint256 internal constant REPORT_CHANGE_TIMESTAMP_BITPOS = 160;
    uint256 internal constant REPORT_EXTRA_DATA_BITPOS = 200;

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

        // get the reporting frequency
        uint256 reportingFrequency = getReportingFrequency(licensee, applicationHash);

        // get the reporting grace period
        uint256 reportingGracePeriod = getReportingGracePeriod(licensee, applicationHash);

        if (licenseRecord.reports.length > 0) {
            // get the previous report
            Report memory previousReport = licenseRecord.reports[licenseRecord.reports.length - 1];

             // get the previous report's submission timestamp
            uint256 previousSubmissionTimestamp = (previousReport.packedData >> SUBMISSION_TIMESTAMP_BITPOS) & PACKED_DATA_ENTRY_BITMASK;

            // if the previous report's submission timestamp is not 0, then we check whether the report was submitted on time.
            // if it's not, then we increment the untimely report count.
            if (previousSubmissionTimestamp + reportingFrequency + reportingGracePeriod < block.timestamp) {
                // increment the untimely report count
                incrementUntimelyReports(licensee, applicationHash);

                emit UntimelyReport(licensee, applicationHash, licenseRecord.reports.length - 1, block.timestamp);
            }
        // if no report is found, we assume it's the first report that they are submitting.
        } else {
            // get the approval date of the license application.
            uint256 approvalDate = getApprovalDate(licensee, applicationHash);

            // even if it's the first report they're submitting, they will get an untimely report count if they submit it after the approval date + reporting frequency + reporting grace period.
            if (approvalDate + reportingFrequency + reportingGracePeriod < block.timestamp) {
                // increment the untimely report count
                incrementUntimelyReports(licensee, applicationHash);

                emit UntimelyReport(licensee, applicationHash, 0, block.timestamp);
            }

            // initialize packedData with the submission timestamp.
            uint256 packedData = block.timestamp;

            licenseRecord.reports.push(Report({
                amountDue: 0,
                url: url,
                packedData: packedData
            }));

            emit ReportSubmitted(licensee, applicationHash, 0, block.timestamp);
        }
    }

    /**
     * @dev (For licensors and license owners) Gets the license record for {licensee} for a specific license with the given {applicationHash}.
     */
    function getLicenseRecord(address licensee, bytes32 applicationHash)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (LicenseRecord memory)
    {
        return _licenseRecord[licensee][applicationHash];
    }

    /**
     * @dev (For licensors and license owners) Gets a report of index {reportIndex} for a specific license.
     */
    function getReport(address licensee, bytes32 applicationHash, uint256 reportIndex)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (Report memory)
    {
        return _licenseRecord[licensee][applicationHash].reports[reportIndex];
    }

    /**
     * @dev (For licensors and license owners) Gets the submission timestamp of a report of index {reportIndex} for a specific license.
     */
    function getReportSubmissionTimestamp(address licensee, bytes32 applicationHash, uint256 reportIndex)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        Report memory report = _licenseRecord[licensee][applicationHash].reports[reportIndex];
        return (report.packedData >> SUBMISSION_TIMESTAMP_BITPOS) & PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev (For licensors and license owners) Gets the approval timestamp of a report of index {reportIndex} for a specific license.
     */
    function getReportApprovalTimestamp(address licensee, bytes32 applicationHash, uint256 reportIndex)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        Report memory report = _licenseRecord[licensee][applicationHash].reports[reportIndex];
        return (report.packedData >> APPROVAL_TIMESTAMP_BITPOS) & PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev (For licensors and license owners) Gets the royalty payment deadline of a report of index {reportIndex} for a specific license.
     */
    function getRoyaltyPaymentDeadline(address licensee, bytes32 applicationHash, uint256 reportIndex)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        Report memory report = _licenseRecord[licensee][applicationHash].reports[reportIndex];
        return (report.packedData >> ROYALTY_PAYMENT_DEADLINE_BITPOS) & PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev (For licensors and license owners) Gets the royalty payment timestamp of a report of index {reportIndex} for a specific license.
     */
    function getRoyaltyPaymentTimestamp(address licensee, bytes32 applicationHash, uint256 reportIndex)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        Report memory report = _licenseRecord[licensee][applicationHash].reports[reportIndex];
        return (report.packedData >> ROYALTY_PAYMENT_TIMESTAMP_BITPOS) & PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev (For licensors and license owners) Gets the report change timestamp of a report of index {reportIndex} for a specific license.
     */
    function getReportChangeTimestamp(address licensee, bytes32 applicationHash, uint256 reportIndex)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        Report memory report = _licenseRecord[licensee][applicationHash].reports[reportIndex];
        return (report.packedData >> REPORT_CHANGE_TIMESTAMP_BITPOS) & PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev (For licensors and license owners) Gets the extra data of a report of index {reportIndex} for a specific license.
     */
    function getReportExtraData(address licensee, bytes32 applicationHash, uint256 reportIndex)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
        view
        returns (uint256)
    {
        Report memory report = _licenseRecord[licensee][applicationHash].reports[reportIndex];
        return (report.packedData >> REPORT_EXTRA_DATA_BITPOS) & PACKED_DATA_ENTRY_BITMASK;
    }

    /**
     * @dev (For licensors) Sets the extra data of a report of index {reportIndex} for a specific license to {extraData}.
     */
    function setReportExtraData(address licensee, bytes32 applicationHash, uint256 reportIndex, uint256 extraData)
        public
        virtual
        onlyOwnerOrLicenseOwner(licensee, applicationHash)
        applicationExists(licensee, applicationHash)
    {
        LicenseRecord storage licenseRecord = _licenseRecord[licensee][applicationHash];
        Report storage report = licenseRecord.reports[reportIndex];

        uint256 packedData = report.packedData;

        // update the report's extra data
        packedData = (packedData & REPORT_EXTRA_DATA_COMPLEMENT_BITMASK) | (extraData << REPORT_EXTRA_DATA_BITPOS);

        // recast the packed data back to {report.packedData}
        report.packedData = packedData;

        emit ReportExtraDataChanged(licensee, applicationHash, reportIndex, extraData, block.timestamp);
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

        uint256 packedData = report.packedData;

        // update the report's change timestamp
        packedData = (packedData & REPORT_CHANGE_TIMESTAMP_COMPLEMENT_BITMASK) | (reportChangeTimestamp << REPORT_CHANGE_TIMESTAMP_BITPOS);

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

        uint256 packedData = report.packedData;

        // update the report's approval timestamp
        packedData = (packedData & FIRST_PACKED_DATA_ENTRY_BITMASK) | (approvalTimestamp << APPROVAL_TIMESTAMP_BITPOS);

        // update the report's payment deadline
        packedData = (packedData & ROYALTY_PAYMENT_DEADLINE_COMPLEMENT_BITMASK) | (paymentDeadline << ROYALTY_PAYMENT_DEADLINE_BITPOS);

        // recast the packed data back to {report.packedData}
        report.packedData = packedData;

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

        uint256 packedData = report.packedData;

        // update the report's royalty payment timestamp
        packedData = (packedData & ROYALTY_PAYMENT_TIMESTAMP_COMPLEMENT_BITMASK) | (block.timestamp << ROYALTY_PAYMENT_TIMESTAMP_BITPOS);

        // recast the packed data back to {report.packedData}
        report.packedData = packedData;

        // check the royalty payment deadline.
        uint256 paymentDeadline = getRoyaltyPaymentDeadline(_msgSender(), applicationHash, reportIndex);
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
        if ((report.packedData >> APPROVAL_TIMESTAMP_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK == 0) {
            revert ReportNotYetApproved(_msgSender(), applicationHash, reportIndex);
        }

        // check whether the royalty has already been paid by checking for the payment timestamp. if it's != 0, revert.
        if ((report.packedData >> ROYALTY_PAYMENT_TIMESTAMP_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK != 0) {
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
        uint256 reportCount = record.reports.length;

        // if there are no reports, then revert.
        if (reportCount == 0) {
            revert NoReportsFound(licensee, applicationHash);
        }

        Report memory report = record.reports[reportCount - 1];

        // check for the approval timestamp. if it's not 0, then revert.
        if ((report.packedData >> APPROVAL_TIMESTAMP_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK != 0) {
            revert ReportAlreadyApproved(licensee, applicationHash, record.reports.length - 1);
        }
    }

    /**
     * @dev Checks whether {licensee} is allowed to submit a new report for {applicationHash}.
     */
    function _checkNewReportAllowed(address licensee, bytes32 applicationHash) private view {
        LicenseRecord memory record = _licenseRecord[licensee][applicationHash];
        uint256 reportCount = record.reports.length;
        Report memory report;

        if (reportCount > 0) {
            report = record.reports[reportCount - 1];
        }

        // get the timestamp of {report}'s submission
        // if report count is 0, we don't have to worry about errors because `report` defaults to a Report struct with default values.
        uint256 submissionTimestamp = (report.packedData >> SUBMISSION_TIMESTAMP_BITPOS) & FIRST_PACKED_DATA_ENTRY_BITMASK;

        // get the reporting frequency
        uint256 reportingFrequency = getReportingFrequency(licensee, applicationHash);

        // if submission timestamp is not 0, we check whether the licensee is allowed to submit a new report.
        if (submissionTimestamp != 0) {
            // if the current timestamp has not exceeded {submissionTimestamp} + {reportingFrequency}, then licensee is not allowed to submit a new report.
            if (submissionTimestamp + reportingFrequency > block.timestamp) {
                revert NewReportNotYetAllowed(licensee, applicationHash);
            }
        // if submission timestamp is 0, we check whether the application approval date + {reportingFrequency} has passed.
        } else {
            // get the application approval date
            uint256 approvalDate = getApprovalDate(licensee, applicationHash);

            // if the current timestamp has not exceeded {approvalDate} + {reportingFrequency}, then licensee is not allowed to submit a new report.
            if (approvalDate + reportingFrequency > block.timestamp) {
                revert NewReportNotYetAllowed(licensee, applicationHash);
            }
        }
    }
}