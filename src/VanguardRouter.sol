// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.26;

import {IWETH} from "./interfaces/IWETH.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IStakingPool} from "./interfaces/IStakingPool.sol";
import {IVault} from "./interfaces/vault/IVault.sol";
import {IPool} from "./interfaces/pool/IPool.sol";
import {IBasePool} from "./interfaces/pool/IBasePool.sol";
import {IERC20Permit, IERC20} from "./interfaces/token/IERC20Permit.sol";
import {IPoolFactory} from "./interfaces/factory/IPoolFactory.sol";
import {IBasePoolFactory as IFactory} from "./interfaces/factory/IBasePoolFactory.sol";

import {TransferHelper} from "./libraries/TransferHelper.sol";

import {SelfPermit} from "./abstract/SelfPermit.sol";
import {Multicall} from "./abstract/Multicall.sol";

/// @notice The router is a universal interface for users to access
/// functions across different protocol parts in one place.
///
/// It handles the allowances and transfers of tokens, and
/// allows chained swaps/operations across multiple pools, with
/// additional features like slippage protection and permit support.
///
contract VanguardRouter is IRouter, SelfPermit, Multicall {
    address public immutable vault;
    address public immutable wETH;
    address public immutable classicFactory;
    address public immutable stableFactory;
    address private constant NATIVE_ETH = address(0);

    mapping(address => mapping(address => bool)) public isPoolEntered;
    mapping(address => address[]) public enteredPools;

    modifier ensure(uint256 deadline) {
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp > deadline) {
            revert Expired();
        }
        _;
    }

    constructor(address _vault, address _wETH, address _classicFactory, address _stableFactory) {
        vault = _vault;
        wETH = _wETH;
        classicFactory = _classicFactory;
        stableFactory = _stableFactory;
    }

    function enteredPoolsLength(address account) external view returns (uint) {
        return enteredPools[account].length;
    }

    // Add Liquidity
    function _transferFromSender(
        address token,
        address to,
        uint256 amount
    ) private {
        if (token == NATIVE_ETH) {
            // Deposit ETH to the vault.
            IVault(vault).deposit{value: amount}(token, to);
        } else {
            // Transfer tokens to the vault.
            TransferHelper.safeTransferFrom(token, msg.sender, vault, amount);

            // Notify the vault to deposit.
            IVault(vault).deposit(token, to);
        }
    }

    function _transferAndAddLiquidity(
        AddLiquidityInfo calldata info,
        address callback,
        bytes calldata callbackData
    ) private returns (uint256 liquidity) {
        // Send all input tokens to the pool.
        TokenInput[] memory inputs = info.tokenInputs;
        uint256 n = inputs.length;

        TokenInput memory input;

        address tokenA = inputs[0].token;
        address tokenB = inputs[1].token;

        address factory = info.factoryType == FactoryType.CLASSIC
            ? classicFactory
            : stableFactory;

        address pool = IFactory(factory).getPool(tokenA, tokenB);

        if (pool == address(0)) {
            pool = IFactory(factory).createPool(tokenA, tokenB);
        }

        for (uint256 i; i < n; ++i) {
            input = inputs[i];

            _transferFromSender(input.token, pool, input.amount);
        }

        liquidity = IPool(pool).mint(info.to, msg.sender, callback, callbackData);

        if (liquidity < info.minLiquidity) revert NotEnoughLiquidityMinted();
    }

    function _markPoolEntered(address pool) private {
        if (!isPoolEntered[pool][msg.sender]) {
            isPoolEntered[pool][msg.sender] = true;
            enteredPools[msg.sender].push(pool);
        }
    }

    function addLiquidity(
        AddLiquidityInfo calldata info,
        address callback,
        bytes calldata callbackData
    ) external payable returns (uint256 liquidity) {
        liquidity = _transferAndAddLiquidity(
            info,
            callback,
            callbackData
        );
    }

    function addLiquidity2(
        address pool,
        AddLiquidityInfo calldata info,
        address callback,
        bytes calldata callbackData
    ) external payable returns (uint256 liquidity) {
        liquidity = _transferAndAddLiquidity(
            info,
            callback,
            callbackData
        );

        _markPoolEntered(pool);
    }

    function addLiquidityWithPermit(
        AddLiquidityInfo calldata info,
        address callback,
        bytes calldata callbackData,
        SplitPermitParams[] memory permits
    ) public payable returns (uint256 liquidity) {
        // Approve all tokens via permit.
        uint256 n = permits.length;

        SplitPermitParams memory params;

        for (uint256 i; i < n; ++i) {
            params = permits[i];

            IERC20Permit(params.token).permit(
                msg.sender,
                address(this),
                params.approveAmount,
                params.deadline,
                params.v,
                params.r,
                params.s
            );
        }

        liquidity = _transferAndAddLiquidity(
            info,
            callback,
            callbackData
        );
    }

    function addLiquidityWithPermit2(
        address pool,
        AddLiquidityInfo calldata info,
        address callback,
        bytes calldata callbackData,
        SplitPermitParams[] memory permits
    ) public payable returns (uint256 liquidity) {
        liquidity = addLiquidityWithPermit(
            info,
            callback,
            callbackData,
            permits
        );

        _markPoolEntered(pool);
    }

    // Burn Liquidity
    function _transferAndBurnLiquidity(
        address pool,
        uint256 liquidity,
        uint8 _withdrawMode,
        address _to,
        uint256[] memory minAmounts,
        address callback,
        bytes calldata callbackData
    ) private returns (IPool.TokenAmount[] memory amounts) {
        IBasePool(pool).transferFrom(msg.sender, pool, liquidity);

        amounts = IPool(pool).burn(_withdrawMode, _to, msg.sender, callback, callbackData);

        uint256 n = amounts.length;

        for (uint256 i; i < n; ++i) {
            if (amounts[i].amount < minAmounts[i]) revert TooLittleReceived();
        }
    }

    function burnLiquidity(
        address pool,
        uint256 liquidity,
        uint8 _withdrawMode,
        address _to,
        uint256[] calldata minAmounts,
        address callback,
        bytes calldata callbackData
    ) external returns (IPool.TokenAmount[] memory amounts) {
        amounts = _transferAndBurnLiquidity(
            pool,
            liquidity,
            _withdrawMode,
            _to,
            minAmounts,
            callback,
            callbackData
        );
    }

    function burnLiquidityWithPermit(
        address pool,
        uint256 liquidity,
        uint8 _withdrawMode,
        address _to,
        uint256[] calldata minAmounts,
        address callback,
        bytes calldata callbackData,
        ArrayPermitParams memory permit
    ) external returns (IPool.TokenAmount[] memory amounts) {
        // Approve liquidity via permit.
        IBasePool(pool).permit2(
            msg.sender,
            address(this),
            permit.approveAmount,
            permit.deadline,
            permit.signature
        );

        amounts = _transferAndBurnLiquidity(
            pool,
            liquidity,
            _withdrawMode,
            _to,
            minAmounts,
            callback,
            callbackData
        );
    }

    // Burn Liquidity Single
    function _transferAndBurnLiquiditySingle(
        address pool,
        uint256 liquidity,
        uint8 _withdrawMode,
        address _tokenOut,
        address _to,
        uint256 minAmount,
        address callback,
        bytes memory callbackData
    ) private returns (IPool.TokenAmount memory amountOut) {
        IBasePool(pool).transferFrom(msg.sender, pool, liquidity);

        amountOut = IPool(pool).burnSingle(
            _withdrawMode,
            _tokenOut,
            _to,
            msg.sender,
            callback,
            callbackData
        );

        if (amountOut.amount < minAmount) revert TooLittleReceived();
    }

    function burnLiquiditySingle(
        address pool,
        uint256 liquidity,
        uint8 _withdrawMode,
        address _tokenOut,
        address _to,
        uint256 minAmount,
        address callback,
        bytes memory callbackData
    ) external returns (IPool.TokenAmount memory amountOut) {
        amountOut = _transferAndBurnLiquiditySingle(
            pool,
            liquidity,
            _withdrawMode,
            _tokenOut,
            _to,
            minAmount,
            callback,
            callbackData
        );
    }

    function burnLiquiditySingleWithPermit(
        address pool,
        uint256 liquidity,
        uint8 _withdrawMode,
        address _tokenOut,
        address _to,
        uint256 minAmount,
        address callback,
        bytes memory callbackData,
        ArrayPermitParams calldata permit
    ) external returns (IPool.TokenAmount memory amountOut) {
        // Approve liquidity via permit.
        IBasePool(pool).permit2(
            msg.sender,
            address(this),
            permit.approveAmount,
            permit.deadline,
            permit.signature
        );

        amountOut = _transferAndBurnLiquiditySingle(
            pool,
            liquidity,
            _withdrawMode,
            _tokenOut,
            _to,
            minAmount,
            callback,
            callbackData
        );
    }

    // Swap
    function _swap(
        SwapPath[] memory paths,
        uint256 amountOutMin
    ) private returns (IPool.TokenAmount memory amountOut) {
        uint256 pathsLength = paths.length;

        SwapPath memory path;
        SwapStep memory step;
        IPool.TokenAmount memory tokenAmount;
        uint256 stepsLength;
        uint256 j;

        for (uint256 i; i < pathsLength; ++i) {
            path = paths[i];

            // Prefund the first step.
            step = path.steps[0];
            _transferFromSender(path.tokenIn, step.pool, path.amountIn);

            // Cache steps length.
            stepsLength = path.steps.length;

            for (j = 0; j < stepsLength; ++j) {
                if (j == stepsLength - 1) {
                    // Accumulate output amount at the last step.
                    tokenAmount = IBasePool(step.pool).swap(
                        step.withdrawMode,
                        step.tokenIn,
                        step.to,
                        msg.sender,
                        step.callback,
                        step.callbackData
                    );

                    amountOut.token = tokenAmount.token;
                    amountOut.amount += tokenAmount.amount;

                    break;
                } else {
                    // Swap and send tokens to the next step.
                    IBasePool(step.pool).swap(
                        step.withdrawMode,
                        step.tokenIn,
                        step.to,
                        msg.sender,
                        step.callback,
                        step.callbackData
                    );

                    // Cache the next step.
                    step = path.steps[j + 1];
                }
            }
        }

        if (amountOut.amount < amountOutMin) revert TooLittleReceived();
    }

    function swap(
        SwapPath[] memory paths,
        uint256 amountOutMin,
        uint256 deadline
    )
        external
        payable
        ensure(deadline)
        returns (IPool.TokenAmount memory amountOut)
    {
        amountOut = _swap(paths, amountOutMin);
    }

    function swapWithPermit(
        SwapPath[] memory paths,
        uint256 amountOutMin,
        uint256 deadline,
        SplitPermitParams calldata permit
    )
        external
        payable
        ensure(deadline)
        returns (IPool.TokenAmount memory amountOut)
    {
        // Approve input tokens via permit.
        IERC20Permit(permit.token).permit(
            msg.sender,
            address(this),
            permit.approveAmount,
            permit.deadline,
            permit.v,
            permit.r,
            permit.s
        );

        amountOut = _swap(paths, amountOutMin);
    }

    /// @notice Wrapper function to allow pool deployment to be batched.
    function createPool(
        address _factory,
        address _tokenA,
        address _tokenB
    ) external payable returns (address) {
        return IPoolFactory(_factory).createPool(_tokenA, _tokenB);
    }

    function stake(
        address stakingPool,
        address token,
        uint256 amount,
        address onBehalf
    ) external {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount
        );

        if (IERC20(token).allowance(address(this), stakingPool) < amount) {
            TransferHelper.safeApprove(token, stakingPool, type(uint).max);
        }

        IStakingPool(stakingPool).stake(amount, onBehalf);
    }
}
