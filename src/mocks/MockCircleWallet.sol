// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICircleWallet} from "../interfaces/ICircleWallet.sol";

contract MockCircleWallet is ICircleWallet {
    address public override owner;
    uint256 private balance;
    
    mapping(address => uint256) public allowances;
    
    event USDCDistributed(address[] recipients, uint256[] amounts);
    event USDCTransferred(address recipient, uint256 amount);
    
    constructor(address _owner) {
        owner = _owner;
        balance = 1000000 * 1e6; // Start with 1M USDC for testing
    }
    
    function distributeUSDC(address[] calldata recipients, uint256[] calldata amounts) external override {
        require(recipients.length == amounts.length, "Array length mismatch");
        
        uint256 totalAmount = 0;
        for (uint i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        
        require(balance >= totalAmount, "Insufficient balance");
        balance -= totalAmount;
        
        emit USDCDistributed(recipients, amounts);
    }
    
    function getBalance() external view override returns (uint256) {
        return balance;
    }
    
    function authorize(address spender, uint256 amount) external override {
        allowances[spender] = amount;
    }
    
    function transferUSDC(address recipient, uint256 amount) external override {
        require(balance >= amount, "Insufficient balance");
        balance -= amount;
        emit USDCTransferred(recipient, amount);
    }
    
    // Test helper functions
    function addBalance(uint256 amount) external {
        balance += amount;
    }
    
    function setBalance(uint256 newBalance) external {
        balance = newBalance;
    }
} 