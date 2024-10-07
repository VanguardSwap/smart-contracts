// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {VanguardStablePoolFactory} from "src/pool/stable/VanguardStablePoolFactory.sol";
import {IPoolMaster} from "src/interfaces/master/IPoolMaster.sol";

/*
    forge script deploy/testnet/StableFactoryDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract StableFactoryDeploy is Script {
    function run(address _master) public returns (address instance) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(new VanguardStablePoolFactory(_master));
        IPoolMaster(_master).setFactoryWhitelisted(instance, true);
        vm.stopBroadcast();
    }
}
