// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {VelkonixPayloadMegaEth} from "./VelkonixPayloadMegaEth.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {EngineFlags} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/EngineFlags.sol";

/// @title VelkonixMegaEth_ConfigureEModes
/// @notice Introduces ETH-correlated and Stablecoin eMode categories and assigns listed
///         blue-chip reserves to them. Users opting into a category enjoy higher ltv/lt
///         when both collateral and borrow stay inside the category.
/// @dev Category layout:
///        1 — ETH-correlated (WETH, wstETH)
///        2 — Stablecoins (USDm, USDe, USDT0)
///      BTC.b is intentionally left out of every eMode category.
contract VelkonixMegaEth_ConfigureEModes is VelkonixPayloadMegaEth {
    uint8 internal constant EMODE_ETH = 1;
    uint8 internal constant EMODE_STABLE = 2;

    address internal constant USDM = 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7;
    address internal constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant WSTETH = 0x601aC63637933D88285A025C685AC4e9a92a98dA;

    /// @notice Declares the two eMode categories (ETH-correlated and stablecoins) with shared risk params.
    /// @return updates Category rows passed to the config engine.
    function eModeCategoriesUpdates()
        public
        pure
        override
        returns (IAaveV3ConfigEngine.EModeCategoryUpdate[] memory updates)
    {
        updates = new IAaveV3ConfigEngine.EModeCategoryUpdate[](2);
        updates[0] = IAaveV3ConfigEngine.EModeCategoryUpdate({
            eModeCategory: EMODE_ETH, ltv: 93_00, liqThreshold: 95_00, liqBonus: 1_00, label: "ETH correlated"
        });
        updates[1] = IAaveV3ConfigEngine.EModeCategoryUpdate({
            eModeCategory: EMODE_STABLE, ltv: 93_00, liqThreshold: 95_00, liqBonus: 1_00, label: "Stablecoins"
        });
    }

    /// @notice Maps blue-chip assets to the ETH or stable eMode category for this deployment.
    /// @return updates Asset-to-category bindings consumed by the engine.
    function assetsEModeUpdates() public pure override returns (IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates) {
        updates = new IAaveV3ConfigEngine.AssetEModeUpdate[](5);

        updates[0] = IAaveV3ConfigEngine.AssetEModeUpdate({
            asset: WETH, eModeCategory: EMODE_ETH, borrowable: EngineFlags.ENABLED, collateral: EngineFlags.ENABLED
        });
        updates[1] = IAaveV3ConfigEngine.AssetEModeUpdate({
            asset: WSTETH, eModeCategory: EMODE_ETH, borrowable: EngineFlags.ENABLED, collateral: EngineFlags.ENABLED
        });

        updates[2] = IAaveV3ConfigEngine.AssetEModeUpdate({
            asset: USDM, eModeCategory: EMODE_STABLE, borrowable: EngineFlags.ENABLED, collateral: EngineFlags.ENABLED
        });
        updates[3] = IAaveV3ConfigEngine.AssetEModeUpdate({
            asset: USDE, eModeCategory: EMODE_STABLE, borrowable: EngineFlags.ENABLED, collateral: EngineFlags.ENABLED
        });
        updates[4] = IAaveV3ConfigEngine.AssetEModeUpdate({
            asset: USDT0, eModeCategory: EMODE_STABLE, borrowable: EngineFlags.ENABLED, collateral: EngineFlags.ENABLED
        });
    }
}
