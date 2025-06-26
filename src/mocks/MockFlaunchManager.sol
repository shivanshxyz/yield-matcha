// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IFlaunchManager} from "../interfaces/IFlaunchManager.sol";

contract MockFlaunchManager is IFlaunchManager {
    mapping(address => bool) public flaunchTokens;
    mapping(address => TokenMetadata) public tokenMetadata;
    mapping(address => address) public tokenHooks;
    
    uint256 private circleWalletCounter;

    function registerYieldHarvester(address tokenAddress, address hookAddress) external override {
        tokenHooks[tokenAddress] = hookAddress;
    }
    
    function createCircleWallet(address tokenAddress) external override returns (address) {
        // Return a mock address for testing
        circleWalletCounter++;
        return address(uint160(0x1000 + circleWalletCounter));
    }
    
    function getTokenMetadata(address tokenAddress) external view override returns (TokenMetadata memory) {
        return tokenMetadata[tokenAddress];
    }
    
    function isFlaunchToken(address tokenAddress) external view override returns (bool) {
        return flaunchTokens[tokenAddress];
    }
    
    function getFairLaunchStatus(address tokenAddress) external view override returns (bool inFairLaunch, uint256 endTime) {
        // Mock implementation
        return (false, 0);
    }
    
    // Test helper functions
    function addFlaunchToken(address tokenAddress, string memory name, string memory symbol) external {
        flaunchTokens[tokenAddress] = true;
        tokenMetadata[tokenAddress] = TokenMetadata({
            name: name,
            symbol: symbol,
            creator: msg.sender,
            deploymentTime: block.timestamp,
            isActive: true
        });
    }
} 