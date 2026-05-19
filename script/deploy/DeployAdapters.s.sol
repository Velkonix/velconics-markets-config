// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ExchangeRateAdapter} from "../../src/adapters/ExchangeRateAdapter.sol";
import {StaticRewardPriceFeed} from "../../src/incentives/StaticRewardPriceFeed.sol";

/// @title DeployAdapters
/// @notice Deploys the price-feed adapters required by the MegaETH listing.
/// @dev The Velkonix market AaveOracle is 8-decimal. USDe, USDm and wstETH only have
///      18-decimal Chainlink feeds on MegaETH. `ExchangeRateAdapter` computes
///      `(feedA × feedB) / 10^feedA.decimals` and reports `feedB.decimals()`. Passing the
///      18-dec source as `feedA` and a constant `1.0 @ 8 decimals` feed as `feedB` yields
///      `source / 1e10` reported at 8 decimals — i.e. a clean 18 → 8 re-scale, reusing the
///      existing adapter. One shared unity feed is deployed and reused for all three.
///      After broadcast, copy each printed adapter address into the matching
///      `*_FEED_PENDING` constant in `VelkonixMegaEth_InitialListing`.
contract DeployAdapters is Script {
    // 18-decimal MegaETH Chainlink source feeds.
    address internal constant USDM_USD_SRC = 0xdFe0063491d9DeD8F8abCdd7AE04238A1e70D270;
    address internal constant USDE_USD_SRC = 0x4F2A91150D5D6B91B5F0b0DF6F109C4BCeCefA61;
    address internal constant WSTETH_USD_SRC = 0xF2E02bfB172757471d091C6Fc66039020d29Eb26;

    int256 internal constant UNITY_8DEC = 1e8; // 1.0 at 8 decimals
    uint8 internal constant TARGET_DECIMALS = 8;

    function run() external {
        vm.startBroadcast();

        // feedB: constant 1.0 at 8 decimals. Drives adapter output decimals to 8 without
        // changing the value (out = src * 1e8 / 1e18 = src / 1e10).
        StaticRewardPriceFeed unity = new StaticRewardPriceFeed(UNITY_8DEC, TARGET_DECIMALS, "ONE / USD (8d)");
        console.log("Unity feed:        ", address(unity));

        ExchangeRateAdapter usdmAdapter = new ExchangeRateAdapter(USDM_USD_SRC, address(unity), "USDm / USD (8d)");
        console.log("USDm/USD adapter:  ", address(usdmAdapter));

        ExchangeRateAdapter usdeAdapter = new ExchangeRateAdapter(USDE_USD_SRC, address(unity), "USDe / USD (8d)");
        console.log("USDe/USD adapter:  ", address(usdeAdapter));

        ExchangeRateAdapter wstEthAdapter = new ExchangeRateAdapter(WSTETH_USD_SRC, address(unity), "wstETH / USD (8d)");
        console.log("wstETH/USD adapter:", address(wstEthAdapter));

        vm.stopBroadcast();

        console.log("\n=== Update VelkonixMegaEth_InitialListing priceFeed placeholders ===");
        console.log("USDM_FEED_PENDING   ->", address(usdmAdapter));
        console.log("USDE_FEED_PENDING   ->", address(usdeAdapter));
        console.log("WSTETH_FEED_PENDING ->", address(wstEthAdapter));
    }
}
