// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {K613MegaEth_ConfigureEModes} from "../src/payloads/K613MegaEth_ConfigureEModes.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {EngineFlags} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/EngineFlags.sol";
import {MegaEthMainnet} from "../src/networks/MegaEthMainnet.sol";

/// @title K613MegaEth_ConfigureEModesTest
/// @notice Static checks on the eMode payload shape and engine wiring (no fork).
contract K613MegaEth_ConfigureEModesTest is Test {
    K613MegaEth_ConfigureEModes internal payload;

    address internal constant USDM = 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7;
    address internal constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant WSTETH = 0x601aC63637933D88285A025C685AC4e9a92a98dA;

    function setUp() public {
        payload = new K613MegaEth_ConfigureEModes();
    }

    function test_BindsMegaETHConfigEngine() public view {
        assertEq(address(payload.CONFIG_ENGINE()), MegaEthMainnet.CONFIG_ENGINE, "engine mismatch");
    }

    function test_CreatesTwoEModeCategories() public view {
        IAaveV3ConfigEngine.EModeCategoryUpdate[] memory updates = payload.eModeCategoriesUpdates();
        assertEq(updates.length, 2, "expected 2 categories");

        assertEq(updates[0].eModeCategory, 1);
        assertEq(updates[0].ltv, 93_00);
        assertEq(updates[0].liqThreshold, 95_00);
        assertEq(updates[0].liqBonus, 1_00);
        assertEq(updates[0].label, "ETH correlated");

        assertEq(updates[1].eModeCategory, 2);
        assertEq(updates[1].ltv, 93_00);
        assertEq(updates[1].liqThreshold, 95_00);
        assertEq(updates[1].liqBonus, 1_00);
        assertEq(updates[1].label, "Stablecoins");
    }

    function test_EModeCategoriesAreWellFormed() public view {
        IAaveV3ConfigEngine.EModeCategoryUpdate[] memory updates = payload.eModeCategoriesUpdates();
        for (uint256 i = 0; i < updates.length; i++) {
            assertLe(updates[i].ltv, updates[i].liqThreshold, "ltv > lt");
            assertLe(updates[i].liqThreshold, 10_000, "lt > 100%");
            assertGt(updates[i].liqBonus, 0, "liqBonus zero");
            assertGt(bytes(updates[i].label).length, 0, "empty label");
        }
    }

    function test_AssignsFiveAssets() public view {
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = payload.assetsEModeUpdates();
        assertEq(updates.length, 5, "expected 5 asset assignments");
    }

    function test_EthAssetsInCategoryOne() public view {
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = payload.assetsEModeUpdates();
        (address a0, address a1) = (updates[0].asset, updates[1].asset);
        assertTrue(
            (a0 == WETH && a1 == WSTETH) || (a0 == WSTETH && a1 == WETH), "ETH bucket must contain WETH + wstETH"
        );
        assertEq(updates[0].eModeCategory, 1);
        assertEq(updates[1].eModeCategory, 1);
    }

    function test_StableAssetsInCategoryTwo() public view {
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = payload.assetsEModeUpdates();
        for (uint256 i = 2; i < 5; i++) {
            assertEq(updates[i].eModeCategory, 2, "stable in wrong category");
            address a = updates[i].asset;
            assertTrue(a == USDM || a == USDE || a == USDT0, "unexpected stable asset");
        }
    }

    function test_AllAssignmentsBorrowableAndCollateral() public view {
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = payload.assetsEModeUpdates();
        for (uint256 i = 0; i < updates.length; i++) {
            assertEq(updates[i].borrowable, EngineFlags.ENABLED, "not borrowable");
            assertEq(updates[i].collateral, EngineFlags.ENABLED, "not collateral");
            assertNotEq(updates[i].asset, address(0), "asset zero");
        }
    }

    function test_AssetsAreUnique() public view {
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = payload.assetsEModeUpdates();
        for (uint256 i = 0; i < updates.length; i++) {
            for (uint256 j = i + 1; j < updates.length; j++) {
                assertNotEq(updates[i].asset, updates[j].asset, "duplicate asset");
            }
        }
    }
}
