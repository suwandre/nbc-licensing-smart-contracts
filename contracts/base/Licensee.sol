// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../access/MultiOwnable.sol";
import "../errors/LicenseErrors.sol";

/**
 * @dev Licensee account and data operations.
 */
abstract contract Licensee is MultiOwnable, ILicenseeErrors {
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

    // a mapping from a licensee's address to their account data.
    mapping (address => LicenseeAccount) private _licenseeAccount;

    event LicenseeAdded(address indexed newLicensee);
    event LicenseeRemoved(address indexed removedLicensee);
    event LicenseeUpdated(address indexed licensee, bytes data);
    event LicenseeStatusUpdated(address indexed licensee, AccountStatus status);
}