// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Plugins} from "Algebra/core/contracts/libraries/Plugins.sol";
import {AlgebraBasePlugin} from "Algebra/plugin/contracts/base/AlgebraBasePlugin.sol";
import {IAlgebraPool} from "Algebra/core/contracts/interfaces/IAlgebraPool.sol";
import {IAlgebraPlugin} from "Algebra/core/contracts/interfaces/plugin/IAlgebraPlugin.sol";

uint8 constant PLUGIN_CONFIG = uint8(
    Plugins.AFTER_INIT_FLAG | Plugins.AFTER_POSITION_MODIFY_FLAG | Plugins.BEFORE_SWAP_FLAG | Plugins.AFTER_SWAP_FLAG
);

contract YieldMatchaPlugin is AlgebraBasePlugin {
    //NOTE: This is the YieldMatchaHook event that needs to be replicated for afterInitialize
    // event PoolInitialized(PoolId indexed poolId, address targetToken, address stableToken);
    // @dev The difference with UniswapV4 is that tokens are known on afterInitialize

    event PoolInitialized(address indexed pool, address targetToken, address stableToken);

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
}
