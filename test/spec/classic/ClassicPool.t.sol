// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {ClassicPoolHelper} from "test/spec/classic/ClassicPoolHelper.sol";

contract ClassicPoolTest is ClassicPoolHelper {
    function setUp() public {
        _createClassicPool();
        assertEq(factory.getPool(token0, token1), poolAddress);

        assertEq(pool.token0(), token0);
        assertEq(pool.token1(), token1);
        assertEq(pool.vault(), address(vault));
        assertEq(pool.master(), address(master));
        assertEq(pool.poolType(), 1);
        assertEq(pool.reserve0(), 0);
        assertEq(pool.reserve1(), 0);
        assertEq(pool.invariantLast(), 0);

        deal(token0, msg.sender, 1000000000000000000000 * 10**decimals);
        deal(token1, msg.sender, 1000000000000000000000 * 10**decimals);
        deal(token0, address(this), 1000000000000000000000 * 10**decimals);
        deal(token1, address(this), 1000000000000000000000 * 10**decimals);
    }

    function test_mint() public {
        // reverts
        _revertMintLiquidityWithoutTokens();
        _revertMintLiquidityWithOnlyToken0();
        _revertMintLiquidityWithOnlyToken1();
        _revertMintLiquidityMinimalAmounts();

        // success
        _mintLiquidityMinimalAmounts();
        _mintExpectedLiquidity();
        _mintExpectedLiquidityEvenly();
        _mintExpectedLiquidityEdgeCase();
        _mintExpectedLiquidityBalanced();
        _mintExpectedLiquidityUnBalanced();
    }

    function test_burn() public {
        _burnSomeLiquidity();
        _burnAllLiquidity();
        _burnSingleForToken0();
    }

    function test_swap() public {
        _swapToken0ForToken1();
        _swapToken1ForToken0();
    }
}
