// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev Interface of {Licensee}. Contains all relevant methods for the {Licensee} contract.
 */
interface ILicensee {
    // a licensee's account status upon registration.
    enum AccountStatus { Pending, Approved, Rejected }

    /**
     * @dev A licensee's account data.
     */
    struct LicenseeAccount {
        // the licensee's data.
        bytes data;
        // the status of the licensee's account.
        // NOTE: only {AccountStatus.Approved} accounts can be used to apply for a license.
        AccountStatus status;
    }

    function getAccount() external view returns (LicenseeAccount memory);
    function registerAccount() external;
    function approveAccounts(address[] memory licensees) external;
    function rejectAccounts(address[] memory licensees) external;
    function updateAccountData(address[] memory licensees, bytes[] memory data) external;
    function removeAccounts(address[] memory licensees) external;
}

