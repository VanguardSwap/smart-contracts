// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/access/Ownable2Step.sol";

import {IFeeRegistry} from "../interfaces/master/IFeeRegistry.sol";
import {IFeeRecipient} from "../interfaces/master/IFeeRecipient.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";

contract VanguardFeeRecipient is IFeeRecipient, Ownable2Step {
    uint public epochDuration = 3 days;

    /// @dev The registry for fee senders.
    address public feeRegistry;

    /// @dev The epoch fees of each token.
    mapping(uint => mapping(address => uint)) public fees; // epoch => token => amount

    /// @dev The fees tokens in each epoch.
    mapping(uint => address[]) public feeTokens;

    /// @dev Whether the address is a fee distributor.
    mapping(address => bool) public isFeeDistributor;

    /// @dev The fee distributors.
    address[] public feeDistributors; // for inspection only

    struct FeeTokenData {
        // The start time of a fee token from a sender.
        uint startTime;
        // The accumulated fee amount since start time.
        uint amount;
    }

    /// @dev The fee token data of a sender.
    mapping(address => mapping(address => FeeTokenData)) public feeTokenData; // sender => token => time

    constructor(address _feeRegistry) Ownable(msg.sender) {
        feeRegistry = _feeRegistry;
    }

    function feeTokensLength(uint epoch) external view returns (uint) {
        return feeTokens[epoch].length;
    }

    function feeDistributorsLength() external view returns (uint) {
        return feeDistributors.length;
    }

    function getEpochStart(uint ts) public view returns (uint) {
        return ts - (ts % epochDuration);
    }

    /// @dev Notifies the fee recipient after sent fees.
    function notifyFees(
        uint16 feeType,
        address token,
        uint amount,
        uint feeRate,
        bytes calldata /*data*/
    ) external override {
        if (!IFeeRegistry(feeRegistry).isFeeSender(msg.sender)) {
            revert InvalidFeeSender();
        }

        uint epoch = getEpochStart(block.timestamp);
        uint epochTokenFees = fees[epoch][token];

        // Unchecked to avoid potential overflow, since fees are only for inspection.
        unchecked {
            if (epochTokenFees == 0) {
                // Pushes new tokens to array.
                feeTokens[epoch].push(token);

                // Updates epoch fees for the token.
                fees[epoch][token] = amount;

                // Updates fee token data for sender.
                feeTokenData[msg.sender][token] = FeeTokenData({
                    startTime: block.timestamp,
                    amount: amount
                });
            } else {
                // Updates epoch fees for the token.
                fees[epoch][token] = (epochTokenFees + amount);

                // Updates fee token data for sender.
                feeTokenData[msg.sender][token].amount += amount;
            }
        }

        emit NotifyFees(msg.sender, feeType, token, amount, feeRate);
    }

    /// @dev Distributes fees to the recipient.
    function distributeFees(
        address to,
        address[] calldata tokens,
        uint[] calldata amounts
    ) external {
        require(
            isFeeDistributor[msg.sender] || msg.sender == owner(),
            NoPermission()
        );
        require(tokens.length == amounts.length, WrongArrayLength());

        uint n = tokens.length;
        address token;
        uint amount;

        for (uint i; i < n; ++i) {
            token = tokens[i];
            amount = amounts[i];

            if (token == address(0)) {
                // ETH
                if (amount == 0) {
                    amount = address(this).balance;
                }
                TransferHelper.safeTransferETH(to, amount);
            } else {
                if (amount == 0) {
                    amount = IERC20(token).balanceOf(address(this));
                }
                TransferHelper.safeTransfer(token, to, amount);
            }
        }
    }

    /// @dev Adds a new fee distributor.
    function addFeeDistributor(address distributor) external onlyOwner {
        require(distributor != address(0), InvalidAddress());
        require(!isFeeDistributor[distributor], AlreadySet());
        isFeeDistributor[distributor] = true;
        feeDistributors.push(distributor);
        emit AddFeeDistributor(distributor);
    }

    /// @dev Removes a new fee distributor.
    function removeFeeDistributor(
        address distributor,
        bool updateArray
    ) external onlyOwner {
        require(isFeeDistributor[distributor], NotSet());
        delete isFeeDistributor[distributor];
        if (updateArray) {
            uint n = feeDistributors.length;
            for (uint i; i < n; ++i) {
                if (feeDistributors[i] == distributor) {
                    feeDistributors[i] = feeDistributors[n - 1];
                    feeDistributors[n - 1] = distributor;
                    feeDistributors.pop();
                    break;
                }
            }
        }
        emit RemoveFeeDistributor(distributor);
    }

    /// @dev Sets a new fee registry.
    function setFeeRegistry(address _feeRegistry) external onlyOwner {
        require(_feeRegistry != address(0), InvalidAddress());
        feeRegistry = _feeRegistry;
        emit SetFeeRegistry(_feeRegistry);
    }

    function setEpochDuration(uint _epochDuration) external onlyOwner {
        require(_epochDuration != 0, InvalidDuration());
        epochDuration = _epochDuration;
        emit SetEpochDuration(_epochDuration);
    }

    function withdrawERC20(
        address token,
        address to,
        uint amount
    ) external onlyOwner {
        if (amount == 0) {
            amount = IERC20(token).balanceOf(address(this));
        }
        TransferHelper.safeTransfer(token, to, amount);
    }

    function withdrawETH(address to, uint amount) external onlyOwner {
        if (amount == 0) {
            amount = address(this).balance;
        }
        TransferHelper.safeTransferETH(to, amount);
    }
}
