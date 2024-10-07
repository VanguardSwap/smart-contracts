// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {TestWETH9} from "test/mocks/TestWETH9.sol";
import {VanguardVault} from "src/vault/VanguardVault.sol";
import {VanguardPoolMaster} from "src/master/VanguardPoolMaster.sol";
import {VanguardFeeManager} from "src/master/VanguardFeeManager.sol";
import {FeeRegistry} from "src/master/FeeRegistry.sol";
import {VanguardFeeRecipient} from "src/master/VanguardFeeRecipient.sol";
import {ForwarderRegistry} from "src/master/ForwarderRegistry.sol";
import {VanguardStablePoolFactory} from "src/pool/stable/VanguardStablePoolFactory.sol";
import {VanguardClassicPoolFactory} from "src/pool/classic/VanguardClassicPoolFactory.sol";
import {IBasePoolFactory} from "src/interfaces/factory/IBasePoolFactory.sol";
import {IPoolMaster} from "src/interfaces/master/IPoolMaster.sol";
import {IStablePool} from "src/interfaces/pool/IStablePool.sol";
import {IClassicPool} from "src/interfaces/pool/IClassicPool.sol";

contract RouterIntegrationTest is Test {
    MockERC20 public tokenA = new MockERC20();
    MockERC20 public tokenB = new MockERC20();