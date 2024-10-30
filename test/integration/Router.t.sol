// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {Test, console} from "forge-std/Test.sol";
import {IVault} from "src/interfaces/vault/IVault.sol";
import {IPoolMaster} from "src/master/VanguardPoolMaster.sol";
import {IFeeManager} from "src/master/VanguardFeeManager.sol";
import {IFeeRegistry} from "src/master/FeeRegistry.sol";
import {IForwarderRegistry} from "src/master/ForwarderRegistry.sol";
import {IBasePoolFactory as IFactory} from "src/interfaces/factory/IBasePoolFactory.sol";
import {IClassicPool} from "src/interfaces/pool/IClassicPool.sol";
import {IRouter} from "src/interfaces/IRouter.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {TestWETH9} from "test/mocks/TestWETH9.sol";
import {IWETH} from "src/interfaces/IWETH.sol";

import {TestnetDeploy} from "deploy/testnet/TestnetDeploy.s.sol";

contract RouterIntegrationTest is IntegrationTest {
    address internal _wallet;
    uint256 internal _walletPrivateKey;

    IVault internal vault;
    IPoolMaster internal master;
    IFeeManager internal feeManager;
    IFactory internal factory;
    IClassicPool internal pool;
    IRouter internal router;
    IFeeRegistry internal feeRegistry;
    IForwarderRegistry internal forwarderRegistry;

    uint8 internal decimals = 18;
    uint256 internal totalSupply = 1000000 * 10 ** decimals;

    TestERC20 internal tokenA = new TestERC20(totalSupply, decimals);
    TestERC20 internal tokenB = new TestERC20(totalSupply, decimals);
    address wIP = 0x6e990040Fd9b06F98eFb62A147201696941680b5; // Story Testnet wIP
    IWETH internal wIPContract = IWETH(wIP);
    address internal token0;
    address internal token1;

    function setUp() public {
        _walletPrivateKey = vm.envUint("PRIVATE_KEY");
        _wallet = vm.addr(_walletPrivateKey);

        TestnetDeploy deploy = new TestnetDeploy();
        TestnetDeploy.DeployedContracts memory contracts = deploy.run();

        vault = IVault(contracts.vault);
        master = IPoolMaster(contracts.master);
        feeManager = IFeeManager(contracts.feeManager);
        factory = IFactory(contracts.classicFactory);
        router = IRouter(contracts.router);
        feeRegistry = IFeeRegistry(contracts.feeRegistry);
        forwarderRegistry = IForwarderRegistry(contracts.forwarderRegistry);

        _correctSetUp();

        (token0, token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        TestWETH9 awesomeContract = new TestWETH9();
        bytes memory code = address(awesomeContract).code;
        vm.etch(wIP, code);

        deal(token0, address(this), _expandToDecimals(10000));
        deal(token1, address(this), _expandToDecimals(10000));

        tokenA.approve(address(router), totalSupply);
        tokenB.approve(address(router), totalSupply);
    }

    function test_step1_createPool() public {
        IRouter.FactoryType factoryType = IRouter.FactoryType.CLASSIC;
        IRouter.TokenInput[] memory tokenInputs = new IRouter.TokenInput[](2);
        tokenInputs[0] = IRouter.TokenInput({token: token0, amount: _expandToDecimals(1000)});
        tokenInputs[1] = IRouter.TokenInput({token: token1, amount: _expandToDecimals(1000)});

        IRouter.AddLiquidityInfo memory info = IRouter.AddLiquidityInfo({
            factoryType: factoryType,
            tokenInputs: tokenInputs,
            pool: address(0),
            to: address(this),
            minLiquidity: _expandToDecimals(100)
        });

        router.addLiquidity(info, address(0), new bytes(0));

        address poolAddress = factory.getPool(token0, token1);
        pool = IClassicPool(poolAddress);

        assertEq(pool.token0(), token0);
        assertEq(pool.token1(), token1);
        assertEq(pool.vault(), address(vault));
        assertEq(pool.master(), address(master));
        assertEq(pool.poolType(), 1);
        assertEq(pool.reserve0(), _expandToDecimals(1000));
        assertEq(pool.reserve1(), _expandToDecimals(1000));
    }

    function test_step2_swapTokensByPoolInput() public {
        test_step1_createPool();

        IRouter.SwapStep[] memory step = new IRouter.SwapStep[](1);
        step[0] = IRouter.SwapStep({
            pool: address(pool),
            withdrawMode: 1,
            tokenIn: token0,
            to: address(this),
            callback: address(0),
            callbackData: new bytes(0)
        });

        IRouter.SwapPath[] memory path = new IRouter.SwapPath[](1);
        path[0] = IRouter.SwapPath({
            steps: step,
            tokenIn: token0,
            tokenOut: address(0),
            factoryType: IRouter.FactoryType.CLASSIC,
            amountIn: _expandToDecimals(100)
        });

        uint256 amountOut = IClassicPool(pool).getAmountOut(token0, _expandToDecimals(100), address(this));

        router.swap(path, amountOut - 1, block.timestamp + 1000);

        assertEq(IERC20(token0).balanceOf(address(this)), _expandToDecimals(10000) - _expandToDecimals(1000) - _expandToDecimals(100));
        assertEq(IERC20(token1).balanceOf(address(this)), _expandToDecimals(10000) - _expandToDecimals(1000) + amountOut);
    }

    function test_step2_swapTokensByTokensInput() public {
        test_step1_createPool();

        IRouter.SwapStep[] memory step = new IRouter.SwapStep[](1);
        step[0] = IRouter.SwapStep({
            pool: address(0),
            withdrawMode: 1,
            tokenIn: token0,
            to: address(this),
            callback: address(0),
            callbackData: new bytes(0)
        });

        IRouter.SwapPath[] memory path = new IRouter.SwapPath[](1);
        path[0] = IRouter.SwapPath({
            steps: step,
            tokenIn: token0,
            tokenOut: token1,
            factoryType: IRouter.FactoryType.CLASSIC,
            amountIn: 100 * 10**decimals
        });

        uint256 amountOut = IClassicPool(pool).getAmountOut(token0, 100 * 10**decimals, address(this));

        router.swap(path, amountOut - 1, block.timestamp + 1000);

        assertEq(IERC20(token0).balanceOf(address(this)), _expandToDecimals(10000) - _expandToDecimals(1000) - _expandToDecimals(100));
        assertEq(IERC20(token1).balanceOf(address(this)), _expandToDecimals(10000) - _expandToDecimals(1000) + amountOut);
    }

    function test_step3_createPoolUsingIP() public {
        test_step2_swapTokensByPoolInput();

        IRouter.FactoryType factoryType = IRouter.FactoryType.CLASSIC;
        IRouter.TokenInput[] memory tokenInputs = new IRouter.TokenInput[](2);
        tokenInputs[0] = IRouter.TokenInput({token: address(0), amount: _expandToDecimals(1000)});
        tokenInputs[1] = IRouter.TokenInput({token: address(tokenA), amount: _expandToDecimals(1000)});

        (address token0Address, address token1Address) = wIP < address(tokenA)
            ? (wIP, address(tokenA))
            : (address(tokenA), wIP);

        IRouter.AddLiquidityInfo memory info = IRouter.AddLiquidityInfo({
            factoryType: factoryType,
            tokenInputs: tokenInputs,
            pool: address(0),
            to: address(this),
            minLiquidity: _expandToDecimals(100)
        });

        router.addLiquidity{value: _expandToDecimals(1000)}(info, address(0), new bytes(0));

        address poolAddress = factory.getPool(token0Address, token1Address);
        pool = IClassicPool(poolAddress);

        assertEq(pool.token0(), token0Address);
        assertEq(pool.token1(), token1Address);
        assertEq(pool.vault(), address(vault));
        assertEq(pool.master(), address(master));
        assertEq(pool.poolType(), 1);
        assertEq(pool.reserve0(), _expandToDecimals(1000));
        assertEq(pool.reserve1(), _expandToDecimals(1000));

        // Add liquidity by provide pool address
        info.pool = poolAddress;
        router.addLiquidity{value: _expandToDecimals(1000)}(info, address(0), new bytes(0));

        assertEq(pool.reserve0(), _expandToDecimals(2000));
        assertEq(pool.reserve1(), _expandToDecimals(2000));

        // Add liquidity by wrapped IP
        wIPContract.deposit{value: _expandToDecimals(1000)}();
        wIPContract.approve(address(router), _expandToDecimals(1000));

        info.tokenInputs[0].token = wIP;
        router.addLiquidity(info, address(0), new bytes(0));

        assertEq(pool.reserve0(), _expandToDecimals(3000));
        assertEq(pool.reserve1(), _expandToDecimals(3000));
    }

    function _correctSetUp() internal view {
        assertEq(feeRegistry.isFeeSender(address(vault)), true);
        assertEq(master.vault(), address(vault));
        assertEq(master.forwarderRegistry(), address(forwarderRegistry));
        assertEq(master.feeManager(), address(feeManager));
        assertEq(master.isFactoryWhitelisted(address(factory)), true);
        assertEq(forwarderRegistry.isForwarder(address(router)), true);
    }

    function _expandToDecimals(uint256 amount) internal view returns (uint256) {
        return amount * 10 ** decimals;
    }
}
