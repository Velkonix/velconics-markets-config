// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AggregatorInterface} from "lib/velkonix-contracts/src/contracts/dependencies/chainlink/AggregatorInterface.sol";

/// @title StaticRewardPriceFeed
/// @notice Minimal `AggregatorInterface` that returns a fixed answer for reward USD pricing.
/// @dev Timestamps track `block.timestamp`; round ids are constant for compatibility with consumers.
contract StaticRewardPriceFeed is AggregatorInterface {
    error ZeroAnswer();

    int256 private immutable fixedAnswer;
    uint8 private immutable dec;
    string private desc;

    /// @notice Deploys a feed with a positive fixed latest answer.
    /// @param fixedLatestAnswer Static price returned by `latestAnswer` / `latestRoundData`.
    /// @param aggregatorDecimals Decimal places reported by `decimals()`.
    /// @param description_ Human-readable feed description.
    constructor(int256 fixedLatestAnswer, uint8 aggregatorDecimals, string memory description_) {
        if (fixedLatestAnswer <= 0) revert ZeroAnswer();
        fixedAnswer = fixedLatestAnswer;
        dec = aggregatorDecimals;
        desc = description_;
    }

    /// @notice Returns configured decimal precision.
    /// @return Feed decimals.
    function decimals() external view override returns (uint8) {
        return dec;
    }

    /// @notice Returns the feed description string.
    /// @return UTF-8 description passed at deployment.
    function description() external view override returns (string memory) {
        return desc;
    }

    /// @notice Returns synthetic round data for compatibility with legacy aggregators; ignores the requested round id.
    /// @return roundId Fixed round identifier.
    /// @return answer Static latest answer.
    /// @return startedAt Block timestamp placeholder.
    /// @return updatedAt Block timestamp placeholder.
    /// @return answeredInRound Round id echo.
    function getRoundData(uint80)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, fixedAnswer, block.timestamp, block.timestamp, 1);
    }

    /// @notice Returns the latest synthetic round with static price and current timestamps.
    /// @return roundId Fixed round identifier.
    /// @return answer Static latest answer.
    /// @return startedAt Block timestamp placeholder.
    /// @return updatedAt Block timestamp placeholder.
    /// @return answeredInRound Round id echo.
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, fixedAnswer, block.timestamp, block.timestamp, 1);
    }

    /// @notice Returns the immutable latest answer.
    /// @return Static price as an int256.
    function latestAnswer() external view override returns (int256) {
        return fixedAnswer;
    }

    /// @notice Returns `block.timestamp` as the latest update time.
    /// @return Current block timestamp.
    function latestTimestamp() external view override returns (uint256) {
        return block.timestamp;
    }

    /// @notice Returns a fixed latest round id for compatibility.
    /// @return Constant round id `1`.
    function latestRound() external view override returns (uint256) {
        return 1;
    }

    /// @notice Ignores round id and returns the fixed answer.
    /// @return Static price as an int256.
    function getAnswer(uint256) external view override returns (int256) {
        return fixedAnswer;
    }

    /// @notice Ignores round id and returns `block.timestamp`.
    /// @return Current block timestamp.
    function getTimestamp(uint256) external view override returns (uint256) {
        return block.timestamp;
    }
}
