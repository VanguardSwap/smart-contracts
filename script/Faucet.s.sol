// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

interface IToken {
    function drip() external;
    function balanceOf(address) external view returns (uint);
    function symbol() external view returns (string memory);
}
/*
    forge script script/Faucet.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract Faucet is Script {
    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        IToken[] memory tokens = new IToken[](4);
        tokens[0] = IToken(0x8812d810EA7CC4e1c3FB45cef19D6a7ECBf2D85D);
        tokens[1] = IToken(0x153B112138C6dE2CAD16D66B4B6448B7b88CAEF3);
        tokens[2] = IToken(0x968B9a5603ddEb2A78Aa08182BC44Ece1D9E5bf0);
        tokens[3] = IToken(0x700722D24f9256Be288f56449E8AB1D27C4a70ca);

        vm.startBroadcast(pk);
        for (uint i; i < tokens.length; i++) {
            tokens[i].drip();
        }
        vm.stopBroadcast();

        for (uint i = 0; i < tokens.length; i++) {
            console.log(tokens[i].symbol(), "balance: ", tokens[i].balanceOf(0x5B1D72Dce914FC4fB24d2BfBa4DdBdd05625152D));
        }
    }
}
