// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

interface IForwarderRegistry {
    event AddForwarder(address forwarder);
    event RemoveForwarder(address forwarder);

    error InvalidAddress();
    error AlreadyAdded();
    error NotAdded();

    function addForwarder(address forwarder) external;

    function isForwarder(address forwarder) external view returns (bool);
}
