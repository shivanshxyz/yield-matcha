// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

library ConversionUtils {
    /// @notice Calculate expected fee from a swap
    /// @param amountSpecified The amount being swapped
    /// @param fee The pool fee (in basis points, e.g., 3000 = 0.3%)
    /// @return expectedFee The calculated fee amount
    function calculateSwapFee(int256 amountSpecified, uint24 fee) internal pure returns (uint256 expectedFee) {
        if (amountSpecified == 0) return 0;
        
        uint256 absAmount = amountSpecified < 0 ? uint256(-amountSpecified) : uint256(amountSpecified);
        
        // Fee is calculated as a percentage of the input amount
        // For exact input swaps (amountSpecified < 0), fee is taken from input
        // For exact output swaps (amountSpecified > 0), fee is added to input
        expectedFee = (absAmount * fee) / 1_000_000; // fee is in basis points (1e6)
    }
    
    /// @notice Determine which token the fee will be taken in
    /// @param params The swap parameters
    /// @param key The pool key
    /// @return feeToken The address of the token the fee will be taken in
    /// @return isTargetToken Whether the fee token matches our target token
    function determineFeeToken(
        SwapParams calldata params, 
        PoolKey calldata key,
        address targetToken
    ) internal pure returns (address feeToken, bool isTargetToken) {
        // In Uniswap V4, fees are taken from the unspecified token
        // For exact input swaps (amountSpecified < 0), fee is taken from output token
        // For exact output swaps (amountSpecified > 0), fee is taken from input token
        
        if (params.amountSpecified < 0) {
            // Exact input: fee taken from output token
            feeToken = params.zeroForOne ? Currency.unwrap(key.currency1) : Currency.unwrap(key.currency0);
        } else {
            // Exact output: fee taken from input token  
            feeToken = params.zeroForOne ? Currency.unwrap(key.currency0) : Currency.unwrap(key.currency1);
        }
        
        isTargetToken = (feeToken == targetToken);
    }
    
    /// @notice Calculate optimal conversion amount to minimize slippage
    /// @param accumulatedFees Current fee balance
    /// @param threshold Conversion threshold
    /// @param maxSlippage Maximum acceptable slippage (in basis points)
    /// @return conversionAmount Amount to convert in this transaction
    function calculateOptimalConversion(
        uint256 accumulatedFees,
        uint256 threshold,
        uint256 maxSlippage
    ) internal pure returns (uint256 conversionAmount) {
        if (accumulatedFees < threshold) return 0;
        
        // For now, convert all accumulated fees
        // In a production system, this could be optimized based on liquidity depth
        conversionAmount = accumulatedFees;
    }
} 