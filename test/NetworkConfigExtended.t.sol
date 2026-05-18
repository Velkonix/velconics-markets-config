// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {NetworkConfig} from "../src/networks/NetworkConfig.sol";
import {MegaEthMainnet} from "../src/networks/MegaEthMainnet.sol";

/// @title MockPoolAddressesProvider
/// @notice Mock for testing NetworkConfig.getPoolConfigurator fallback
contract MockPoolAddressesProvider is Test {
    address public poolConfigurator;

    /// @param _poolConfigurator Address returned by `getPoolConfigurator`.
    constructor(address _poolConfigurator) {
        poolConfigurator = _poolConfigurator;
    }

    function getPoolConfigurator() external view returns (address) {
        return poolConfigurator;
    }

    function getPool() external pure returns (address) {
        return address(0);
    }

    function getPriceOracle() external pure returns (address) {
        return address(0);
    }

    function getPoolDataProvider() external pure returns (address) {
        return address(0);
    }

    function getAddress(bytes32) external pure returns (address) {
        return address(0);
    }
}

/// @title NetworkConfigExtendedTest
/// @notice Extended tests for NetworkConfig to improve coverage
contract NetworkConfigExtendedTest is Test {
    function test_NetworkConfigGetPoolConfiguratorWithProvider() public {
        address mockConfigurator = address(0x1234);
        MockPoolAddressesProvider provider = new MockPoolAddressesProvider(mockConfigurator);

        NetworkConfig.Addresses memory addrs = NetworkConfig.Addresses({
            poolAddressesProvider: address(provider),
            pool: address(0),
            poolConfigurator: address(0),
            oracle: address(0),
            aTokenImpl: address(0),
            variableDebtImpl: address(0),
            treasury: address(0),
            incentivesController: address(0),
            defaultInterestRateStrategy: address(0),
            configEngine: address(0)
        });

        address result = NetworkConfig.getPoolConfigurator(addrs);
        assertEq(result, mockConfigurator, "Should return configurator from provider");
    }

    function test_MegaEthMainnetGetAddresses() public pure {
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
        assertNotEq(addrs.configEngine, address(0), "ConfigEngine should be set");
    }

    function test_NetworkConfigAddressesStructure() public pure {
        NetworkConfig.Addresses memory addrs = MegaEthMainnet.getAddresses();

        assertNotEq(addrs.poolAddressesProvider, address(0), "PoolAddressesProvider should be set");
        assertNotEq(addrs.pool, address(0), "Pool should be set");
        assertNotEq(addrs.oracle, address(0), "Oracle should be set");
    }
}
