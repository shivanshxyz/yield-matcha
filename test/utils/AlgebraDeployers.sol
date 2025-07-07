// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../src/algebra-integration/YieldMatchaPlugin.sol";
import "../../src/algebra-integration/YieldMatchaPoolEntryPoint.sol";
import {AlgebraFactory} from "Algebra/core/contracts/AlgebraFactory.sol";
import "v4-core/test/utils/Deployers.sol";
import {AlgebraPoolDeployer} from "Algebra/core/contracts/AlgebraPoolDeployer.sol";
import {Create2} from "@uniswap/v4-core/lib/openzeppelin-contracts/contracts/utils/Create2.sol";

contract AlgebraDeployers is Test, Deployers {
    using Create2 for bytes32;

    //@dev This is only added for readablitity
    address peripheryDeployer = address(this);

    YieldMatchaPlugin public plugin;
    YieldMatchaPoolEntryPoint public entryPoint;
    AlgebraFactory public factory;
    AlgebraPoolDeployer public poolDeployer;

    function deployFreshFactoryAndPoolDeployer() internal virtual {
        vm.startPrank(peripheryDeployer);
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
        deployCodeTo("AlgebraPoolDeployer", abi.encode(address(factory)), address(poolDeployer));
        vm.stopPrank();
    }
}
