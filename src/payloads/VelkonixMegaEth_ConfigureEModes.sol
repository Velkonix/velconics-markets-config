// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {VelkonixPayloadMegaEth} from "./VelkonixPayloadMegaEth.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";

/// @title VelkonixMegaEth_ConfigureEModes
/// @notice Creates the ETH-correlated and Stablecoin eMode categories and binds the listed
///         reserves to them (as both collateral and borrowable). Must run AFTER the initial
///         listing — the engine sets per-asset eMode flags, which requires listed reserves.
/// @dev Uses the config-engine **creation** path (`eModeCategoryCreations`), not the update
///      path: on a fresh market the categories don't exist yet, so `updateEModeCategories`
///      would revert `INVALID_UPDATE`. Category ids are auto-assigned to the first unused
///      slots (ETH correlated → 1, Stablecoins → 2 on a fresh market). `liqBonus` is the
///      bonus part only; the engine stores `100_00 + liqBonus` (here 1% → 101_00).
///      BTC.b is intentionally left out of every eMode category.
contract VelkonixMegaEth_ConfigureEModes is VelkonixPayloadMegaEth {
    address internal constant USDM = 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7;
    address internal constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant WSTETH = 0x601aC63637933D88285A025C685AC4e9a92a98dA;

    /// @notice Declares the two eMode categories with their collateral/borrowable members.
    /// @return creations Category creation rows passed to the config engine.
    function eModeCategoryCreations()
        public
        pure
        override
        returns (IAaveV3ConfigEngine.EModeCategoryCreation[] memory creations)
    {
        creations = new IAaveV3ConfigEngine.EModeCategoryCreation[](2);

        // Category 1 — ETH correlated: WETH, wstETH (collateral + borrowable).
        address[] memory ethAssets = new address[](2);
        ethAssets[0] = WETH;
        ethAssets[1] = WSTETH;
        creations[0] = IAaveV3ConfigEngine.EModeCategoryCreation({
            ltv: 93_00,
            liqThreshold: 95_00,
            liqBonus: 1_00,
            label: "ETH correlated",
            borrowables: ethAssets,
            collaterals: ethAssets
        });

        // Category 2 — Stablecoins: USDm, USDe, USDT0 (collateral + borrowable).
        address[] memory stableAssets = new address[](3);
        stableAssets[0] = USDM;
        stableAssets[1] = USDE;
        stableAssets[2] = USDT0;
        creations[1] = IAaveV3ConfigEngine.EModeCategoryCreation({
            ltv: 93_00,
            liqThreshold: 95_00,
            liqBonus: 1_00,
            label: "Stablecoins",
            borrowables: stableAssets,
            collaterals: stableAssets
        });
    }
}
