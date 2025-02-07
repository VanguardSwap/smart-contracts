// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IERC20Metadata as IERC20} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IPoolMaster} from "../../interfaces/master/IPoolMaster.sol";
import {BasePoolFactory} from "../BasePoolFactory.sol";
import {VanguardStablePool} from "./VanguardStablePool.sol";

contract VanguardStablePoolFactory is BasePoolFactory {
    constructor(address _master) BasePoolFactory(_master) {}

    function _createPool(
        address token0,
        address token1
    ) internal override returns (address pool) {
        // Tokens with decimals more than 18 are not supported and will lead to reverts.
        uint token0PrecisionMultiplier = 10 ** (18 - IERC20(token0).decimals());
        uint token1PrecisionMultiplier = 10 ** (18 - IERC20(token1).decimals());

        bytes memory deployData = abi.encode(
            token0,
            token1,
            token0PrecisionMultiplier,
            token1PrecisionMultiplier
        );

        cachedDeployData = deployData;

        bytes32 salt = keccak256(abi.encode(token0, token1));
        pool = address(new VanguardStablePool{salt: salt}(deployData)); // this will prevent duplicated pools.

        // Register the pool with config.
        IPoolMaster(master).registerPool(pool, 2, deployData);
    }
}
