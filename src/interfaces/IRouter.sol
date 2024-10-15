// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

import {IPool} from "src/interfaces/pool/IPool.sol";

interface IRouter {
    enum FactoryType {
        CLASSIC,
        STABLE
    }

    struct SwapStep {
        address pool;
        uint8 withdrawMode;
        address tokenIn;
        address to;
        address callback;
        bytes callbackData;
    }

    struct SwapPath {
        SwapStep[] steps;
        address tokenIn;
        address tokenOut;
        FactoryType factoryType;
        uint amountIn;
    }

    struct SplitPermitParams {
        address token;
        uint approveAmount;
        uint deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct ArrayPermitParams {
        uint approveAmount;
        uint deadline;
        bytes signature;
    }

    struct TokenInput {
        address token;
        uint amount;
    }

    struct AddLiquidityInfo {
        FactoryType factoryType;
        TokenInput[] tokenInputs;
        address to;
        uint256 minLiquidity;
    }

    error NotEnoughLiquidityMinted();
    error TooLittleReceived();
    error Expired();

    function addLiquidity(
        AddLiquidityInfo calldata info,
        address callback,
        bytes calldata callbackData
    ) external payable returns (uint256 liquidity);

    function burnLiquidity(
        address pool,
        uint256 liquidity,
        uint8 _withdrawMode,
        address _to,
        uint256[] calldata minAmounts,
        address callback,
        bytes calldata callbackData
    ) external returns (IPool.TokenAmount[] memory amounts);

    function burnLiquiditySingle(
        address pool,
        uint256 liquidity,
        uint8 _withdrawMode,
        address _tokenOut,
        address _to,
        uint256 minAmount,
        address callback,
        bytes memory callbackData
    ) external returns (IPool.TokenAmount memory amountOut);

    function swap(
        SwapPath[] memory paths,
        uint256 amountOutMin,
        uint256 deadline
    ) external payable returns (IPool.TokenAmount memory amountOut);
}
