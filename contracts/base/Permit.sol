// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../access/MultiOwnable.sol";
import "../errors/LicenseErrors.sol";
import "../interfaces/IPermit.sol";

/**
 * @dev License permit management.
 */
abstract contract Permit is MultiOwnable, IPermit, IPermitErrors {
    // a mapping from a license's hash to its base terms URL.
    mapping (bytes32 => string) private _license;

    event LicenseAdded(bytes32 indexed licenseHash, uint256 timestamp);
    event LicenseRemoved(bytes32 indexed licenseHash, uint256 timestamp);
    event LicenseTermsChanged(bytes32 indexed licenseHash, string newTerms, uint256 timestamp);

    /**
     * @dev Gets the base terms URL of a license.
     */
    function getLicense(bytes32 licenseHash) external virtual view returns (string memory) {
        return _license[licenseHash];
    }

    /**
     * @dev Adds a license to {_license} by adding its {baseTerms} (i.e. base terms URL) into the mapping.
     *
     * Requirements:
     * - The caller must be an owner.
     * - The given {licenseHash} must not be empty.
     * - The given {baseTerms} must not be empty.
     * - The given {licenseHash} must not already exist within {_license}.
     */
    function addLicense(bytes32 licenseHash, string calldata baseTerms) external virtual onlyOwner {
        if (licenseHash.length == 0) {
            revert EmptyLicenseHash();
        }

        if (bytes(baseTerms).length == 0) {
            revert EmptyBaseTerms();
        }

        if (_licenseExists(licenseHash)) {
            revert LicenseAlreadyExists(licenseHash);
        }

        _license[licenseHash] = baseTerms;

        emit LicenseAdded(licenseHash, block.timestamp);
    }

    /**
     * @dev Removes a license from {_license}.
     * 
     * Requirements:
     * - The caller must be an owner.
     * - The given {licenseHash} must not be empty.
     * - The given {licenseHash} must exist within {_license}.
     */
    function removeLicense(bytes32 licenseHash) external virtual onlyOwner {
        if (licenseHash.length == 0) {
            revert EmptyLicenseHash();
        }

        if (!_licenseExists(licenseHash)) {
            revert LicenseDoesntExist(licenseHash);
        }

        delete _license[licenseHash];

        emit LicenseRemoved(licenseHash, block.timestamp);
    }

    /**
     * @dev Changes the base terms URL of a license.
     *
     * Requirements:
     * - The caller must be an owner.
     * - The given {licenseHash} must not be empty.
     * - The given {licenseHash} must exist within {_license}.
     * - The given {newTerms} must not be empty.
     * - The given {newTerms} must be different from the current base terms URL.
     */
    function changeLicenseTerms(bytes32 licenseHash, string calldata newTerms) external virtual onlyOwner {
        if (licenseHash.length == 0) {
            revert EmptyLicenseHash();
        }

        if (!_licenseExists(licenseHash)) {
            revert LicenseDoesntExist(licenseHash);
        }

        if (bytes(newTerms).length == 0) {
            revert EmptyNewTerms();
        }

        if (keccak256(abi.encodePacked(_license[licenseHash])) == keccak256(abi.encodePacked(newTerms))) {
            revert SameBaseTerms(newTerms);
        }

        _license[licenseHash] = newTerms;

        emit LicenseTermsChanged(licenseHash, newTerms, block.timestamp);
    }

    /**
     * @dev Gets the keccak256 hash of {license}. This corresponds to the hash used for {Permit - license}.
     */
    function _licenseHash(string memory license) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(license));
    }

    /**
     * @dev Checks whether a license exists within {_license}.
     * In order to do so, we simply check whether the base terms URL is empty.
     */
    function _licenseExists(bytes32 licenseHash) internal virtual view returns (bool) {
        return bytes(_license[licenseHash]).length > 0;
    }
}