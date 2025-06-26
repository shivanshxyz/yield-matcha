// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ICircleWallet {
    /// @notice Distribute USDC to multiple recipients
    function distributeUSDC(address[] calldata recipients, uint256[] calldata amounts) external;
    
    /// @notice Get current USDC balance in the wallet
    function getBalance() external view returns (uint256);
    
    /// @notice Authorize a spender to use USDC from this wallet
    function authorize(address spender, uint256 amount) external;
    
    /// @notice Transfer USDC to a single recipient
    function transferUSDC(address recipient, uint256 amount) external;
    
    /// @notice Get the wallet owner
    function owner() external view returns (address);
} 