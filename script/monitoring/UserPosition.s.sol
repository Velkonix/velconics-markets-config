// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IPool} from "lib/velkonix-contracts/src/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "lib/velkonix-contracts/src/contracts/interfaces/IPoolDataProvider.sol";
import {
    IERC20Detailed
} from "lib/velkonix-contracts/src/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

/// @title UserPosition
/// @notice Read-only dump of a user's Aave position on MegaETH mainnet.
/// @dev Env var:
///        USER — address of the account to inspect
contract UserPosition is Script {
    function run() external view {
        address user = vm.envAddress("USER");

        IPool pool = IPool(MegaEthMainnet.POOL);
        IPoolDataProvider dp = IPoolDataProvider(MegaEthMainnet.AAVE_PROTOCOL_DATA_PROVIDER);

        console.log("=== User position ===");
        console.log("User:", user);
        console.log("");

        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = pool.getUserAccountData(user);

        console.log("totalCollateralBase:", totalCollateralBase);
        console.log("totalDebtBase:", totalDebtBase);
        console.log("availableBorrowsBase:", availableBorrowsBase);
        console.log("currentLT (bps):", currentLiquidationThreshold);
        console.log("currentLTV (bps):", ltv);
        console.log("healthFactor (1e18):", healthFactor);
        console.log("eMode category:", pool.getUserEMode(user));

        if (healthFactor < 1e18 && totalDebtBase > 0) {
            console.log("CRITICAL: healthFactor below 1.0 - position is liquidatable");
        } else if (healthFactor < 1.1e18 && totalDebtBase > 0) {
            console.log("WARNING: healthFactor below 1.1");
        }
        console.log("");

        address[] memory reserves = pool.getReservesList();
        for (uint256 i = 0; i < reserves.length; i++) {
            (uint256 aBalance,, uint256 variableDebt,,,,,, bool usedAsCollateral) =
                dp.getUserReserveData(reserves[i], user);

            if (aBalance == 0 && variableDebt == 0) continue;

            string memory symbol = _safeSymbol(reserves[i]);
            console.log("---", symbol, reserves[i]);
            console.log("  aToken balance:", aBalance);
            console.log("  variable debt:", variableDebt);
            console.log("  used as collateral:", usedAsCollateral);
        }
    }

    function _safeSymbol(address asset) private view returns (string memory) {
        try IERC20Detailed(asset).symbol() returns (string memory s) {
            return s;
        } catch {
            return "???";
        }
    }
}
