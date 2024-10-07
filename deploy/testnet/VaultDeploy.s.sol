// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {VanguardVault} from "src/vault/VanguardVault.sol";

/*
    forge script deploy/testnet/VaultDeploy.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract VaultDeploy is Script {
    function run() public returns (address instance) {
        address wIP = 0x6e990040Fd9b06F98eFb62A147201696941680b5; // Story Testnet wIP

        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        instance = address(new VanguardVault(wIP));
        vm.stopBroadcast();
    }
}
