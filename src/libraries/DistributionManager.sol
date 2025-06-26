// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {ICircleProgrammableWallet} from "../interfaces/ICircleProgrammableWallet.sol";
import {ICirclePaymaster} from "../interfaces/ICirclePaymaster.sol";

library DistributionManager {
    struct DistributionBatch {
        address[] recipients;
        uint256[] amounts;
        uint256 totalAmount;
        uint256 timestamp;
        bool executed;
    }

    struct DistributionState {
        uint256 pendingDistributions;
        uint256 lastDistributionTime;
        uint256 totalDistributed;
        mapping(address => uint256) recipientTotals;
        DistributionBatch[] batches;
    }

    event DistributionBatchCreated(PoolId indexed poolId, uint256 batchId, uint256 totalAmount, uint256 recipientCount);
    event DistributionExecuted(PoolId indexed poolId, uint256 batchId, uint256 actualAmount);
    event DistributionFailed(PoolId indexed poolId, uint256 batchId, string reason);

    /// @notice Create optimized distribution batches
    function createDistributionBatches(
        DistributionState storage state,
        address[] memory allRecipients,
        uint256[] memory allAmounts,
        uint256 maxBatchSize
    ) internal returns (uint256 numBatches) {
        require(allRecipients.length == allAmounts.length, "Array length mismatch");
        
        numBatches = (allRecipients.length + maxBatchSize - 1) / maxBatchSize;
        
        for (uint256 i = 0; i < numBatches; i++) {
            uint256 startIdx = i * maxBatchSize;
            uint256 endIdx = startIdx + maxBatchSize;
            if (endIdx > allRecipients.length) {
                endIdx = allRecipients.length;
            }
            
            uint256 batchSize = endIdx - startIdx;
            address[] memory batchRecipients = new address[](batchSize);
            uint256[] memory batchAmounts = new uint256[](batchSize);
            uint256 batchTotal = 0;
            
            for (uint256 j = 0; j < batchSize; j++) {
                batchRecipients[j] = allRecipients[startIdx + j];
                batchAmounts[j] = allAmounts[startIdx + j];
                batchTotal += allAmounts[startIdx + j];
            }
            
            state.batches.push(DistributionBatch({
                recipients: batchRecipients,
                amounts: batchAmounts,
                totalAmount: batchTotal,
                timestamp: block.timestamp,
                executed: false
            }));
            
            state.pendingDistributions += batchTotal;
        }
        
        return numBatches;
    }

    /// @notice Execute a distribution batch with gas optimization
    function executeDistributionBatch(
        DistributionState storage state,
        uint256 batchId,
        ICircleProgrammableWallet wallet,
        ICirclePaymaster paymaster
    ) internal returns (bool success) {
        require(batchId < state.batches.length, "Invalid batch ID");
        
        DistributionBatch storage batch = state.batches[batchId];
        require(!batch.executed, "Batch already executed");
        
        // Check wallet balance
        uint256 walletBalance = wallet.getUSDCBalance();
        require(walletBalance >= batch.totalAmount, "Insufficient wallet balance");
        
        // Estimate gas cost and check if paymaster can cover it
        uint256 estimatedGas = estimateDistributionGas(batch.recipients.length);
        require(paymaster.canPayGas(address(wallet), estimatedGas), "Cannot pay gas fees");
        
        try wallet.batchDistributeUSDC(batch.recipients, batch.amounts, "") {
            // Update state on successful distribution
            batch.executed = true;
            state.pendingDistributions -= batch.totalAmount;
            state.totalDistributed += batch.totalAmount;
            state.lastDistributionTime = block.timestamp;
            
            // Update recipient totals
            for (uint256 i = 0; i < batch.recipients.length; i++) {
                state.recipientTotals[batch.recipients[i]] += batch.amounts[i];
            }
            
            return true;
        } catch Error(string memory reason) {
            // Handle distribution failure
            return false;
        }
    }

    /// @notice Estimate gas required for distribution
    function estimateDistributionGas(uint256 recipientCount) internal pure returns (uint256) {
        // Base gas + per-recipient gas cost
        return 21000 + (recipientCount * 25000);
    }

    /// @notice Calculate optimal batch size based on gas limits
    function calculateOptimalBatchSize(
        uint256 totalRecipients,
        uint256 maxGasLimit
    ) internal pure returns (uint256 optimalSize) {
        uint256 baseGas = 21000;
        uint256 perRecipientGas = 25000;
        
        optimalSize = (maxGasLimit - baseGas) / perRecipientGas;
        
        // Ensure we don't exceed total recipients
        if (optimalSize > totalRecipients) {
            optimalSize = totalRecipients;
        }
        
        // Minimum batch size of 1
        if (optimalSize == 0) {
            optimalSize = 1;
        }
        
        return optimalSize;
    }
} 