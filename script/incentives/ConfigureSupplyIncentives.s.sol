// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "lib/velkonix-contracts/src/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {IPool} from "lib/velkonix-contracts/src/contracts/interfaces/IPool.sol";
import {DataTypes} from "lib/velkonix-contracts/src/contracts/protocol/libraries/types/DataTypes.sol";
import {IPoolAddressesProvider} from "lib/velkonix-contracts/src/contracts/interfaces/IPoolAddressesProvider.sol";
import {IEmissionManager} from "lib/velkonix-contracts/src/contracts/rewards/interfaces/IEmissionManager.sol";
import {ITransferStrategyBase} from "lib/velkonix-contracts/src/contracts/rewards/interfaces/ITransferStrategyBase.sol";
import {
    PullRewardsTransferStrategy
} from "lib/velkonix-contracts/src/contracts/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";
import {RewardsDataTypes} from "lib/velkonix-contracts/src/contracts/rewards/libraries/RewardsDataTypes.sol";
import {AggregatorInterface} from "lib/velkonix-contracts/src/contracts/dependencies/chainlink/AggregatorInterface.sol";
import {IRewardsDistributor} from "lib/velkonix-contracts/src/contracts/rewards/interfaces/IRewardsDistributor.sol";
import {StaticRewardPriceFeed} from "../../src/incentives/StaticRewardPriceFeed.sol";
import {IncentivesConfig} from "../../src/incentives/IncentivesConfig.sol";
import {NetworkConfig} from "../../src/networks/NetworkConfig.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

interface IOwnable {
    function owner() external view returns (address);
}

