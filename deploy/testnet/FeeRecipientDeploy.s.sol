// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {VanguardFeeRecipient} from "src/master/VanguardFeeRecipient.sol";

/*
    forge script deploy/testnet/FeeRecipientDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract FeeRecipientDeploy is Script {
    function run(address _feeRegistry) public returns (address instance) {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(new VanguardFeeRecipient(_feeRegistry));
        vm.stopBroadcast();
    }
}
