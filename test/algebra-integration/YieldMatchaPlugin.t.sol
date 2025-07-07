// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../src/algebra-integration/YieldMatchaPlugin.sol";
import "../../src/algebra-integration/YieldMatchaPoolEntryPoint.sol";
import {AlgebraFactory} from "Algebra/core/contracts/AlgebraFactory.sol";
import "v4-core/test/utils/Deployers.sol";
import {AlgebraPoolDeployer} from "Algebra/core/contracts/AlgebraPoolDeployer.sol";
import {Create2} from "@uniswap/v4-core/lib/openzeppelin-contracts/contracts/utils/Create2.sol";
import {IAlgebraPool} from "Algebra/core/contracts/interfaces/IAlgebraPool.sol";

struct Addresses {
    address address1;
    address address2;
}

contract YieldMatchaPluginTest is Test, Deployers {
    using Create2 for bytes32;

    YieldMatchaPlugin public plugin;
    YieldMatchaPoolEntryPoint public entryPoint;
    AlgebraFactory public factory;
    AlgebraPoolDeployer public poolDeployer;
    //@dev This is only added for readablitity
    address peripheryDeployer = address(this);
    address poolCreator = peripheryDeployer;

    function setUp() public {
        (currency0, currency1) = deployAndMint2Currencies();
        vm.startPrank(peripheryDeployer);
        {
            poolDeployer = AlgebraPoolDeployer(
                address(
                    uint160(
                        uint256(
                            keccak256(
                                abi.encodePacked(
                                    bytes1(0xFF),
                                    peripheryDeployer,
                                    keccak256("AlgebraPoolDeployer"),
                                    keccak256(type(AlgebraPoolDeployer).creationCode)
                                )
                            )
                        )
                    )
                )
            );
            factory = new AlgebraFactory(address(poolDeployer));
            deployCodeTo(
                "AlgebraPoolDeployer",
                abi.encode(Addresses({address1: address(factory), address2: address(poolDeployer)})),
                address(poolDeployer)
            );
            entryPoint = new YieldMatchaPoolEntryPoint(address(factory));
            factory.setDefaultPluginFactory(address(entryPoint));
        }
        vm.stopPrank();
    }

    function setNewCreator(address newCreator) public {
        poolCreator = newCreator;
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
