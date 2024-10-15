// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {VanguardRouter} from "src/VanguardRouter.sol";
import {IForwarderRegistry} from "src/interfaces/master/IForwarderRegistry.sol";

/*
    forge script deploy/testnet/RouterReDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract RouterReDeploy is Script {
    function run() public returns (address instance) {
        address wIP = 0x6e990040Fd9b06F98eFb62A147201696941680b5; // Story Testnet wIP
        address vault = 0x72B5eC7618ef5CDB836D266AF8C97458F00E1543;
        address forwarderRegistry = 0xCb59dDADBfbEe4008f53bCdf1A2Ea35ff6C0E682;
        address classicFactory = 0x16D6D5627a6d4da55cE81b624Ad31e42E163B9c4;
        address stableFactory = 0x951A7c09e1caeDEcdC893C98cCFA8B7B65272f58;

        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(
            new VanguardRouter(vault, wIP, classicFactory, stableFactory)
        );

        IForwarderRegistry(forwarderRegistry).addForwarder(instance);
        vm.stopBroadcast();
    }
}
