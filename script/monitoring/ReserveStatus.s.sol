// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IPool} from "lib/velkonix-contracts/src/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "lib/velkonix-contracts/src/contracts/interfaces/IPoolDataProvider.sol";
import {
    IERC20Detailed
} from "lib/velkonix-contracts/src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

/// @title ReserveStatus
/// @notice Read-only dump of every listed reserve on MegaETH mainnet. No broadcast.
/// @dev Run with `forge script script/monitoring/ReserveStatus.s.sol --rpc-url $MEGAETH_RPC_URL`.
contract ReserveStatus is Script {
    uint256 internal constant RAY = 1e27;

    /// @notice Iterates `IPool.getReservesList` and prints per-reserve state.
    function run() external view {
        IPool pool = IPool(MegaEthMainnet.POOL);
        IPoolDataProvider dp = IPoolDataProvider(MegaEthMainnet.AAVE_PROTOCOL_DATA_PROVIDER);

        address[] memory reserves = pool.getReservesList();
        console.log("=== MegaETH mainnet reserves ===");
        console.log("Reserves:", reserves.length);
        console.log("");

        for (uint256 i = 0; i < reserves.length; i++) {
            _printReserve(dp, reserves[i]);
        }
    }

    function _printReserve(IPoolDataProvider dp, address asset) private view {
        string memory symbol = _safeSymbol(asset);
        console.log("---", symbol, asset);

        (
            uint256 decimals,
            uint256 ltv,
            uint256 lt,
            uint256 liqBonus,
            uint256 reserveFactor,
            bool usageAsCollateral,
            bool borrowingEnabled,,
            bool isActive,
            bool isFrozen
        ) = dp.getReserveConfigurationData(asset);

        (uint256 borrowCap, uint256 supplyCap) = dp.getReserveCaps(asset);
        bool isPaused = dp.getPaused(asset);

        (,, uint256 totalAToken,, uint256 totalVariableDebt, uint256 liquidityRate, uint256 variableBorrowRate,,,,,) =
            dp.getReserveData(asset);

        console.log("  decimals:", decimals);
        console.log("  ltv / lt / liqBonus (bps):", ltv, lt, liqBonus);
        console.log("  reserveFactor (bps):", reserveFactor);
        console.log("  supplyCap / borrowCap (whole units):", supplyCap, borrowCap);
        console.log("  totalAToken:", totalAToken);
        console.log("  totalVariableDebt:", totalVariableDebt);
        console.log("  supplyRate  (ray):", liquidityRate);
        console.log("  borrowRate  (ray):", variableBorrowRate);
        console.log("  usageAsCollateral / borrowingEnabled:", usageAsCollateral, borrowingEnabled);
        console.log("  active / frozen / paused:", isActive, isFrozen, isPaused);

        // Utilization % (bps): debt / (debt + availableLiquidity). Guard zero supply.
        if (totalAToken > 0) {
            uint256 utilBps = (totalVariableDebt * 10_000) / totalAToken;
            console.log("  utilization (bps):", utilBps);
        }
        console.log("");
    }

    function _safeSymbol(address asset) private view returns (string memory) {
        try IERC20Detailed(asset).symbol() returns (string memory s) {
            return s;
        } catch {
            return "???";
        }
    }
}
