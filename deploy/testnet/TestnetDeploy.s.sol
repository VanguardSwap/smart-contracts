// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {VaultDeploy} from "deploy/testnet/VaultDeploy.s.sol";
import {ForwarderRegistryDeploy} from "deploy/testnet/ForwarderRegistryDeploy.s.sol";
import {PoolMasterDeploy} from "deploy/testnet/PoolMasterDeploy.s.sol";
import {FeeRegistryDeploy} from "deploy/testnet/FeeRegistryDeploy.s.sol";
import {FeeRecipientDeploy} from "deploy/testnet/FeeRecipientDeploy.s.sol";
import {FeeManagerDeploy} from "deploy/testnet/FeeManagerDeploy.s.sol";
import {ClassicFactoryDeploy} from "deploy/testnet/ClassicFactoryDeploy.s.sol";
import {StableFactoryDeploy} from "deploy/testnet/StableFactoryDeploy.s.sol";
import {RouterDeploy} from "deploy/testnet/RouterDeploy.s.sol";

/*
    forge script deploy/testnet/TestnetDeploy.s.sol \
       --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract TestnetDeploy {
    struct DeployedContracts {
        address vault;
        address forwarderRegistry;
        address master;
        address feeRegistry;
        address feeRecipient;
        address feeManager;
        address classicFactory;
        address stableFactory;
        address router;
    }

    function run() public returns (DeployedContracts memory) {
        address vault = new VaultDeploy().run();

        address forwarderRegistry = new ForwarderRegistryDeploy().run();

        address master = new PoolMasterDeploy().run(vault, forwarderRegistry);

        address feeRegistry = new FeeRegistryDeploy().run(master, vault);

        address feeRecipient = new FeeRecipientDeploy().run(feeRegistry);

        address feeManager = new FeeManagerDeploy().run(feeRecipient, master);

        address classicFactory = new ClassicFactoryDeploy().run(master);

        address stableFactory = new StableFactoryDeploy().run(master);

        address router = new RouterDeploy().run(vault, forwarderRegistry, classicFactory, stableFactory);

        return
            DeployedContracts(
                vault,
                forwarderRegistry,
                master,
                feeRegistry,
                feeRecipient,
                feeManager,
                classicFactory,
                stableFactory,
                router
            );
    }
}
