// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

interface IFeeRecipient {
    event NotifyFees(address indexed sender, uint16 indexed feeType, address indexed token, uint amount, uint feeRate);
    event AddFeeDistributor(address indexed distributor);
    event RemoveFeeDistributor(address indexed distributor);
    event SetFeeRegistry(address indexed feeRegistry);
    event SetEpochDuration(uint epochDuration);

    error InvalidFeeSender();
    error InvalidAddress();
    error InvalidDuration();
    error NotSet();
    error NoPermission();
    error WrongArrayLength();
    error AlreadySet();

    /// @dev Notifies the fee recipient after sent fees.
    function notifyFees(
        uint16 feeType,
        address token,
        uint amount,
        uint feeRate,
        bytes calldata data
    ) external;
}
