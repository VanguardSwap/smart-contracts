// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IPoolFactory} from "./IPoolFactory.sol";

interface IBasePoolFactory is IPoolFactory {
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        address pool
    );

    error InvalidTokens();

    function getPool(
        address tokenA,
        address tokenB
    ) external view returns (address pool);

    function getSwapFee(
        address pool,
        address sender,
        address tokenIn,
        address tokenOut,
        bytes calldata data
    ) external view returns (uint24 swapFee);
}
