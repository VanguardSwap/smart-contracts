// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {VanguardPoolMaster} from "src/master/VanguardPoolMaster.sol";

/*
    forge script deploy/testnet/PoolMasterDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract PoolMasterDeploy is Script {
    function run(
        address _vault,
        address _forwarderRegistry
    ) public returns (address instance) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(new VanguardPoolMaster(_vault, _forwarderRegistry, address(0)));
        vm.stopBroadcast();
    }
}
