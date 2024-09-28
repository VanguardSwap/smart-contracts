// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

/// @notice The manager contract to control fees.
/// Management functions are omitted.
interface IFeeManager {
    event SetDefaultSwapFee(uint16 indexed poolType, uint24 fee);
    event SetTokenSwapFee(address indexed tokenIn, address indexed tokenOut, uint24 fee);
    event SetDefaultProtocolFee(uint16 indexed poolType, uint24 fee);
    event SetPoolProtocolFee(address indexed pool, uint24 fee);
    event SetFeeRecipient(address indexed previousFeeRecipient, address indexed newFeeRecipient);

    error InvalidFee();

    function getSwapFee(
        address pool,
        address sender,
        address tokenIn,
        address tokenOut,
        bytes calldata data
    ) external view returns (uint24);

    function getProtocolFee(address pool) external view returns (uint24);
    function getFeeRecipient() external view returns (address);
}
