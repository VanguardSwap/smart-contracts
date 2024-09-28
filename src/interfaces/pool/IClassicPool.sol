// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IBasePool} from "./IBasePool.sol";

interface IClassicPool is IBasePool {
    error Overflow();
    error InsufficientLiquidityMinted();
}
