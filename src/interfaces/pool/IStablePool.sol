// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import {IBasePool} from "./IBasePool.sol";

interface IStablePool is IBasePool {
    error Overflow();
    error InsufficientLiquidityMinted();

    function token0PrecisionMultiplier() external view returns (uint);
    function token1PrecisionMultiplier() external view returns (uint);
}
