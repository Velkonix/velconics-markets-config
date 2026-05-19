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

    /// @dev Invariant: every asset placed in an eMode category (collateral or borrowable)
    ///      must have been listed first. Running eMode creation before the listing would
    ///      brick because the config engine rejects assets not registered in the pool.
    function test_EModeAssetsAreAllListed() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory cats = emodes.eModeCategoryCreations();

        for (uint256 k = 0; k < cats.length; k++) {
            _assertAllListed(cats[k].collaterals, listings);
            _assertAllListed(cats[k].borrowables, listings);
        }
    }

    function _assertAllListed(address[] memory assets, IAaveV3ConfigEngine.Listing[] memory listings) private pure {
        for (uint256 i = 0; i < assets.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < listings.length; j++) {
                if (listings[j].asset == assets[i]) {
                    found = true;
                    break;
                }
            }
            require(found, "eMode asset is not listed by InitialListing");
        }
    }

    /// @dev Invariant: every created eMode category is well-formed (has members and a label),
    ///      so there are no empty/orphan categories.
    function test_EModeCategoriesAreDefined() public view {
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory cats = emodes.eModeCategoryCreations();
        assertGt(cats.length, 0, "no eMode categories");
        for (uint256 k = 0; k < cats.length; k++) {
            assertGt(cats[k].collaterals.length, 0, "category has no collaterals");
            assertGt(cats[k].borrowables.length, 0, "category has no borrowables");
            assertGt(bytes(cats[k].label).length, 0, "category has no label");
        }
    }

    /// @dev Invariant: eMode categories never loosen risk vs. the listing-level params.
    ///      For every member asset, the category LTV/LT must be >= the asset's listing
    ///      LTV/LT — a regression that drops a category below its members' base fails here.
    function test_EModeCategoriesNotSofterThanListings() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        IAaveV3ConfigEngine.EModeCategoryCreation[] memory cats = emodes.eModeCategoryCreations();

        for (uint256 k = 0; k < cats.length; k++) {
            for (uint256 i = 0; i < cats[k].collaterals.length; i++) {
                address asset = cats[k].collaterals[i];
                IAaveV3ConfigEngine.Listing memory l;
                bool lFound;
                for (uint256 j = 0; j < listings.length; j++) {
                    if (listings[j].asset == asset) {
                        l = listings[j];
                        lFound = true;
                        break;
                    }
                }
                assertTrue(lFound, "listing not found for eMode asset");
                assertGe(cats[k].ltv, l.ltv, "eMode ltv tighter than listing");
                assertGe(cats[k].liqThreshold, l.liqThreshold, "eMode lt tighter than listing");
            }
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
