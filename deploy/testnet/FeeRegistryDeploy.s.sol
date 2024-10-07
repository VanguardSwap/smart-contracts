// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {FeeRegistry, IFeeRegistry} from "src/master/FeeRegistry.sol";

/*
    forge script deploy/testnet/FeeRegistryDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract FeeRegistryDeploy is Script {
    function run(
        address _master,
        address _vault
    ) public returns (address instance) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(new FeeRegistry(_master));
        IFeeRegistry(instance).setSenderWhitelisted(_vault, true);
        vm.stopBroadcast();
    }
}
