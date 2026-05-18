// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IPool} from "lib/velkonix-contracts/src/contracts/interfaces/IPool.sol";
import {DataTypes} from "lib/velkonix-contracts/src/contracts/protocol/libraries/types/DataTypes.sol";
import {IRewardsDistributor} from "lib/velkonix-contracts/src/contracts/rewards/interfaces/IRewardsDistributor.sol";
import {IRewardsController} from "lib/velkonix-contracts/src/contracts/rewards/interfaces/IRewardsController.sol";
import {IERC20} from "lib/velkonix-contracts/src/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {
    IERC20Detailed
} from "lib/velkonix-contracts/src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

/// @title IncentivesStatus
/// @notice Read-only snapshot of xK613 emissions per reserve, plus vault + allowance sanity checks.
/// @dev Env vars:
///        INCENTIVES_REWARD_TOKEN  — reward token address (xK613)
///        INCENTIVES_REWARDS_VAULT — vault address holding the reward tokens
contract IncentivesStatus is Script {
    function run() external view {
        address rewardToken = vm.envAddress("INCENTIVES_REWARD_TOKEN");
        address rewardsVault = vm.envAddress("INCENTIVES_REWARDS_VAULT");

        IPool pool = IPool(MegaEthMainnet.POOL);
        IRewardsDistributor dist = IRewardsDistributor(MegaEthMainnet.INCENTIVES_CONTROLLER);
        IRewardsController ctrl = IRewardsController(MegaEthMainnet.INCENTIVES_CONTROLLER);

        console.log("=== xK613 incentives status ===");
        console.log("Reward token:", rewardToken);
        console.log("Rewards vault:", rewardsVault);
        console.log("");

        address strategy = ctrl.getTransferStrategy(rewardToken);
        address oracle = ctrl.getRewardOracle(rewardToken);
        console.log("TransferStrategy:", strategy);
        console.log("RewardOracle:", oracle);

        uint256 vaultBal = IERC20(rewardToken).balanceOf(rewardsVault);
        console.log("Vault balance:", vaultBal);

        if (strategy != address(0)) {
            uint256 allowance = IERC20(rewardToken).allowance(rewardsVault, strategy);
            console.log("Vault -> strategy allowance:", allowance);
            if (allowance < type(uint256).max / 2) {
                console.log("WARNING: vault allowance is low or unset");
            }
        }
        console.log("");

        address[] memory reserves = pool.getReservesList();
        uint256 totalEmissionPerSec;

        for (uint256 i = 0; i < reserves.length; i++) {
            DataTypes.ReserveDataLegacy memory rd = pool.getReserveData(reserves[i]);
            string memory symbol = _safeSymbol(reserves[i]);

            (, uint256 supplyEps,, uint256 supplyEnd) = dist.getRewardsData(rd.aTokenAddress, rewardToken);
            (, uint256 borrowEps,, uint256 borrowEnd) = dist.getRewardsData(rd.variableDebtTokenAddress, rewardToken);

            console.log("---", symbol, reserves[i]);
            console.log("  supply eps / end:", supplyEps, supplyEnd);
            console.log("  borrow eps / end:", borrowEps, borrowEnd);
            totalEmissionPerSec += supplyEps + borrowEps;
        }

        console.log("");
        console.log("Total emission/sec across all reserves:", totalEmissionPerSec);
        console.log("Implied daily emission:", totalEmissionPerSec * 86_400);
    }

    function _safeSymbol(address asset) private view returns (string memory) {
        try IERC20Detailed(asset).symbol() returns (string memory s) {
            return s;
        } catch {
            return "???";
        }
    }
}
