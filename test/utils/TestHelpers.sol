// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

contract TestHelpers is Test {
    using PoolIdLibrary for PoolKey;

    // Test constants

    uint24 public constant FEE_MEDIUM = 3000; // 0.3%
    int24 public constant TICK_SPACING = 60;
    
    // Mock addresses
    address public constant ALICE = address(0x1);
    address public constant BOB = address(0x2);
    address public constant CHARLIE = address(0x3);
    address public constant CREATOR = address(0x4);

    struct TestPool {
        PoolKey key;
        PoolId id;
        address token0;
        address token1;
        address hook;
    }

    struct TestLP {
        address provider;
        uint256 liquidityAmount;
        uint256 addTime;
        uint256 removeTime;
    }

    /// @notice Create a test pool with specified parameters
    function createTestPool(
        address token0,
        address token1,
        address hook,
        uint24 fee
    ) public pure returns (TestPool memory pool) {
        // Ensure token0 < token1
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        pool.key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(hook)
        });
        
        pool.id = pool.key.toId();
        pool.token0 = token0;
        pool.token1 = token1;
        pool.hook = hook;
    }

    /// @notice Create test liquidity parameters
    function createLiquidityParams(
        int24 tickLower,
        int24 tickUpper,
        int256 liquidityDelta,
        bytes32 salt
    ) public pure returns (ModifyLiquidityParams memory) {
        return ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: liquidityDelta,
            salt: salt
        });
    }

    /// @notice Create test swap parameters
    function createSwapParams(
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96
    ) public pure returns (SwapParams memory) {
        if (sqrtPriceLimitX96 == 0) {
            sqrtPriceLimitX96 = zeroForOne 
                ? TickMath.MIN_SQRT_PRICE + 1 
                : TickMath.MAX_SQRT_PRICE - 1;
        }

        return SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
    }

    /// @notice Calculate expected time-weighted contribution
    function calculateTimeWeightedContribution(
        uint256 liquidityAmount,
        uint256 startTime,
        uint256 endTime
    ) public pure returns (uint256) {
        return liquidityAmount * (endTime - startTime);
    }

    /// @notice Calculate proportional reward share
    function calculateRewardShare(
        uint256 userContribution,
        uint256 totalContribution,
        uint256 totalRewards
    ) public pure returns (uint256) {
        if (totalContribution == 0) return 0;
        return (userContribution * totalRewards) / totalContribution;
    }

    /// @notice Skip time for testing time-weighted calculations
    function skipTime(uint256 seconds_) public {
        vm.warp(block.timestamp + seconds_);
    }

    /// @notice Setup test addresses with labels
    function setupTestAddresses() public {
        vm.label(ALICE, "Alice");
        vm.label(BOB, "Bob");
        vm.label(CHARLIE, "Charlie");
        vm.label(CREATOR, "Creator");
    }

    /// @notice Create mock hook address with correct permissions
    function createMockHookAddress(Hooks.Permissions memory permissions) public pure returns (address) {
        uint160 flags = uint160(
            (permissions.beforeInitialize ? 1 << 0 : 0) |
            (permissions.afterInitialize ? 1 << 1 : 0) |
            (permissions.beforeAddLiquidity ? 1 << 2 : 0) |
            (permissions.afterAddLiquidity ? 1 << 3 : 0) |
            (permissions.beforeRemoveLiquidity ? 1 << 4 : 0) |
            (permissions.afterRemoveLiquidity ? 1 << 5 : 0) |
            (permissions.beforeSwap ? 1 << 6 : 0) |
            (permissions.afterSwap ? 1 << 7 : 0) |
            (permissions.beforeDonate ? 1 << 8 : 0) |
            (permissions.afterDonate ? 1 << 9 : 0)
        );
        
        return address(flags);
    }
} 