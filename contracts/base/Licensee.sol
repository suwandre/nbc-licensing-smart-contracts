// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../access/MultiOwnable.sol";
import "../interfaces/ILicensee.sol";
import "../errors/LicenseErrors.sol";

/**
 * @dev Licensee account and data operations.
 */
abstract contract Licensee is MultiOwnable, ILicensee, ILicenseeErrors {
    // a mapping from a licensee's address to their account data.
    mapping (address => LicenseeAccount) private _licenseeAccount;

    event LicenseeAdded(address indexed newLicensee);
    event LicenseeRemoved(address indexed removedLicensee);
    event LicenseeUpdated(address indexed licensee, bytes data);
    event LicenseeStatusUpdated(address indexed licensee, AccountStatus status);
}