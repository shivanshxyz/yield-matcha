// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ICircleProgrammableWallet {
    struct WalletConfig {
        address owner;
        address[] authorizedSpenders;
        uint256 dailyLimit;
        uint256 transactionLimit;
        bool isActive;
    }

    struct DistributionConfig {
        uint256 minimumDistribution;
        uint256 maxRecipientsPerBatch;
        uint256 distributionCooldown;
        bool autoDistributionEnabled;
    }

    /// @notice Initialize wallet with specific configuration
    function initialize(WalletConfig calldata config, DistributionConfig calldata distConfig) external;
    
    /// @notice Batch distribute USDC to multiple recipients with gas optimization
    function batchDistributeUSDC(
        address[] calldata recipients, 
        uint256[] calldata amounts,
        bytes calldata permitSignature
    ) external;
    
    /// @notice Execute automated distribution based on predefined rules
    function executeAutomatedDistribution(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;
    
    /// @notice Get current USDC balance
    function getUSDCBalance() external view returns (uint256);
    
    /// @notice Get wallet configuration
    function getWalletConfig() external view returns (WalletConfig memory);
    
    /// @notice Get distribution configuration
    function getDistributionConfig() external view returns (DistributionConfig memory);
    
    /// @notice Check if address is authorized for operations
    function isAuthorized(address operator) external view returns (bool);
    
    /// @notice Get remaining daily limit
    function getRemainingDailyLimit() external view returns (uint256);
    
    /// @notice Emergency pause functionality
    function pause() external;
    function unpause() external;
    function isPaused() external view returns (bool);
} 