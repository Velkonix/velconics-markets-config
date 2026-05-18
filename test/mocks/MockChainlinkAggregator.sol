// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AggregatorInterface} from "lib/velkonix-contracts/src/contracts/dependencies/chainlink/AggregatorInterface.sol";

contract MockChainlinkAggregator is AggregatorInterface {
    uint8 internal immutable dec;
    int256 internal ans;
    uint256 internal updatedAt;
    uint80 internal roundId;

    constructor(uint8 decimals_, int256 initialAnswer) {
        dec = decimals_;
        ans = initialAnswer;
        updatedAt = block.timestamp;
        roundId = 1;
    }

    function setAnswer(int256 newAnswer) external {
        ans = newAnswer;
    }

    function setUpdatedAt(uint256 t) external {
        updatedAt = t;
    }

    function decimals() external view override returns (uint8) {
        return dec;
    }

    function description() external pure override returns (string memory) {
        return "mock";
    }

    function getRoundData(uint80) external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, ans, updatedAt, updatedAt, roundId);
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (roundId, ans, updatedAt, updatedAt, roundId);
    }

    function latestAnswer() external view override returns (int256) {
        return ans;
    }

    function latestTimestamp() external view override returns (uint256) {
        return updatedAt;
    }

    function latestRound() external view override returns (uint256) {
        return uint256(roundId);
    }

    function getAnswer(uint256) external view override returns (int256) {
        return ans;
    }

    function getTimestamp(uint256) external view override returns (uint256) {
        return updatedAt;
    }
}
