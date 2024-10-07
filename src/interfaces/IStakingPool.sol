// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

interface IStakingPool {
    function stake(uint amount, address onBehalf) external;
}
