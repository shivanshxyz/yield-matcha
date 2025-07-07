// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IAlgebraPool} from "Algebra/core/contracts/interfaces/IAlgebraPool.sol";
import "../utils/AlgebraDeployers.sol";

contract YieldMatchaPluginTest is Test, AlgebraDeployers {
    function setUp() public {
        (currency0, currency1) = deployAndMint2Currencies();

        deployFactoryAndPoolDeployer();
        vm.startPrank(peripheryDeployer);
        entryPoint = new YieldMatchaPoolEntryPoint(address(factory));
        factory.setDefaultPluginFactory(address(entryPoint));
        vm.stopPrank();
    }

    function test__initializePool() external {
        vm.startPrank(peripheryDeployer);
        (address token0, address token1) = (Currency.unwrap(currency0), Currency.unwrap(currency1));
        {
            address pool = entryPoint.createPool(token0, token1, bytes(""));
            plugin = YieldMatchaPlugin(
                address(
                    uint160(
                        uint256(
                            keccak256(
                                abi.encodePacked(
                                    bytes1(0xFF),
                                    peripheryDeployer,
                                    keccak256("YieldMatchaPlugin"),
                                    keccak256(type(YieldMatchaPlugin).creationCode)
                                )
                            )
                        )
                    )
                )
            );
            deployCodeTo("YieldMatchaPlugin", abi.encode(pool, address(factory), address(entryPoint)), address(plugin));

            IAlgebraPool(pool).setPlugin(address(plugin));
            IAlgebraPool(pool).setPluginConfig(PLUGIN_CONFIG);
            IAlgebraPool(pool).initialize(SQRT_PRICE_1_2);
        }
        vm.stopPrank();
    }
}
