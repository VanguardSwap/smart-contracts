// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IFeeManager} from "./IFeeManager.sol";

/// @dev The master contract to create pools and manage whitelisted factories.
/// Inheriting the fee manager interface to support fee queries.
interface IPoolMaster is IFeeManager {
    event SetFactoryWhitelisted(address indexed factory, bool whitelisted);
    event UpdateForwarderRegistry(address indexed newForwarderRegistry);
    event UpdateFeeManager(address indexed newFeeManager);

    event RegisterPool(
        address indexed factory,
        address indexed pool,
        uint16 indexed poolType,
        bytes data
    );

    error NotWhitelistedFactory();
    error PoolAlreadyExists();
    error InvalidFactory();
    error RegisterPoolZeroAddress();

    function vault() external view returns (address);

    function feeManager() external view returns (address);

    function forwarderRegistry() external view returns (address);

    function pools(uint) external view returns (address);

    function poolsLength() external view returns (uint);

    function isForwarder(address forwarder) external view returns (bool);

    // Forwarder Registry
    function setForwarderRegistry(address) external;

    // Fees
    function setFeeManager(address) external;

    // Factories
    function isFactoryWhitelisted(address) external view returns (bool);

    function setFactoryWhitelisted(address factory, bool whitelisted) external;

    // Pools
    function isPool(address) external view returns (bool);

    function getPool(bytes32) external view returns (address);

    function createPool(
        address factory,
        address tokenA,
        address tokenB
    ) external returns (address pool);

    function registerPool(
        address pool,
        uint16 poolType,
        bytes calldata data
    ) external;
}
