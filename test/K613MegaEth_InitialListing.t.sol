// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {K613MegaEth_InitialListing} from "../src/payloads/K613MegaEth_InitialListing.sol";
import {K613PayloadMegaEth} from "../src/payloads/K613PayloadMegaEth.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {EngineFlags} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/EngineFlags.sol";
import {MegaEthMainnet} from "../src/networks/MegaEthMainnet.sol";

/// @title K613MegaEth_InitialListingTest
/// @notice Verifies the declarative `Listing[]` produced by the initial MegaETH payload.
contract K613MegaEth_InitialListingTest is Test {
    K613MegaEth_InitialListing internal payload;

    function setUp() public {
        payload = new K613MegaEth_InitialListing();
    }

    function test_BindsMegaETHConfigEngine() public view {
        assertEq(address(payload.CONFIG_ENGINE()), MegaEthMainnet.CONFIG_ENGINE, "engine mismatch");
    }

    function test_PoolContextIsMegaETH() public view {
        IAaveV3ConfigEngine.PoolContext memory ctx = payload.getPoolContext();
        assertEq(ctx.networkName, "MegaETH");
        assertEq(ctx.networkAbbreviation, "Mega");
    }

    function test_ListsSixAssets() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = payload.newListings();
        assertEq(listings.length, 6, "expected 6 reserves");
    }

    function test_EveryListingWellFormed() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = payload.newListings();

        for (uint256 i = 0; i < listings.length; i++) {
            IAaveV3ConfigEngine.Listing memory l = listings[i];

            assertNotEq(l.asset, address(0), "asset zero");
            assertNotEq(l.priceFeed, address(0), "feed zero");
            assertGt(bytes(l.assetSymbol).length, 0, "empty symbol");

            assertGt(l.rateStrategyParams.optimalUsageRatio, 0, "optimal usage zero");
            assertGt(l.rateStrategyParams.variableRateSlope1, 0, "slope1 zero");
            assertGt(l.rateStrategyParams.variableRateSlope2, 0, "slope2 zero");

            assertEq(l.enabledToBorrow, EngineFlags.ENABLED, "borrow disabled");
            assertEq(l.flashloanable, EngineFlags.ENABLED, "flashloan disabled");

            assertLe(l.ltv, 10_000, "ltv > 100%");
            assertLe(l.liqThreshold, 10_000, "lt > 100%");
            assertLe(l.ltv, l.liqThreshold, "ltv > lt");
            assertGt(l.liqBonus, 0, "liqBonus zero");
            assertLe(l.reserveFactor, 10_000, "rf > 100%");

            assertGt(l.supplyCap, 0, "supplyCap zero");
            assertGt(l.borrowCap, 0, "borrowCap zero");
            assertGe(l.supplyCap, l.borrowCap, "supply < borrow");
        }
    }

    function test_AssetsAreUnique() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = payload.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            for (uint256 j = i + 1; j < listings.length; j++) {
                assertNotEq(listings[i].asset, listings[j].asset, "duplicate asset");
            }
        }
    }
}
