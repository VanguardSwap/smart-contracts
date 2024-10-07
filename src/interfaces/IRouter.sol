// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

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
}
