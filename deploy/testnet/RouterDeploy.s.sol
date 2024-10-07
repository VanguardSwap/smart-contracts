// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {VanguardRouter} from "src/VanguardRouter.sol";
import {IForwarderRegistry} from "src/interfaces/master/IForwarderRegistry.sol";

/*
    forge script deploy/testnet/RouterDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract RouterDeploy is Script {
    function run(
        address _vault,
        address _forwarderRegistry,
        address _classicFactory,
        address _stableFactory
    ) public returns (address instance) {
        address wIP = 0x6e990040Fd9b06F98eFb62A147201696941680b5; // Story Testnet wIP

        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(
            new VanguardRouter(_vault, wIP, _classicFactory, _stableFactory)
        );

        IForwarderRegistry(_forwarderRegistry).addForwarder(instance);
        vm.stopBroadcast();
    }
}