contract ConfigureSupplyIncentives is Script {
    error DistributionEndOverflow();
    error DistributionEndInPast();
    error InvalidOracleAnswer();
    error ZeroIncentivesController();
    error ZeroPool();
    error ZeroEmissionManager();
    error SetEmissionAdminFirst();
    error NotEmissionAdmin();
    error ReserveNotListed(string symbol);
    error ZeroIncentivesConfig();
    error ZeroWeights();

    function run() external {
        address deployer;
        uint256 pk;
        bool pkResolved;

        try vm.envUint("PRIVATE_KEY") returns (uint256 pk_) {
            pk = pk_;
            pkResolved = true;
            deployer = vm.addr(pk_);
        } catch {
            address[] memory wallets = vm.getWallets();
            deployer = wallets.length > 0 ? wallets[0] : tx.origin;
        }

        if (pkResolved) vm.startBroadcast(pk);
        else vm.startBroadcast();

        address rewardToken = vm.envAddress("INCENTIVES_REWARD_TOKEN");
        address rewardsVault = vm.envAddress("INCENTIVES_REWARDS_VAULT");
        address incentivesConfigAddr = vm.envAddress("INCENTIVES_CONFIG");
        if (incentivesConfigAddr == address(0)) revert ZeroIncentivesConfig();
        uint256 distributionEndU = vm.envUint("INCENTIVES_DISTRIBUTION_END");
        if (distributionEndU > uint256(type(uint32).max)) revert DistributionEndOverflow();
        uint32 distributionEnd = uint32(distributionEndU);
        if (distributionEnd <= block.timestamp) revert DistributionEndInPast();

        int256 oracleAnswer = vm.envOr("INCENTIVES_REWARD_ORACLE_ANSWER", int256(800_000));
        if (oracleAnswer <= 0) revert InvalidOracleAnswer();
        uint8 oracleDecimals = uint8(vm.envOr("INCENTIVES_REWARD_ORACLE_DECIMALS", uint256(8)));

        NetworkConfig.Addresses memory addrs = MegaEthMainnet.getAddresses();
        if (addrs.incentivesController == address(0)) revert ZeroIncentivesController();

        address poolAddr = addrs.pool;
        if (poolAddr == address(0)) {
            poolAddr = IPoolAddressesProvider(addrs.poolAddressesProvider).getPool();
        }
        if (poolAddr == address(0)) revert ZeroPool();
        IPool pool = IPool(poolAddr);

        address emissionManagerAddr = IRewardsDistributor(addrs.incentivesController).EMISSION_MANAGER();
        if (emissionManagerAddr == address(0)) revert ZeroEmissionManager();
        IEmissionManager emissionManager = IEmissionManager(emissionManagerAddr);

        address emissionAdmin = emissionManager.getEmissionAdmin(rewardToken);
        if (emissionAdmin == address(0)) {
            address emOwner = IOwnable(emissionManagerAddr).owner();
            if (emOwner != deployer) revert SetEmissionAdminFirst();
            emissionManager.setEmissionAdmin(rewardToken, deployer);
        }
        if (emissionManager.getEmissionAdmin(rewardToken) != deployer) revert NotEmissionAdmin();

        StaticRewardPriceFeed priceFeed = new StaticRewardPriceFeed(oracleAnswer, oracleDecimals, "Reward / USD");
        PullRewardsTransferStrategy strategy =
            new PullRewardsTransferStrategy(addrs.incentivesController, deployer, rewardsVault);

        IncentivesConfig incentivesConfig = IncentivesConfig(incentivesConfigAddr);
        if (incentivesConfig.weightCount() == 0) revert ZeroWeights();
        IncentivesConfig.EmissionConfig[] memory emissions =
            incentivesConfig.getEmissionConfigs(incentivesConfig.YEAR1_TOTAL());

        RewardsDataTypes.RewardsConfigInput[] memory cfg =
            new RewardsDataTypes.RewardsConfigInput[](emissions.length * 2);

        for (uint256 i = 0; i < emissions.length; i++) {
            DataTypes.ReserveDataLegacy memory reserveData = pool.getReserveData(emissions[i].asset);
            address aToken = reserveData.aTokenAddress;
            address variableDebtToken = reserveData.variableDebtTokenAddress;
            if (aToken == address(0) || variableDebtToken == address(0)) {
                revert ReserveNotListed(vm.toString(emissions[i].asset));
            }

            uint256 base = i * 2;
            cfg[base] = RewardsDataTypes.RewardsConfigInput({
                emissionPerSecond: emissions[i].supplyEmissionPerSecond,
                totalSupply: 0,
                distributionEnd: distributionEnd,
                asset: aToken,
                reward: rewardToken,
                transferStrategy: ITransferStrategyBase(strategy),
                rewardOracle: AggregatorInterface(address(priceFeed))
            });
            cfg[base + 1] = RewardsDataTypes.RewardsConfigInput({
                emissionPerSecond: emissions[i].borrowEmissionPerSecond,
                totalSupply: 0,
                distributionEnd: distributionEnd,
                asset: variableDebtToken,
                reward: rewardToken,
                transferStrategy: ITransferStrategyBase(strategy),
                rewardOracle: AggregatorInterface(address(priceFeed))
            });

            console.log("asset:", emissions[i].asset);
            console.log("  aToken:", aToken);
            console.log("  variableDebtToken:", variableDebtToken);
            console.log("  supply bps:", emissions[i].supplyBps);
            console.log("  borrow bps:", emissions[i].borrowBps);
            console.log("  supply emission/sec:", uint256(emissions[i].supplyEmissionPerSecond));
            console.log("  borrow emission/sec:", uint256(emissions[i].borrowEmissionPerSecond));
        }

        emissionManager.configureAssets(cfg);

        console.log("\n=== Deployment Summary ===");
        console.log("Reward token:", rewardToken);
        console.log("Rewards vault:", rewardsVault);
        console.log("PriceFeed:", address(priceFeed));
        console.log("TransferStrategy:", address(strategy));
        console.log("Reward distributions configured:", cfg.length);
        console.log("Distribution end:", uint256(distributionEnd));

        uint256 allowance = IERC20(rewardToken).allowance(rewardsVault, address(strategy));
        if (allowance < type(uint256).max / 2) {
            console.log("\nACTION REQUIRED: from REWARDS_VAULT call:");
            console.log("  IERC20(rewardToken).approve(strategy, type(uint256).max)");
        }

        vm.stopBroadcast();
    }
}
