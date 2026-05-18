// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {NetworkConfig} from "./NetworkConfig.sol";

/// @title MegaEthMainnet
/// @notice Canonical addresses for the MegaETH mainnet deployment (chain id 4326, market "Velkonix").
/// @dev Constants below are fixed mainnet deployment addresses for the live pool stack,
///      parsed from the `setMarketReport` call of the core protocol deployment broadcast
///      and mapped via `IMarketReportTypes.MarketReport`.
library MegaEthMainnet {
    address internal constant POOL_ADDRESSES_PROVIDER = 0x4E293100F46889B21a12C5884551FF340AD8d7b9;
    address internal constant POOL = 0x202FC1FEf70C8a7001f1579518e9288A547C12Ee;
    address internal constant POOL_CONFIGURATOR = 0xbcc62FD71f80C93aF0C2b85e525929B127307FEB;
    address internal constant ORACLE = 0xfE7FCB1814Cb025149a938eDC85CE28BC71ce836;
    address internal constant ATOKEN_IMPL = 0x38D6c977F780996F4272dFe629Ec5979C0e2E055;
    address internal constant VARIABLE_DEBT_IMPL = 0x592912839240365bC3bfF32a162CA70FFfBd5dfA;
    address internal constant TREASURY = 0x7c65028FDDc87baa3eFd6f04F36d3AC4b11388fE;
    address internal constant INCENTIVES_CONTROLLER = 0xe243175aB6c779f9cFE8780B45e98752db8a8E79;
    address internal constant DEFAULT_INTEREST_RATE_STRATEGY = 0x4d2A6AF6aBB2561F204894f6aCEE30972bb1Ff2E;
    address internal constant CONFIG_ENGINE = 0x3F7402c391560F09632F136c776114A1B0D1e34B;
    address internal constant ACL_MANAGER = 0xdB9d5b0D7AB17e7AD5f63A788F880bFd4d008976;
    address internal constant EMISSION_MANAGER = 0xF52D65a26c512E9b7A36f5507AF5ACd12e0922E2;
    address internal constant AAVE_PROTOCOL_DATA_PROVIDER = 0x6da56B769B42952CACA18D37Feda3015FDB2fE67;

    /// @notice Returns the full address bundle for this network.
    /// @return Structured addresses for scripts and payloads.
    function getAddresses() internal pure returns (NetworkConfig.Addresses memory) {
        return NetworkConfig.Addresses({
            poolAddressesProvider: POOL_ADDRESSES_PROVIDER,
            pool: POOL,
            poolConfigurator: POOL_CONFIGURATOR,
            oracle: ORACLE,
            aTokenImpl: ATOKEN_IMPL,
            variableDebtImpl: VARIABLE_DEBT_IMPL,
            treasury: TREASURY,
            incentivesController: INCENTIVES_CONTROLLER,
            defaultInterestRateStrategy: DEFAULT_INTEREST_RATE_STRATEGY,
            configEngine: CONFIG_ENGINE
        });
    }

    /// @notice Convenience accessor for the pool configurator on this chain.
    /// @return Configurator address (explicit or from provider).
    function getPoolConfigurator() internal view returns (address) {
        return NetworkConfig.getPoolConfigurator(getAddresses());
    }
}
