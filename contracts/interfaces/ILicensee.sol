// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev Interface of {Licensee}. Contains all relevant methods for the {Licensee} contract.
 */
interface ILicensee {
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

    function getAccount() external view returns (LicenseeAccount memory);
    function registerAccount(bytes calldata data) external;
    function approveAccounts(address[] memory licensees) external;
    function rejectAccounts(address[] memory licensees) external;
    function updateAccountData(address[] memory licensees, bytes[] calldata data) external;
    function removeAccounts(address[] memory licensees) external;
}

