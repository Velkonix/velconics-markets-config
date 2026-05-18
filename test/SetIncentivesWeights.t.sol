// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {SetIncentivesWeights} from "../script/incentives/SetIncentivesWeights.s.sol";
import {IncentivesConfig} from "../src/incentives/IncentivesConfig.sol";

/// @title SetIncentivesWeightsTest
/// @notice Snapshot tests for the canonical 65/35 weight vector shipped with the mainnet deploy.
/// @dev Guards against bps typos before broadcast. If the canonical distribution changes, these
///      assertions must be updated deliberately.
contract SetIncentivesWeightsTest is Test {
    SetIncentivesWeights internal script;
    IncentivesConfig internal cfg;

    uint256 internal constant EXPECTED_COUNT = 6;
    uint256 internal constant EXPECTED_SUPPLY_SUM = 6500;
    uint256 internal constant EXPECTED_BORROW_SUM = 3500;

    function setUp() public {
        script = new SetIncentivesWeights();
        cfg = new IncentivesConfig(address(this));
    }

    function test_CanonicalWeightsLength() public view {
        IncentivesConfig.AssetWeight[] memory ws = script.canonicalWeights();
        assertEq(ws.length, EXPECTED_COUNT, "expected 6 asset rows");
    }

    function test_CanonicalWeightsSum() public view {
        IncentivesConfig.AssetWeight[] memory ws = script.canonicalWeights();

        uint256 supplySum;
        uint256 borrowSum;
        for (uint256 i = 0; i < ws.length; ++i) {
            supplySum += ws[i].supplyBps;
            borrowSum += ws[i].borrowBps;
        }

        assertEq(supplySum, EXPECTED_SUPPLY_SUM, "supply side must be 6500 bps");
        assertEq(borrowSum, EXPECTED_BORROW_SUM, "borrow side must be 3500 bps");
        assertEq(supplySum + borrowSum, cfg.WEIGHT_BPS(), "total must equal WEIGHT_BPS (10_000)");
    }

    function test_CanonicalWeightsNoZeroAssetOrDuplicates() public view {
        IncentivesConfig.AssetWeight[] memory ws = script.canonicalWeights();

        for (uint256 i = 0; i < ws.length; ++i) {
            assertTrue(ws[i].asset != address(0), "asset address cannot be zero");
            for (uint256 j = 0; j < i; ++j) {
                assertTrue(ws[i].asset != ws[j].asset, "duplicate asset in canonical vector");
            }
        }
    }

    function test_CanonicalWeightsAcceptedByIncentivesConfig() public {
        IncentivesConfig.AssetWeight[] memory ws = script.canonicalWeights();
        cfg.setWeights(ws);

        assertEq(cfg.weightCount(), EXPECTED_COUNT, "all 6 rows stored");

        IncentivesConfig.AssetWeight[] memory stored = cfg.getWeights();
        for (uint256 i = 0; i < stored.length; ++i) {
            assertEq(stored[i].asset, ws[i].asset, "asset order preserved");
            assertEq(stored[i].supplyBps, ws[i].supplyBps, "supplyBps preserved");
            assertEq(stored[i].borrowBps, ws[i].borrowBps, "borrowBps preserved");
        }
    }

    function test_CanonicalWeightsPerAssetShares() public view {
        IncentivesConfig.AssetWeight[] memory ws = script.canonicalWeights();

        // Anchor a few per-row expectations so a single-row swap fails loudly.
        assertEq(ws[0].supplyBps, 1700, "USDm supply");
        assertEq(ws[0].borrowBps, 900, "USDm borrow");
        assertEq(ws[3].supplyBps, 1200, "BTC.b supply");
        assertEq(ws[3].borrowBps, 600, "BTC.b borrow");
        assertEq(ws[5].supplyBps, 800, "WETH supply");
        assertEq(ws[5].borrowBps, 500, "WETH borrow");
    }
}
