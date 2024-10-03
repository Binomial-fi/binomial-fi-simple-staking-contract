// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Transfer Helper Library
 * @dev Contains helper methods for interacting with ERC20 tokens that do not consistently return true/false
 * @author Uniswap
 *
 */
library TransferHelper {
    // Tranfer helper library Errors
    error TH_SAFE_TRANSFER_FAILED();
    error TH_SAFE_TRANSFER_FROM_FAILED();

    function safeTransfer(address token, address to, uint256 value) internal {
        bool toThrow = _call(token, abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        if (toThrow) {
            revert TH_SAFE_TRANSFER_FAILED();
        }
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        bool toThrow = _call(token, abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        if (toThrow) {
            revert TH_SAFE_TRANSFER_FROM_FAILED();
        }
    }

    function _call(address token, bytes memory data) internal returns (bool) {
        (bool success, bytes memory resultData) = token.call(data);
        if (!success || (resultData.length > 0 && !abi.decode(resultData, (bool)))) {
            return true;
        }

        return false;
    }
}
