// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IPoolMaster} from "../interfaces/master/IPoolMaster.sol";
import {IFeeRegistry} from "../interfaces/master/IFeeRegistry.sol";

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

contract FeeRegistry is IFeeRegistry, Ownable {
    /// @dev The pool master.
    address public immutable master;

    /// @dev Whether a fee sender is whitelisted.
    mapping(address => bool) public isSenderWhitelisted;

    constructor(address _master) Ownable(msg.sender) {
        master = _master;
    }

    /// @dev Returns whether the address is a valid fee sender.
    function isFeeSender(address sender) external view override returns (bool) {
        return
            isSenderWhitelisted[sender] || IPoolMaster(master).isPool(sender);
    }

    /// @dev Whitelists a fee sender explicitly.
    function setSenderWhitelisted(
        address sender,
        bool isWhitelisted
    ) external onlyOwner {
        require(sender != address(0), InvalidAddress());
        require(isSenderWhitelisted[sender] != isWhitelisted, AlreadySet());
        isSenderWhitelisted[sender] = isWhitelisted;
        emit SetSenderWhitelisted(sender, isWhitelisted);
    }
}
