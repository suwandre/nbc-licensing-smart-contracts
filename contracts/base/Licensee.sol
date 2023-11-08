// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "../access/MultiOwnable.sol";

/**
 * @dev Licensee handles all licensees' data.
 */
contract Licensee is MultiOwnable {
    // a mapping from a licensee's address to their data.
    mapping (address => bytes) private licenseeData;

    /**
     * @dev Throws if the caller is not the owner or a licensee.
     */
    error NotOwnerOrLicensee(address caller);

    /**
     * @dev Throws if the given licensee already exists within {licenseeData}.
     */
    error LicenseeAlreadyExists(address licensee);

    /**
     * @dev Throws if the given {licensee} address is invalid (e.g. `address(0)`).
     */
    error InvalidLicenseeAddress(address licensee);

    /**
     * @dev Throws if the given licensee {data} is empty.
     */
    error LicenseeDataMustNotBeEmpty();

    /**
     * @dev Throws if the data to change is the same as the data inside {licenseeData}.
     */
    error LicenseeDataSame(bytes data);

    /**
     * @dev Throws if the given licensee doesn't exist within {licenseeData}.
     */
    error LicenseeDoesntExist(address licensee);

    event LicenseeAdded(address indexed newLicensee);
    event LicenseeRemoved(address indexed removedLicensee);
    event LicenseeDataUpdated(address indexed licensee, bytes data);

    // a modifier that checks whether the caller is one of the owners or a licensee.
    modifier onlyOwnerOrLicensee(address licensee) {
        _checkOwnerOrLicensee(licensee);
        _;
    }

    /**
     * @dev Checks whether the caller is one of the owners or a licensee.
     */
    function _checkOwnerOrLicensee(address licensee) private view {
        if (!_isOwner() || _msgSender() != licensee) {
            revert NotOwnerOrLicensee(_msgSender());
        }
    }

    /**
     * @dev Updates a licensee's data in {licenseeData}.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given licensee must exist within {licenseeData}.
     * - the given {data} must not be empty.
     * - the given {data} must not be the same as the data inside {licenseeData}.
     */
    function updateLicenseeData(address licensee, bytes calldata data) public virtual onlyOwner() {
        if (licenseeData[licensee].length == 0) {
            revert LicenseeDoesntExist(licensee);
        }

        if (data.length == 0) {
            revert LicenseeDataMustNotBeEmpty();
        }

        if (keccak256(licenseeData[licensee]) == keccak256(data)) {
            revert LicenseeDataSame(data);
        }

        licenseeData[licensee] = data;
        emit LicenseeDataUpdated(licensee, data);
    }

    /**
     * @dev Retrieves the licensee's data from {licenseeData}.
     *
     * Requirements:
     * - the caller must be an owner or a licensee.
     */
    function getLicenseeData(address licensee) public view onlyOwnerOrLicensee(licensee) returns (bytes memory) {
        return licenseeData[licensee];
    }

    /**
     * @dev Adds a licensee's data into {licenseeData}.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given licensee must not exist within {licenseeData}.
     * - the given {licensee} address must not be invalid (e.g. `address(0)`).
     * - the given {data} must not be empty.
     */
    function addLicenseeData(address licensee, bytes calldata data) public virtual onlyOwner {
        if (licenseeData[licensee].length != 0) {
            revert LicenseeAlreadyExists(licensee);
        }

        if (licensee == address(0)) {
            revert InvalidLicenseeAddress(licensee);
        }

        if (data.length == 0) {
            revert LicenseeDataMustNotBeEmpty();
        }

        licenseeData[licensee] = data;
        emit LicenseeAdded(licensee);
    }

    /**
     * @dev Removes a licensee's data from {licenseeData}.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given licensee must exist within {licenseeData}.
     */
    function removeLicenseeData(address licensee) public virtual onlyOwner {
        if (licenseeData[licensee].length == 0) {
            revert LicenseeDoesntExist(licensee);
        }

        delete licenseeData[licensee];
        emit LicenseeRemoved(licensee);
    }
}