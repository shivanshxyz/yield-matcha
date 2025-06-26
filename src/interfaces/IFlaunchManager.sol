// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IFlaunchManager {
    struct TokenMetadata {
        string name;
        string symbol;
        address creator;
        uint256 deploymentTime;
        bool isActive;
    }

    /// @notice Register a yield harvester hook with a Flaunch token
    function registerYieldHarvester(address tokenAddress, address hookAddress) external;
    
    /// @notice Create a Circle Wallet for token-specific operations
    function createCircleWallet(address tokenAddress) external returns (address);
    
    /// @notice Get metadata for a Flaunch-deployed token
    function getTokenMetadata(address tokenAddress) external view returns (TokenMetadata memory);
    
    /// @notice Check if a token was deployed through Flaunch
    function isFlaunchToken(address tokenAddress) external view returns (bool);
    
    /// @notice Get the current fair launch status for a token
    function getFairLaunchStatus(address tokenAddress) external view returns (bool inFairLaunch, uint256 endTime);
} 