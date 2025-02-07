// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {Math} from "../../libraries/Math.sol";
import {StableMath} from "../../libraries/StableMath.sol";
import {ERC20Permit2} from "../../libraries/ERC20Permit2.sol";
import {MetadataHelper} from "../../libraries/MetadataHelper.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/utils/ReentrancyGuard.sol";

import {ICallback} from "../../interfaces/ICallback.sol";
import {IVault} from "../../interfaces/vault/IVault.sol";
import {IStablePool} from "../../interfaces/pool/IStablePool.sol";
import {IPoolMaster} from "../../interfaces/master/IPoolMaster.sol";
import {IFeeRecipient} from "../../interfaces/master/IFeeRecipient.sol";
import {IPoolFactory} from "../../interfaces/factory/IPoolFactory.sol";

contract VanguardStablePool is IStablePool, ERC20Permit2, ReentrancyGuard {
    using Math for uint;

    /// @dev The max adjusted reserve of two tokens to avoid overflow.
    uint private constant MAXIMUM_XP = 3802571709128108338056982581425910818;
    uint private constant MINIMUM_LIQUIDITY = 1000;
    uint private constant MAX_FEE = 1e5; /// @dev 100%.

    /// @dev Pool type `2` for stable pools.
    uint16 public constant override poolType = 2;

    address public immutable override master;
    address public immutable override vault;

    address public immutable override token0;
    address public immutable override token1;

    /// @dev Multipliers for each pooled token's precision to get to the pool precision decimals
    /// which is agnostic to the pool, but usually is 18.
    /// For example, TBTC has 18 decimals, so the multiplier should be 10 ** (18 - 18) = 1.
    /// WBTC has 8, so the multiplier should be 10 ** (18 - 8) => 10 ** 10.
    /// The value is only for stable pools, and has no effects on non-stable pools.
    uint public immutable override token0PrecisionMultiplier;
    uint public immutable override token1PrecisionMultiplier;

    /// @dev Pool reserve of each pool token as of immediately after the most recent balance event.
    /// The value is used to measure growth in invariant on mints and input tokens on swaps.
    uint public override reserve0;
    uint public override reserve1;

    /// @dev Invariant of the pool as of immediately after the most recent liquidity event.
    /// The value is used to measure growth in invariant when protocol fee is enabled,
    /// and will be reset to zero if protocol fee is disabled.
    uint public override invariantLast;

    /// @dev Factory must ensures that the parameters are valid.
    constructor(bytes memory _deployData) {
        (
            address _token0,
            address _token1,
            uint _token0PrecisionMultiplier,
            uint _token1PrecisionMultiplier
        ) = abi.decode(_deployData, (address, address, uint, uint));

        address _master = IPoolFactory(msg.sender).master();
        master = _master;

        vault = IPoolMaster(_master).vault();
        (
            token0,
            token1,
            token0PrecisionMultiplier,
            token1PrecisionMultiplier
        ) = (
            _token0,
            _token1,
            _token0PrecisionMultiplier,
            _token1PrecisionMultiplier
        );

        // try to set symbols for the LP token
        (bool _success0, string memory _symbol0) = MetadataHelper.getSymbol(
            _token0
        );
        (bool _success1, string memory _symbol1) = MetadataHelper.getSymbol(
            _token1
        );

        if (_success0 && _success1) {
            _initialize(
                string(
                    abi.encodePacked(
                        "Vanguard",
                        _symbol0,
                        "/",
                        _symbol1,
                        " Stable LP"
                    )
                ),
                string(abi.encodePacked(_symbol0, "/", _symbol1, " sVLP"))
            );
        } else {
            _initialize("Vanguard Stable LP", "sVLP");
        }
    }

    function getAssets() external view returns (address[] memory assets) {
        assets = new address[](2);
        assets[0] = token0;
        assets[1] = token1;
    }

    /// @dev Returns the verified sender address otherwise `address(0)`.
    function _getVerifiedSender(
        address _sender
    ) private view returns (address) {
        if (_sender != address(0)) {
            if (_sender != msg.sender) {
                if (!IPoolMaster(master).isForwarder(msg.sender)) {
                    // The sender from non-forwarder is invalid.
                    return address(0);
                }
            }
        }
        return _sender;
    }

    /// @dev Mints LP tokens - should be called via the router after transferring pool tokens.
    /// The router should ensure that sufficient LP tokens are minted.
    function mint(
        address _to,
        address _sender,
        address _callback,
        bytes calldata _callbackData
    ) external nonReentrant returns (uint) {
        ICallback.BaseMintCallbackParams memory params;

        params.to = _to;
        (params.reserve0, params.reserve1) = (reserve0, reserve1);
        (params.balance0, params.balance1) = _balances();

        params.newInvariant = _computeInvariant(
            params.balance0,
            params.balance1
        );
        params.amount0 = params.balance0 - params.reserve0;
        params.amount1 = params.balance1 - params.reserve1;
        //require(_amount0 != 0 && _amount1 != 0);

        // Gets swap fee for the sender.
        _sender = _getVerifiedSender(_sender);
        uint _amount1Optimal = params.reserve0 == 0
            ? 0
            : (params.amount0 * params.reserve1) / params.reserve0;
        bool _swap0For1 = params.amount1 < _amount1Optimal;
        if (_swap0For1) {
            params.swapFee = _getSwapFee(_sender, token0, token1);
        } else {
            params.swapFee = _getSwapFee(_sender, token1, token0);
        }

        // Adds mint fee to reserves (applies to invariant increase) if unbalanced.
        (params.fee0, params.fee1) = _unbalancedMintFee(
            params.swapFee,
            params.amount0,
            params.amount1,
            _amount1Optimal,
            params.reserve0,
            params.reserve1
        );
        params.reserve0 += params.fee0;
        params.reserve1 += params.fee1;

        // Calculates old invariant (where unbalanced fee added to) and, mint protocol fee if any.
        params.oldInvariant = _computeInvariant(
            params.reserve0,
            params.reserve1
        );
        bool _feeOn;
        (_feeOn, params.totalSupply) = _mintProtocolFee(
            0,
            0,
            params.oldInvariant
        );

        if (params.totalSupply == 0) {
            params.liquidity = params.newInvariant - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock on first mint.
        } else {
            // Calculates liquidity proportional to invariant growth.
            params.liquidity =
                ((params.newInvariant - params.oldInvariant) *
                    params.totalSupply) /
                params.oldInvariant;
        }

        // Mints liquidity for recipient.
        if (params.liquidity == 0) revert InsufficientLiquidityMinted();
        _mint(params.to, params.liquidity);

        // Calls callback with data.
        if (_callback != address(0)) {
            // Fills additional values for callback params.
            params.sender = _sender;
            params.callbackData = _callbackData;

            ICallback(_callback).vanguardBaseMintCallback(params);
        }

        // Updates reserves and last invariant with new balances.
        _updateReserves(params.balance0, params.balance1);
        if (_feeOn) {
            invariantLast = params.newInvariant;
        }

        emit Mint(
            msg.sender,
            params.amount0,
            params.amount1,
            params.liquidity,
            params.to
        );

        return params.liquidity;
    }

    /// @dev Burns LP tokens sent to this contract.
    /// The router should ensure that sufficient pool tokens are received.
    function burn(
        uint8 _withdrawMode,
        address _to,
        address _sender,
        address _callback,
        bytes calldata _callbackData
    ) external nonReentrant returns (TokenAmount[] memory _amounts) {
        ICallback.BaseBurnCallbackParams memory params;

        (params.to, params.withdrawMode) = (_to, _withdrawMode);
        (params.balance0, params.balance1) = _balances();
        params.liquidity = balanceOf[address(this)];

        // Mints protocol fee if any.
        // Note `_mintProtocolFee` here will checks overflow.
        bool _feeOn;
        (_feeOn, params.totalSupply) = _mintProtocolFee(
            params.balance0,
            params.balance1,
            0
        );

        // Calculates amounts of pool tokens proportional to balances.
        params.amount0 =
            (params.liquidity * params.balance0) /
            params.totalSupply;
        params.amount1 =
            (params.liquidity * params.balance1) /
            params.totalSupply;
        //require(_amount0 != 0 || _amount1 != 0);

        // Burns liquidity and transfers pool tokens.
        _burn(address(this), params.liquidity);
        _transferTokens(token0, params.to, params.amount0, params.withdrawMode);
        _transferTokens(token1, params.to, params.amount1, params.withdrawMode);

        // Updates balances.
        /// @dev Cannot underflow because amounts are lesser figures derived from balances.
        unchecked {
            params.balance0 -= params.amount0;
            params.balance1 -= params.amount1;
        }

        // Calls callback with data.
        // Note reserves are not updated at this point to allow read the old values.
        if (_callback != address(0)) {
            // Fills additional values for callback params.
            params.sender = _getVerifiedSender(_sender);
            params.callbackData = _callbackData;

            ICallback(_callback).vanguardBaseBurnCallback(params);
        }

        // Updates reserves and last invariant with up-to-date balances (after transfers).
        _updateReserves(params.balance0, params.balance1);
        if (_feeOn) {
            invariantLast = _computeInvariant(params.balance0, params.balance1);
        }

        _amounts = new TokenAmount[](2);
        _amounts[0] = TokenAmount(token0, params.amount0);
        _amounts[1] = TokenAmount(token1, params.amount1);

        emit Burn(
            msg.sender,
            params.amount0,
            params.amount1,
            params.liquidity,
            params.to
        );
    }

    /// @dev Burns LP tokens sent to this contract and swaps one of the output tokens for another
    /// - i.e., the user gets a single token out by burning LP tokens.
    /// The router should ensure that sufficient pool tokens are received.
    function burnSingle(
        uint8 _withdrawMode,
        address _tokenOut,
        address _to,
        address _sender,
        address _callback,
        bytes calldata _callbackData
    ) external nonReentrant returns (TokenAmount memory _tokenAmount) {
        ICallback.BaseBurnSingleCallbackParams memory params;

        (params.tokenOut, params.to, params.withdrawMode) = (
            _tokenOut,
            _to,
            _withdrawMode
        );

        (params.balance0, params.balance1) = _balances();
        params.liquidity = balanceOf[address(this)];

        // Mints protocol fee if any.
        // Note `_mintProtocolFee` here will checks overflow.
        bool _feeOn;
        (_feeOn, params.totalSupply) = _mintProtocolFee(
            params.balance0,
            params.balance1,
            0
        );

        // Calculates amounts of pool tokens proportional to balances.
        params.amount0 =
            (params.liquidity * params.balance0) /
            params.totalSupply;
        params.amount1 =
            (params.liquidity * params.balance1) /
            params.totalSupply;

        // Burns liquidity.
        _burn(address(this), params.liquidity);

        // Gets swap fee for the sender.
        _sender = _getVerifiedSender(_sender);

        // Swaps one token for another, transfers desired tokens, and update context values.
        /// @dev Calculate `amountOut` as if the user first withdrew balanced liquidity and then swapped from one token for another.
        if (params.tokenOut == token1) {
            // Swaps `token0` for `token1`.
            params.swapFee = _getSwapFee(_sender, token0, token1);

            params.tokenIn = token0;
            (params.amountSwapped, params.feeIn) = _getAmountOut(
                params.swapFee,
                params.amount0,
                params.balance0 - params.amount0,
                params.balance1 - params.amount1,
                true
            );
            params.amount1 += params.amountSwapped;

            _transferTokens(
                token1,
                params.to,
                params.amount1,
                params.withdrawMode
            );
            params.amountOut = params.amount1;
            params.amount0 = 0;
            params.balance1 -= params.amount1;
        } else {
            // Swaps `token1` for `token0`.
            //require(_tokenOut == token0);
            params.swapFee = _getSwapFee(_sender, token1, token0);

            params.tokenIn = token1;
            (params.amountSwapped, params.feeIn) = _getAmountOut(
                params.swapFee,
                params.amount1,
                params.balance0 - params.amount0,
                params.balance1 - params.amount1,
                false
            );
            params.amount0 += params.amountSwapped;

            _transferTokens(
                token0,
                params.to,
                params.amount0,
                params.withdrawMode
            );
            params.amountOut = params.amount0;
            params.amount1 = 0;
            params.balance0 -= params.amount0;
        }

        // Calls callback with data.
        // Note reserves are not updated at this point to allow read the old values.
        if (_callback != address(0)) {
            // Fills additional values for callback params.
            params.sender = _sender;
            params.callbackData = _callbackData;

            ICallback(_callback).vanguardBaseBurnSingleCallback(params);
        }

        // Update reserves and last invariant with up-to-date balances (updated above).
        _updateReserves(params.balance0, params.balance1);
        if (_feeOn) {
            invariantLast = _computeInvariant(params.balance0, params.balance1);
        }

        _tokenAmount = TokenAmount(params.tokenOut, params.amountOut);

        emit Burn(
            msg.sender,
            params.amount0,
            params.amount1,
            params.liquidity,
            params.to
        );
    }

    /// @dev Swaps one token for another - should be called via the router after transferring input tokens.
    /// The router should ensure that sufficient output tokens are received.
    function swap(
        uint8 _withdrawMode,
        address _tokenIn,
        address _to,
        address _sender,
        address _callback,
        bytes calldata _callbackData
    ) external nonReentrant returns (TokenAmount memory _tokenAmount) {
        ICallback.BaseSwapCallbackParams memory params;

        (params.tokenIn, params.to, params.withdrawMode) = (
            _tokenIn,
            _to,
            _withdrawMode
        );

        (params.reserve0, params.reserve1) = (reserve0, reserve1);
        (params.balance0, params.balance1) = _balances();

        // Gets swap fee for the sender.
        _sender = _getVerifiedSender(_sender);

        // Calculates output amount, update context values and emit event.
        if (params.tokenIn == token0) {
            params.swapFee = _getSwapFee(_sender, token0, token1);

            params.tokenOut = token1;
            params.amountIn = params.balance0 - params.reserve0;

            (params.amountOut, params.feeIn) = _getAmountOut(
                params.swapFee,
                params.amountIn,
                params.reserve0,
                params.reserve1,
                true
            );
            params.balance1 -= params.amountOut;

            emit Swap(
                msg.sender,
                params.amountIn,
                0,
                0,
                params.amountOut,
                params.to
            );
        } else {
            //require(params.tokenIn == token1);
            params.swapFee = _getSwapFee(_sender, token1, token0);

            params.tokenOut = token0;
            params.amountIn = params.balance1 - params.reserve1;

            (params.amountOut, params.feeIn) = _getAmountOut(
                params.swapFee,
                params.amountIn,
                params.reserve0,
                params.reserve1,
                false
            );
            params.balance0 -= params.amountOut;

            emit Swap(
                msg.sender,
                0,
                params.amountIn,
                params.amountOut,
                0,
                params.to
            );
        }

        // Checks overflow.
        if (params.balance0 * token0PrecisionMultiplier > MAXIMUM_XP) {
            revert Overflow();
        }
        if (params.balance1 * token1PrecisionMultiplier > MAXIMUM_XP) {
            revert Overflow();
        }

        // Transfers output tokens.
        _transferTokens(
            params.tokenOut,
            params.to,
            params.amountOut,
            params.withdrawMode
        );

        // Calls callback with data.
        if (_callback != address(0)) {
            // Fills additional values for callback params.
            params.sender = _sender;
            params.callbackData = _callbackData;

            ICallback(_callback).vanguardBaseSwapCallback(params);
        }

        // Updates reserves with up-to-date balances (updated above).
        _updateReserves(params.balance0, params.balance1);

        _tokenAmount.token = params.tokenOut;
        _tokenAmount.amount = params.amountOut;
    }

    function _getSwapFee(
        address _sender,
        address _tokenIn,
        address _tokenOut
    ) private view returns (uint24 _swapFee) {
        _swapFee = getSwapFee(_sender, _tokenIn, _tokenOut, "");
    }

    /// @dev This function doesn't check the forwarder.
    function getSwapFee(
        address _sender,
        address _tokenIn,
        address _tokenOut,
        bytes memory data
    ) public view override returns (uint24 _swapFee) {
        _swapFee = IPoolMaster(master).getSwapFee(
            address(this),
            _sender,
            _tokenIn,
            _tokenOut,
            data
        );
    }

    function getProtocolFee()
        public
        view
        override
        returns (uint24 _protocolFee)
    {
        _protocolFee = IPoolMaster(master).getProtocolFee(address(this));
    }

    function _updateReserves(uint _balance0, uint _balance1) private {
        (reserve0, reserve1) = (_balance0, _balance1);
        emit Sync(_balance0, _balance1);
    }

    function _transferTokens(
        address token,
        address to,
        uint amount,
        uint8 withdrawMode
    ) private {
        if (withdrawMode == 0) {
            IVault(vault).transfer(token, to, amount);
        } else {
            IVault(vault).withdrawAlternative(token, to, amount, withdrawMode);
        }
    }

    function _balances() private view returns (uint balance0, uint balance1) {
        balance0 = IVault(vault).balanceOf(token0, address(this));
        balance1 = IVault(vault).balanceOf(token1, address(this));
    }

    /// @dev This fee is charged to cover for the swap fee when users adding unbalanced liquidity.
    function _unbalancedMintFee(
        uint _swapFee,
        uint _amount0,
        uint _amount1,
        uint _amount1Optimal,
        uint _reserve0,
        uint _reserve1
    ) private pure returns (uint _token0Fee, uint _token1Fee) {
        if (_reserve0 == 0) {
            return (0, 0);
        }
        if (_amount1 >= _amount1Optimal) {
            _token1Fee =
                (_swapFee * (_amount1 - _amount1Optimal)) /
                (2 * MAX_FEE);
        } else {
            uint _amount0Optimal = (_amount1 * _reserve0) / _reserve1;
            _token0Fee =
                (_swapFee * (_amount0 - _amount0Optimal)) /
                (2 * MAX_FEE);
        }
    }

    function _mintProtocolFee(
        uint _reserve0,
        uint _reserve1,
        uint _invariant
    ) private returns (bool _feeOn, uint _totalSupply) {
        _totalSupply = totalSupply;

        address _feeRecipient = IPoolMaster(master).getFeeRecipient();
        _feeOn = (_feeRecipient != address(0));

        uint _invariantLast = invariantLast;
        if (_invariantLast != 0) {
            if (_feeOn) {
                if (_invariant == 0) {
                    _invariant = _computeInvariant(_reserve0, _reserve1);
                }

                if (_invariant > _invariantLast) {
                    /// @dev Mints `protocolFee` % of growth in liquidity (invariant).
                    uint _protocolFee = getProtocolFee();
                    uint _numerator = _totalSupply *
                        (_invariant - _invariantLast) *
                        _protocolFee;
                    uint _denominator = (MAX_FEE - _protocolFee) *
                        _invariant +
                        _protocolFee *
                        _invariantLast;
                    uint _liquidity = _numerator / _denominator;

                    if (_liquidity != 0) {
                        _mint(_feeRecipient, _liquidity);

                        // Notifies the fee recipient.
                        IFeeRecipient(_feeRecipient).notifyFees(
                            2,
                            address(this),
                            _liquidity,
                            _protocolFee,
                            ""
                        );

                        _totalSupply += _liquidity; // update cached value.
                    }
                }
            } else {
                /// @dev Resets last invariant to clear measured growth if protocol fee is not enabled.
                invariantLast = 0;
            }
        }
    }

    function getReserves()
        external
        view
        override
        returns (uint _reserve0, uint _reserve1)
    {
        (_reserve0, _reserve1) = (reserve0, reserve1);
    }

    function getAmountOut(
        address _tokenIn,
        uint _amountIn,
        address _sender
    ) external view override returns (uint _amountOut) {
        (uint _reserve0, uint _reserve1) = (reserve0, reserve1);
        bool _swap0For1 = _tokenIn == token0;
        address _tokenOut = _swap0For1 ? token1 : token0;
        (_amountOut, ) = _getAmountOut(
            _getSwapFee(_sender, _tokenIn, _tokenOut),
            _amountIn,
            _reserve0,
            _reserve1,
            _swap0For1
        );
    }

    function getAmountIn(
        address _tokenOut,
        uint _amountOut,
        address _sender
    ) external view override returns (uint _amountIn) {
        (uint _reserve0, uint _reserve1) = (reserve0, reserve1);
        bool _swap1For0 = _tokenOut == token0;
        address _tokenIn = _swap1For0 ? token1 : token0;
        _amountIn = _getAmountIn(
            _getSwapFee(_sender, _tokenIn, _tokenOut),
            _amountOut,
            _reserve0,
            _reserve1,
            _swap1For0
        );
    }

    function _getAmountOut(
        uint _swapFee,
        uint _amountIn,
        uint _reserve0,
        uint _reserve1,
        bool _token0In
    ) private view returns (uint _dy, uint _feeIn) {
        if (_amountIn == 0) {
            _dy = 0;
        } else {
            uint _adjustedReserve0 = _reserve0 * token0PrecisionMultiplier;
            uint _adjustedReserve1 = _reserve1 * token1PrecisionMultiplier;

            _feeIn = (_amountIn * _swapFee) / MAX_FEE;
            uint _feeDeductedAmountIn = _amountIn - _feeIn;
            uint _d = StableMath.computeDFromAdjustedBalances(
                _adjustedReserve0,
                _adjustedReserve1
            );

            if (_token0In) {
                uint _x = _adjustedReserve0 +
                    (_feeDeductedAmountIn * token0PrecisionMultiplier);
                uint _y = StableMath.getY(_x, _d);
                _dy = _adjustedReserve1 - _y - 1;
                _dy /= token1PrecisionMultiplier;
            } else {
                uint _x = _adjustedReserve1 +
                    (_feeDeductedAmountIn * token1PrecisionMultiplier);
                uint _y = StableMath.getY(_x, _d);
                _dy = _adjustedReserve0 - _y - 1;
                _dy /= token0PrecisionMultiplier;
            }
        }
    }

    function _getAmountIn(
        uint _swapFee,
        uint _amountOut,
        uint _reserve0,
        uint _reserve1,
        bool _token0Out
    ) private view returns (uint _dx) {
        if (_amountOut == 0) {
            _dx = 0;
        } else {
            unchecked {
                uint _adjustedReserve0 = _reserve0 * token0PrecisionMultiplier;
                uint _adjustedReserve1 = _reserve1 * token1PrecisionMultiplier;
                uint _d = StableMath.computeDFromAdjustedBalances(
                    _adjustedReserve0,
                    _adjustedReserve1
                );

                if (_token0Out) {
                    uint _y = _adjustedReserve0 -
                        (_amountOut * token0PrecisionMultiplier);
                    if (_y <= 1) {
                        return 1;
                    }
                    uint _x = StableMath.getY(_y, _d);
                    _dx =
                        (MAX_FEE * (_x - _adjustedReserve1)) /
                        (MAX_FEE - _swapFee) +
                        1;
                    _dx /= token1PrecisionMultiplier;
                } else {
                    uint _y = _adjustedReserve1 -
                        (_amountOut * token1PrecisionMultiplier);
                    if (_y <= 1) {
                        return 1;
                    }
                    uint _x = StableMath.getY(_y, _d);
                    _dx =
                        (MAX_FEE * (_x - _adjustedReserve0)) /
                        (MAX_FEE - _swapFee) +
                        1;
                    _dx /= token0PrecisionMultiplier;
                }
            }
        }
    }

    function _computeInvariant(
        uint _reserve0,
        uint _reserve1
    ) private view returns (uint _invariant) {
        /// @dev Gets D, the StableSwap invariant, based on a set of balances and a particular A.
        /// See the StableSwap paper for details.
        /// Originally https://github.com/saddle-finance/saddle-contract/blob/0b76f7fb519e34b878aa1d58cffc8d8dc0572c12/contracts/SwapUtils.sol#L319.
        /// Returns the invariant, at the precision of the pool.
        unchecked {
            uint _adjustedReserve0 = _reserve0 * token0PrecisionMultiplier;
            uint _adjustedReserve1 = _reserve1 * token1PrecisionMultiplier;
            if (
                _adjustedReserve0 > MAXIMUM_XP || _adjustedReserve1 > MAXIMUM_XP
            ) revert Overflow();
            _invariant = StableMath.computeDFromAdjustedBalances(
                _adjustedReserve0,
                _adjustedReserve1
            );
        }
    }
}
