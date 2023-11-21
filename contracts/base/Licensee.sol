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

    event LicenseeAdded(address indexed newLicensee, uint256 timestamp);
    event LicenseeRemoved(address indexed removedLicensee, uint256 timestamp);
    event LicenseeUpdated(address indexed licensee, bytes data, uint256 timestamp);
    event LicenseeStatusUpdated(address indexed licensee, bool usable, uint256 timestamp);

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

    /**
     * @dev Fetches the caller's {LicenseeAccount} instance.
     */
    function getAccount() external virtual view returns (LicenseeAccount memory) {
        return _licenseeAccount[_msgSender()];
    }

    /**
     * @dev Fetches {licensee}'s {LicenseeAccount} instance. Can only be called by an owner.
     */
    function getAccount(address licensee) external virtual onlyOwner view returns (LicenseeAccount memory) {
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

        emit LicenseeAdded(_msgSender(), block.timestamp);
    }

    /**
     * @dev Similar to the other {registerAccount}, but allows an owner to manually register {user}'s licensee account.
     * Since this account will be directly added by an owner, this function assumes legitimacy checks beforehand are complete and sets {usable} directly to true.
     *
     * Requirements:
     * - The caller must be an owner.
     * - The given {user} must not have a licensee account registered within {_licenseeAccount}.
     * - The given {data} must not be empty.
     */
    function registerAccount(address user, bytes calldata data) external virtual onlyOwner {
        if (_licenseeAccount[user].data.length != 0) {
            revert LicenseeAlreadyExists(user);
        }

        if (data.length == 0) {
            revert EmptyLicenseeData();
        }

        LicenseeAccount memory licenseeAccount = LicenseeAccount({
            data: data,
            usable: true
        });

        _licenseeAccount[user] = licenseeAccount;

        emit LicenseeAdded(user, block.timestamp);
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