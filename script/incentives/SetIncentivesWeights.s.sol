// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IncentivesConfig} from "../../src/incentives/IncentivesConfig.sol";

/// @title SetIncentivesWeights
/// @notice One-shot script that writes the canonical supply/borrow bps split to IncentivesConfig.
/// @dev Broadcaster must be the current `admin` of the target IncentivesConfig instance.
///      Env var: INCENTIVES_CONFIG — address of the deployed IncentivesConfig contract.
contract SetIncentivesWeights is Script {
    address internal constant USDM = 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7;
    address internal constant USDE = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address internal constant BTCB = 0xB0F70C0bD6FD87dbEb7C10dC692a2a6106817072;
    address internal constant WSTETH = 0x601aC63637933D88285A025C685AC4e9a92a98dA;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;

    /// @notice Canonical 6-asset 65/35 (supply/borrow) weight vector in bps.
    /// @dev Pure getter so tests can assert the snapshot without broadcasting.
    function canonicalWeights() public pure returns (IncentivesConfig.AssetWeight[] memory weights) {
        weights = new IncentivesConfig.AssetWeight[](6);

        //                                                  supplyBps  borrowBps   total
        weights[0] = IncentivesConfig.AssetWeight(USDM, 1700, 900); // 26%
        weights[1] = IncentivesConfig.AssetWeight(USDE, 1200, 700); // 19%
        weights[2] = IncentivesConfig.AssetWeight(USDT0, 800, 400); // 12%
        weights[3] = IncentivesConfig.AssetWeight(BTCB, 1200, 600); // 18%
        weights[4] = IncentivesConfig.AssetWeight(WSTETH, 800, 400); // 12%
        weights[5] = IncentivesConfig.AssetWeight(WETH, 800, 500); // 13%
        // Total supply: 6500 (65%), borrow: 3500 (35%), sum: 10000 = WEIGHT_BPS
    }

    function run() external {
        address cfgAddr = vm.envAddress("INCENTIVES_CONFIG");
        IncentivesConfig cfg = IncentivesConfig(cfgAddr);

        IncentivesConfig.AssetWeight[] memory weights = canonicalWeights();

        console.log("IncentivesConfig:", cfgAddr);
        console.log("Current admin:", cfg.admin());
        console.log("Writing 6 asset weights (65% supply / 35% borrow split)");

        vm.startBroadcast();
        cfg.setWeights(weights);
        vm.stopBroadcast();

        console.log("Stored weightCount:", cfg.weightCount());
    }
}
