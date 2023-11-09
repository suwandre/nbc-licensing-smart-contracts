// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "../access/MultiOwnable.sol";

/**
 * @dev Licensee handles all licensees' data.
 */
abstract contract Licensee is MultiOwnable {
    // lists all possible statuses when registering for a licensee account.
    enum LicenseeStatus { Pending, Approved, Rejected }

    struct LicenseeAccount {
        // the licensee's address.
        address licensee;
        // the licensee's data.
        bytes data;
        // the status of the licensee's account.
        // NOTE: only {LicenseeStatus.Approved} accounts can be used to apply for a license.
        LicenseeStatus status;
    }

    // mapping from a licensee's address to their account data.
    mapping (address => LicenseeAccount) private _licenseeAccount;

    /**
     * @dev Throws if the caller is not the owner or a licensee.
     */
    error NotOwnerOrLicensee(address caller);

    /**
     * @dev Throws if the given licensee already exists within {_licenseeAccount}.
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
     * @dev Throws if the data to change is the same as the data inside {_licenseeAccount}.
     */
    error LicenseeDataSame(bytes data);

    /**
     * @dev Throws if the licensee's status is either {LicenseeStatus.Approved} or {LicenseeStatus.Rejected}.
     */
    error LicenseeStatusNotPending(address licensee);

    /**
     * @dev Throws if the given licensee doesn't exist within {licenseeData}.
     */
    error LicenseeDoesntExist(address licensee);

    event LicenseeAdded(address indexed newLicensee);
    event LicenseeRemoved(address indexed removedLicensee);
    event LicenseeUpdated(address indexed licensee, bytes data);
    event LicenseeStatusUpdated(address indexed licensee, LicenseeStatus status);

    // a modifier that checks whether the caller is one of the owners or a licensee.
    modifier onlyOwnerOrLicensee() {
        _checkOwnerOrLicensee();
        _;
    }

    // a modifier that checks whether the caller is a licensee.
    modifier onlyLicensee() {
        _checkLicenseeExists();
        _;
    }

    /**
     * @dev Checks whether the caller is one of the owners or a licensee.
     */
    function _checkOwnerOrLicensee() private view {
        if (!_isOwner() || !_checkLicenseeExists()) {
            revert NotOwnerOrLicensee(_msgSender());
        }
    }

    /**
     * @dev Checks whether the caller has a licensee account registered (i.e. has a data in {licenseeData})
     */
    function _checkLicenseeExists() private view returns (bool) {
        if (_licenseeAccount[_msgSender()].data.length == 0) {
            return false;
        }

        return true;
    }

    /**
     * @dev Allows a user to register their wallet as a licensee.
     *
     * Because any wallet can invoke this function, there will be checks of {data} done separately to ensure that it is of the correct format.
     * This will ensure that the licensor (NBC) will only grant a licensee account to those who meet our requirements.
     *
     * Requirements:
     * - the licensee account must not already exist within {_licenseeAccount}.
     * - the given {data} must not be empty.
     *
     * NOTE: All newly registered accounts will automatically receive a status of {LicenseeStatus.Pending}.
     */
    function registerLicenseeAccount(
        bytes calldata data
    ) public {
        if (_licenseeAccount[_msgSender()].data.length != 0) {
            revert LicenseeAlreadyExists(_msgSender());
        }

        if (data.length == 0) {
            revert LicenseeDataMustNotBeEmpty();
        }

        LicenseeAccount memory licenseeAccount = LicenseeAccount({
            licensee: _msgSender(),
            data: data,
            status: LicenseeStatus.Pending
        });

        _licenseeAccount[_msgSender()] = licenseeAccount;

        emit LicenseeAdded(_msgSender());
    }

    /**
     * @dev Batch approves a list of licensee accounts.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given licensee must exist within {licenseeData}.
     * - the given licensee's status must be {LicenseeStatus.Pending}.
     *
     * NOTE: As this is a batch execution, we will not revert if any of the checks fail. 
     * instead, we will simply skip the licensee.
     */
    function approveLicenseeAccounts(address[] memory licensees) public onlyOwner {
        for (uint256 i = 0; i < licensees.length; i++) {
            address licensee = licensees[i];

            if (_licenseeAccount[licensee].data.length == 0) {
                continue;
            }

            if (_licenseeAccount[licensee].status != LicenseeStatus.Pending) {
                continue;
            }

            _licenseeAccount[licensee].status = LicenseeStatus.Approved;

            emit LicenseeStatusUpdated(licensee, LicenseeStatus.Approved);
        }
    }

    /**
     * @dev Batch rejects a list of licensee accounts.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given licensee must exist within {licenseeData}.
     * - the given licensee's status must be {LicenseeStatus.Pending}.
     *
     * NOTE: As this is a batch execution, we will not revert if any of the checks fail.
     * instead, we will simply skip the licensee.
     */
    function rejectLicenseeAccounts(address[] memory licensees) public onlyOwner {
        for (uint256 i = 0; i < licensees.length; i++) {
            address licensee = licensees[i];

            if (_licenseeAccount[licensee].data.length == 0) {
                continue;
            }

            if (_licenseeAccount[licensee].status != LicenseeStatus.Pending) {
                continue;
            }

            _licenseeAccount[licensee].status = LicenseeStatus.Rejected;

            emit LicenseeStatusUpdated(licensee, LicenseeStatus.Rejected);
        }
    }

    /**
     * @dev Batch updates a list of licensee accounts.
     * 
     * Requirements:
     * - the caller must be an owner.
     * - the given licensee must exist within {licenseeData}.
     * - the given {data} must not be empty.
     * - the given {data} must not be the same as the data inside {licenseeData}.
     *
     * NOTE: As this is a batch execution, we will not revert if any of the checks fail.
     * instead, we will simply skip the licensee.
     */
    function updateLicenseeAccounts(address[] memory licensees, bytes[] memory data) public onlyOwner {
        for (uint256 i = 0; i < licensees.length; i++) {
            address licensee = licensees[i];

            if (_licenseeAccount[licensee].data.length == 0) {
                continue;
            }

            if (data[i].length == 0) {
                continue;
            }

            if (keccak256(_licenseeAccount[licensee].data) == keccak256(data[i])) {
                continue;
            }

            _licenseeAccount[licensee].data = data[i];

            emit LicenseeUpdated(licensee, data[i]);
        }
    }

    /**
     * @dev Batch removes a list of licensee accounts.
     *
     * Requirements:
     * - the caller must be an owner.
     * - the given licensee must exist within {licenseeData}.
     */
    function removeLicenseeAccounts(address[] memory licensees) public onlyOwner {
        for (uint256 i = 0; i < licensees.length; i++) {
            address licensee = licensees[i];

            if (_licenseeAccount[licensee].data.length == 0) {
                continue;
            }

            delete _licenseeAccount[licensee];

            emit LicenseeRemoved(licensee);
        }
    }
}