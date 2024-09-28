// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

interface IPoolFactory {
    function master() external view returns (address);

    function getDeployData() external view returns (bytes memory);

    function createPool(bytes calldata data) external returns (address pool);
}
