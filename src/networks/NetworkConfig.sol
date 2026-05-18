// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IPoolAddressesProvider} from "lib/velkonix-contracts/src/contracts/interfaces/IPoolAddressesProvider.sol";

/// @title NetworkConfig
/// @notice Shared helpers and the canonical address bundle for a deployment.
/// @dev Per-chain constants live in `MegaEthMainnet`.
library NetworkConfig {
    /// @notice Core protocol addresses required by listing and maintenance scripts.
    struct Addresses {
        /// @notice Aave `PoolAddressesProvider` proxy.
        address poolAddressesProvider;
        /// @notice Optional explicit pool; may be zero and resolved via the provider.
        address pool;
        /// @notice Optional explicit configurator; zero triggers provider lookup.
        address poolConfigurator;
        /// @notice Aave oracle proxy.
        address oracle;
        /// @notice aToken implementation used when listing reserves.
        address aTokenImpl;
        /// @notice Variable debt token implementation for new reserves.
        address variableDebtImpl;
        /// @notice Protocol treasury receiving fees.
        address treasury;
        /// @notice Rewards / incentives controller.
        address incentivesController;
        /// @notice Default borrow interest rate strategy for new reserves.
        address defaultInterestRateStrategy;
        /// @notice `AaveV3ConfigEngine` instance used as `delegatecall` target by payloads.
        address configEngine;
    }

    /// @notice Resolves the pool configurator, preferring an explicit address when set.
    /// @param addrs Network address bundle.
    /// @return configurator Resolved from `addrs.poolConfigurator` or `IPoolAddressesProvider`.
    function getPoolConfigurator(Addresses memory addrs) internal view returns (address configurator) {
        if (addrs.poolConfigurator != address(0)) {
            return addrs.poolConfigurator;
        }
        return IPoolAddressesProvider(addrs.poolAddressesProvider).getPoolConfigurator();
    }
}
