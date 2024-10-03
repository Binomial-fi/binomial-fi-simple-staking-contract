// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ISimpleStaking.sol";
import "../libs/TransferHelper.sol";

/**
 * @title SimpleStaking
 * @dev A simple staking contract that allows users to stake ERC20 tokens.
 */
contract SimpleStaking is ReentrancyGuard, Ownable, ISimpleStaking {
    constructor() Ownable(msg.sender) {}

    address public constant NATIVE_CURRENCY = address(0);

    mapping(address => bool) public whitelistedTokens;
    mapping(address => mapping(address => uint256)) public stakes;
    mapping(address => uint256) public totalStaked;
    mapping(address => bool) public bannedAddresses;

    /**
     * @dev Whitelists a token for staking.
     * @param token The address of the token to be whitelisted.
     */
    function whitelistToken(address token) external override onlyOwner {
        whitelistedTokens[token] = true;
        emit WhitelistToken(msg.sender, token);
    }

    /**
     * @dev Removes a token from the whitelist.
     * @param token The address of the token to be removed from the whitelist.
     */
    function removeWhitelistedToken(address token) external override onlyOwner {
        whitelistedTokens[token] = false;
        emit RemoveWhitelistedToken(msg.sender, token);
    }

    /**
     * @dev Blacklist a wallet address for staking.
     * @param addresses Array of addresses to be banned.
     * @param status The status of the banned address.
     */
    function setBannedAddress(address[] memory addresses, bool status) external override onlyOwner {
        uint256 addressesLength = addresses.length;
        for (uint256 i = 0; i < addressesLength;) {
            bannedAddresses[addresses[i]] = status;

            unchecked {
                ++i;
            }
        }

        emit SetBannedAddress(msg.sender, addresses, status);
    }

    /**
     * @dev Stakes an amount of tokens.
     * @param token The address of the token to be staked.
     * @param amount The amount of tokens to be staked.
     */
    function stake(address token, uint256 amount) external override nonReentrant checkBannedAddress {
        if (!whitelistedTokens[token]) revert TokenNotWhitelisted();

        uint256 balance = IERC20(token).balanceOf(address(this));

        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amount);

        uint256 balanceAfterTrasnfer = IERC20(token).balanceOf(address(this));

        uint256 actualAmount = balanceAfterTrasnfer - balance;
        if (actualAmount != amount) revert TransferAmountMismatch();

        stakes[msg.sender][token] += actualAmount;
        totalStaked[token] += actualAmount;

        emit Stake(msg.sender, token, actualAmount, block.timestamp);
    }

    /**
     * @dev Unstakes an amount of tokens.
     * @param token The address of the token to be unstaked.
     * @param amount The amount of tokens to be unstaked.
     */
    function unstake(address token, uint256 amount) external override nonReentrant checkBannedAddress {
        if (stakes[msg.sender][token] < amount) revert InsufficientStakedAmount();

        stakes[msg.sender][token] -= amount;
        totalStaked[token] -= amount;

        TransferHelper.safeTransfer(token, msg.sender, amount);

        emit Unstake(msg.sender, token, amount, block.timestamp);
    }

    /**
     * @dev Allows a user to stake native currency.
     */
    function stakeNative() external payable override nonReentrant checkBannedAddress {
        if (!whitelistedTokens[NATIVE_CURRENCY]) revert TokenNotWhitelisted();

        stakes[msg.sender][NATIVE_CURRENCY] += msg.value;
        totalStaked[NATIVE_CURRENCY] += msg.value;

        emit Stake(msg.sender, NATIVE_CURRENCY, msg.value, block.timestamp);
    }

    /**
     * @dev Unstakes a specified amount of native currency from the staking contract.
     * @param amount The amount of native currency to unstake.
     */
    function unstakeNative(uint256 amount) external override nonReentrant checkBannedAddress {
        if (stakes[msg.sender][NATIVE_CURRENCY] < amount) revert InsufficientStakedAmount();

        stakes[msg.sender][NATIVE_CURRENCY] -= amount;
        totalStaked[NATIVE_CURRENCY] -= amount;

        (bool success,) = msg.sender.call{value: amount}(new bytes(0));
        if (!success) {
            revert SafeTransferNativeFailed();
        }

        emit Unstake(msg.sender, NATIVE_CURRENCY, amount, block.timestamp);
    }

    modifier checkBannedAddress() {
        if (bannedAddresses[msg.sender]) revert AddressBanned();
        _;
    }
}
