// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {TestWETH9} from "test/mocks/TestWETH9.sol";
import {VanguardVault} from "src/vault/VanguardVault.sol";
import {VanguardPoolMaster} from "src/master/VanguardPoolMaster.sol";
import {VanguardFeeManager} from "src/master/VanguardFeeManager.sol";
import {FeeRegistry} from "src/master/FeeRegistry.sol";
import {VanguardFeeRecipient} from "src/master/VanguardFeeRecipient.sol";
import {ForwarderRegistry} from "src/master/ForwarderRegistry.sol";
import {VanguardStablePoolFactory} from "src/pool/stable/VanguardStablePoolFactory.sol";
import {VanguardClassicPoolFactory} from "src/pool/classic/VanguardClassicPoolFactory.sol";
import {IBasePoolFactory} from "src/interfaces/factory/IBasePoolFactory.sol";
import {IPoolMaster} from "src/interfaces/master/IPoolMaster.sol";
import {IStablePool} from "src/interfaces/pool/IStablePool.sol";
import {IClassicPool} from "src/interfaces/pool/IClassicPool.sol";

contract BasePoolFactoryTest is Test {
    MockERC20 public tokenA = new MockERC20();
    MockERC20 public tokenB = new MockERC20();
    TestWETH9 public weth = new TestWETH9();
    VanguardVault public vault;
    VanguardPoolMaster public master;
    VanguardFeeManager public feeManager;
    VanguardStablePoolFactory public stableFactory;
    VanguardClassicPoolFactory public classicFactory;

    function setUp() public {
        vault = new VanguardVault(address(weth));
        (master, feeManager) = _deployPoolMaster(address(vault));
        stableFactory = new VanguardStablePoolFactory(address(master));
        classicFactory = new VanguardClassicPoolFactory(address(master));

        master.setFactoryWhitelisted(address(stableFactory), true);
        master.setFactoryWhitelisted(address(classicFactory), true);
    }

    function test_createStablePool() public {
        (address token0, address token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        vm.expectEmit(true, false, true, false);
        emit IPoolMaster.RegisterPool(
            address(stableFactory),
            address(0),
            2,
            new bytes(0)
        );

        vm.expectEmit(true, true, false, false);
        emit IBasePoolFactory.PoolCreated(token0, token1, address(0));

        address pool = master.createPool(address(stableFactory), token0, token1);

        vm.expectRevert();
        master.createPool(address(stableFactory), token1, token0);

        assertEq(stableFactory.getPool(token0, token1), pool);
        assertEq(stableFactory.getPool(token1, token0), pool);
        assertEq(master.poolsLength(), 1);
        assertEq(master.pools(0), pool);
        assertEq(master.isPool(pool), true);

        assertEq(IStablePool(pool).token0(), token0);
        assertEq(IStablePool(pool).token1(), token1);
        assertEq(IStablePool(pool).poolType(), 2);
        assertEq(IStablePool(pool).master(), address(master));
        assertEq(IStablePool(pool).vault(), address(vault));

        address[] memory tokens = IStablePool(pool).getAssets();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token0);
        assertEq(tokens[1], token1);

        assertEq(
            IStablePool(pool).getSwapFee(pool, token0, token1, new bytes(0)),
            40
        );

        assertEq(IStablePool(pool).getProtocolFee(), 50000);

        assertEq(
            IStablePool(pool).token0PrecisionMultiplier(),
            10 ** (18 - tokenA.decimals())
        );

        assertEq(
            IStablePool(pool).token1PrecisionMultiplier(),
            10 ** (18 - tokenB.decimals())
        );
    }

    function test_createClassicPool() public {
        (address token0, address token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        vm.expectEmit(true, false, true, false);
        emit IPoolMaster.RegisterPool(
            address(classicFactory),
            address(0),
            1,
            new bytes(0)
        );

        vm.expectEmit(true, true, false, false);
        emit IBasePoolFactory.PoolCreated(token0, token1, address(0));

        address pool = master.createPool(address(classicFactory), token0, token1);

        vm.expectRevert();
        master.createPool(address(classicFactory), token1, token0);

        assertEq(classicFactory.getPool(token0, token1), pool);
        assertEq(classicFactory.getPool(token1, token0), pool);
        assertEq(master.poolsLength(), 1);
        assertEq(master.pools(0), pool);
        assertEq(master.isPool(pool), true);

        assertEq(IClassicPool(pool).token0(), token0);
        assertEq(IClassicPool(pool).token1(), token1);
        assertEq(IClassicPool(pool).poolType(), 1);
        assertEq(IClassicPool(pool).master(), address(master));
        assertEq(IClassicPool(pool).vault(), address(vault));

        address[] memory tokens = IClassicPool(pool).getAssets();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token0);
        assertEq(tokens[1], token1);

        assertEq(
            IClassicPool(pool).getSwapFee(pool, token0, token1, new bytes(0)),
            200
        );

        assertEq(IClassicPool(pool).getProtocolFee(), 50000);
    }

    function test_createPool_invalidTokens() public {
        vm.expectRevert(IBasePoolFactory.InvalidTokens.selector);
        master.createPool(address(stableFactory), address(tokenA), address(tokenA));

        vm.expectRevert(IBasePoolFactory.InvalidTokens.selector);
        master.createPool(address(stableFactory), address(tokenA), address(0));

        vm.expectRevert(IBasePoolFactory.InvalidTokens.selector);
        master.createPool(address(classicFactory), address(tokenA), address(tokenA));

        vm.expectRevert(IBasePoolFactory.InvalidTokens.selector);
        master.createPool(address(classicFactory), address(tokenA), address(0));
    }

    function test_createPool_notWhitelistedFactory() public {
        VanguardStablePoolFactory anotherFactory = new VanguardStablePoolFactory(
                address(master)
            );

        vm.expectRevert(IPoolMaster.NotWhitelistedFactory.selector);
        master.createPool(
            address(anotherFactory),
            address(tokenA),
            address(tokenB)
        );
    }

    function _deployPoolMaster(
        address _vault
    )
        private
        returns (VanguardPoolMaster _master, VanguardFeeManager _feeManager)
    {
        ForwarderRegistry forwarderRegistry = new ForwarderRegistry();

        _master = new VanguardPoolMaster(
            _vault,
            address(forwarderRegistry),
            address(0)
        );

        FeeRegistry feeRegistry = new FeeRegistry(address(_master));

        VanguardFeeRecipient feeRecipient = new VanguardFeeRecipient(
            address(feeRegistry)
        );

        _feeManager = new VanguardFeeManager(address(feeRecipient));

        _master.setFeeManager(address(_feeManager));
    }
}
