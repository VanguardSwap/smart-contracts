// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.26;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
interface IERC20Permit is IERC20 {
    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address owner) external view returns (uint);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}
