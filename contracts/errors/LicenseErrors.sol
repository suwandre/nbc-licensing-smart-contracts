// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @dev All errors related to the {Licensee} contract.
 */
interface ILicenseeErrors {
    /**
     * @dev Throws if the caller is neither an owner nor a licensee.
     */
    error NotOwnerOrLicensee(address caller);

    /**
     * @dev Throws if an account with the given {licensee} address already exists within {Licensee - _licenseeAccount}.
     */
    error LicenseeAlreadyExists(address licensee);

    /**
     * @dev Throws if the given {licensee} address is invalid (e.g. `address(0)`).
     */
    error InvalidLicenseeAddress(address licensee);

    /**
     * @dev Throws if the given licensee data is empty.
     */
    error EmptyLicenseeData();

    /**
     * @dev Throws if the given {data} is the same as the data inside the {Licensee - _licenseeAccount} instance.
     */
    error SameLicenseeData(bytes data);

    /**
     * @dev Throws if the licensee's account status is not {LicenseeStatus.Pending}.
     */
    error AccountStatusNotPending(address licensee);

    /**
     * @dev Throws if the given licensee account doesn't exist within {_licenseeAccount}.
     */
    error LicenseeDoesntExist(address licensee);
}