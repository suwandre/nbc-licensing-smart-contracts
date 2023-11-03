// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev LicenseRegistry is used to create, validate and revoke licenses from the licensor to the licensee.
 */
contract LicenseRegistry {
    // the licensor; the address corresponds to one of NBC's addresses
    address public licensor;
}