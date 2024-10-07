// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

interface IFeeRegistry {
    event SetSenderWhitelisted(
        address indexed sender,
        bool indexed isWhitelisted
    );

    error InvalidAddress();
    error AlreadySet();

    function setSenderWhitelisted(
        address sender,
        bool isWhitelisted
    ) external;

    function isFeeSender(address sender) external view returns (bool);
}
