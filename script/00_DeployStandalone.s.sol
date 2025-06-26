// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console2} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";

import {YieldMatchaHook} from "../src/YieldMatchaHook.sol";
import {MockFlaunchManager} from "../src/mocks/MockFlaunchManager.sol";
import {MockCircleProgrammableWallet} from "../src/mocks/MockCircleProgrammableWallet.sol";
import {MockERC20} from "@uniswap/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

/// @notice Deploy YieldMatchaHook to Base Sepolia with proper address mining
contract DeployStandaloneScript is Script {
    
    // Base Sepolia addresses
    address constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    
    function run() public {
        console2.log("=== YIELD HARVESTER HOOK DEPLOYMENT ===");
        console2.log("Network Chain ID:", block.chainid);
        console2.log("Deployer:", msg.sender);
        console2.log("PoolManager:", POOL_MANAGER);
        
        vm.startBroadcast();
        
        // Deploy tokens and sponsor contracts first
        console2.log("Deploying mock USDC...");
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console2.log("USDC deployed at:", address(usdc));
        
        console2.log("Deploying mock memecoin...");
        MockERC20 memecoin = new MockERC20("UHI Memecoin", "UHIM", 18);
        console2.log("Memecoin deployed at:", address(memecoin));
        
        console2.log("Deploying Flaunch Manager...");
        MockFlaunchManager flaunchManager = new MockFlaunchManager();
        console2.log("FlaunchManager deployed at:", address(flaunchManager));
        
        console2.log("Deploying Circle Wallet...");
        MockCircleProgrammableWallet circleWallet = new MockCircleProgrammableWallet();
        console2.log("CircleWallet deployed at:", address(circleWallet));
        
        // Mine for hook address with correct permissions
        console2.log("Mining hook address with correct permissions...");
        
        // Define the permissions our hook needs
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.AFTER_ADD_LIQUIDITY_FLAG | 
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG |
            Hooks.AFTER_INITIALIZE_FLAG
        );
        
        // Get hook creation code with constructor args
        bytes memory hookCreationCode = abi.encodePacked(
            type(YieldMatchaHook).creationCode,
            abi.encode(
                IPoolManager(POOL_MANAGER),
                address(usdc),
                address(circleWallet)
            )
        );
        
        // Mine for the correct hook address
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this), // deployer (this script)
            flags,
            type(YieldMatchaHook).creationCode,
            abi.encode(
                IPoolManager(POOL_MANAGER),
                address(usdc),
                address(circleWallet)
            )
        );
        
        console2.log("Found hook address:", hookAddress);
        console2.log("Salt:", vm.toString(salt));
        
        // Deploy the hook at the mined address
        console2.log("Deploying YieldMatchaHook at mined address...");
        
        YieldMatchaHook yieldHook = new YieldMatchaHook{salt: salt}(
            IPoolManager(POOL_MANAGER),
            address(usdc),
            address(circleWallet)
        );
        
        require(address(yieldHook) == hookAddress, "Hook address mismatch");
        console2.log("YieldMatchaHook deployed at:", address(yieldHook));
        
        // Verify hook permissions
        console2.log("Verifying hook permissions:");
        console2.log("  beforeSwap:", Hooks.hasPermission(IHooks(address(yieldHook)), Hooks.BEFORE_SWAP_FLAG));
        console2.log("  afterSwap:", Hooks.hasPermission(IHooks(address(yieldHook)), Hooks.AFTER_SWAP_FLAG));
        console2.log("  afterAddLiquidity:", Hooks.hasPermission(IHooks(address(yieldHook)), Hooks.AFTER_ADD_LIQUIDITY_FLAG));
        console2.log("  afterRemoveLiquidity:", Hooks.hasPermission(IHooks(address(yieldHook)), Hooks.AFTER_REMOVE_LIQUIDITY_FLAG));
        
        // Configure the hook
        console2.log("Configuring hook...");
        yieldHook.setFlaunchManager(address(flaunchManager));
        yieldHook.updateMaxSlippage(500); // 5%
        
        // Setup demo data
        console2.log("Setting up Flaunch integration...");
        flaunchManager.addFlaunchToken(
            address(memecoin),
            "UHI Memecoin",
            "UHIM"
        );
        
        // Mint demo tokens
        console2.log("Minting demo tokens...");
        usdc.mint(msg.sender, 1000000 * 1e6); // 1M USDC
        memecoin.mint(msg.sender, 1000000 * 1e18); // 1M HACK
        
        console2.log("Hook configured and demo data setup");
        
        vm.stopBroadcast();
        
        console2.log("\n=== DEPLOYMENT SUMMARY ===");
        console2.log("YieldMatchaHook:", address(yieldHook));
        console2.log("USDC Token:", address(usdc));
        console2.log("Memecoin Token:", address(memecoin));
        console2.log("Flaunch Manager:", address(flaunchManager));
        console2.log("Circle Wallet:", address(circleWallet));
        console2.log("PoolManager (Base Sepolia):", POOL_MANAGER);
        console2.log("\n YIELD HARVESTER HOOK DEPLOYED SUCCESSFULLY!");
        console2.log("Full sponsor integration!");
    }
} 