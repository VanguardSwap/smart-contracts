// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {IWETH} from "src/interfaces/IWETH.sol";

/*
    forge script script/WrapIP.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract WrapIP is Script {
    IWETH wIP = IWETH(0x6e990040Fd9b06F98eFb62A147201696941680b5);

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(pk);
        wIP.deposit{value: 1.5 ether}();
        vm.stopBroadcast();

        console.log("WIP balance: ", wIP.balanceOf(0x5B1D72Dce914FC4fB24d2BfBa4DdBdd05625152D));
    }
}
