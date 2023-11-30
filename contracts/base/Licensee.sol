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
    mapping(address => LicenseeAccount) private _licenseeAccount;

    // a modifier that checks whether the caller is a licensee.
    modifier onlyLicensee() {
        _checkLicensee(_msgSender());
        _;
    }

    // a modifier that checks whether the caller is an owner or a licensee.
    modifier onlyOwnerOrLicensee() {
        if (!isOwner() && !_isLicensee()) {
            revert NotOwnerOrLicensee(_msgSender());
        }
        _;
    }

    // a modifier that checks whether the caller is an owner or the queried for licensee.
    modifier onlyOwnerOrOwnLicensee(address licensee) {
        if (!isOwner() && _msgSender() != licensee) {
            revert NotOwnerOrOwnLicensee(_msgSender(), licensee);
        }
        _;
    }

    /**
     * @dev Fetches {licensee}'s {LicenseeAccount} instance. Can only be called by an owner or self (for licensees).
     * If the caller is neither an owner nor the queried for {licensee}, this function reverts.
     */
    function getAccount(address licensee) external virtual onlyOwnerOrOwnLicensee(licensee) view returns (LicenseeAccount memory) {
        return _licenseeAccount[licensee];
    }

    /**
     * @dev Allows a user to register a licensee account using their wallet address.
     *
     * Can be called by anyone. As such, checks for valid {data} parameters will be done off-chain to:
     * 1. Distinguish falsely registered accounts from legitimately registered accounts.
     * 2. Approve legimitately registered accounts.
     *
     * Requirements:
     * - The caller must not have a licensee account registered within {_licenseeAccount}.
     * - The given {data} must not be empty.
     *
     * NOTE: All newly registered accounts via {registerAccount} automatically receive a {usable} field of false.
     */
    function registerAccount(bytes calldata data) external virtual {
        if (_licenseeAccount[_msgSender()].data.length != 0) {
            revert LicenseeAlreadyExists(_msgSender());
        }

        if (data.length == 0) {
            revert EmptyLicenseeData();
        }

        LicenseeAccount memory licenseeAccount = LicenseeAccount({
            data: data,
            usable: false
        });

        _licenseeAccount[_msgSender()] = licenseeAccount;

        emit LicenseeRegistered(_msgSender(), block.timestamp);
    }

    /**
     * @dev Batch approves a list of registered accounts.
     *
     * Requirements:
     * - The caller must be an owner.
     * - The given {licensees} must exist within {_licenseeAccount}.
     * - The given {licensees}'s {usable} field must be false.
     * 
     * NOTE: As this is a batch execution, this function doesn't revert if any of the checks fail.
     * Instead, that specific licensee will be skipped.
     */
    function approveAccounts(address[] calldata licensees) external virtual onlyOwner {
        for (uint256 i = 0; i < licensees.length; i++) {
            address licensee = licensees[i];

            if (_licenseeAccount[licensee].data.length == 0) {
                continue;
            }

            if (_licenseeAccount[licensee].usable) {
                continue;
            }

            _licenseeAccount[licensee].usable = true;
        }

        emit LicenseeStatusesUpdated(licensees, true, block.timestamp);
    }

    /**
     * @dev Batch updates the {data} field of a list of registered accounts.
     *
     * Requirements:
     * - The caller must be an owner.
     * - The given {licensees} must exist within {_licenseeAccount}.
     * - The given {data} for each licensee must not be empty.
     * - The given {data} for each licensee must be different from their current {data}.
     *
     * NOTE: As this is a batch execution, this function doesn't revert if any of the checks fail.
     * Instead, that specific licensee will be skipped.
     */
    function updateAccounts(address[] calldata licensees, bytes[] calldata data) external virtual onlyOwner {
        for (uint256 i = 0; i < licensees.length; i++) {
            address licensee = licensees[i];

            if (_licenseeAccount[licensee].data.length == 0) {
                continue;
            }

            if (data[i].length == 0) {
                continue;
            }

            if (keccak256(abi.encodePacked(_licenseeAccount[licensee].data)) == keccak256(abi.encodePacked(data[i]))) {
                continue;
            }

            _licenseeAccount[licensee].data = data[i];
        }

        emit LicenseesUpdated(licensees, data, block.timestamp);
    }

    /**
     * @dev Removes the caller's licensee account.
     *
     * Requirements:
     * - The caller must have a licensee account registered within {_licenseeAccount}.
     */
    function removeAccount() external virtual onlyLicensee {
        delete _licenseeAccount[_msgSender()];
    }

    /**
     * @dev Batch removes a list of registered accounts.
     *
     * Requirements:
     * - The caller must be an owner.
     * - The given {licensees} must exist within {_licenseeAccount}.
     *
     * NOTE: As this is a batch execution, this function doesn't revert if any of the checks fail.
     * Instead, that specific licensee will be skipped.
     */
    function removeAccounts(address[] calldata licensees) external virtual onlyOwner {
        for (uint256 i = 0; i < licensees.length; i++) {
            address licensee = licensees[i];

            if (_licenseeAccount[licensee].data.length == 0) {
                continue;
            }

            delete _licenseeAccount[licensee];
        }

        emit LicenseesRemoved(licensees, block.timestamp);
    }

    /**
     * @dev Checks whether the caller is a licensee.
     *
     * In order for the caller to be a licensee (regardless of account status), {LicenseeAccount - data} must NOT be empty (i.e. length != 0).
     */
    function _isLicensee() internal virtual view returns (bool) {
        return _licenseeAccount[_msgSender()].data.length > 0;
    }

    /**
     * @dev Calls {_isLicensee} and reverts if the caller is not a licensee.
     */
    function _checkLicensee(address toCheck) internal virtual view {
        if (!_isLicensee()) {
            revert LicenseeDoesntExist(toCheck);
        }
    }
}