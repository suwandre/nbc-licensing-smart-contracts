// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev Interface of {Royalty}. Contains all relevant function signatures and methods for the {Royalty} contract.
 */
interface IRoyalty {
    /**
     * @dev Contains the record of a license. Primarily handles revenue statement reports and royalty payments.
     */
    struct LicenseRecord {
        // the licensee's address.
        address licensee;
        // the license hash of the license type the licensee is applying for. see {Permit - _licenseHash}.
        bytes32 licenseHash;
        // the list of revenue reports and royalty payments for this license.
        Report[] reports;
    }

    struct Report {
        // the amount of royalty due to the licensor.
        uint256 amountDue;
        // a packed data instance containing the following values via their bit layout:
        // [0 - 39] - the timestamp of the report's submission.
        // [40 - 79] - the timestamp of the report's approval (if approved; else 0).
        // [80 - 119] - the deadline for the royalty payment (if not yet approved: 0).
        // [120 - 159] - the timestamp of the royalty payment (if paid; else 0).
        // [120 - 159] - the timestamp of the report's change (if changed; else 0).
        // [160 - 255] - extra data (if applicable).
        uint256 packedData;
    }

    event ReportSubmitted(address indexed licensee, bytes32 indexed licenseHash, uint256 reportIndex, uint256 timestamp);
    event RoyaltyPaid(address indexed licensee, bytes32 indexed licenseHash, uint256 reportIndex, uint256 timestamp);
    event ReportApproved(address indexed licensee, bytes32 indexed licenseHash, uint256 reportIndex, uint256 timestamp);
    event ReportChanged(address indexed licensee, bytes32 indexed licenseHash, uint256 reportIndex, uint256 timestamp);
    event UntimelyReport(address indexed licensee, bytes32 indexed licenseHash, uint256 reportIndex, uint256 timestamp);
    event UntimelyRoyaltyPayment(address indexed licensee, bytes32 indexed licenseHash, uint256 reportIndex, uint256 timestamp);

    function submitReport(bytes32 applicationHash, string calldata url) external;
    function getReport(bytes32 applicationHash, uint256 reportIndex) external view returns (Report memory);
    function getReportSubmissionTimestamp(bytes32 applicationHash, uint256 reportIndex) external view returns (uint256);
    function getReportApprovalTimestamp(bytes32 applicationHash, uint256 reportIndex) external view returns (uint256);
    function getRoyaltyPaymentDeadline(bytes32 applicationHash, uint256 reportIndex) external view returns (uint256);
    function getRoyaltyPaymentTimestamp(bytes32 applicationHash, uint256 reportIndex) external view returns (uint256);
    function getReportChangeTimestamp(bytes32 applicationHash, uint256 reportIndex) external view returns (uint256);
    function getReportExtraData(bytes32 applicationHash, uint256 reportIndex) external view returns (uint256);
    function setReportExtraData(bytes32 applicationHash, uint256 reportIndex, uint256 extraData) external;
    function changeReport(bytes32 applicationHash, uint256 reportIndex, string calldata newUrl) external;
    function approveReport(address licensee, bytes32 applicationHash) external;
    function payRoyalty(address licensee, uint256 reportIndex, bytes32 applicationHash) external;
    function untimelyReport(address licensee, uint256 reportIndex, bytes32 applicationHash) external;
    function untimelyRoyaltyPayment(address licensee, uint256 reportIndex, bytes32 applicationHash) external;
}