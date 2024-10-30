// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

import {IRouter} from "src/interfaces/IRouter.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/*
    forge script script/AddLiquidity.s.sol \
        --ffi --broadcast --rpc-url https://testnet.storyrpc.io
*/
contract AddLiquidity is Script {
    IRouter router = IRouter(0x8535F24C5762011999509a73A9c3AD0E8acc35De);
    IRouter.FactoryType factoryType = IRouter.FactoryType.CLASSIC;
    address token0 = 0x968B9a5603ddEb2A78Aa08182BC44Ece1D9E5bf0;
    address token1 = 0x153B112138C6dE2CAD16D66B4B6448B7b88CAEF3;
    address to = 0x5B1D72Dce914FC4fB24d2BfBa4DdBdd05625152D;
    uint256 amount0 = 3 ether;
    uint256 amount1 = 2e7;
    uint256 minLiquidity = 0;

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        IRouter.TokenInput[] memory tokenInputs = new IRouter.TokenInput[](2);
        tokenInputs[0] = IRouter.TokenInput({token: token0, amount: amount0});
        tokenInputs[1] = IRouter.TokenInput({token: token1, amount: amount1});

        vm.startBroadcast(pk);
        IERC20(token0).approve(address(router), amount0);
        IERC20(token1).approve(address(router), amount1);

        uint256 liquidity = router.addLiquidity(
            IRouter.AddLiquidityInfo({
                factoryType: factoryType,
                tokenInputs: tokenInputs,
                pool: address(0),
                to: to,
                minLiquidity: minLiquidity
            }),
            address(0),
            new bytes(0)
        );
        vm.stopBroadcast();

        console.log("Liquidity: ", liquidity);
    }
}
