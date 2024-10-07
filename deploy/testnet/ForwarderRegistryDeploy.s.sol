// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {ForwarderRegistry} from "src/master/ForwarderRegistry.sol";

/*
    forge script deploy/testnet/ForwarderRegistryDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract ForwarderRegistryDeploy is Script {
    function run() public returns (address instance) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(new ForwarderRegistry());
        vm.stopBroadcast();
    }
}
