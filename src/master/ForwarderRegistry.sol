// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IForwarderRegistry} from "../interfaces/master/IForwarderRegistry.sol";

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// @notice A simple registry for sender forwarder contracts (usually the routers).
contract ForwarderRegistry is IForwarderRegistry, Ownable {
    mapping(address => bool) private _isForwarder;

    constructor() Ownable(msg.sender) {}

    function isForwarder(
        address forwarder
    ) external view override returns (bool) {
        return _isForwarder[forwarder];
    }

    function addForwarder(address forwarder) external onlyOwner {
        require(forwarder != address(0), InvalidAddress());
        require(!_isForwarder[forwarder], AlreadyAdded());
        _isForwarder[forwarder] = true;
        emit AddForwarder(forwarder);
    }

    function removeForwarder(address forwarder) external onlyOwner {
        require(_isForwarder[forwarder], NotAdded());
        delete _isForwarder[forwarder];
        emit RemoveForwarder(forwarder);
    }
}
