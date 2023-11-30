// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev Interface of {Licensee}. Contains all relevant function signatures and methods for the {Licensee} contract.
 */
interface ILicensee {
    event LicenseeRegistered(address indexed newLicensee, uint256 timestamp);
    event LicenseesRemoved(address[] indexed removedLicensee, uint256 timestamp);
    event LicenseesUpdated(address[] indexed licensee, bytes[] data, uint256 timestamp);
    event LicenseeStatusesUpdated(address[] indexed licensee, bool usable, uint256 timestamp);

    /**
     * @dev A licensee's account data.
     */
    struct LicenseeAccount {
        // the licensee's data.
        bytes data;
        // if the licensee account is usable.
        // NOTE: after account registration, {usable} will automatically be set to false until approved by the licensor.
        // only usable accounts can have full access (e.g. applying for a license).
        // if a licensor wishes to blacklist a licensee account, they can simply just set {usable} to (or leave it as) false.
        bool usable;
    }

    function getAccount(address licensee) external view returns (LicenseeAccount memory);
    function registerAccount(bytes calldata data) external;
    function approveAccounts(address[] memory licensees) external;
    function updateAccounts(address[] memory licensees, bytes[] calldata data) external;
    function removeAccount() external;
    function removeAccounts(address[] memory licensees) external;
}