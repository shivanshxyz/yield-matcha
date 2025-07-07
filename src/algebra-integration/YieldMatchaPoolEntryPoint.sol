// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAlgebraPluginFactory} from "Algebra/core/contracts/interfaces/plugin/IAlgebraPluginFactory.sol";
import {YieldMatchaPlugin} from "./YieldMatchaPlugin.sol";
import {IAlgebraFactory} from "Algebra/core/contracts/interfaces/IAlgebraFactory.sol";

contract YieldMatchaPoolEntryPoint is IAlgebraPluginFactory {
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function beforeCreatePoolHook(
        address pool,
        address creator,
        address deployer,
        address token0,
        address token1,
        bytes calldata data
    ) external returns (address) {
        require(msg.sender == factory, "Only factory");
        address yieldMatchaAddress = _deployYieldMacthaPlugin(pool);
        return yieldMatchaAddress;
    }

    function createPool(address tokenA, address tokenB, bytes calldata data) external returns (address) {
        return IAlgebraFactory(factory).createPool(tokenA, tokenB, data);
    }

    function afterCreatePoolHook(address plugin, address pool, address deployer) external override {
        require(msg.sender == factory, "Only factory");
    }

    function _deployYieldMacthaPlugin(address pool) internal returns (address yieldMatchaAddress) {
        bytes memory encodedParams = abi.encode(pool, factory, address(this));
        yieldMatchaAddress =
            address(new YieldMatchaPlugin{salt: keccak256(encodedParams)}(pool, factory, address(this)));
    }
}
