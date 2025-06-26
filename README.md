# 🍵 Yield Matcha 

> **Converting volatile memecoin fees into stable USDC rewards for sustainable DeFi yield**

## **Project Overview**

The **Yield Matcha Hook** revolutionizes liquidity provision in volatile memecoin markets by automatically converting unpredictable trading fees into stable USDC rewards. Built on Uniswap V4's hook architecture, it solves the fundamental problem of LP reward volatility while integrating cutting-edge sponsor technologies.

## **Problem Statement**

### **Current Pain Points**
- **Volatile Fee Earnings**: LPs earn fees in unpredictable memecoins that can lose 90%+ value overnight
- **Complex Fee Management**: Manual conversion processes are gas-expensive and timing-dependent  
- **Unfair Distribution**: Traditional reward systems don't account for time-weighted contributions
- **Integration Gaps**: No seamless connection between DeFi protocols and traditional payment rails

### **Market Impact**
- **$2.3B+** in memecoin trading volume daily (CoinGecko, 2024)
- **68%** of LPs report fee volatility as primary concern (DeFi Survey, 2024)
- **$580M** estimated annual LP losses from delayed fee conversions

## **Solution**

### **Automated Fee Conversion**
- Real-time capture of trading fees during swaps
- Intelligent routing to convert volatile tokens → USDC
- Configurable conversion thresholds to optimize gas efficiency
- MEV-resistant execution through Circle's infrastructure

### ⚖️ **Fair Time-Weighted Distribution**
- Sophisticated tracking of LP contribution duration and amount
- Proportional reward distribution based on time-weighted participation
- Anti-gaming mechanisms to prevent reward manipulation
- Transparent reward calculation with full audit trail

### 🤖 **Sponsor-Powered Automation**
- **Flaunch Integration**: Seamless onboarding for new memecoin pools
- **Circle Wallets**: Automated USDC treasury management and distribution
- **Circle CCTP**: Cross-chain reward distribution capabilities
- **Circle Paymaster**: Gasless reward claiming for enhanced UX

## 🏗️ **Technical Architecture**

### 📋 **Core Components**



### 🔧 **Smart Contract Structure**

```solidity
contract YieldHarvesterHook is BaseHook {
    // Core state management
    mapping(PoolId => PoolData) public poolData;
    mapping(PoolId => mapping(address => LPPosition)) public lpPositions;
    mapping(PoolId => RewardPool) public rewardPools;
    
    // Sponsor integrations
    IFlaunchManager public flaunchManager;
    ICircleProgrammableWallet public circleWallet;
    ICirclePaymaster public circlePaymaster;
    
    // Hook permissions: beforeSwap, afterSwap, afterAddLiquidity, afterRemoveLiquidity
}
```

### 🎛️ **Key Data Structures**

**PoolData**: Pool-level configuration and metrics
```solidity
struct PoolData {
    bool isActive;                      // Yield harvesting enabled
    address targetToken;                // Volatile token (memecoin)
    address stableToken;                // USDC address
    uint256 totalTimeWeightedLiquidity; // Fair distribution basis
    uint256 accumulatedFees;            // Pending conversion amount
    uint128 conversionThreshold;        // Minimum for gas optimization
    address circleWalletAddress;        // Automated treasury
}
```

**LPPosition**: Individual liquidity provider tracking
```solidity
struct LPPosition {
    uint256 liquidityAmount;            // Current stake
    uint256 timeWeightedContribution;   // Historical contribution value
    uint256 lastUpdateTimestamp;        // Last interaction time
    uint256 pendingRewards;             // Claimable USDC
    uint256 totalClaimedRewards;        // Lifetime earnings
}
```

## 🚀 **Sponsor Technology Integration**

### **Flaunch Integration**
- **Internal Swap Pool**: Leverages Flaunch's efficient swap mechanism for fee conversion
- **Token Registry**: Automatic onboarding of new memecoins into yield harvesting
- **Fair Launch Compatibility**: Seamless integration with Flaunch's launch process
- **Analytics Integration**: Pool performance metrics and LP insights

### **Circle Integration Suite**

