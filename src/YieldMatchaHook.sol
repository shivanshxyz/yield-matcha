// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// import {AutoDistributionConfig} from "./AutoDistributionConfig.sol";

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams, ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {ICircleProgrammableWallet} from "./interfaces/ICircleProgrammableWallet.sol";
import {ICirclePaymaster} from "./interfaces/ICirclePaymaster.sol";
import {DistributionManager} from "./libraries/DistributionManager.sol";
import {IFlaunchManager} from "./interfaces/IFlaunchManager.sol";
import {ICircleWallet} from "./interfaces/ICircleWallet.sol";
import {ConversionUtils} from "./libraries/ConversionUtils.sol";


contract YieldMatchaHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    struct PoolData {
        bool isActive;                    // Whether yield harvesting is enabled
        address targetToken;              // The volatile token (typically the memecoin)
        address stableToken;              // USDC or equivalent stable token
        uint256 totalTimeWeightedLiquidity; // Cumulative time-weighted contributions
        uint256 lastUpdateTimestamp;      // Last time calculations were updated
        uint256 accumulatedFees;          // Total fees captured for conversion
        uint128 conversionThreshold;      // Minimum fee amount before conversion
        address circleWalletAddress;      // Associated Circle Wallet for this pool
    }

    struct LPPosition {
        uint256 liquidityAmount;          // Current liquidity provided
        uint256 timeWeightedContribution; // Accumulated time-weighted value
        uint256 lastUpdateTimestamp;      // When position was last modified
        uint256 pendingRewards;           // Unclaimed USDC rewards
        uint256 totalClaimedRewards;      // Historical reward total
    }

    struct RewardPool {
        uint256 totalUSDCReserves;        // Available USDC for distribution
        uint256 distributionRate;         // USDC per second distribution rate
        uint256 lastDistributionTime;     // Timestamp of last reward distribution
        uint256 rewardPerTimeWeightedUnit; // Current reward rate calculation
    }

    struct AutoDistributionConfig {
    bool enabled;
    uint256 minimumThreshold;
    uint256 distributionInterval;
    uint256 maxRecipientsPerBatch;
}

    mapping(PoolId => PoolData) public poolData;
    
    mapping(PoolId => mapping(address => LPPosition)) public lpPositions;

    mapping(PoolId => RewardPool) public rewardPools;

    IFlaunchManager public flaunchManager;
    ICirclePaymaster public circlePaymaster;

    mapping(PoolId => ICircleProgrammableWallet) public circleWallets;

    mapping(PoolId => DistributionManager.DistributionState) private distributionStates;

    mapping(PoolId => ICircleProgrammableWallet.DistributionConfig) public distributionConfigs;

    mapping(PoolId => AutoDistributionConfig) public autoDistributionConfigs;

    address public immutable USDC;

    uint256 public maxSlippage = 500;

    event LiquidityAdded(PoolId indexed poolId, address indexed provider, uint256 amount, uint256 timestamp);
    event LiquidityRemoved(PoolId indexed poolId, address indexed provider, uint256 amount, uint256 timestamp);
    event FeeCaptured(PoolId indexed poolId, address token, uint256 amount);
    event RewardDistributed(PoolId indexed poolId, address indexed recipient, uint256 usdcAmount);
    event PoolInitialized(PoolId indexed poolId, address targetToken, address stableToken);
    event CircleWalletCreated(PoolId indexed poolId, address walletAddress, address owner);
    event AutoDistributionConfigured(PoolId indexed poolId, AutoDistributionConfig config);
    event RewardDistributionInitiated(PoolId indexed poolId, uint256 totalAmount, uint256 recipientCount);
    event RewardDistributionCompleted(PoolId indexed poolId, uint256 totalAmount, uint256 batchesExecuted);
    event DistributionThresholdReached(PoolId indexed poolId, uint256 pendingAmount);
    event FeeConversionTriggered(PoolId indexed poolId, uint256 feeAmount, uint256 usdcReceived);
    event ConversionThresholdUpdated(PoolId indexed poolId, uint256 newThreshold);
    event InternalSwapExecuted(PoolId indexed poolId, address fromToken, address toToken, uint256 amountIn, uint256 amountOut);

    event HookSwap(bytes32 indexed id, address indexed sender, int128 amount0, int128 amount1, uint128 hookLPfeeAmount0, uint128 hookLPfeeAmount1);
    event HookFee(bytes32 indexed id, address indexed sender, uint128 feeAmount0, uint128 feeAmount1);

    constructor(
        IPoolManager _poolManager, 
        address _usdc, 
        address _circlePaymaster
    ) BaseHook(_poolManager) {
        USDC = _usdc;
        circlePaymaster = ICirclePaymaster(_circlePaymaster);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: false,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick
    ) external override onlyPoolManager returns (bytes4) {
        PoolId poolId = key.toId();
        emit PoolInitialized(poolId, address(0), address(0));
        return YieldMatchaHook.afterInitialize.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        
        // Update time-weighted calculations for existing position
        _updateLPPosition(poolId, sender);
        
        // Record new liquidity addition
        LPPosition storage position = lpPositions[poolId][sender];
        uint256 liquidityDelta = uint256(int256(params.liquidityDelta));
        position.liquidityAmount += liquidityDelta;
        position.lastUpdateTimestamp = block.timestamp;
        
        // Update pool-level tracking
        _updatePoolTimeWeightedTotals(poolId);
        
        emit LiquidityAdded(poolId, sender, liquidityDelta, block.timestamp);
        
        return (YieldMatchaHook.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        
        // Update time-weighted calculations before removing liquidity
        _updateLPPosition(poolId, sender);
        
        // Calculate and accrue rewards for removed liquidity
        _calculateAndAccrueRewards(poolId, sender);
        
        // Update position data
        LPPosition storage position = lpPositions[poolId][sender];
        uint256 liquidityDelta = uint256(-int256(params.liquidityDelta));
        position.liquidityAmount -= liquidityDelta;
        position.lastUpdateTimestamp = block.timestamp;
        
        // Update pool-level tracking
        _updatePoolTimeWeightedTotals(poolId);
        
        emit LiquidityRemoved(poolId, sender, liquidityDelta, block.timestamp);
        
        return (YieldMatchaHook.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId poolId = key.toId();
        PoolData storage pool = poolData[poolId];
        
        if (!pool.isActive) {
            return (YieldMatchaHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }
        
        // Calculate expected fee from this swap
        uint256 expectedFee = ConversionUtils.calculateSwapFee(params.amountSpecified, key.fee);
        
        if (expectedFee > 0) {
            // Determine which token the fee will be taken in
            (address feeToken, bool isTargetToken) = ConversionUtils.determineFeeToken(params, key, pool.targetToken);
            
            if (isTargetToken) {
                // Mark this fee for capture
                pool.accumulatedFees += expectedFee;
                emit FeeCaptured(poolId, pool.targetToken, expectedFee);
                
                // Check if we should trigger conversion
                uint256 conversionAmount = ConversionUtils.calculateOptimalConversion(
                    pool.accumulatedFees,
                    pool.conversionThreshold,
                    maxSlippage
                );
                
                if (conversionAmount > 0) {
                    _triggerFeeConversion(poolId, conversionAmount);
                }
            }
        }
        
        return (YieldMatchaHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, int128) {
        PoolId poolId = key.toId();
        PoolData storage pool = poolData[poolId];
        
        if (!pool.isActive) {
            return (YieldMatchaHook.afterSwap.selector, 0);
        }
        
        // Update reward distribution calculations after each swap
        _updateRewardDistribution(poolId);
        
        // Emit standardized events for Flaunch integration
        _emitFlaunchStandardEvents(poolId, sender, delta);
        
        return (YieldMatchaHook.afterSwap.selector, 0);
    }

    function initializePoolWithCircle(
        PoolKey calldata key,
        address flaunchTokenAddress,
        uint128 conversionThreshold,
        ICircleProgrammableWallet.WalletConfig memory walletConfig,
        ICircleProgrammableWallet.DistributionConfig memory distConfig,
        AutoDistributionConfig memory autoConfig
    ) public {
        PoolId poolId = key.toId();
        require(poolData[poolId].targetToken == address(0), "Pool already initialized");
        require(address(flaunchManager) != address(0), "Flaunch manager not set");
        
        // Verify this is a Flaunch token
        require(flaunchManager.isFlaunchToken(flaunchTokenAddress), "Not a Flaunch token");
        
        // Register with Flaunch platform
        flaunchManager.registerYieldHarvester(flaunchTokenAddress, address(this));
        
        // Initialize pool data
        poolData[poolId] = PoolData({
            isActive: true,
            targetToken: flaunchTokenAddress,
            stableToken: USDC,
            totalTimeWeightedLiquidity: 0,
            lastUpdateTimestamp: block.timestamp,
            accumulatedFees: 0,
            conversionThreshold: conversionThreshold,
            circleWalletAddress: address(0)
        });
        
        emit PoolInitialized(poolId, flaunchTokenAddress, USDC);
        
        // Then set up Circle wallet
        require(address(circleWallets[poolId]) == address(0), "Wallet already initialized");

        PoolData storage pool = poolData[poolId];
        require(pool.isActive, "Pool not active");

        // Create Circle wallet through Flaunch manager
        address walletAddress = flaunchManager.createCircleWallet(pool.targetToken);
        ICircleProgrammableWallet wallet = ICircleProgrammableWallet(walletAddress);

        // Initialize wallet configuration
        wallet.initialize(walletConfig, distConfig);

        // Store references
        circleWallets[poolId] = wallet;
        distributionConfigs[poolId] = distConfig;
        autoDistributionConfigs[poolId] = autoConfig;

        // Update pool data
        pool.circleWalletAddress = walletAddress;

        emit CircleWalletCreated(poolId, walletAddress, walletConfig.owner);
        emit AutoDistributionConfigured(poolId, autoConfig);
    }

    function initializePoolWithFlaunch(
        PoolKey calldata key,
        address flaunchTokenAddress,
        uint128 conversionThreshold
    ) external {
        ICircleProgrammableWallet.WalletConfig memory walletConfig = ICircleProgrammableWallet.WalletConfig({
            owner: msg.sender,
            authorizedSpenders: new address[](0),
            dailyLimit: type(uint256).max,
            transactionLimit: type(uint256).max,
            isActive: true
        });

        ICircleProgrammableWallet.DistributionConfig memory distConfig = ICircleProgrammableWallet.DistributionConfig({
            minimumDistribution: 1,
            maxRecipientsPerBatch: 100,
            distributionCooldown: 0,
            autoDistributionEnabled: false
        });

        AutoDistributionConfig memory autoConfig = AutoDistributionConfig({
            enabled: false,
            minimumThreshold: 0,
            distributionInterval: 0,
            maxRecipientsPerBatch: 100
        });

        initializePoolWithCircle(key, flaunchTokenAddress, conversionThreshold, walletConfig, distConfig, autoConfig);
    }

    function checkAndExecuteAutoDistribution(PoolId poolId) external {
        AutoDistributionConfig storage autoConfig = autoDistributionConfigs[poolId];
        
        if (!autoConfig.enabled) return;
        
        RewardPool storage rewards = rewardPools[poolId];
        
        // Check if minimum threshold is met
        if (rewards.totalUSDCReserves < autoConfig.minimumThreshold) return;
        
        // Check if enough time has passed since last distribution
        if (block.timestamp < rewards.lastDistributionTime + autoConfig.distributionInterval) return;
        
        // Get all active LP addresses
        address[] memory activeLPs = _getActiveLPs(poolId);
        
        if (activeLPs.length == 0) return;
        
        emit DistributionThresholdReached(poolId, rewards.totalUSDCReserves);
        
        // Execute automated distribution
        executeRewardDistribution(poolId, activeLPs);
    }

    function executeRewardDistribution(PoolId poolId, address[] memory recipients) public returns (uint256 totalDistributed) {
        require(recipients.length > 0, "No recipients specified");
        require(address(circleWallets[poolId]) != address(0), "Circle wallet not initialized");
        
        ICircleProgrammableWallet wallet = circleWallets[poolId];
        
        // Calculate reward amounts for each recipient
        uint256[] memory amounts = new uint256[](recipients.length);
        totalDistributed = 0;
        
        for (uint i = 0; i < recipients.length; i++) {
            // Update LP position before calculating rewards
            _updateLPPosition(poolId, recipients[i]);
            
            amounts[i] = _calculateRewardShare(poolId, recipients[i]);
            totalDistributed += amounts[i];
            
            // Update LP position to reflect pending distribution
            lpPositions[poolId][recipients[i]].pendingRewards = amounts[i];
        }
        
        require(totalDistributed > 0, "No rewards to distribute");
        require(wallet.getUSDCBalance() >= totalDistributed, "Insufficient wallet balance");
        
        // Create and execute distribution batches
        AutoDistributionConfig storage autoConfig = autoDistributionConfigs[poolId];
        uint256 batchSize = DistributionManager.calculateOptimalBatchSize(
            recipients.length,
            300000 // Max gas limit per transaction
        );
        
        if (autoConfig.maxRecipientsPerBatch > 0 && batchSize > autoConfig.maxRecipientsPerBatch) {
            batchSize = autoConfig.maxRecipientsPerBatch;
        }
        
        DistributionManager.DistributionState storage distState = distributionStates[poolId];
        uint256 numBatches = DistributionManager.createDistributionBatches(
            distState,
            recipients,
            amounts,
            batchSize
        );
        
        emit RewardDistributionInitiated(poolId, totalDistributed, recipients.length);
        
        // Execute batches
        uint256 successfulBatches = 0;
        for (uint256 i = 0; i < numBatches; i++) {
            bool success = DistributionManager.executeDistributionBatch(
                distState,
                distState.batches.length - numBatches + i,
                wallet,
                circlePaymaster
            );
            
            if (success) {
                successfulBatches++;
            }
        }
        
        // Update LP positions after successful distribution
        _finalizeDistribution(poolId, recipients, amounts, successfulBatches == numBatches);
        
        emit RewardDistributionCompleted(poolId, totalDistributed, successfulBatches);
        
        return totalDistributed;
    }

    function setFlaunchManager(address _flaunchManager) external {
        flaunchManager = IFlaunchManager(_flaunchManager);
    }

    function updateConversionThreshold(PoolId poolId, uint128 newThreshold) external {
        poolData[poolId].conversionThreshold = newThreshold;
        emit ConversionThresholdUpdated(poolId, newThreshold);
    }

    function updateMaxSlippage(uint256 newMaxSlippage) external {
        require(newMaxSlippage <= 1000, "Max slippage too high");
        maxSlippage = newMaxSlippage;
    }

    function updateAutoDistributionConfig(
        PoolId poolId,
        AutoDistributionConfig calldata newConfig
    ) external {
        autoDistributionConfigs[poolId] = newConfig;
        emit AutoDistributionConfigured(poolId, newConfig);
    }

    function pauseCircleWallet(PoolId poolId) external {
        require(address(circleWallets[poolId]) != address(0), "Wallet not initialized");
        circleWallets[poolId].pause();
    }

    function unpauseCircleWallet(PoolId poolId) external {
        require(address(circleWallets[poolId]) != address(0), "Wallet not initialized");
        circleWallets[poolId].unpause();
    }

    function _updateLPPosition(PoolId poolId, address provider) internal {
        LPPosition storage position = lpPositions[poolId][provider];
        
        if (position.liquidityAmount > 0 && position.lastUpdateTimestamp > 0) {
            uint256 timeElapsed = block.timestamp - position.lastUpdateTimestamp;
            position.timeWeightedContribution += position.liquidityAmount * timeElapsed;
            poolData[poolId].totalTimeWeightedLiquidity += position.liquidityAmount * timeElapsed;
        }
        
        position.lastUpdateTimestamp = block.timestamp;
    }

    function _updatePoolTimeWeightedTotals(PoolId poolId) internal {
        PoolData storage pool = poolData[poolId];
        pool.lastUpdateTimestamp = block.timestamp;
    }

    function _calculateAndAccrueRewards(PoolId poolId, address provider) internal {
        // Placeholder for reward calculation logic
    }

    function _triggerFeeConversion(PoolId poolId, uint256 conversionAmount) internal {
        PoolData storage pool = poolData[poolId];
        
        if (conversionAmount == 0 || conversionAmount > pool.accumulatedFees) return;
        
        uint256 usdcReceived = _executeInternalSwap(
            poolId,
            pool.targetToken,
            pool.stableToken,
            conversionAmount
        );
        
        if (usdcReceived > 0) {
            rewardPools[poolId].totalUSDCReserves += usdcReceived;
            pool.accumulatedFees -= conversionAmount;
            _updateRewardDistribution(poolId);
            emit FeeConversionTriggered(poolId, conversionAmount, usdcReceived);
        }
    }

    function _executeInternalSwap(
        PoolId poolId,
        address fromToken,
        address toToken,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        // Simplified conversion for testing
        amountOut = (amountIn * 1e2) / 1e6;
        emit InternalSwapExecuted(poolId, fromToken, toToken, amountIn, amountOut);
        return amountOut;
    }

    function _updateRewardDistribution(PoolId poolId) internal {
        RewardPool storage rewards = rewardPools[poolId];
        PoolData storage pool = poolData[poolId];
        
        if (pool.totalTimeWeightedLiquidity > 0 && rewards.totalUSDCReserves > 0) {
            rewards.rewardPerTimeWeightedUnit = rewards.totalUSDCReserves / pool.totalTimeWeightedLiquidity;
            rewards.lastDistributionTime = block.timestamp;
        }
    }

    function _calculateRewardShare(PoolId poolId, address provider) internal view returns (uint256) {
        LPPosition storage position = lpPositions[poolId][provider];
        PoolData storage pool = poolData[poolId];
        
        if (pool.totalTimeWeightedLiquidity == 0) return 0;
        
        uint256 currentContribution = position.timeWeightedContribution;
        if (position.liquidityAmount > 0 && position.lastUpdateTimestamp > 0) {
            uint256 timeElapsed = block.timestamp - position.lastUpdateTimestamp;
            currentContribution += position.liquidityAmount * timeElapsed;
        }
        
        RewardPool storage rewards = rewardPools[poolId];
        if (rewards.totalUSDCReserves == 0) return 0;
        
        return (currentContribution * rewards.totalUSDCReserves) / pool.totalTimeWeightedLiquidity;
    }

    function _finalizeDistribution(
        PoolId poolId,
        address[] memory recipients,
        uint256[] memory amounts,
        bool allBatchesSuccessful
    ) internal {
        if (!allBatchesSuccessful) return;
        
        RewardPool storage rewards = rewardPools[poolId];
        uint256 totalDistributed = 0;
        
        for (uint256 i = 0; i < recipients.length; i++) {
            LPPosition storage position = lpPositions[poolId][recipients[i]];
            position.pendingRewards = 0;
            position.totalClaimedRewards += amounts[i];
            totalDistributed += amounts[i];
            emit RewardDistributed(poolId, recipients[i], amounts[i]);
        }
        
        rewards.totalUSDCReserves -= totalDistributed;
        rewards.lastDistributionTime = block.timestamp;
    }

    function _getActiveLPs(PoolId poolId) internal view returns (address[] memory) {
        // Simplified implementation - return empty array
        return new address[](0);
    }

    function _emitFlaunchStandardEvents(PoolId poolId, address sender, BalanceDelta delta) internal {
        emit HookSwap(PoolId.unwrap(poolId), sender, delta.amount0(), delta.amount1(), 0, 0);
        
        PoolData storage pool = poolData[poolId];
        if (pool.accumulatedFees > 0) {
            emit HookFee(PoolId.unwrap(poolId), sender, uint128(pool.accumulatedFees), 0);
        }
    }

    function calculateRewardShare(PoolId poolId, address provider) external view returns (uint256) {
        return _calculateRewardShare(poolId, provider);
    }

    function getLPPosition(PoolId poolId, address provider) external view returns (LPPosition memory) {
        return lpPositions[poolId][provider];
    }

    function getPoolData(PoolId poolId) external view returns (PoolData memory) {
        return poolData[poolId];
    }

    function getRewardPool(PoolId poolId) external view returns (RewardPool memory) {
        return rewardPools[poolId];
    }

    function getDistributionStatus(PoolId poolId) external view returns (
        uint256 totalReserves,
        uint256 pendingDistributions,
        uint256 lastDistributionTime,
        bool autoDistributionEnabled,
        uint256 nextAutoDistributionTime
    ) {
        RewardPool storage rewards = rewardPools[poolId];
        DistributionManager.DistributionState storage distState = distributionStates[poolId];
        AutoDistributionConfig storage autoConfig = autoDistributionConfigs[poolId];
        
        totalReserves = rewards.totalUSDCReserves;
        pendingDistributions = distState.pendingDistributions;
        lastDistributionTime = rewards.lastDistributionTime;
        autoDistributionEnabled = autoConfig.enabled;
        
        if (autoConfig.enabled) {
            nextAutoDistributionTime = rewards.lastDistributionTime + autoConfig.distributionInterval;
        }
    }

    function getCircleWalletStatus(PoolId poolId) external view returns (
        address walletAddress,
        uint256 balance,
        bool isPaused,
        uint256 remainingDailyLimit
    ) {
        ICircleProgrammableWallet wallet = circleWallets[poolId];
        
        if (address(wallet) == address(0)) {
            return (address(0), 0, false, 0);
        }
        
        walletAddress = address(wallet);
        balance = wallet.getUSDCBalance();
        isPaused = wallet.isPaused();
        remainingDailyLimit = wallet.getRemainingDailyLimit();
    }
} 