// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

interface IForwarderRegistry {
    event AddForwarder(address forwarder);
    event RemoveForwarder(address forwarder);

    error InvalidAddress();
    error AlreadyAdded();
    error NotAdded();

    function isForwarder(address forwarder) external view returns (bool);
}
