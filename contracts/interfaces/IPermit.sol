// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev Interface of {Permit}. Contains all relevant function signatures and methods for the {Permit} contract.
 */
interface IPermit {
    event LicenseAdded(string licenseType);
    event LicenseRemoved(string licenseType);
    event LicenseTermsChanged(string licenseType);

    function addLicense(bytes32 licenseHash, string calldata baseTerms) external;
    function removeLicense(bytes32 licenseHash) external;
    function changeLicenseTerms(bytes32 licenseHash, string calldata newTerms) external;
    function getLicense(bytes32 licenseHash) external view returns (string memory);
}