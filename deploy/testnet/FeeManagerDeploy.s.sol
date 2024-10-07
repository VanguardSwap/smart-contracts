// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {VanguardFeeManager} from "src/master/VanguardFeeManager.sol";
import {IPoolMaster} from "src/interfaces/master/IPoolMaster.sol";

/*
    forge script deploy/testnet/FeeManagerDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract FeeManagerDeploy is Script {
    function run(
        address _feeRecipient,
        address _master
    ) public returns (address instance) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(new VanguardFeeManager(_feeRecipient));
        IPoolMaster(_master).setFeeManager(instance);
        vm.stopBroadcast();
    }
}
