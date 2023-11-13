// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../access/MultiOwnable.sol";

/**
 * @dev LicensePermit defines and manages all license types.
 */
abstract contract LicensePermit is MultiOwnable {
    /**
     * @dev An instance of a license type.
     */
    struct License {
        // the license permit type.
        string licenseType;
        // the hash of {licenseType} (i.e. the license permit type's hash).
        // used to ensure case sensitivity.
        bytes32 licenseHash;
        // the URL of the license that leads to the terms and conditions.
        // this only contains the `skeleton`/reference version of the contract; some values here will be left blank to be filled.
        string baseTerms;
    }

    // checks whether a given {licenseType} of License exists.
    mapping(bytes32 => bool) public licenseExists;

    // a list of all currently available license types.
    License[] public licenseTypes;

    /**
     * @dev Throws if the given URL is the same as the previous URL of that license type.
     */
    error SameLicenseUrl(string url);

    /**
     * @dev Throws if the given URL is empty.
     */
    error EmptyUrl();

    /**
     * @dev Throws is the given license type is empty.
     */
    error EmptyLicenseType();

    /**
     * @dev Throws if the given license type already exists within {licenseTypes}.
     */
    error LicenseAlreadyExists(string license);

    /**
     * @dev Throws when trying to remove a license that doesn't exist within {licenseTypes}.
     */
    error LicenseDoesNotExist(bytes32 licenseTypeHash);

    /**
     * @dev Throws an error when trying to remove a license when the license hash is empty or not given.
     */
    error LicenseHashNotGiven();

    event LicenseAdded(string licenseType, string url);
    event LicenseRemoved(string licenseType);
    event LicenseUrlChanged(string licenseType, string oldUrl, string newUrl);


    /**
     * @dev Adds a new license type.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given license type must not be empty.
     * - the given license type must not already exist.
     * - the given URL must not be empty.
     * 
     */
    function addLicense(string calldata licenseType, string calldata url) public onlyOwner {
        // gets the hash of {licenseType}.
        bytes32 licenseHash = keccak256(abi.encodePacked(licenseType));

        if (bytes(licenseType).length == 0) {
            revert EmptyLicenseType();
        }

        if (bytes(url).length == 0) {
            revert EmptyUrl();
        }

        if (getIndexByLicenseHash(licenseHash) != 0) {
            revert LicenseAlreadyExists(licenseType);
        }

        // add the new license type to {licenseTypes}.
        licenseTypes.push(License(licenseType, licenseHash, url));

        // add the new pair to the {licenseExists} mapping.
        licenseExists[licenseHash] = true;

        emit LicenseAdded(licenseType, url);
    }

    /**
     * @dev Removes an existing license type.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given license type must exist.
     * - the given license hash must not be empty.
     */
    function removeLicense(bytes32 licenseHash) public onlyOwner {
        if (!licenseExists[licenseHash]) {
            revert LicenseDoesNotExist(licenseHash);
        }

        if (licenseHash == 0) {
            revert LicenseHashNotGiven();
        }

        if (getIndexByLicenseHash(licenseHash) == 0) {
            revert LicenseDoesNotExist(licenseHash);
        }

        // find the index of the last license in the {licenseTypes} array.
        uint256 lastLicenseIndex = licenseTypes.length - 1;

        // if the license to remove is not the last one, swap it with the last one.
        if (licenseHash != licenseTypes[lastLicenseIndex].licenseHash) {
            // get the index to remove
            uint256 indexToRemove = getIndexByLicenseHash(licenseHash);
            // get the last license
            License storage lastLicense = licenseTypes[lastLicenseIndex];

            // swap the last license with the license to remove
            licenseTypes[indexToRemove] = lastLicense;
        }

        // remove the last license from the array
        licenseTypes.pop();

        emit LicenseRemoved(licenseTypes[lastLicenseIndex].licenseType);

        // remove the license type from the {licenseExists} mapping.
        delete licenseExists[licenseHash];
    }

    /**
     * @dev Changes the base terms URL of an existing license type.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given license type must exist.
     * - the given license hash must not be empty.
     * - the given URL must be different from the previous URL of that license type.
     * - the given URL must not be empty.
     */
    function changeLicenseUrl(bytes32 licenseHash, string memory newBaseTerms) public onlyOwner {
        if (!licenseExists[licenseHash]) {
            revert LicenseDoesNotExist(licenseHash);
        }

        if (licenseHash == 0) {
            revert LicenseHashNotGiven();
        }

        if (bytes(newBaseTerms).length == 0) {
            revert EmptyUrl();
        }

        // get the index of the license to change
        uint256 indexToChange = getIndexByLicenseHash(licenseHash);

        // get the license to change
        License storage licenseToChange = licenseTypes[indexToChange - 1];

        // check if the given URL is the same as the previous URL of that license type
        if (keccak256(abi.encodePacked(licenseToChange.baseTerms)) == keccak256(abi.encodePacked(newBaseTerms))) {
            revert SameLicenseUrl(newBaseTerms);
        }

        emit LicenseUrlChanged(licenseToChange.licenseType, licenseToChange.baseTerms, newBaseTerms);

        // change the URL of the license type
        licenseToChange.baseTerms = newBaseTerms;
    }

    /**
     * @dev Gets a license type and its respective data given the {licenseHash}.
     *
     * Requirements:
     * - the given license hash must not be empty.
     * - the given license type must exist.
     */
    function getLicenseType(bytes32 licenseHash) public view returns (License memory) {
        if (licenseHash == 0) {
            revert LicenseHashNotGiven();
        }

        // get the {License} instance
        uint256 index = getIndexByLicenseHash(licenseHash);

        // revert if the license does not exist
        if (index == 0) {
            revert LicenseDoesNotExist(licenseHash);
        }

        // return the license type
        return licenseTypes[index - 1];
    }

    /**
     * @dev Gets the index of a license within {licenseTypes} given a {licenseHash}.

     * Can be used to check whether a license exists. The index returned from this function will always be incremented by 1.
     * This is done so that a `0` can be returned should the queried-for license not exist.
     *
     * If {licenseHash} does not match with any of the license hashes within {licenseTypes}, an error is thrown.
     */
    function getIndexByLicenseHash(bytes32 licenseHash) internal view returns (uint256) {
        for (uint256 i = 0; i < licenseTypes.length; i++) {
            if (licenseTypes[i].licenseHash == licenseHash) {
                // we add 1 so that the index starts at a minimum of 1 instead of 0.
                // this is so that we can return a 0 if the license does not exist.
                return i + 1;
            }
        }

        // 0 is returned if the license hash does not exist.
        return 0;
    }
}