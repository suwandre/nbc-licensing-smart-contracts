// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./LicensePermit.sol";
import "./Licensee.sol";

/**
 * @dev BaseLicenseRegistry handles base variables and constants for {LicenseRegistry}.
 */
abstract contract BaseLicenseRegistry is LicensePermit, Licensee {
    // the licensor; the address corresponds to one of NBC's addresses
    address public licensor;

    /**
     * @dev a license data instance which contains the base license and its respective final terms.
     *
     * NOTE: {appliedTerms} contains the full applied terms of {License - baseTerms}; licensees are to use this as their main reference.
     */
    struct LicenseData {
        // the licensee (the party that is receiving the license).
        address licensee;
        // the license obtained from {LicensePermit}.
        License license;
        // the URL that leads to the applied terms.
        string appliedTerms;
        // the license's expiration date (in unix timestamp).
        // note that the data of {appliedTerms} should also include the expiration date.
        uint256 expirationDate;
    }

    /**
     * @dev LicenseAgreement is the final agreement between the licensor and the licensee, in which the licensee has confirmed and signed the LicenseData instance.
     */
    struct LicenseAgreement {
        // the license data instance.
        LicenseData licenseData;
        // the signature containing the {LicenseData} instance signed by the licensee.
        bytes32 signature;
    }

    // a mapping of a licensee's address to the licenses obtained.
    mapping(address => LicenseAgreement[]) public licensesObtained;

    
}