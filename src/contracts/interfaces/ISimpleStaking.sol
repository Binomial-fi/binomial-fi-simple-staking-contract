// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface ISimpleStaking {
    event Stake(address indexed staker, address indexed token, uint256 amount, uint256 timestamp);
    event Unstake(address indexed staker, address indexed token, uint256 amount, uint256 timestamp);
    event WhitelistToken(address indexed admin, address indexed token);
    event RemoveWhitelistedToken(address indexed admin, address indexed token);
    event SetBannedAddress(address indexed admin, address[] indexed addresses, bool indexed status);
    event RemoveBlacklistedAddress(address indexed admin, address indexed _address);

    error TokenNotWhitelisted();
    error InsufficientStakedAmount();
    error SafeTransferNativeFailed();
    error AddressBanned();
    error TransferAmountMismatch();

    function whitelistToken(address token) external;
    function removeWhitelistedToken(address token) external;
    function setBannedAddress(address[] memory addresses, bool status) external;
    function stake(address token, uint256 amount) external;
    function unstake(address token, uint256 amount) external;
    function stakeNative() external payable;
    function unstakeNative(uint256 amount) external;
}
