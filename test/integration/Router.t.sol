// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

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

        deal(token0, address(this), 10000 * 10**decimals);
        deal(token1, address(this), 10000 * 10**decimals);

        tokenA.approve(address(router), totalSupply);
        tokenB.approve(address(router), totalSupply);
    }

    function test_step1_createPool() public {
        IRouter.FactoryType factoryType = IRouter.FactoryType.CLASSIC;
        IRouter.TokenInput[] memory tokenInputs = new IRouter.TokenInput[](2);
        tokenInputs[0] = IRouter.TokenInput({token: token0, amount: 1000 * 10**decimals});
        tokenInputs[1] = IRouter.TokenInput({token: token1, amount: 1000 * 10**decimals});

        IRouter.AddLiquidityInfo memory info = IRouter.AddLiquidityInfo({
            factoryType: factoryType,
            tokenInputs: tokenInputs,
            to: address(this),
            minLiquidity: 100 * 10**decimals
        });

        router.addLiquidity(info, address(0), new bytes(0));

        address poolAddress = factory.getPool(token0, token1);
        pool = IClassicPool(poolAddress);

        assertEq(pool.token0(), token0);
        assertEq(pool.token1(), token1);
        assertEq(pool.vault(), address(vault));
        assertEq(pool.master(), address(master));
        assertEq(pool.poolType(), 1);
        assertEq(pool.reserve0(), 1000 * 10**decimals);
        assertEq(pool.reserve1(), 1000 * 10**decimals);
    }

    function _correctSetUp() internal pure {
        assertEq(feeRegistry.isFeeSender(address(vault)), true);
        assertEq(master.vault(), address(vault));
        assertEq(master.forwarderRegistry(), address(forwarderRegistry));
        assertEq(master.feeManager(), address(feeManager));
        assertEq(master.isFactoryWhitelisted(address(factory)), true);
        assertEq(forwarderRegistry.isForwarder(address(router)), true);
    }
}
