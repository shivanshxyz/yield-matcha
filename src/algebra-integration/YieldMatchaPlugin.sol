// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Plugins} from "Algebra/core/contracts/libraries/Plugins.sol";
import {AlgebraBasePlugin} from "Algebra/plugin/contracts/base/AlgebraBasePlugin.sol";
import {IAlgebraPool} from "Algebra/core/contracts/interfaces/IAlgebraPool.sol";
import {IAlgebraPlugin} from "Algebra/core/contracts/interfaces/plugin/IAlgebraPlugin.sol";
import {YieldMatchaHook} from "../YieldMatchaHook.sol";

uint8 constant PLUGIN_CONFIG = uint8(
    Plugins.AFTER_INIT_FLAG | Plugins.AFTER_POSITION_MODIFY_FLAG | Plugins.BEFORE_SWAP_FLAG | Plugins.AFTER_SWAP_FLAG
);

contract YieldMatchaPlugin is AlgebraBasePlugin {
    //NOTE: This is the YieldMatchaHook event that needs to be replicated for afterInitialize
    // event PoolInitialized(PoolId indexed poolId, address targetToken, address stableToken);
    // @dev The difference with UniswapV4 is that tokens are known on afterInitialize

    mapping(address lpProvider => YieldMatchaHook.LPPosition) public lpPositions;
    YieldMatchaHook.PoolData public poolData;

    event PoolInitialized(address indexed pool, address targetToken, address stableToken);
    event LiquidityAdded(address indexed pool, address indexed provider, uint256 amount, uint256 timestamp);
    event LiquidityRemoved(address indexed pool, address indexed provider, uint256 amount, uint256 timestamp);

    constructor(address _pool, address _factory, address _yieldMatchEntryPoint)
        AlgebraBasePlugin(_pool, _factory, _yieldMatchEntryPoint)
    {}

    function defaultPluginConfig() external view returns (uint8) {
        return PLUGIN_CONFIG;
    }

    function beforeInitialize(address sender, uint160 sqrtPriceX96) external override returns (bytes4) {
        return IAlgebraPlugin.beforeInitialize.selector;
    }

    //  @param sender The initial msg.sender for the initialize call
    function afterInitialize(address sender, uint160 sqrtPriceX96, int24 tick)
        external
        virtual
        override
        onlyPool
        returns (bytes4)
    {
        // TODO: This needs to verify that the tokens are sorted
        emit PoolInitialized(pool, IAlgebraPool(pool).token0(), IAlgebraPool(pool).token1());
        return IAlgebraPlugin.afterInitialize.selector;
    }
    // @param recipient Address to which the liquidity will be assigned in case of a mint or
    /// to which tokens will be sent in case of a burn
    // The below params are quivalent to the ModifyLiquidityParams
    // on Uni V4

    function afterModifyPosition(
        address sender,
        address receipient,
        int24 bottomTick,
        int24 topTick,
        int128 desiredLiquidityDelta,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external virtual override onlyPool returns (bytes4) {
        //===============ADDING LIQUIDITY ===================
        _updateLPPosition(sender);
        YieldMatchaHook.LPPosition storage position = lpPositions[sender];
        uint256 liquidityDelta =
            uint256(desiredLiquidityDelta < 0 ? -int256(desiredLiquidityDelta) : int256(desiredLiquidityDelta));
        if (desiredLiquidityDelta > 0) {
            position.liquidityAmount += liquidityDelta;
            emit LiquidityAdded(pool, sender, liquidityDelta, block.timestamp);
        } else if (desiredLiquidityDelta < 0) {
            _calculateAndAccrueRewards(sender);
            position.liquidityAmount -= liquidityDelta;
            emit LiquidityRemoved(pool, sender, liquidityDelta, block.timestamp);
        }

        position.lastUpdateTimestamp = block.timestamp;
        _updatePoolTimeWeightedTotals();
        return IAlgebraPlugin.afterModifyPosition.selector;
    }

    function _updateLPPosition(address provider) internal {
        YieldMatchaHook.LPPosition storage position = lpPositions[provider];

        if (position.liquidityAmount > 0 && position.lastUpdateTimestamp > 0) {
            uint256 timeElapsed = block.timestamp - position.lastUpdateTimestamp;
            position.timeWeightedContribution += position.liquidityAmount * timeElapsed;
            poolData.totalTimeWeightedLiquidity += position.liquidityAmount * timeElapsed;
        }

        position.lastUpdateTimestamp = block.timestamp;
    }

    function _updatePoolTimeWeightedTotals() internal {
        YieldMatchaHook.PoolData storage _poolData = poolData;
        _poolData.lastUpdateTimestamp = block.timestamp;
    }

    function _calculateAndAccrueRewards(address provider) internal {
        // Placeholder for reward calculation logic
    }
}
