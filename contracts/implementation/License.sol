// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../base/Royalty.sol";

/**
 * @dev Handles and manages all license-related functionality and logic; inherits {Royalty} which in turn inherits all other contracts.
 */
contract License is Royalty {
    // sets {_receiver} to {receiver}.
    constructor(address receiver) {
        _currentApplicationIndex = 1;
        _receiver = receiver;
    }
}