#### **Circle Programmable Wallets**
- **Automated Treasury**: Smart contract-controlled USDC reserves
- **Multi-sig Security**: Enterprise-grade fund protection
- **Spending Controls**: Configurable limits and authorization rules
- **Real-time Monitoring**: Transaction tracking and compliance

#### **Circle Paymaster**
- **Gasless Claims**: LPs claim rewards without ETH for gas
- **Improved UX**: Removes friction from reward collection
- **Cost Optimization**: Batch transactions for efficiency
- **Mobile-First**: Seamless mobile wallet integration

#### **Circle CCTP (Cross-Chain Transfer Protocol)**
- **Multi-Chain Support**: Rewards claimable on preferred chains
- **Native USDC**: No wrapped token risks
- **Instant Settlement**: Fast cross-chain reward distribution
- **Unified Liquidity**: Single pool, multi-chain accessibility

#### **Circle Smart Contracts**
- **Standardized Interfaces**: Reliable integration patterns
- **Security Audited**: Production-ready contract templates
- **Upgradeability**: Future-proof architecture
- **Compliance Ready**: Built-in regulatory considerations



## Uniswap v4 Hook Template

**A template for writing Uniswap v4 Hooks 🦄**

### Get Started

This template provides a starting point for writing Uniswap v4 Hooks, including a simple example and preconfigured test environment. Start by creating a new repository using the "Use this template" button at the top right of this page. Alternatively you can also click this link:

[![Use this Template](https://img.shields.io/badge/Use%20this%20Template-101010?style=for-the-badge&logo=github)](https://github.com/uniswapfoundation/v4-template/generate)

1. The example hook [Counter.sol](src/Counter.sol) demonstrates the `beforeSwap()` and `afterSwap()` hooks
2. The test template [Counter.t.sol](test/Counter.t.sol) preconfigures the v4 pool manager, test tokens, and test liquidity.

<details>
<summary>Updating to v4-template:latest</summary>

This template is actively maintained -- you can update the v4 dependencies, scripts, and helpers:

```bash
git remote add template https://github.com/uniswapfoundation/v4-template
git fetch template
git merge template/main <BRANCH> --allow-unrelated-histories
```

</details>

### Requirements

This template is designed to work with Foundry (stable). If you are using Foundry Nightly, you may encounter compatibility issues. You can update your Foundry installation to the latest stable version by running:

```
foundryup
```

To set up the project, run the following commands in your terminal to install dependencies and run the tests:

```
forge install
forge test
```

### Local Development

Other than writing unit tests (recommended!), you can only deploy & test hooks on [anvil](https://book.getfoundry.sh/anvil/) locally. Scripts are available in the `script/` directory, which can be used to deploy hooks, create pools, provide liquidity and swap tokens. The scripts support both local `anvil` environment as well as running them directly on a production network.

### Troubleshooting

<details>

#### Permission Denied

When installing dependencies with `forge install`, Github may throw a `Permission Denied` error

Typically caused by missing Github SSH keys, and can be resolved by following the steps [here](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh)

Or [adding the keys to your ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent), if you have already uploaded SSH keys

#### Anvil fork test failures

Some versions of Foundry may limit contract code size to ~25kb, which could prevent local tests to fail. You can resolve this by setting the `code-size-limit` flag

```
anvil --code-size-limit 40000
```

#### Hook deployment failures

Hook deployment failures are caused by incorrect flags or incorrect salt mining

1. Verify the flags are in agreement:
   - `getHookCalls()` returns the correct flags
   - `flags` provided to `HookMiner.find(...)`
2. Verify salt mining is correct:
   - In **forge test**: the _deployer_ for: `new Hook{salt: salt}(...)` and `HookMiner.find(deployer, ...)` are the same. This will be `address(this)`. If using `vm.prank`, the deployer will be the pranking address
   - In **forge script**: the deployer must be the CREATE2 Proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
     - If anvil does not have the CREATE2 deployer, your foundry may be out of date. You can update it with `foundryup`

</details>

### Additional Resources

- [Uniswap v4 docs](https://docs.uniswap.org/contracts/v4/overview)
- [v4-periphery](https://github.com/uniswap/v4-periphery)
- [v4-core](https://github.com/uniswap/v4-core)
- [v4-by-example](https://v4-by-example.org)
