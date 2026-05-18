// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {NetworkConfig} from "../src/networks/NetworkConfig.sol";
import {MegaEthMainnet} from "../src/networks/MegaEthMainnet.sol";

/// @title NetworkConfigTest
/// @notice Tests for network configuration libraries
contract NetworkConfigTest is Test {
    function test_MegaEthMainnetAddresses() public pure {
        NetworkConfig.Addresses memory addrs = MegaEthMainnet.getAddresses();

        assertNotEq(addrs.poolAddressesProvider, address(0), "PoolAddressesProvider should be set");
        assertNotEq(addrs.pool, address(0), "Pool should be set");
        assertNotEq(addrs.poolConfigurator, address(0), "PoolConfigurator should be set");
        assertNotEq(addrs.oracle, address(0), "Oracle should be set");
        assertNotEq(addrs.aTokenImpl, address(0), "ATokenImpl should be set");
        assertNotEq(addrs.variableDebtImpl, address(0), "VariableDebtImpl should be set");
        assertNotEq(addrs.treasury, address(0), "Treasury should be set");
        assertNotEq(addrs.incentivesController, address(0), "IncentivesController should be set");
        assertNotEq(addrs.defaultInterestRateStrategy, address(0), "DefaultInterestRateStrategy should be set");
    }

    function test_MegaEthMainnetGetPoolConfigurator() public view {
        address configurator = MegaEthMainnet.getPoolConfigurator();
        assertNotEq(configurator, address(0), "PoolConfigurator should not be zero");
        assertEq(configurator, MegaEthMainnet.POOL_CONFIGURATOR, "Should return POOL_CONFIGURATOR constant");
    }

    function test_NetworkConfigGetPoolConfigurator() public view {
        NetworkConfig.Addresses memory addrs = MegaEthMainnet.getAddresses();
        address configurator = NetworkConfig.getPoolConfigurator(addrs);
        assertEq(configurator, MegaEthMainnet.POOL_CONFIGURATOR, "Should return POOL_CONFIGURATOR when set");
    }

    function test_MegaEthMainnetConstants() public pure {
        assertEq(
            MegaEthMainnet.POOL_ADDRESSES_PROVIDER,
            0x4E293100F46889B21a12C5884551FF340AD8d7b9,
            "POOL_ADDRESSES_PROVIDER should match"
        );
        assertEq(MegaEthMainnet.POOL, 0x202FC1FEf70C8a7001f1579518e9288A547C12Ee, "POOL should match");
        assertEq(MegaEthMainnet.ORACLE, 0xfE7FCB1814Cb025149a938eDC85CE28BC71ce836, "ORACLE should match");
    }
}
