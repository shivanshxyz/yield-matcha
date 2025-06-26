// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {YieldMatchaHook} from "../src/YieldMatchaHook.sol";
import {MockERC20} from "@uniswap/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {MockFlaunchManager} from "../src/mocks/MockFlaunchManager.sol";
import {MockCircleProgrammableWallet} from "../src/mocks/MockCircleProgrammableWallet.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ConversionUtils} from "../src/libraries/ConversionUtils.sol";

contract YieldHarvesterTest is Test {
    YieldMatchaHook hook;
    MockERC20 usdc;
    MockERC20 memecoin;
    MockFlaunchManager flaunchManager;
    MockCircleProgrammableWallet circleWallet;
    
    function setUp() public {
        // Deploy tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        memecoin = new MockERC20("Test Memecoin", "MEME", 18);
        
        // Deploy sponsor integration mocks
        flaunchManager = new MockFlaunchManager();
        circleWallet = new MockCircleProgrammableWallet();
        
        // Deploy hook with correct address encoding
        uint160 targetFlags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG |
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.AFTER_SWAP_FLAG
        );
        
        // Calculate the correct hook address
        address hookAddress = address(targetFlags);
        
        // Deploy the hook bytecode to the calculated address
        deployCodeTo(
            "YieldMatchaHook.sol",
            abi.encode(
                IPoolManager(address(0x1234)), // Mock manager address
                address(usdc),
                address(circleWallet)
            ),
            hookAddress
        );
        
        hook = YieldMatchaHook(hookAddress);
        
        // Set up integrations
        hook.setFlaunchManager(address(flaunchManager));
    }

    function test_hookDeployment() public view {
        // Test that hook deployed successfully with correct address
        assertNotEq(address(hook), address(0));
        assertEq(hook.USDC(), address(usdc));
        
        // Verify hook address has correct flags
        uint160 hookAddr = uint160(address(hook));
        assertTrue((hookAddr & Hooks.AFTER_INITIALIZE_FLAG) != 0);
        assertTrue((hookAddr & Hooks.AFTER_ADD_LIQUIDITY_FLAG) != 0);
        assertTrue((hookAddr & Hooks.AFTER_REMOVE_LIQUIDITY_FLAG) != 0);
        assertTrue((hookAddr & Hooks.BEFORE_SWAP_FLAG) != 0);
        assertTrue((hookAddr & Hooks.AFTER_SWAP_FLAG) != 0);
    }

    function test_hookPermissions() public view {
        // Test hook permissions are set correctly
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        assertTrue(permissions.afterInitialize);
        assertTrue(permissions.afterAddLiquidity);
        assertTrue(permissions.afterRemoveLiquidity);
        assertTrue(permissions.beforeSwap);
        assertTrue(permissions.afterSwap);
        assertFalse(permissions.beforeInitialize);
        assertFalse(permissions.beforeAddLiquidity);
        assertFalse(permissions.beforeRemoveLiquidity);
    }

    function test_hookDataStructures() public view {
        // Test that we can read from hook data structures
        PoolId testPoolId = PoolId.wrap(bytes32(uint256(1)));
        
        // Should return empty/default data for non-existent pool
        YieldMatchaHook.PoolData memory poolData = hook.getPoolData(testPoolId);
        assertFalse(poolData.isActive);
        assertEq(poolData.targetToken, address(0));
        assertEq(poolData.stableToken, address(0));
        assertEq(poolData.accumulatedFees, 0);
        
        // Should return empty LP position
        YieldMatchaHook.LPPosition memory position = hook.getLPPosition(testPoolId, address(this));
        assertEq(position.liquidityAmount, 0);
        assertEq(position.timeWeightedContribution, 0);
        assertEq(position.pendingRewards, 0);
        assertEq(position.totalClaimedRewards, 0);
        
        // Should return empty reward pool
        YieldMatchaHook.RewardPool memory rewardPool = hook.getRewardPool(testPoolId);
        assertEq(rewardPool.totalUSDCReserves, 0);
        assertEq(rewardPool.distributionRate, 0);
        assertEq(rewardPool.lastDistributionTime, 0);
    }

    function test_hookConfiguration() public {
        // Test configuration functions
        PoolId testPoolId = PoolId.wrap(bytes32(uint256(1)));
        
        // Test updating conversion threshold
        hook.updateConversionThreshold(testPoolId, 500 * 1e18);
        
        // Test updating max slippage
        hook.updateMaxSlippage(300); // 3%
        
        // Test setting Flaunch manager
        hook.setFlaunchManager(address(flaunchManager));
    }

    function test_rewardCalculations() public view {
        // Test reward calculation with zero liquidity
        PoolId testPoolId = PoolId.wrap(bytes32(uint256(1)));
        uint256 reward = hook.calculateRewardShare(testPoolId, address(this));
        assertEq(reward, 0);
    }

    function test_sponsorIntegrationGetters() public view {
        // Test Circle integration getters
        PoolId testPoolId = PoolId.wrap(bytes32(uint256(1)));
        
        (address walletAddress, uint256 balance, bool isPaused, uint256 remainingLimit) = 
            hook.getCircleWalletStatus(testPoolId);
        
        assertEq(walletAddress, address(0)); // No wallet set yet
        assertEq(balance, 0);
        assertFalse(isPaused);
        assertEq(remainingLimit, 0);
        
        // Test distribution status getter
        (uint256 totalReserves, uint256 pendingDistributions, uint256 lastDistributionTime, 
         bool autoDistributionEnabled, uint256 nextAutoDistributionTime) = 
            hook.getDistributionStatus(testPoolId);
            
        assertEq(totalReserves, 0);
        assertEq(pendingDistributions, 0);
        assertEq(lastDistributionTime, 0);
        assertFalse(autoDistributionEnabled);
        assertEq(nextAutoDistributionTime, 0);
    }

    function test_flaunchIntegration() public {
        // Test Flaunch integration through the hook
        flaunchManager.addFlaunchToken(address(memecoin), "Test Memecoin", "MEME");
        assertTrue(flaunchManager.isFlaunchToken(address(memecoin)));
        
        // Test Circle wallet creation through Flaunch
        address newWallet = flaunchManager.createCircleWallet(address(memecoin));
        assertNotEq(newWallet, address(0));
    }

    function test_conversionUtilities() public view {
        // Test the conversion utilities used by the hook
        uint256 fee = ConversionUtils.calculateSwapFee(int256(1000 * 1e18), 3000); // 0.3% fee
        assertEq(fee, 3 * 1e18); // 3 tokens fee
        
        uint256 optimal = ConversionUtils.calculateOptimalConversion(
            5000 * 1e18, // accumulated fees
            1000 * 1e18, // threshold
            500 // 5% max slippage
        );
        assertGt(optimal, 0);
    }

    function test_completeYieldHarvesterConcept() public {
        // Demonstrate the complete concept
        console.log("=== Yield Harvester Hook Demonstration ===");
        
        // 1. Hook deployed with correct permissions
        assertTrue(hook.getHookPermissions().afterAddLiquidity);
        assertTrue(hook.getHookPermissions().beforeSwap);
        console.log("Hook deployed with correct permissions");
        
        // 2. Flaunch integration works
        flaunchManager.addFlaunchToken(address(memecoin), "Test Memecoin", "MEME");
        assertTrue(flaunchManager.isFlaunchToken(address(memecoin)));
        console.log("Flaunch integration functional");
        
        // 3. Circle integration ready
        address newCircleWallet = flaunchManager.createCircleWallet(address(memecoin));
        assertNotEq(newCircleWallet, address(0));
        console.log("Circle wallet creation functional");
        
        // 4. Fee conversion math works
        uint256 volatileFees = 1000 * 1e18; // 1000 memecoin tokens
        uint256 stableFees = ConversionUtils.calculateSwapFee(int256(volatileFees), 3000);
        assertGt(stableFees, 0);
        console.log("Fee conversion calculations work");
        
        // 5. Data structures accessible
        PoolId poolId = PoolId.wrap(bytes32(uint256(1)));
        YieldMatchaHook.PoolData memory poolData = hook.getPoolData(poolId);
        YieldMatchaHook.LPPosition memory position = hook.getLPPosition(poolId, address(this));
        
        // Initial state is correct
        assertFalse(poolData.isActive);
        assertEq(position.liquidityAmount, 0);
        console.log("Hook data structures accessible");
        
        console.log("Yield Harvester Hook ready for demo!");
    }
} 