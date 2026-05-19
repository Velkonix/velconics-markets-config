// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {VelkonixMegaEth_ConfigureEModes} from "../src/payloads/VelkonixMegaEth_ConfigureEModes.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {MegaEthMainnet} from "../src/networks/MegaEthMainnet.sol";

/// @title VelkonixMegaEth_ConfigureEModesTest
/// @notice Static checks on the eMode creation payload shape and engine wiring (no fork).
/// @dev The payload uses the config-engine creation path (`eModeCategoryCreations`), not the
///      update path — on a fresh market the categories do not exist yet.
contract VelkonixMegaEth_ConfigureEModesTest is Test {
    VelkonixMegaEth_ConfigureEModes internal payload;

    address internal constant USDM = 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7;
    address internal constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address internal constant BTCB = 0xB0F70C0bD6FD87dbEb7C10dC692a2a6106817072;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant WSTETH = 0x601aC63637933D88285A025C685AC4e9a92a98dA;

    function setUp() public {
        payload = new VelkonixMegaEth_ConfigureEModes();
    }

    function test_BindsMegaETHConfigEngine() public view {
        assertEq(address(payload.CONFIG_ENGINE()), MegaEthMainnet.CONFIG_ENGINE, "engine mismatch");
    }

    function test_UsesCreationNotUpdatePath() public view {
        // Creation path is populated; the update / asset-update hooks stay empty so the
        // base payload dispatches to `createEModeCategories` (not `updateEModeCategories`).
        assertEq(payload.eModeCategoryCreations().length, 2, "expected 2 category creations");
        assertEq(payload.eModeCategoriesUpdates().length, 0, "update hook must be empty");
        assertEq(payload.assetsEModeUpdates().length, 0, "asset-update hook must be empty");
    }

    function test_CreatesTwoEModeCategories() public view {
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory c = payload.eModeCategoryCreations();
        assertEq(c.length, 2, "expected 2 categories");

        assertEq(c[0].ltv, 93_00);
        assertEq(c[0].liqThreshold, 95_00);
        assertEq(c[0].liqBonus, 1_00);
        assertEq(c[0].label, "ETH correlated");

        assertEq(c[1].ltv, 93_00);
        assertEq(c[1].liqThreshold, 95_00);
        assertEq(c[1].liqBonus, 1_00);
        assertEq(c[1].label, "Stablecoins");
    }

    function test_EModeCategoriesAreWellFormed() public view {
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory c = payload.eModeCategoryCreations();
        for (uint256 i = 0; i < c.length; i++) {
            assertLe(c[i].ltv, c[i].liqThreshold, "ltv > lt");
            assertLe(c[i].liqThreshold, 10_000, "lt > 100%");
            assertGt(c[i].liqBonus, 0, "liqBonus zero");
            assertLt(c[i].liqBonus, 10_000, "liqBonus >= 100% (engine adds 100_00)");
            assertGt(bytes(c[i].label).length, 0, "empty label");
            assertGt(c[i].collaterals.length, 0, "no collaterals");
            assertGt(c[i].borrowables.length, 0, "no borrowables");
        }
    }

    function test_EthCategoryMembers() public view {
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory c = payload.eModeCategoryCreations();
        assertEq(c[0].collaterals.length, 2, "ETH cat: 2 collaterals");
        assertEq(c[0].borrowables.length, 2, "ETH cat: 2 borrowables");
        assertEq(c[0].collaterals[0], WETH);
        assertEq(c[0].collaterals[1], WSTETH);
        assertEq(c[0].borrowables[0], WETH);
        assertEq(c[0].borrowables[1], WSTETH);
    }

    function test_StableCategoryMembers() public view {
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory c = payload.eModeCategoryCreations();
        assertEq(c[1].collaterals.length, 3, "stable cat: 3 collaterals");
        assertEq(c[1].borrowables.length, 3, "stable cat: 3 borrowables");
        for (uint256 i = 0; i < 3; i++) {
            address a = c[1].collaterals[i];
            assertTrue(a == USDM || a == USDE || a == USDT0, "unexpected stable asset");
            assertEq(c[1].borrowables[i], a, "collateral/borrowable lists must match");
        }
    }

    function test_NoZeroOrDuplicateMembers() public view {
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory c = payload.eModeCategoryCreations();
        for (uint256 k = 0; k < c.length; k++) {
            address[] memory m = c[k].collaterals;
            for (uint256 i = 0; i < m.length; i++) {
                assertNotEq(m[i], address(0), "zero member");
                for (uint256 j = i + 1; j < m.length; j++) {
                    assertNotEq(m[i], m[j], "duplicate member in category");
                }
            }
        }
    }

    function test_BtcbExcludedFromAllCategories() public view {
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory c = payload.eModeCategoryCreations();
        for (uint256 k = 0; k < c.length; k++) {
            for (uint256 i = 0; i < c[k].collaterals.length; i++) {
                assertNotEq(c[k].collaterals[i], BTCB, "BTC.b must not be in any eMode");
            }
            for (uint256 i = 0; i < c[k].borrowables.length; i++) {
                assertNotEq(c[k].borrowables[i], BTCB, "BTC.b must not be in any eMode");
            }
        }
    }
}
