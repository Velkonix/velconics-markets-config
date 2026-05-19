// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {StaticRewardPriceFeed} from "../src/incentives/StaticRewardPriceFeed.sol";

contract StaticRewardPriceFeedTest is Test {
    StaticRewardPriceFeed internal feed;

    function setUp() public {
        feed = new StaticRewardPriceFeed(int256(800_000), 8, "Velkonix / USD");
    }

    function test_ConstructorRevertsOnZeroAnswer() public {
        vm.expectRevert(StaticRewardPriceFeed.ZeroAnswer.selector);
        new StaticRewardPriceFeed(0, 8, "x");
    }

    function test_ConstructorRevertsOnNegativeAnswer() public {
        vm.expectRevert(StaticRewardPriceFeed.ZeroAnswer.selector);
        new StaticRewardPriceFeed(-1, 8, "x");
    }

    function test_DecimalsDescription() public view {
        assertEq(feed.decimals(), 8);
        assertEq(feed.description(), "Velkonix / USD");
    }

    function test_LatestAnswer() public view {
        assertEq(feed.latestAnswer(), int256(800_000));
    }

    function test_LatestRoundData() public {
        (uint80 rid, int256 ans, uint256 started, uint256 updated, uint80 answered) = feed.latestRoundData();
        assertEq(rid, 1);
        assertEq(ans, int256(800_000));
        assertEq(started, block.timestamp);
        assertEq(updated, block.timestamp);
        assertEq(answered, 1);
    }

    function test_GetRoundData() public {
        (uint80 rid, int256 ans,, uint256 updated,) = feed.getRoundData(99);
        assertEq(rid, 1);
        assertEq(ans, int256(800_000));
        assertEq(updated, block.timestamp);
    }

    function test_LatestTimestamp_GetTimestamp() public {
        assertEq(feed.latestTimestamp(), block.timestamp);
        assertEq(feed.getTimestamp(123), block.timestamp);
    }

    function test_LatestRound() public view {
        assertEq(feed.latestRound(), 1);
    }

    function test_GetAnswer() public view {
        assertEq(feed.getAnswer(0), int256(800_000));
    }
}
