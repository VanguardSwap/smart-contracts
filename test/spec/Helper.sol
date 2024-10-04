// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {console} from "forge-std/Test.sol";
import {IBasePool as IPool} from "src/interfaces/pool/IBasePool.sol";
import {IStablePool} from "src/interfaces/pool/IStablePool.sol";
import {IVault} from "src/interfaces/vault/IVault.sol";
import {IPoolMaster} from "src/interfaces/master/IPoolMaster.sol";

abstract contract Helper {
    uint private constant MAX_FEE = 1e5;

    function _calculateLiquidityToMint(
        address sender,
        address master,
        address vault,
        address pool,
        address token0,
        address token1,
        uint256 amount0In,
        uint256 amount1In
    )
        internal
        view
        returns (
            uint256 liquidity,
            uint256 fee0,
            uint256 fee1,
            uint256
        )
    {
        uint256 reserve0 = IPool(pool).reserve0();
        uint256 reserve1 = IPool(pool).reserve1();

        uint256 balance0 = IVault(vault).balanceOf(token0, pool);
        uint256 balance1 = IVault(vault).balanceOf(token1, pool);

        uint256 newInvariant = _computeInvariant(pool, balance0, balance1);
        uint256 swapFee = IPoolMaster(master).getSwapFee(
            pool,
            sender,
            address(0),
            address(0),
            new bytes(0)
        );

        (fee0, fee1) = _unbalancedMintFee(
            swapFee,
            reserve0,
            reserve1,
            amount0In,
            amount1In
        );

        (uint256 totalSupply, uint256 oldInvariant, uint256 protocolFee) = _calculateMintProtocolFee(
            pool,
            master,
            reserve0 + fee0,
            reserve1 + fee1
        );

        if (totalSupply == 0) {
            return (newInvariant, fee0, fee1, 0);
        } else {
            return(
                ((newInvariant - oldInvariant) * totalSupply) / oldInvariant,
                fee0,
                fee1,
                protocolFee
            );
        }
    }

    function _calculateMintProtocolFee(
        address pool,
        address master,
        uint256 reserve0,
        uint256 reserve1
    )
        internal
        view
        returns (uint256 totalSupply, uint256 invariant, uint256 protocolFee)
    {
        totalSupply = IPool(pool).totalSupply();
        invariant = _computeInvariant(pool, reserve0, reserve1);

        address feeTo = IPoolMaster(master).getFeeRecipient();

        if (feeTo == address(0)) {
            return (totalSupply, invariant, 0);
        }

        uint256 lastInvariant = IPool(pool).invariantLast();
        if (lastInvariant != 0) {
            if (invariant > lastInvariant) {
                protocolFee = IPoolMaster(master).getProtocolFee(pool);
                uint256 numerator = totalSupply * (invariant - lastInvariant) * protocolFee;
                uint256 denominator = (MAX_FEE - protocolFee) * invariant + protocolFee * lastInvariant;
                uint256 liquidity = numerator / denominator;
                return (totalSupply + liquidity, invariant, liquidity);
            }
        }

        return (totalSupply, invariant, 0);
    }

    function _computeInvariant(
        address pool,
        uint256 balance0,
        uint256 balance1
    ) internal view returns (uint256 invariant) {
        uint256 poolType = IPool(pool).poolType();

        if (poolType == 1) {
            invariant = _sqrt(balance0 * balance1);
        } else {
            uint256 adjustedReserve0 = balance0 *
                IStablePool(pool).token0PrecisionMultiplier();
            uint256 adjustedReserve1 = balance1 *
                IStablePool(pool).token1PrecisionMultiplier();
        }
    }

    function _sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function _unbalancedMintFee(
        uint _swapFee,
        uint _reserve0,
        uint _reserve1,
        uint _amount0,
        uint _amount1
    ) private pure returns (uint _token0Fee, uint _token1Fee) {
        if (_reserve0 == 0 || _reserve1 == 0) {
            return (0, 0);
        }

        uint256 amount1Optimal = (_amount0 * _reserve1) / _reserve0;
        if (_amount1 >= amount1Optimal) {
            _token1Fee =
                (_swapFee * (_amount1 - amount1Optimal)) /
                (2 * MAX_FEE);
        } else {
            uint amount0Optimal = (_amount1 * _reserve0) / _reserve1;
            _token0Fee =
                (_swapFee * (_amount0 - amount0Optimal)) /
                (2 * MAX_FEE);
        }
    }

    function _calculatePoolTokens(
        uint256 liquidity,
        uint256 balance,
        uint256 totalSupply
    ) internal view returns (uint256) {
        return (liquidity * balance) / totalSupply;
    }

    function _getAmountOutClassic(
        uint256 amountIn,
        uint256 swapFee,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * (MAX_FEE - swapFee);
        return amountInWithFee * reserveOut / (reserveIn * MAX_FEE + amountInWithFee);
    }
}
