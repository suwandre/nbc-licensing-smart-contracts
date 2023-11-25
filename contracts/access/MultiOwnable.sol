// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;


import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev A modification to OpenZeppelin's {Ownable} that allows multiple owners.
 * There will be one main owner and multiple owners can exist.
 * The main owner has higher privileges than the other owners, primarily within {MultiOwnable}.
 * In inherited contracts, other owners may have the same or similar privileges to the main owner.
 */
abstract contract MultiOwnable is Context {
    // stores the address of the main owner.
    address private _mainOwner;

    // checks if an address is an owner (incl. the main owner).
    mapping(address => bool) private _isOwner;

    event OwnerAdded(address indexed newOwner, uint256 timestamp);
    event OwnerRemoved(address indexed removedOwner, uint256 timestamp);

    // throws if the caller is not an owner.
    error MultiOwnableUnauthorized(address caller);

    // throws if the caller is not the main owner.
    error MultiOwnableNotMainOwner(address caller);

    // throws if the given address is an invalid address (e.g. `address(0)`).
    // alternatively, if used within {removeOwner}, throws if the given address is not an owner.
    error MultiOwnableInvalidOwner(address owner);

    // throws if a new owner is being added and the given address is already an owner.
    error MultiOwnableAlreadyOwner(address owner);

    constructor() {
        // sets the main owner to the deployer and count them as an owner in {_isOwner}.
        _mainOwner = _msgSender();
        _isOwner[_mainOwner] = true;
    }

    // a modifier that calls {_checkMainOwner} and throws if the caller is not the main owner.
    modifier onlyMainOwner() {
        _checkMainOwner();
        _;
    }

    // a modifier that calls {_checkOwner} and throws if the caller is not an owner.
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Fetches {_mainOwner} and checks whether the caller is the main owner.
     */
    function isMainOwner() internal view virtual returns (bool) {
        return _mainOwner == _msgSender();
    }

    /**
     * @dev Fetches the {_isOwner} mapping and checks whether the caller is an owner.
     */
    function isOwner() internal view virtual returns (bool) {
        return _isOwner[_msgSender()];
    }

    /**
     * @dev Calls {_isOwner} and reverts if the caller is not the main owner.
     */
    function _checkMainOwner() internal view virtual {
        if (!isMainOwner()) {
            revert MultiOwnableNotMainOwner(_msgSender());
        }
    }

    /** 
     * @dev Calls {_isOwner} and reverts if the caller is not an owner.
     */
    function _checkOwner() internal view virtual {
        if (!isOwner()) {
            revert MultiOwnableUnauthorized(_msgSender());
        }
    }

    /**
     * @dev Adds a new owner by adding them to the {_isOwner} mapping.
     *
     * Requirements: 
     * - the caller must be the main owner.
     * - the given address must not be an owner.
     * - the given address must not be an invalid address (e.g. `address(0)`).
     */
    function addOwner(address newOwner) public virtual onlyMainOwner {
        if (newOwner == address(0)) {
            revert MultiOwnableInvalidOwner(newOwner);
        }

        if (_isOwner[newOwner]) {
            revert MultiOwnableAlreadyOwner(newOwner);
        }

        _isOwner[newOwner] = true;

        emit OwnerAdded(newOwner, block.timestamp);
    }

    /**
     * @dev Removes an owner by removing them from the {_isOwner} mapping.
     *
     * Requirements:
     * - the caller must be the main owner.
     * - the given {toRemove} address must be an owner.
     * - the given {toRemove} address must not be an invalid address (e.g. `address(0)`).
     */
    function removeOwner(address toRemove) public virtual onlyMainOwner {
        if (toRemove == address(0)) {
            revert MultiOwnableInvalidOwner(toRemove);
        }

        if (!_isOwner[toRemove]) {
            revert MultiOwnableInvalidOwner(toRemove);
        }

        _isOwner[toRemove] = false;

        emit OwnerRemoved(toRemove, block.timestamp);
    }
}