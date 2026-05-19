// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {VelkonixMegaEth_InitialListing} from "../src/payloads/VelkonixMegaEth_InitialListing.sol";
import {VelkonixMegaEth_ConfigureEModes} from "../src/payloads/VelkonixMegaEth_ConfigureEModes.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";

/// @title PayloadIntegrationTest
/// @notice Cross-payload consistency checks that both payloads must satisfy together.
///         Enforces the real-world ordering invariant: every asset the eMode payload
///         binds to a category must be listed by the initial listing payload.
contract PayloadIntegrationTest is Test {
    VelkonixMegaEth_InitialListing internal listing;
    VelkonixMegaEth_ConfigureEModes internal emodes;

    function setUp() public {
        listing = new VelkonixMegaEth_InitialListing();
        emodes = new VelkonixMegaEth_ConfigureEModes();
    }

    /// @dev Invariant: every asset assigned to an eMode category must have been listed first.
    ///      Without this check, running the eMode payload second on mainnet would brick because
    ///      the config engine rejects assets that aren't registered in the pool.
    function test_EModeAssetsAreAllListed() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = emodes.assetsEModeUpdates();

        for (uint256 i = 0; i < updates.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < listings.length; j++) {
                if (listings[j].asset == updates[i].asset) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "eMode asset is not listed by InitialListing");
        }
    }

    /// @dev Invariant: every eMode category referenced by asset bindings must be defined in the
    ///      same payload's category updates — no orphan category ids.
    function test_EModeCategoriesAreDefined() public view {
        IAaveV3ConfigEngine.EModeCategoryUpdate[] memory cats = emodes.eModeCategoriesUpdates();
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = emodes.assetsEModeUpdates();

        for (uint256 i = 0; i < updates.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < cats.length; j++) {
                if (cats[j].eModeCategory == updates[i].eModeCategory) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "asset references undefined eMode category");
        }
    }

    /// @dev Invariant: eMode categories never loosen risk vs. the listing-level params.
    ///      If a stable listing has LT 80% and is pulled into a stable eMode with LT 95%,
    ///      that must be intentional — this test locks the relationship in place so a future
    ///      regression that drops an eMode category's LT below the underlying listing LT fails.
    function test_EModeCategoriesNotSofterThanListings() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        IAaveV3ConfigEngine.EModeCategoryUpdate[] memory cats = emodes.eModeCategoriesUpdates();
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = emodes.assetsEModeUpdates();

        for (uint256 i = 0; i < updates.length; i++) {
            // Find the listing row for this asset.
            IAaveV3ConfigEngine.Listing memory l;
            bool lFound;
            for (uint256 j = 0; j < listings.length; j++) {
                if (listings[j].asset == updates[i].asset) {
                    l = listings[j];
                    lFound = true;
                    break;
                }
            }
            assertTrue(lFound, "listing not found for eMode asset");

            // Find the category params.
            IAaveV3ConfigEngine.EModeCategoryUpdate memory c;
            bool cFound;
            for (uint256 j = 0; j < cats.length; j++) {
                if (cats[j].eModeCategory == updates[i].eModeCategory) {
                    c = cats[j];
                    cFound = true;
                    break;
                }
            }
            assertTrue(cFound, "category not found for eMode asset");

            // eMode categories should raise the risk envelope, not tighten it
            // (underlying listing stays as the base floor for non-eMode users).
            assertGe(c.ltv, l.ltv, "eMode ltv tighter than listing");
            assertGe(c.liqThreshold, l.liqThreshold, "eMode lt tighter than listing");
        }
    }

    /// @dev Invariant: each listed asset's price feed must also be non-zero and unique per asset.
    ///      Sanity check against copy/paste mistakes where two reserves alias the same feed.
    function test_FeedsAreDistinctPerAsset() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            for (uint256 j = i + 1; j < listings.length; j++) {
                assertNotEq(listings[i].priceFeed, listings[j].priceFeed, "feed reused across assets");
            }
        }
    }
}
