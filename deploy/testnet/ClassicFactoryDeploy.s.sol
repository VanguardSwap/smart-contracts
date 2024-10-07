// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {VanguardClassicPoolFactory} from "src/pool/classic/VanguardClassicPoolFactory.sol";
import {IPoolMaster} from "src/interfaces/master/IPoolMaster.sol";

/*
    forge script deploy/testnet/ClassicFactoryDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract ClassicFactoryDeploy is Script {
    function run(address _master) public returns (address instance) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(new VanguardClassicPoolFactory(_master));
        IPoolMaster(_master).setFactoryWhitelisted(instance, true);
        vm.stopBroadcast();
    }
}
