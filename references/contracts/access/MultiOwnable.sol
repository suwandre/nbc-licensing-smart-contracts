//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev A modification to {Ownable} by Openzeppelin that allows multiple owners.
 * The main owner has higher privileges than the other owners within {MultiOwnable}. 
 * In inherited contracts, other owners should have the same or similar privileges to the main owner.
 * 
 * Note that this version of {MultiOwnable} may not be optimized and may lack some features.
 */
 abstract contract MultiOwnable is Context {
    // stores the addresses of all owners.
    address[] private _owners;
    // stores the address of the main owner.
    address private _mainOwner;
    // the limit of owners that can exist within `_owners`.
    uint256 private MAX_OWNERS = 3;

    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);

    /**
     * @dev Throws if the caller is not an owner.
     */
    error MultiOwnableUnauthorized(address caller);

    /**
     * @dev Throws if the caller is not the main owner.
     */
    error MultiOwnableNotMainOwner(address caller);

    /**
     * @dev Throws if the given address is an invalid address (e.g. `address(0)`).
     * Alternatively, if used within {removeOwner}, throws if the given address is not an owner.
     */
    error MultiOwnableInvalidOwner(address owner);

    /**
     * @dev Throws if a new owner is being added and the maximum amount of owners has already been reached.
     */
    error MultiOwnableMaxOwnersReached();

    /**
     * @dev Throws if a new owner is being added and the given address is already an owner.
     */
    error MultiOwnableAlreadyOwner(address owner);

    constructor() {
        // set the main owner to the deployer.
        _mainOwner = _msgSender();
    }

    /**
     * @dev Calls{_checkOwner} and throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Calls {_checkMainOwner} and throws if called by any account other than the main owner.
     */
    modifier onlyMainOwner() {
        _checkMainOwner();
        _;
    }

    /**
     * @dev Returns the addresses of the current owners.
     */
    function owners() public view virtual returns (address[] memory) {
        return _owners;
    }

    /**
     * @dev Changes the max owner limit to {newLimit}.
     */
    function changeOwnerLimit(uint8 newLimit) public virtual onlyMainOwner {
        MAX_OWNERS = newLimit;
    }

    /**
     * @dev Checks whether the caller is an owner.
     */
    function _isOwner() internal view virtual returns (bool) {
        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == _msgSender()) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev Calls {_isOwner} and reverts with {MultiOwnableUnauthorized} if the caller is unauthorized (i.e. not an owner).
     */
    function _checkOwner() internal view virtual {
        if (!_isOwner()) {
            revert MultiOwnableUnauthorized(_msgSender());
        }
    }

    /**
     * @dev Checks whether the caller is the main owner.
     */
    function _checkMainOwner() internal view virtual {
        if (_msgSender() != _mainOwner) {
            revert MultiOwnableNotMainOwner(_msgSender());
        }
    }

    /**
     * @dev Adds a new owner.
     *
     * Requirements:
     *
     * - the caller must be the main owner.
     * - the given address must not be a zero address.
     * - the given address must not already be an owner.
     * - the given address must not exceed the maximum amount of owners.
     */
    function addOwner(address newOwner) public virtual onlyMainOwner {
        if (newOwner == address(0)) {
            revert MultiOwnableInvalidOwner(newOwner);
        }

        if (_isOwner()) {
            revert MultiOwnableAlreadyOwner(newOwner);
        }

        if (_owners.length >= MAX_OWNERS) {
            revert MultiOwnableMaxOwnersReached();
        }

        _owners.push(newOwner);
    }

    /**
     * @dev Removes an owner.
     *
     * Requirements:
     *
     * - the caller must be the main owner.
     * - the given address must not be a zero address.
     * - the given address must be an owner.
     */
    function removeOwner(address owner) public virtual onlyMainOwner {
        if (owner == address(0)) {
            revert MultiOwnableInvalidOwner(owner);
        }

        if (!_isOwner()) {
            revert MultiOwnableInvalidOwner(owner);
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == owner) {
                _owners[i] = _owners[_owners.length - 1];
                _owners.pop();
                break;
            }
        }
    }
}