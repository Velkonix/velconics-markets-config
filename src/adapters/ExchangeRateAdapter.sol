// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AggregatorInterface} from "lib/velkonix-contracts/src/contracts/dependencies/chainlink/AggregatorInterface.sol";

/// @title ExchangeRateAdapter
/// @notice Combines a token/MON exchange rate feed with MON/USD price feed
///         to produce a token/USD price compatible with AaveOracle.
/// @dev price = (exchangeRate × monUsdPrice) / 10^exchangeRateDecimals
contract ExchangeRateAdapter is AggregatorInterface {
    error ZeroExchangeRateFeed();
    error ZeroMonUsdFeed();

    address private constant ZERO_ADDRESS = address(0);
    int256 private constant ZERO_PRICE = 0;
    uint80 private constant STATIC_ROUND_ID = 1;

    AggregatorInterface public immutable exchangeRateFeed;
    AggregatorInterface public immutable monUsdFeed;
    uint8 private immutable _decimals;
    string private _description;

    /// @notice Deploys adapter for token/MON and MON/USD feeds.
    /// @param _exchangeRateFeed Chainlink-style feed returning the asset per MON unit.
    /// @param _monUsdFeed Chainlink-style MON/USD price feed.
    /// @param description_ Human-readable adapter description for tooling.

    constructor(address _exchangeRateFeed, address _monUsdFeed, string memory description_) {
        if (_exchangeRateFeed == ZERO_ADDRESS) revert ZeroExchangeRateFeed();
        if (_monUsdFeed == ZERO_ADDRESS) revert ZeroMonUsdFeed();
        exchangeRateFeed = AggregatorInterface(_exchangeRateFeed);
        monUsdFeed = AggregatorInterface(_monUsdFeed);
        _description = description_;
        _decimals = monUsdFeed.decimals();
    }

    /// @notice Returns decimals of the resulting token/USD answer.
    /// @return Adapter decimals.
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /// @notice Returns adapter description string.
    /// @return Adapter description.
    function description() external view override returns (string memory) {
        return _description;
    }

    /// @notice Returns token/USD = exchangeRate × MON/USD / exchangeRateDecimals
    /// @return Computed token/USD answer, or zero if any source answer is non-positive.
    function latestAnswer() external view override returns (int256) {
        int256 rate = exchangeRateFeed.latestAnswer();
        int256 monPrice = monUsdFeed.latestAnswer();
        if (rate <= ZERO_PRICE || monPrice <= ZERO_PRICE) return ZERO_PRICE;

        uint8 rateDecimals = exchangeRateFeed.decimals();
        return (rate * monPrice) / int256(10 ** uint256(rateDecimals));
    }

    /// @notice Returns latest round data composed from both source feeds.
    /// @return roundId Static round identifier.
    /// @return answer Computed token/USD answer, or zero if any source answer is non-positive.
    /// @return startedAt Earliest update timestamp among both feeds.
    /// @return updatedAt Earliest update timestamp among both feeds.
    /// @return answeredInRound Static round identifier.
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (, int256 rate,, uint256 rateUpdatedAt,) = exchangeRateFeed.latestRoundData();
        (, int256 monPrice,, uint256 monUpdatedAt,) = monUsdFeed.latestRoundData();

        int256 price = ZERO_PRICE;
        if (rate > ZERO_PRICE && monPrice > ZERO_PRICE) {
            uint8 rateDecimals = exchangeRateFeed.decimals();
            price = (rate * monPrice) / int256(10 ** uint256(rateDecimals));
        }

        uint256 oldestUpdate = rateUpdatedAt < monUpdatedAt ? rateUpdatedAt : monUpdatedAt;
        return (STATIC_ROUND_ID, price, oldestUpdate, oldestUpdate, STATIC_ROUND_ID);
    }

    /// @notice Returns round data for compatibility with legacy consumers.
    /// @return roundId Static round identifier.
    /// @return answer Computed token/USD answer.
    /// @return startedAt Earliest update timestamp among both feeds.
    /// @return updatedAt Earliest update timestamp among both feeds.
    /// @return answeredInRound Static round identifier.
    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return this.latestRoundData();
    }

    /// @notice Returns latest timestamp across source feeds.
    /// @return Earliest update timestamp among both feeds.
    function latestTimestamp() external view override returns (uint256) {
        (,,, uint256 rateUpdatedAt,) = exchangeRateFeed.latestRoundData();
        (,,, uint256 monUpdatedAt,) = monUsdFeed.latestRoundData();
        return rateUpdatedAt < monUpdatedAt ? rateUpdatedAt : monUpdatedAt;
    }

    /// @notice Returns static round id for compatibility.
    /// @return Static round identifier.
    function latestRound() external view override returns (uint256) {
        return uint256(STATIC_ROUND_ID);
    }

    /// @notice Returns latest token/USD answer.
    /// @return Computed token/USD answer.
    function getAnswer(uint256) external view override returns (int256) {
        return this.latestAnswer();
    }

    /// @notice Returns latest token/USD timestamp.
    /// @return Earliest update timestamp among both feeds.
    function getTimestamp(uint256) external view override returns (uint256) {
        return this.latestTimestamp();
    }
}
