// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICircleProgrammableWallet} from "../interfaces/ICircleProgrammableWallet.sol";

contract MockCircleProgrammableWallet is ICircleProgrammableWallet {
    WalletConfig private _config;
    DistributionConfig private _distConfig;
    
    uint256 private balance;
    uint256 private dailySpent;
    uint256 private lastResetDay;
    bool private _paused;
    
    mapping(address => bool) private authorized;
    
    event WalletInitialized(address owner);
    event BatchDistributionExecuted(uint256 totalAmount, uint256 recipientCount);
    event AutoDistributionExecuted(uint256 totalAmount);
    
    constructor() {
        balance = 10000000 * 1e6; // Start with 10M USDC for testing
        lastResetDay = block.timestamp / 86400;
    }
    
    function initialize(
        WalletConfig calldata config, 
        DistributionConfig calldata distConfig
    ) external override {
        _config = config;
        _distConfig = distConfig;
        
        // Set up authorized addresses
        for (uint i = 0; i < config.authorizedSpenders.length; i++) {
            authorized[config.authorizedSpenders[i]] = true;
        }
        
        emit WalletInitialized(config.owner);
    }
    
    function batchDistributeUSDC(
        address[] calldata recipients, 
        uint256[] calldata amounts,
        bytes calldata permitSignature
    ) external override {
        require(!_paused, "Wallet is paused");
        require(recipients.length == amounts.length, "Array length mismatch");
        require(recipients.length <= _distConfig.maxRecipientsPerBatch, "Too many recipients");
        
        uint256 totalAmount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            require(amounts[i] >= _distConfig.minimumDistribution, "Amount below minimum");
            totalAmount += amounts[i];
        }
        
        _checkLimitsAndExecute(totalAmount);
        
        emit BatchDistributionExecuted(totalAmount, recipients.length);
    }
    
    function executeAutomatedDistribution(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external override {
        require(!_paused, "Wallet is paused");
        require(authorized[msg.sender], "Not authorized");
        
        uint256 totalAmount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        _checkLimitsAndExecute(totalAmount);
        
        emit AutoDistributionExecuted(totalAmount);
    }
    
    function _checkLimitsAndExecute(uint256 amount) internal {
        require(balance >= amount, "Insufficient balance");
        
        // Check daily limits
        uint256 currentDay = block.timestamp / 86400;
        if (currentDay > lastResetDay) {
            dailySpent = 0;
            lastResetDay = currentDay;
        }
        
        require(dailySpent + amount <= _config.dailyLimit, "Daily limit exceeded");
        require(amount <= _config.transactionLimit, "Transaction limit exceeded");
        
        // Execute
        balance -= amount;
        dailySpent += amount;
    }
    
    function getUSDCBalance() external view override returns (uint256) {
        return balance;
    }
    
    function getWalletConfig() external view override returns (WalletConfig memory) {
        return _config;
    }
    
    function getDistributionConfig() external view override returns (DistributionConfig memory) {
        return _distConfig;
    }
    
    function isAuthorized(address operator) external view override returns (bool) {
        return authorized[operator] || operator == _config.owner;
    }
    
    function getRemainingDailyLimit() external view override returns (uint256) {
        uint256 currentDay = block.timestamp / 86400;
        if (currentDay > lastResetDay) {
            return _config.dailyLimit;
        }
        
        if (dailySpent >= _config.dailyLimit) {
            return 0;
        }
        
        return _config.dailyLimit - dailySpent;
    }
    
    function pause() external override {
        require(msg.sender == _config.owner, "Only owner can pause");
        _paused = true;
    }
    
    function unpause() external override {
        require(msg.sender == _config.owner, "Only owner can unpause");
        _paused = false;
    }
    
    function isPaused() external view override returns (bool) {
        return _paused;
    }
    
    // Test helper functions
    function addBalance(uint256 amount) external {
        balance += amount;
    }
    
    function setBalance(uint256 newBalance) external {
        balance = newBalance;
    }
    
    function addAuthorized(address addr) external {
        authorized[addr] = true;
    }
} 