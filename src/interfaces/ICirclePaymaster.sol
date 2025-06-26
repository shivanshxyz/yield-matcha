// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ICirclePaymaster {
    struct GasPaymentConfig {
        uint256 maxGasPrice;
        uint256 maxGasLimit;
        address[] allowedTokens;
        bool isActive;
    }

    /// @notice Pay gas fees using USDC from the wallet
    function payGasWithUSDC(
        address wallet,
        uint256 gasAmount,
        bytes calldata permitSignature
    ) external;
    
    /// @notice Get gas payment configuration
    function getGasPaymentConfig() external view returns (GasPaymentConfig memory);
    
    /// @notice Estimate gas cost in USDC
    function estimateGasCostInUSDC(uint256 gasAmount) external view returns (uint256);
    
    /// @notice Check if wallet can pay for gas
    function canPayGas(address wallet, uint256 gasAmount) external view returns (bool);
} 