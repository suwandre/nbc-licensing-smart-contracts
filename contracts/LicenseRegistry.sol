// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./base/LicenseApplication.sol";

/**
 * @dev LicenseRegistry is used to create, validate and revoke licenses from the licensor to the licensee for each license permit.
 */
contract LicenseRegistry is LicenseApplication {
    address public licensor;
}