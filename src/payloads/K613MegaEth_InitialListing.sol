// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {K613PayloadMegaEth} from "./K613PayloadMegaEth.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {EngineFlags} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/EngineFlags.sol";

/// @title K613MegaEth_InitialListing
/// @notice One-shot payload that lists the 6 canonical MegaETH mainnet reserves via the config engine.
/// @dev Risk profiles follow the canonical stablecoin / blue-chip curves. Per-asset LTV/LT and
///      supply/borrow caps come from the MegaETH listing sheet.
///
///      Price feeds are MegaETH Chainlink aggregators. The market AaveOracle is 8-decimal,
///      so only 8-decimal Chainlink feeds can be wired directly:
///        WETH  → ETH/USD  (8 dec)   USDT0 → USDT/USD (8 dec)   BTC.b → BTC/USD (8 dec)
///      USDe / USDm / wstETH only have 18-decimal Chainlink feeds on MegaETH. They are
///      priced through an `ExchangeRateAdapter(src18d, unity8d)` (re-scales 18 → 8 dec)
///      deployed by `script/deploy/DeployAdapters.s.sol`; their `*_FEED_PENDING`
///      placeholders MUST be replaced with the deployed adapter addresses before
///      broadcast. The 18-dec source feed for each is recorded in the `*_USD_SRC` below.
///      `hasPendingPriceFeeds()` returns true while any placeholder remains.
contract K613MegaEth_InitialListing is K613PayloadMegaEth {
    // ───────── Stablecoins ─────────
    address internal constant USDM = 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7;
    // USDM/USD Chainlink feed is 18-dec → priced via ExchangeRateAdapter(USDM_USD_SRC, unity8d).
    address internal constant USDM_USD_SRC = 0xdFe0063491d9DeD8F8abCdd7AE04238A1e70D270;
    address internal constant USDM_FEED_PENDING = 0x0000000000000000000000000000000000000001;

    address internal constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    // USDE/USD Chainlink feed is 18-dec → priced via ExchangeRateAdapter(USDE_USD_SRC, unity8d).
    address internal constant USDE_USD_SRC = 0x4F2A91150D5D6B91B5F0b0DF6F109C4BCeCefA61;
    address internal constant USDE_FEED_PENDING = 0x0000000000000000000000000000000000000002;

    address internal constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    // USDT0 (USDT OFT, 1:1) priced via the 8-dec USDT/USD Chainlink feed.
    address internal constant USDT0_FEED = 0xA533f4164d8d9F8C3995FC83F2f022a622d1765D;

    // ───────── Blue-chip collateral ─────────
    address internal constant BTCB = 0xB0F70C0bD6FD87dbEb7C10dC692a2a6106817072;
    // BTC.b tracks BTC; priced via the 8-dec BTC/USD Chainlink feed.
    address internal constant BTCB_FEED = 0xc6E3007B597f6F5a6330d43053D1EF73cCbbE721;

    address internal constant WSTETH = 0x601aC63637933D88285A025C685AC4e9a92a98dA;
    // wstETH/USD Calculated Chainlink feed is 18-dec → priced via ExchangeRateAdapter(WSTETH_USD_SRC, unity8d).
    address internal constant WSTETH_USD_SRC = 0xF2E02bfB172757471d091C6Fc66039020d29Eb26;
    address internal constant WSTETH_FEED_PENDING = 0x0000000000000000000000000000000000000003;

    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    // Network base-token ETH/USD aggregator (8 decimals), from the core deployment market config.
    address internal constant WETH_FEED = 0xcA4e254D95637DE95E2a2F79244b03380d697feD;

    /// @notice Declares the full initial reserve listing batch for MegaETH mainnet.
    /// @return listings Six `Listing` structs with feeds, caps, and risk parameters.
    function newListings() public pure override returns (IAaveV3ConfigEngine.Listing[] memory listings) {
        listings = new IAaveV3ConfigEngine.Listing[](6);

        listings[0] = _stablecoin(USDM, "USDm", USDM_FEED_PENDING, 35_000_000, 40_000_000);
        listings[1] = _stablecoin(USDE, "USDe", USDE_FEED_PENDING, 25_000_000, 30_000_000);
        listings[2] = _stablecoin(USDT0, "USDT0", USDT0_FEED, 8_000_000, 10_000_000);

        listings[3] = _btc(BTCB, "BTC.b", BTCB_FEED, 15, 20);
        listings[4] = _wstEth(WSTETH, "wstETH", WSTETH_FEED_PENDING, 2_500, 3_000);
        listings[5] = _weth(WETH, "WETH", WETH_FEED, 3_500, 4_000);
    }

    /// @notice True while any reserve still points at a placeholder price feed.
    /// @dev Guard for tooling/tests: must be `false` before this payload is broadcast.
    /// @return pending Whether unresolved `*_FEED_PENDING` feeds remain in the listing.
    function hasPendingPriceFeeds() external pure returns (bool pending) {
        IAaveV3ConfigEngine.Listing[] memory listings = newListings();
        for (uint256 i = 0; i < listings.length; i++) {
            // Placeholder sentinels occupy the low address space (0x01..0x03):
            // USDm / USDe / wstETH, pending their ExchangeRateAdapter deployment.
            if (uint160(listings[i].priceFeed) <= 0x03) return true;
        }
        return false;
    }

    /// @dev Stablecoin rate curve: low base (1%), gentle slope, steep penalty past optimal.
    function _stableRate() private pure returns (IAaveV3ConfigEngine.InterestRateInputData memory) {
        return IAaveV3ConfigEngine.InterestRateInputData({
            optimalUsageRatio: 90_00, baseVariableBorrowRate: 1_00, variableRateSlope1: 4_00, variableRateSlope2: 75_00
        });
    }

    /// @dev Blue-chip rate curve (WETH, wstETH, BTC.b): low base, moderate slopes.
    function _blueChipRate() private pure returns (IAaveV3ConfigEngine.InterestRateInputData memory) {
        return IAaveV3ConfigEngine.InterestRateInputData({
            optimalUsageRatio: 80_00, baseVariableBorrowRate: 1_00, variableRateSlope1: 3_50, variableRateSlope2: 80_00
        });
    }

    /// @dev Assembles a `Listing` from risk inputs and a rate strategy for this payload.
    function _build(
        address asset,
        string memory symbol,
        address feed,
        uint256 borrowCap,
        uint256 supplyCap,
        uint256 ltv,
        uint256 liqThreshold,
        uint256 liqBonus,
        uint256 reserveFactor,
        uint256 borrowableInIsolation,
        IAaveV3ConfigEngine.InterestRateInputData memory rate
    ) private pure returns (IAaveV3ConfigEngine.Listing memory) {
        return IAaveV3ConfigEngine.Listing({
            asset: asset,
            assetSymbol: symbol,
            priceFeed: feed,
            rateStrategyParams: rate,
            enabledToBorrow: EngineFlags.ENABLED,
            borrowableInIsolation: borrowableInIsolation,
            withSiloedBorrowing: EngineFlags.DISABLED,
            flashloanable: EngineFlags.ENABLED,
            ltv: ltv,
            liqThreshold: liqThreshold,
            liqBonus: liqBonus,
            reserveFactor: reserveFactor,
            supplyCap: supplyCap,
            borrowCap: borrowCap,
            debtCeiling: 0,
            liqProtocolFee: 10_00
        });
    }

    /// @dev Stablecoin profile: LTV 80%, LT 83%, liquidation bonus 5%, reserve factor 25%, isolation borrow on.
    function _stablecoin(address asset, string memory symbol, address feed, uint256 borrowCap, uint256 supplyCap)
        private
        pure
        returns (IAaveV3ConfigEngine.Listing memory)
    {
        return _build(
            asset, symbol, feed, borrowCap, supplyCap, 80_00, 83_00, 5_00, 25_00, EngineFlags.ENABLED, _stableRate()
        );
    }

    /// @dev BTC.b profile: LTV 68%, LT 73%, liquidation bonus 7%, reserve factor 25%.
    function _btc(address asset, string memory symbol, address feed, uint256 borrowCap, uint256 supplyCap)
        private
        pure
        returns (IAaveV3ConfigEngine.Listing memory)
    {
        return _build(
            asset, symbol, feed, borrowCap, supplyCap, 68_00, 73_00, 7_00, 25_00, EngineFlags.DISABLED, _blueChipRate()
        );
    }

    /// @dev wstETH profile: LTV 75%, LT 79%, liquidation bonus 6%, reserve factor 25% (LST basis risk vs WETH).
    function _wstEth(address asset, string memory symbol, address feed, uint256 borrowCap, uint256 supplyCap)
        private
        pure
        returns (IAaveV3ConfigEngine.Listing memory)
    {
        return _build(
            asset, symbol, feed, borrowCap, supplyCap, 75_00, 79_00, 6_00, 25_00, EngineFlags.DISABLED, _blueChipRate()
        );
    }

    /// @dev WETH profile: LTV 78%, LT 81%, liquidation bonus 6%, reserve factor 25%.
    function _weth(address asset, string memory symbol, address feed, uint256 borrowCap, uint256 supplyCap)
        private
        pure
        returns (IAaveV3ConfigEngine.Listing memory)
    {
        return _build(
            asset, symbol, feed, borrowCap, supplyCap, 78_00, 81_00, 6_00, 25_00, EngineFlags.DISABLED, _blueChipRate()
        );
    }
}
