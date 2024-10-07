// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {Test, console} from "forge-std/Test.sol";
import {TestERC20} from "test/mocks/TestERC20.sol";
import {TestWETH9} from "test/mocks/TestWETH9.sol";
import {VanguardVault} from "src/vault/VanguardVault.sol";
import {VanguardPoolMaster} from "src/master/VanguardPoolMaster.sol";
import {VanguardFeeManager} from "src/master/VanguardFeeManager.sol";
import {FeeRegistry} from "src/master/FeeRegistry.sol";
import {VanguardFeeRecipient} from "src/master/VanguardFeeRecipient.sol";
import {ForwarderRegistry} from "src/master/ForwarderRegistry.sol";
import {VanguardClassicPoolFactory} from "src/pool/classic/VanguardClassicPoolFactory.sol";
import {IBasePoolFactory} from "src/interfaces/factory/IBasePoolFactory.sol";
import {IPoolMaster} from "src/interfaces/master/IPoolMaster.sol";
import {IClassicPool} from "src/interfaces/pool/IClassicPool.sol";
import {Helper, IPool} from "test/spec/Helper.sol";

abstract contract ClassicPoolHelper is Test, Helper {
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10 ** decimals;
    uint private constant MINIMUM_LIQUIDITY = 1000;

    TestERC20 public tokenA = new TestERC20(totalSupply, decimals);
    TestERC20 public tokenB = new TestERC20(totalSupply, decimals);
    TestWETH9 public weth = new TestWETH9();
    VanguardVault public vault;
    VanguardPoolMaster public master;
    VanguardFeeManager public feeManager;
    VanguardClassicPoolFactory public factory;
    IClassicPool public pool;

    address public token0;
    address public token1;
    address public poolAddress;
    address public wallet = address(this);

    modifier restartState() {
        uint256 snapshot = vm.snapshot();
        _;
        vm.revertTo(snapshot);
    }

    function _createClassicPool() internal {
        vault = new VanguardVault(address(weth));
        (master, feeManager) = _deployPoolMaster(address(vault));
        factory = new VanguardClassicPoolFactory(address(master));

        master.setFactoryWhitelisted(address(factory), true);

        (token0, token1) = address(tokenA) < address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        poolAddress = master.createPool(address(factory), token0, token1);
        pool = IClassicPool(poolAddress);
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

    function _expandToDecimals(uint256 amount) internal view returns (uint256) {
        return amount * 10 ** decimals;
    }

    function _deposit(address token, uint256 amount) internal {
        IERC20(token).transfer(address(vault), amount);
        vault.deposit(token, poolAddress);
    }

    /////////////////////////////////
    //////// MINT LIQUIDITY /////////
    /////////////////////////////////

    function _tryMint(
        uint256 token0Amount,
        uint256 token1Amount,
        uint256 expectedLiquidity,
        uint256 expectedFee0,
        uint256 expectedFee1
    ) internal {
        uint256 poolBalance0Before = vault.balanceOf(token0, poolAddress);
        uint256 poolBalance1Before = vault.balanceOf(token1, poolAddress);

        uint256 totalSupplyBefore = pool.totalSupply();
        uint256 liquidityBefore = pool.balanceOf(msg.sender);

        // Prefund tokens
        _deposit(token0, token0Amount);
        _deposit(token1, token1Amount);
        assertEq(
            vault.balanceOf(token0, poolAddress),
            poolBalance0Before + token0Amount
        );
        assertEq(
            vault.balanceOf(token1, poolAddress),
            poolBalance1Before + token1Amount
        );

        (
            uint256 liquidity,
            uint256 fee0,
            uint256 fee1,
            uint256 protocolFee
        ) = _calculateLiquidityToMint(
                msg.sender,
                address(master),
                address(vault),
                poolAddress,
                token0,
                token1,
                token0Amount,
                token1Amount
            );

        if (expectedLiquidity != 0) assertEq(liquidity, expectedLiquidity);
        if (expectedFee0 != 0) assertEq(fee0, expectedFee0);
        if (expectedFee1 != 0) assertEq(fee1, expectedFee1);

        if (poolBalance0Before == 0) {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), address(0), MINIMUM_LIQUIDITY);
            vm.expectEmit();
            emit IERC20.Transfer(address(0), msg.sender, liquidity - MINIMUM_LIQUIDITY);
            vm.expectEmit();
            emit IPool.Sync(token0Amount, token1Amount);
            vm.expectEmit();
            emit IPool.Mint(address(this), token0Amount, token1Amount, liquidity - MINIMUM_LIQUIDITY, msg.sender);
        } else {
            vm.expectEmit();
            emit IERC20.Transfer(address(0), msg.sender, liquidity);
            vm.expectEmit();
            emit IPool.Sync(token0Amount + poolBalance0Before, token1Amount + poolBalance1Before);
            vm.expectEmit();
            emit IPool.Mint(address(this), token0Amount, token1Amount, liquidity, msg.sender);
        }

        pool.mint(msg.sender, msg.sender, address(0), new bytes(0));

        assertEq(pool.totalSupply(), totalSupplyBefore + liquidity + protocolFee);

        uint256 liquidityAfter = poolBalance0Before == 0 
            ? liquidity - MINIMUM_LIQUIDITY
            : liquidity + liquidityBefore;

        assertEq(pool.balanceOf(msg.sender), liquidityAfter);
        assertEq(pool.reserve0(), poolBalance0Before + token0Amount);
        assertEq(pool.reserve1(), poolBalance1Before + token1Amount);

        assertEq(vault.balanceOf(token0, poolAddress), poolBalance0Before + token0Amount);
        assertEq(vault.balanceOf(token1, poolAddress), poolBalance1Before + token1Amount);
    }

    function _mintExpectedLiquidity() internal restartState {
        uint256 token0Amount = _expandToDecimals(2);
        uint256 token1Amount = _expandToDecimals(8);

        _tryMint(token0Amount, token1Amount, _expandToDecimals(4), 0, 0);
        assertEq(pool.totalSupply(), _expandToDecimals(4));
    }

    function _mintExpectedLiquidityEvenly() internal restartState {
        uint256 token0Amount = _expandToDecimals(4);
        uint256 token1Amount = _expandToDecimals(4);

        _tryMint(token0Amount, token1Amount, _expandToDecimals(4), 0, 0);
        assertEq(pool.totalSupply(), _expandToDecimals(4));
    }

    function _mintExpectedLiquidityEdgeCase() internal restartState {
        uint256 token0Amount = 14276;
        uint256 token1Amount = _expandToDecimals(2789);

        _tryMint(token0Amount, token1Amount, 6309973375538, 0, 0);
        assertEq(pool.totalSupply(), 6309973375538);
    }

    function _mintExpectedLiquidityBalanced() internal restartState {
        uint256 token0Amount = _expandToDecimals(4);
        uint256 token1Amount = _expandToDecimals(9);

        _tryMint(token0Amount, token1Amount, _expandToDecimals(6), 0, 0);
        assertEq(pool.totalSupply(), _expandToDecimals(6));

        _tryMint(token0Amount, token1Amount, _expandToDecimals(6), 0, 0);
        assertEq(pool.totalSupply(), _expandToDecimals(12));

        token0Amount = _expandToDecimals(16);
        token1Amount = _expandToDecimals(36);
        _tryMint(token0Amount, token1Amount, _expandToDecimals(24), 0, 0);
        assertEq(pool.totalSupply(), _expandToDecimals(36));
    }

    function _mintExpectedLiquidityUnBalanced() internal restartState {
        uint256 token0Amount = _expandToDecimals(1);
        uint256 token1Amount = _expandToDecimals(4);

        _tryMint(token0Amount, token1Amount, _expandToDecimals(2), 0, 0);
        assertEq(pool.totalSupply(), _expandToDecimals(2));

        token0Amount = _expandToDecimals(4);
        token1Amount = _expandToDecimals(4);
        _tryMint(token0Amount, token1Amount, 4318321251448424997, 3000000000000000, 0);

        // Add calculated balanced liquidity expects no fee.
        uint256 reserve0 = pool.reserve0();
        uint256 reserve1 = pool.reserve1();
        token0Amount = _expandToDecimals(1);
        token1Amount = token0Amount * reserve1 / reserve0;
        _tryMint(token0Amount, token1Amount, 1263963801131667101, 0, 0);
    }

    function _mintLiquidityMinimalAmounts() internal restartState {
        _deposit(token0, 1001);
        _deposit(token1, 1001);

        pool.mint(msg.sender, msg.sender, address(0), new bytes(0));

        assertEq(pool.reserve0(), 1001);
        assertEq(pool.reserve1(), 1001);
        assertEq(pool.totalSupply(), 1001);
    }

    function _revertMintLiquidityWithoutTokens() internal {
        vm.expectRevert();
        pool.mint(msg.sender, msg.sender, address(0), new bytes(0));
    }

    function _revertMintLiquidityWithOnlyToken0() internal restartState {
        _deposit(token0, _expandToDecimals(10000));

        vm.expectRevert();
        pool.mint(msg.sender, msg.sender, address(0), new bytes(0));
    }

    function _revertMintLiquidityWithOnlyToken1() internal restartState {
        _deposit(token1, _expandToDecimals(10000));

        vm.expectRevert();
        pool.mint(msg.sender, msg.sender, address(0), new bytes(0));
    }

    function _revertMintLiquidityMinimalAmounts() internal restartState {
        _deposit(token0, 1000);
        _deposit(token1, 1000);

        vm.expectRevert(IClassicPool.InsufficientLiquidityMinted.selector);
        pool.mint(msg.sender, msg.sender, address(0), new bytes(0));
    }

    /////////////////////////////////
    //////// BURN LIQUIDITY /////////
    /////////////////////////////////

    function _tryBurn(uint256 liquidity, uint256 expectedAmount0, uint256 expectedAmount1) internal {
        uint256 liquidityBalance = pool.balanceOf(wallet);
        uint256 balance0Before = IERC20(token0).balanceOf(wallet);
        uint256 balance1Before = IERC20(token1).balanceOf(wallet);

        uint256 _totalSupply = pool.totalSupply();
        uint256 poolBalance0 = vault.balanceOf(token0, poolAddress);
        uint256 poolBalance1 = vault.balanceOf(token1, poolAddress);

        assertEq(_calculatePoolTokens(liquidity, poolBalance0, _totalSupply), expectedAmount0);
        assertEq(_calculatePoolTokens(liquidity, poolBalance1, _totalSupply), expectedAmount1);

        pool.transfer(poolAddress, liquidity);
        assertEq(pool.balanceOf(wallet), liquidityBalance - liquidity);
        assertEq(pool.balanceOf(poolAddress), liquidity);

        vm.expectEmit(poolAddress);
        emit IERC20.Transfer(poolAddress, address(0), liquidity);
        vm.expectEmit(poolAddress);
        emit IPool.Sync(poolBalance0 - expectedAmount0, poolBalance1 - expectedAmount1);
        vm.expectEmit(poolAddress);
        emit IPool.Burn(wallet, expectedAmount0, expectedAmount1, liquidity, wallet);

        pool.burn(1, wallet, wallet, address(0), new bytes(0));

        assertEq(pool.totalSupply(), _totalSupply - liquidity);
        assertEq(pool.balanceOf(poolAddress), 0);
        assertEq(pool.balanceOf(wallet), liquidityBalance - liquidity);

        assertEq(IERC20(token0).balanceOf(wallet), balance0Before + expectedAmount0);
        assertEq(IERC20(token1).balanceOf(wallet), balance1Before + expectedAmount1);

        assertEq(vault.balanceOf(token0, poolAddress), poolBalance0 - expectedAmount0);
        assertEq(vault.balanceOf(token1, poolAddress), poolBalance1 - expectedAmount1);
    }

    function _tryBurnSingle(
        uint256 liquidity,
        address tokenOut,
        uint256 expectedAmount0,
        uint256 expectedAmount1
    ) internal {
        uint256 liquidityBalance = pool.balanceOf(wallet);

        uint256 _totalSupply = pool.totalSupply();
        uint256 poolBalance0 = vault.balanceOf(token0, poolAddress);
        uint256 poolBalance1 = vault.balanceOf(token1, poolAddress);

        uint256 token0AmountBalanced = _calculatePoolTokens(liquidity, poolBalance0, _totalSupply);
        uint256 token1AmountBalanced = _calculatePoolTokens(liquidity, poolBalance1, _totalSupply);

        uint256 swapFee = master.getSwapFee(poolAddress, wallet, address(0), address(0), new bytes(0));
        uint256 token0Amount = tokenOut == token0
            ? token0AmountBalanced + _getAmountOutClassic(
                token1AmountBalanced,
                swapFee,
                poolBalance1 - token1AmountBalanced,
                poolBalance0 - token0AmountBalanced
            )
            : 0;

        uint256 token1Amount = tokenOut == token1
            ? token1AmountBalanced + _getAmountOutClassic(
                token0AmountBalanced,
                swapFee,
                poolBalance0 - token0AmountBalanced,
                poolBalance1 - token1AmountBalanced
            )
            : 0;

        assertEq(token0Amount, expectedAmount0);
        assertEq(token1Amount, expectedAmount1);

        pool.transfer(poolAddress, liquidity);
        assertEq(pool.balanceOf(wallet), liquidityBalance - liquidity);
        assertEq(pool.balanceOf(poolAddress), liquidity);

        vm.expectEmit(poolAddress);
        emit IERC20.Transfer(poolAddress, address(0), liquidity);
        vm.expectEmit(poolAddress);
        emit IPool.Sync(poolBalance0 - token0Amount, poolBalance1 - token1Amount);
        vm.expectEmit(poolAddress);
        emit IPool.Burn(wallet, token0Amount, token1Amount, liquidity, wallet);

        pool.burnSingle(1, tokenOut, wallet, wallet, address(0), new bytes(0));
    }

    function _burnSomeLiquidity() internal restartState {
        _deposit(token0, _expandToDecimals(2));
        _deposit(token1, _expandToDecimals(8));
        pool.mint(wallet, wallet, address(0), new bytes(0));

        _tryBurn(50000, 25000, 100000);
    }

    function _burnAllLiquidity() internal restartState {
        uint256 token0Amount = _expandToDecimals(2);
        uint256 token1Amount = _expandToDecimals(8);
        _deposit(token0, token0Amount);
        _deposit(token1, token1Amount);
        pool.mint(wallet, wallet, address(0), new bytes(0));

        uint256 liquidity = pool.balanceOf(wallet);
        assertEq(liquidity, _sqrt(token0Amount * token1Amount) - MINIMUM_LIQUIDITY);

        _tryBurn(liquidity, 1999999999999999500, 7999999999999998000);
    }

    function _burnSingleForToken0() internal restartState {
        uint256 token0Amount = _expandToDecimals(1);
        uint256 token1Amount = _expandToDecimals(4);
        _deposit(token0, token0Amount);
        _deposit(token1, token1Amount);
        pool.mint(wallet, wallet, address(0), new bytes(0));

        uint256 burnLiquidity = 500000;
        uint256 currentLiquidity = pool.balanceOf(wallet);
        _tryBurnSingle(burnLiquidity, token0, 499499, 0);

        assertEq(pool.balanceOf(wallet), currentLiquidity - burnLiquidity);
    }

    /////////////////////////////////
    //////// SWAP ///////////////////
    /////////////////////////////////

    function _trySwap(
        uint256 liquidity0,
        uint256 liquidity1,
        uint256 amountIn,
        uint256 expectedAmountOut,
        address tokenIn
    ) internal restartState {
        _tryMint(liquidity0, liquidity1, 0, 0, 0);

        uint256 poolTokenInBalanceBefore = vault.balanceOf(tokenIn, poolAddress);
        bool zeroToOne = tokenIn == token0;
        address tokenOut = zeroToOne ? token1 : token0;
        uint256 poolTokenOutBalanceBefore = vault.balanceOf(tokenOut, poolAddress);

        uint256 walletBalanceInBefore = IERC20(tokenIn).balanceOf(wallet);
        uint256 walletBalanceOutBefore = IERC20(tokenOut).balanceOf(wallet);

        _deposit(tokenIn, amountIn);
        assertEq(vault.balanceOf(tokenIn, poolAddress), poolTokenInBalanceBefore + amountIn);

        uint256 reserve0 = pool.reserve0();
        uint256 reserve1 = pool.reserve1();

        (uint256 reserveIn, uint256 reserveOut) = zeroToOne
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        uint256 swapFee = master.getSwapFee(poolAddress, wallet, tokenIn, tokenOut, new bytes(0));

        uint256 amountOut = _getAmountOutClassic(
            amountIn,
            swapFee,
            reserveIn,
            reserveOut
        );

        assertEq(amountOut, expectedAmountOut);

        (uint256 amount0Out, uint256 amount1Out) = zeroToOne
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        (uint256 amount0In, uint256 amount1In) = zeroToOne
            ? (amountIn, uint256(0))
            : (uint256(0), amountIn);

        vm.expectEmit(poolAddress);
        emit IPool.Swap(wallet, amount0In, amount1In, amount0Out, amount1Out, wallet);
        vm.expectEmit(poolAddress);
        if (zeroToOne) {
            emit IPool.Sync(reserve0 + amount0In, reserve1 - amount1Out);
        } else {
            emit IPool.Sync(reserve0 - amount0Out, reserve1 + amount1In);
        }

        pool.swap(1, tokenIn, wallet, wallet, address(0), new bytes(0));

        assertEq(vault.balanceOf(tokenIn, poolAddress), poolTokenInBalanceBefore + amountIn);
        assertEq(vault.balanceOf(tokenOut, poolAddress), poolTokenOutBalanceBefore - amountOut);

        assertEq(vault.balanceOf(tokenIn, poolAddress), reserveIn + amountIn);
        assertEq(vault.balanceOf(tokenOut, poolAddress), reserveOut - amountOut);

        assertEq(IERC20(tokenIn).balanceOf(wallet), walletBalanceInBefore - amountIn);
        assertEq(IERC20(tokenOut).balanceOf(wallet), walletBalanceOutBefore + amountOut);
    }

    function _swapToken0ForToken1() internal {
        SwapData[] memory data = _prepareSwapData();
        for (uint256 i = 0; i < data.length; i++) {
            _trySwap(data[i].liquidity0, data[i].liquidity1, data[i].amountIn, data[i].amountOut, token0);
        }
    }

    function _swapToken1ForToken0() internal {
        SwapData[] memory data = _prepareSwapData();
        for (uint256 i = 0; i < data.length; i++) {
            _trySwap(data[i].liquidity1, data[i].liquidity0, data[i].amountIn, data[i].amountOut, token1);
        }
    }

    struct SwapData {
        uint256 liquidity0;
        uint256 liquidity1;
        uint256 amountIn;
        uint256 amountOut;
    }

    function _prepareSwapData() internal view returns (SwapData[] memory swaps) {
        swaps = new SwapData[](4);

        swaps[0] = SwapData(_expandToDecimals(1), _expandToDecimals(4), _expandToDecimals(1), 1997997997997997997);
        swaps[1] = SwapData(_expandToDecimals(4), _expandToDecimals(1), _expandToDecimals(1), 199679871948779511);
        swaps[2] = SwapData(_expandToDecimals(1), _expandToDecimals(1), _expandToDecimals(1), 499499499499499499);
        swaps[3] = SwapData(_expandToDecimals(1), _expandToDecimals(1), _expandToDecimals(100), 990079365079365079);
    }
}
