// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "../access/MultiOwnable.sol";

/**
 * @dev Licensee handles all licensees' data.
 */
abstract contract Licensee is MultiOwnable {
    struct LicenseeAccount {
        // the licensee's address.
        address licensee;
        // the licensee's data.
        bytes data;
        // if the licensee account is usable.
        // NOTE: after account registration, {usable} will automatically be set to false until approved by the licensor.
        // only usable accounts can have full access (e.g. applying for a license).
        bool usable;
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
    event LicenseeUsableUpdated(address indexed licensee, bool usable);

    // a modifier that checks whether the caller a licensee.
    modifier onlyLicensee(address toCheck) {
        _checkLicensee(toCheck);
        _;
    }

    // a modifier that checks whether the caller is either a licensee or an owner.
    modifier onlyLicenseeOrOwner(address toCheck) {
        bool toCheckIsLicensee = _checkLicenseeExists(toCheck);
        bool toCheckIsOwner = _isOwner();

        if (!toCheckIsLicensee && !toCheckIsOwner) {
            revert NotOwnerOrLicensee(toCheck);
        }
        _;
    }

    /**
     * @dev Checks whether {toCheck} has a licensee account registered (i.e. has a data in {licenseeData})
     */
    function _checkLicenseeExists(address toCheck) internal view returns (bool) {
        if (_licenseeAccount[toCheck].data.length == 0) {
            return false;
        }

        return true;
    }

    /**
     * @dev An alternative to {_checkLicenseeExists} that throws if the given {toCheck} doesn't have a licensee account registered.
     */
    function _checkLicensee(address toCheck) internal view {
        if (!_checkLicenseeExists(toCheck)) {
            revert LicenseeDoesntExist(toCheck);
        }
    }

    /**
     * @dev Gets the licensee account of {licensee}. Can only be called by the owner.
     */
    function getLicenseeAccountDev(address licensee) public view onlyOwner returns (LicenseeAccount memory) {
        return _licenseeAccount[licensee];
    }

    /**
     * @dev Gets the licensee account of the caller.
     */
    function getLicenseeAccount() public view onlyLicenseeOrOwner(_msgSender()) returns (LicenseeAccount memory) {
        return _licenseeAccount[_msgSender()];
    }

    /**
     * @dev Allows a user to register their wallet as a licensee.
     *
     * Because any wallet can invoke this function, there will be checks of {data} to ensure that it is of the correct format.
     * This will ensure that the licensor (NBC) will only grant a licensee account to those who meet our requirements.
     *
     * Requirements:
     * - the licensee account must not already exist within {_licenseeAccount}.
     * - the given {data} must not be empty.
     *
     * NOTE: All newly registered accounts will automatically receive a {usable} field of false.
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
            usable: false
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