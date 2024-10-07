// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

interface IPool {
    struct TokenAmount {
        address token;
        uint amount;
    }

    /// @dev Returns the address of pool master.
    function master() external view returns (address);

    /// @dev Returns the vault.
    function vault() external view returns (address);

    /// @dev Returns the pool type.
    function poolType() external view returns (uint16);

    /// @dev Returns the assets of the pool.
    function getAssets() external view returns (address[] memory assets);

    /// @dev Returns the swap fee of the pool.
    function getSwapFee(
        address sender,
        address tokenIn,
        address tokenOut,
        bytes calldata data
    ) external view returns (uint24 swapFee);

    /// @dev Returns the protocol fee of the pool.
    function getProtocolFee() external view returns (uint24 protocolFee);

    /// @dev Mints liquidity.
    function mint(
        address to,
        address sender,
        address callback,
        bytes calldata callbackData
    ) external returns (uint liquidity);

    /// @dev Burns liquidity.
    function burn(
        uint8 withdrawMode,
        address to,
        address sender,
        address callback,
        bytes calldata callbackData
    ) external returns (TokenAmount[] memory tokenAmounts);

    /// @dev Burns liquidity with single output token.
    function burnSingle(
        uint8 withdrawMode,
        address tokenOut,
        address to,
        address sender,
        address callback,
        bytes calldata callbackData
    ) external returns (TokenAmount memory tokenAmount);

    /// @dev Swaps between tokens.
    function swap(
        uint8 withdrawMode,
        address tokenIn,
        address to,
        address sender,
        address callback,
        bytes calldata callbackData
    ) external returns (TokenAmount memory tokenAmount);
}
