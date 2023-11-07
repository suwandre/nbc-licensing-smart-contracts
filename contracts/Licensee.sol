// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "./access/MultiOwnable.sol";

/**
 * @dev Licensee handles all licensees' data.
 */
contract Licensee is MultiOwnable {
    // a mapping from a licensee's address to their data.
    mapping (address => bytes32) private licenseeData;

    /**
     * @dev Throws if the caller is not the owner or a licensee.
     */
    error NotOwnerOrLicensee(address caller);

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
     * @dev Retrieves the licensee's data from {licenseeData}.
     */
    function getLicenseeData(address licensee) public view onlyOwnerOrLicensee(licensee) returns (bytes32) {
        return licenseeData[licensee];
    }

    /**
     * @dev Adds a licensee's data into {licenseeData}.
     */
    function addLicenseeData(address licensee, bytes32 data) public virtual onlyOwner {
        licenseeData[licensee] = data;
    }

    /**
     * @dev Removes a licensee's data from {licenseeData}.
     */
    function removeLicenseeData(address licensee) public virtual onlyOwner {
        delete licenseeData[licensee];
    }
}