// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IBasePoolFactory} from "../interfaces/factory/IBasePoolFactory.sol";
import {IPoolMaster} from "../interfaces/master/IPoolMaster.sol";

abstract contract BasePoolFactory is IBasePoolFactory {
    /// @dev The pool master that control fees and registry.
    address public immutable master;

    /// @dev Pools by its two pool tokens.
    mapping(address => mapping(address => address)) public override getPool;

    bytes internal cachedDeployData;

    constructor(address _master) {
        master = _master;
    }

    function getSwapFee(
        address pool,
        address sender,
        address tokenIn,
        address tokenOut,
        bytes calldata data
    ) external view override returns (uint24 swapFee) {
        swapFee = IPoolMaster(master).getSwapFee(
            pool,
            sender,
            tokenIn,
            tokenOut,
            data
        );
    }

    function createPool(
        address tokenA,
        address tokenB
    ) external override returns (address pool) {
        // Perform safety checks.
        if (tokenA == tokenB) revert InvalidTokens();

        // Sort tokens.
        if (tokenB < tokenA) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        if (tokenA == address(0)) revert InvalidTokens();

        // Underlying implementation to deploy the pools and register them.
        pool = _createPool(tokenA, tokenB);

        // Populate mapping in both directions.
        // Not necessary as existence of the master, but keep them for better compatibility.
        getPool[tokenA][tokenB] = pool;
        getPool[tokenB][tokenA] = pool;

        emit PoolCreated(tokenA, tokenB, pool);
    }

    function _createPool(
        address tokenA,
        address tokenB
    ) internal virtual returns (address) {}
}
