//SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "./LicenseApplication.sol";

/**
 * @dev LicenseRoyalty handles the payment and receiving of royalties for licensees and the licensor.
 */
abstract contract LicenseRoyalty is LicenseApplication {
    // the address that receives royalty or other forms of payment from licensees (e.g. the licensor's wallet).
    address private _receiver;

    /**
     * @dev Throws when the royalty for a specific report has already been paid.
     */
    error RoyaltyAlreadyPaid(address licensee, bytes32 applicationHash, uint256 royaltyStatementIndex);

    /**
     * @dev Throws when the licensee pays a different amount than the amount due.
     */
    error RoyaltyAmountMismatch(address license, bytes32 applicationHash, uint256 royaltyStatementIndex, uint256 royaltyDue, uint256 royaltyToPay);

    /**
     * @dev Throws when the licensee tries to pay the royalty for a report that hasn't been approved yet.
     */
    error RevenueReportNotYetApproved(address licensee, bytes32 applicationHash, uint256 royaltyStatementIndex);

    /**
     * @dev Throws when trying to change a report when the report has already been approved.
     */
    error RevenueReportAlreadyApproved(address licensee, bytes32 applicationHash, uint256 royaltyStatementIndex);

    /**
     * @dev Throws when a licensee tries to report a new revenue report when it is not yet allowed.
     */
    error NewRevenueReportNotYetAllowed(address licensee, bytes32 applicationHash);

    /**
     * @dev Contains the record of a license. Primarily handles the royalty and revenue reports.
     */
    struct LicenseRecord {
        // the licensee's address (that applied for this specific license)
        address licensee;
        // the hash of the license application
        bytes32 licenseHash;
        // handles the royalty and revenue reports per specific time periods for this license.
        RoyaltyStatement[] royaltyStatements;
    }

    /**
     * @dev Contains primarily the details of the royalty and revenue report for a specific time period.
     */
    struct RoyaltyStatement {
        // the timestamp when the revenue report was submitted.
        uint256 submitted;
        // the timestamp when the royalty to the licensor is due.
        uint256 deadline;
        // the url that leads to the revenue report.
        string reportUrl;
        // the amount of royalty that is due to the licensor.
        uint256 amountDue;
        // checks if the report given by the licensee is approved by the licensor.
        // only once approved will the licensee be allowed to pay the royalty.
        bool reportApproved;
        // checks if the royalty has already been paid.
        bool paid;
        // the timestamp when the royalty was paid.
        uint256 paidTimestamp;
    }

    // a mapping from a licensee's address to the license application hash which contains the royalty and revenue report data record.
    mapping(address => mapping(bytes32 => LicenseRecord)) private _licenseRecord;

    event RevenueReported(address licensee, bytes32 _applicationHash, uint256 royaltyStatementIndex, uint256 timestamp);
    event RoyaltyPaid(address licensee, bytes32 _applicationHash, uint256 royaltyStatementIndex, uint256 timestamp);
    event RevenueReportApproved(address licensee, bytes32 _applicationHash, uint256 royaltyStatementIndex, uint256 timestamp);
    event RevenueReportChanged(address licensee, bytes32 _applicationHash, uint256 royaltyStatementIndex, uint256 timestamp);

    // a modifier that checks whether a license application's report for that time period is approved already.
    modifier onlyApprovedReport(address licensee, bytes32 _applicationHash, uint256 royaltyStatementIndex) {
        _checkReportApproved(licensee, _applicationHash, royaltyStatementIndex);
        _;
    }

    // a modifier that checks if a licensee is allowed to report a new revenue report for a specific license application.
    modifier newReportAllowed(address licensee, bytes32 _applicationHash) {
        _checkNewReportAllowed(licensee, _applicationHash);
        _;
    }

    /**
     * @dev (For licensees) Reports a timely revenue report (i.e. a RoyaltyStatement instance) for a specific license.
     */
    function reportRevenue(bytes32 _applicationHash, string calldata reportUrl) 
        public 
        onlyOwnerOrOwnedLicensee(_msgSender(), _applicationHash)
        applicationExists(_msgSender(), _applicationHash)
        onlyApprovedApplication(_msgSender(), _applicationHash)
        newReportAllowed(_msgSender(), _applicationHash)
    {
        LicenseRecord storage licenseRecord = _licenseRecord[_msgSender()][_applicationHash];
        
        licenseRecord.royaltyStatements.push(RoyaltyStatement({
            submitted: block.timestamp,
            deadline: 0,
            reportUrl: reportUrl,
            amountDue: 0,
            reportApproved: false,
            paid: false,
            paidTimestamp: 0
        }));
    }

    /**
     * @dev Changes the report URL for the latest royalty statement instance for a specific license application.
     * Can only be done if the report has not been approved yet.
     */
    function changeReport(bytes32 _applicationHash, string calldata reportUrl)
        public
        onlyOwnerOrOwnedLicensee(_msgSender(), _applicationHash)
        applicationExists(_msgSender(), _applicationHash)
        onlyApprovedApplication(_msgSender(), _applicationHash)
    {
        LicenseRecord storage licenseRecord = _licenseRecord[_msgSender()][_applicationHash];
        RoyaltyStatement storage royaltyStatement = licenseRecord.royaltyStatements[licenseRecord.royaltyStatements.length - 1];

        if (royaltyStatement.reportApproved) {
            revert RevenueReportAlreadyApproved(_msgSender(), _applicationHash, licenseRecord.royaltyStatements.length - 1);
        }

        royaltyStatement.reportUrl = reportUrl;

        emit RevenueReportChanged(_msgSender(), _applicationHash, licenseRecord.royaltyStatements.length - 1, block.timestamp);
    }

    /**
     * @dev Checks whether a licensee is allowed to report a new revenue report for a specific license application.
     */
    function _checkNewReportAllowed(address licensee, bytes32 _applicationHash) internal view {
        LicenseRecord memory licenseRecord = _licenseRecord[licensee][_applicationHash];
        RoyaltyStatement memory royaltyStatement = licenseRecord.royaltyStatements[licenseRecord.royaltyStatements.length - 1];

        // check if {submitted} != 0, meaning that the royalty statement exists.
        if (royaltyStatement.submitted != 0) {
            uint256 submitted = royaltyStatement.submitted;
            // check if the timestamp now has exceeded submitted + {reportFrequency}.
            // if it has, then a new revenue report is allowed.
            if ((submitted + licenseApplications[licensee][_applicationHash].applicationData.reportFrequency) <= block.timestamp) {
                return;
            }

            // otherwise, revert.
            revert NewRevenueReportNotYetAllowed(licensee, _applicationHash);
        }
    }

    /**
     * @dev Checks whether a new revenue report is due for a specific license application.
     *
     * This can be done by checking the timestamp of the last revenue report and comparing it to now. 
     * If it is equal to or has exceeded the {reportFrequency} of the license application, then a new revenue report is due.
     * Doesn't take into account the lateness of the revenue report.
     */
    function _checkRevenueReportable(address licensee, bytes32 _applicationHash) 
        public 
        view
        onlyOwnerOrOwnedLicensee(licensee, _applicationHash)
        applicationExists(licensee, _applicationHash)
        onlyApprovedApplication(licensee, _applicationHash)
        returns (bool) 
    {
        LicenseRecord memory licenseRecord = _licenseRecord[licensee][_applicationHash];
        uint256 reportFrequency = licenseApplications[licensee][_applicationHash].applicationData.reportFrequency;

        // if there are no royalty statements submitted yet, we check if the approved date + {reportFrequency} has exceeded or is equal to now.
        // if it has, then a new revenue report is due, and this returns true.
        if (licenseRecord.royaltyStatements.length == 0) {
            uint256 approvedDate = licenseApplications[licensee][_applicationHash].applicationData.approvedDate;

            return (approvedDate + reportFrequency) <= block.timestamp;
        }

        // if the license has royalty statements, we check if the last royalty statement's submitted timestamp + {reportFrequency} has exceeded or is equal to now.
        uint256 submitted = licenseRecord.royaltyStatements[licenseRecord.royaltyStatements.length - 1].submitted;

        return (submitted + reportFrequency) <= block.timestamp;
    }

    /**
     * @dev (For licensors) Approves a revenue report for a specific license application.
     * On top of that, set the {deadline} and {amountDue} properties of the royalty statement for the licensee.
     */
    function approveReport(
        address licensee, 
        bytes32 _applicationHash, 
        uint256 royaltyStatementIndex,
        uint256 deadline,
        uint256 amountDue
    )
        public
        onlyOwner
        applicationExists(licensee, _applicationHash)
        onlyApprovedApplication(licensee, _applicationHash)
    {
        LicenseRecord storage licenseRecord = _licenseRecord[licensee][_applicationHash];
        RoyaltyStatement storage royaltyStatement = licenseRecord.royaltyStatements[royaltyStatementIndex];

        // set the {reportApproved} property of the royalty statement to true.
        royaltyStatement.reportApproved = true;

        // set the {deadline} property of the royalty statement to the given {deadline}.
        royaltyStatement.deadline = deadline;

        // set the {amountDue} property of the royalty statement to the given {amountDue}.
        royaltyStatement.amountDue = amountDue;

        emit RevenueReportApproved(licensee, _applicationHash, royaltyStatementIndex, block.timestamp);
    }

    /**
     * @dev (For licensees) Pays the royalty to the licensor for a specific license application.
     */
    function payRoyalty(bytes32 _applicationHash, uint256 royaltyStatementIndex, uint256 royaltyAmount)
        public
        onlyOwnerOrOwnedLicensee(_msgSender(), _applicationHash)
        applicationExists(_msgSender(), _applicationHash)
        onlyApprovedApplication(_msgSender(), _applicationHash)
    {
        // get the {licensee}'s license record for {_applicationHash}, and then the royalty statement at {royaltyStatementIndex}.
        LicenseRecord storage licenseRecord = _licenseRecord[_msgSender()][_applicationHash];
        RoyaltyStatement storage royaltyStatement = licenseRecord.royaltyStatements[royaltyStatementIndex];

        // goes through a few checks before the licensee can pay the royalty.
        _payRoyaltyChecks(_msgSender(), _applicationHash, royaltyStatementIndex, royaltyAmount);

        // transfer the royalty amount to the licensor.
        _transferRoyalty(royaltyAmount, _applicationHash, royaltyStatementIndex);

        // set the {paid} property of the royalty statement to true.
        royaltyStatement.paid = true;

        // set the {paidTimestamp} property of the royalty statement to now.
        royaltyStatement.paidTimestamp = block.timestamp;
    }

    /**
     * @dev A few checks to go through before a licensee can pay the royalty to the licensor.
     * Called within {payRoyalty}.
     */
    function _payRoyaltyChecks(
        address licensee, 
        bytes32 _applicationHash,
        uint256 royaltyStatementIndex,
        uint256 royaltyAmount
    ) internal view {
        LicenseRecord memory licenseRecord = _licenseRecord[licensee][_applicationHash];
        RoyaltyStatement memory royaltyStatement = licenseRecord.royaltyStatements[royaltyStatementIndex];

        // first, checks if {royaltyStatement.reportApproved} is true.
        // if it is false, then revert.
        _checkReportApproved(licensee, _applicationHash, royaltyStatementIndex);

        // then, checks the royalty amount to be sent by the licensee.
        // if it is not equal to the amount due to the licensor, then revert.
        if (royaltyStatement.amountDue != royaltyAmount) {
            revert RoyaltyAmountMismatch(licensee, _applicationHash, royaltyStatementIndex, royaltyStatement.amountDue, royaltyAmount);
        }        
    }

    /**
     * @dev Checks if a specific license application's report has been approved. If not, reverts.
     */
    function _checkReportApproved(address licensee, bytes32 _applicationHash, uint256 royaltyStatementIndex) internal view {
        LicenseRecord memory licenseRecord = _licenseRecord[licensee][_applicationHash];
        RoyaltyStatement memory royaltyStatement = licenseRecord.royaltyStatements[royaltyStatementIndex];

        if (!royaltyStatement.reportApproved) {
            revert RevenueReportNotYetApproved(licensee, _applicationHash, royaltyStatementIndex);
        }
    }

    /**
     * @dev Transfers the royalty amount to the licensor.
     */
    function _transferRoyalty(uint256 royaltyAmount, bytes32 _applicationHash, uint256 royaltyStatementIndex) internal {
        // transfer the royalty amount to the licensor.
        payable(_receiver).transfer(royaltyAmount);

        emit RoyaltyPaid(_msgSender(), _applicationHash, royaltyStatementIndex, block.timestamp);
    }
}