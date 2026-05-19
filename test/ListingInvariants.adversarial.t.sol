// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {VelkonixMegaEth_InitialListing} from "../src/payloads/VelkonixMegaEth_InitialListing.sol";
import {VelkonixMegaEth_ConfigureEModes} from "../src/payloads/VelkonixMegaEth_ConfigureEModes.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {EngineFlags} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/EngineFlags.sol";

/// @title ListingInvariantsAdversarialTest
/// @notice Hard invariant checks on listing parameters that, if violated, would cause
///         liquidation insolvency, oracle misuse, or broken rate strategies on-chain.
contract ListingInvariantsAdversarialTest is Test {
    VelkonixMegaEth_InitialListing internal listing;
    VelkonixMegaEth_ConfigureEModes internal emodes;

    function setUp() public {
        listing = new VelkonixMegaEth_InitialListing();
        emodes = new VelkonixMegaEth_ConfigureEModes();
    }

    // ───────── Liquidation solvency ─────────

    /// @dev CRITICAL: liqThreshold + liqBonus must be <= 100_00.
    ///      If LT + bonus > 100%, liquidator receives more than 100% of collateral value —
    ///      the protocol pays the difference → insolvency.
    function test_LiqBonusDoesNotExceedSafetyBuffer() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            uint256 lt = listings[i].liqThreshold;
            uint256 bonus = listings[i].liqBonus;
            assertTrue(lt + bonus <= 10_000, string.concat("INSOLVENCY: LT+bonus>100% for ", listings[i].assetSymbol));
        }
    }

    /// @dev Liquidation bonus must be > 0, otherwise no incentive to liquidate.
    function test_LiqBonusIsPositive() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertGt(listings[i].liqBonus, 0, "zero liqBonus: no liquidation incentive");
        }
    }

    /// @dev LTV must be strictly less than liqThreshold.
    ///      If LTV >= LT, a position can be opened and immediately liquidated.
    function test_LtvStrictlyLessThanLiqThreshold() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertLt(
                listings[i].ltv,
                listings[i].liqThreshold,
                string.concat("LTV >= LT: instant liquidation for ", listings[i].assetSymbol)
            );
        }
    }

    // ───────── Rate strategy sanity ─────────

    /// @dev slope2 must be > slope1. slope2 is the penalty above optimal utilization.
    ///      If slope2 <= slope1, there's no additional cost for exceeding optimal usage →
    ///      rates don't spike to discourage over-borrowing.
    function test_Slope2GreaterThanSlope1() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            IAaveV3ConfigEngine.InterestRateInputData memory r = listings[i].rateStrategyParams;
            assertGt(
                r.variableRateSlope2,
                r.variableRateSlope1,
                string.concat("slope2 <= slope1: no penalty curve for ", listings[i].assetSymbol)
            );
        }
    }

    /// @dev optimalUsageRatio must be between 1% and 99%.
    ///      0% means instant penalty; 100% means penalty never kicks in.
    function test_OptimalUsageInSaneRange() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            uint256 opt = listings[i].rateStrategyParams.optimalUsageRatio;
            assertGt(opt, 1_00, "optimal usage < 1%: penalty too aggressive");
            assertLt(opt, 100_00, "optimal usage = 100%: penalty never triggers");
        }
    }

    /// @dev Stablecoin optimal usage should be high (>= 80%). Low optimal makes stables
    ///      expensive to borrow, defeating their purpose as the primary borrowing asset.
    function test_StablecoinOptimalUsageHigh() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        // First 3 listings are stablecoins (USDm, USDe, USDT0)
        for (uint256 i = 0; i < 3; i++) {
            assertGe(
                listings[i].rateStrategyParams.optimalUsageRatio,
                80_00,
                string.concat("stablecoin optimal < 80%: ", listings[i].assetSymbol)
            );
        }
    }

    /// @dev Blue-chip asset optimal usage should be moderate (<= 80%).
    ///      High optimal for blue-chips means rates stay low even at high utilization — risky.
    function test_BlueChipOptimalUsageModerate() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        // Listings 3-5 are blue-chip: BTC.b, wstETH, WETH
        for (uint256 i = 3; i < listings.length; i++) {
            assertLe(
                listings[i].rateStrategyParams.optimalUsageRatio,
                80_00,
                string.concat("blue-chip optimal > 80%: ", listings[i].assetSymbol)
            );
        }
    }

    // ───────── Supply/Borrow cap logic ─────────

    /// @dev borrowCap <= supplyCap for every asset. You can't borrow more than exists.
    function test_BorrowCapNeverExceedsSupplyCap() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertLe(
                listings[i].borrowCap,
                listings[i].supplyCap,
                string.concat("borrowCap > supplyCap: ", listings[i].assetSymbol)
            );
        }
    }

    /// @dev Reserve factor must be > 0 (protocol earns something) and < 100% (suppliers earn something).
    function test_ReserveFactorBounds() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertGt(listings[i].reserveFactor, 0, "RF = 0: protocol earns nothing");
            assertLt(listings[i].reserveFactor, 100_00, "RF = 100%: suppliers earn nothing");
        }
    }

    // ───────── Stablecoin isolation mode ─────────

    /// @dev All stablecoins must be borrowable in isolation mode. This enables users with
    ///      isolation-mode collateral to borrow stables.
    function test_StablecoinsBorrowableInIsolation() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < 3; i++) {
            assertEq(
                listings[i].borrowableInIsolation,
                EngineFlags.ENABLED,
                string.concat("stablecoin not borrowable in isolation: ", listings[i].assetSymbol)
            );
        }
    }

    /// @dev Non-stables must NOT be borrowable in isolation — too volatile for isolation mode.
    function test_NonStablesNotBorrowableInIsolation() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 3; i < listings.length; i++) {
            assertEq(
                listings[i].borrowableInIsolation,
                EngineFlags.DISABLED,
                string.concat("non-stable borrowable in isolation: ", listings[i].assetSymbol)
            );
        }
    }

    // ───────── eMode safety invariants ─────────

    /// @dev eMode LT + liqBonus must be <= 100_00 (same insolvency check as base listings).
    function test_EModeLiqBonusSolvency() public view {
        IAaveV3ConfigEngine.EModeCategoryUpdate[] memory cats = emodes.eModeCategoriesUpdates();
        for (uint256 i = 0; i < cats.length; i++) {
            assertTrue(cats[i].liqThreshold + cats[i].liqBonus <= 10_000, "INSOLVENCY: eMode LT+bonus > 100%");
        }
    }

    /// @dev eMode must raise LTV and LT vs base listing — that's the whole point.
    ///      If eMode is worse than base, users get nothing from opting in.
    function test_EModeImprovesBothLtvAndLt() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        IAaveV3ConfigEngine.EModeCategoryUpdate[] memory cats = emodes.eModeCategoriesUpdates();
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = emodes.assetsEModeUpdates();

        for (uint256 i = 0; i < updates.length; i++) {
            // Find base listing
            uint256 baseLtv;
            uint256 baseLt;
            bool found;
            for (uint256 j = 0; j < listings.length; j++) {
                if (listings[j].asset == updates[i].asset) {
                    baseLtv = listings[j].ltv;
                    baseLt = listings[j].liqThreshold;
                    found = true;
                    break;
                }
            }
            assertTrue(found, "eMode asset missing from listings");

            // Find eMode category
            for (uint256 k = 0; k < cats.length; k++) {
                if (cats[k].eModeCategory == updates[i].eModeCategory) {
                    assertGt(cats[k].ltv, baseLtv, "eMode LTV not better than base");
                    assertGt(cats[k].liqThreshold, baseLt, "eMode LT not better than base");
                    break;
                }
            }
        }
    }

    /// @dev No asset should appear in more than one eMode category.
    ///      If it does, the last write wins on-chain and the first is silently overwritten.
    function test_NoAssetInMultipleEModes() public view {
        IAaveV3ConfigEngine.AssetEModeUpdate[] memory updates = emodes.assetsEModeUpdates();
        for (uint256 i = 0; i < updates.length; i++) {
            for (uint256 j = i + 1; j < updates.length; j++) {
                if (updates[i].asset == updates[j].asset) {
                    assertEq(updates[i].eModeCategory, updates[j].eModeCategory, "asset in multiple eMode categories");
                }
            }
        }
    }

    // ───────── Flash loan / siloed sanity ─────────

    /// @dev All assets are flashloanable. If any isn't, flash-loan-based liquidations fail.
    function test_AllAssetsFlashloanable() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertEq(
                listings[i].flashloanable,
                EngineFlags.ENABLED,
                string.concat("not flashloanable: ", listings[i].assetSymbol)
            );
        }
    }

    /// @dev No asset uses siloed borrowing at launch.
    function test_NoSiloedBorrowingAtLaunch() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertEq(
                listings[i].withSiloedBorrowing,
                EngineFlags.DISABLED,
                string.concat("unexpected siloed: ", listings[i].assetSymbol)
            );
        }
    }

    /// @dev liqProtocolFee = 10_00 (10%) for all assets. Inconsistency would mean some
    ///      liquidations generate different protocol revenue — likely a copy-paste bug.
    function test_UniformLiqProtocolFee() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertEq(
                listings[i].liqProtocolFee,
                10_00,
                string.concat("non-uniform liqProtocolFee: ", listings[i].assetSymbol)
            );
        }
    }

    // ───────── Address sanity ─────────

    /// @dev No two assets share the same address (copy-paste protection).
    function test_AllAssetAddressesUnique() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            for (uint256 j = i + 1; j < listings.length; j++) {
                assertNotEq(listings[i].asset, listings[j].asset, "duplicate asset address");
            }
        }
    }

    /// @dev No feed address equals any asset address (wiring mistake).
    function test_FeedNotEqualToAsset() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertNotEq(
                listings[i].priceFeed, listings[i].asset, string.concat("feed == asset: ", listings[i].assetSymbol)
            );
        }
    }

    /// @dev No address is the zero address.
    function test_NoZeroAddresses() public view {
        IAaveV3ConfigEngine.Listing[] memory listings = listing.newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            assertNotEq(listings[i].asset, address(0), "zero asset");
            assertNotEq(listings[i].priceFeed, address(0), "zero feed");
        }
    }
}
