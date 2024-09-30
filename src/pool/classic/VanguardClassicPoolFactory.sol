// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IPoolMaster} from "../../interfaces/master/IPoolMaster.sol";
import {BasePoolFactory} from "../BasePoolFactory.sol";
import {VanguardClassicPool} from "./VanguardClassicPool.sol";

contract VanguardClassicPoolFactory is BasePoolFactory {
    constructor(address _master) BasePoolFactory(_master) {}

    function _createPool(
        address token0,
        address token1
    ) internal override returns (address pool) {
        // Perform sanity checks.
        IERC20(token0).balanceOf(address(this));
        IERC20(token1).balanceOf(address(this));

        bytes memory deployData = abi.encode(token0, token1);
        cachedDeployData = deployData;

        // The salt is same with deployment data.
        bytes32 salt = keccak256(deployData);
        pool = address(new VanguardClassicPool{salt: salt}(deployData)); // this will prevent duplicated pools.

        // Register the pool. The config is same with deployment data.
        IPoolMaster(master).registerPool(pool, 1, deployData);
    }
}
