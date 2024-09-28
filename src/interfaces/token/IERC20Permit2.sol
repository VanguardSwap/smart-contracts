// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;

import {IERC20Permit} from "./IERC20Permit.sol";

interface IERC20Permit2 is IERC20Permit {
    function permit2(
        address owner,
        address spender,
        uint amount,
        uint deadline,
        bytes calldata signature
    ) external;
}
