// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IPoolConfigurator} from "lib/velkonix-contracts/src/contracts/interfaces/IPoolConfigurator.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

/// @title ExecuteEmergencyPayload
/// @notice Freeze / unfreeze / pause / unpause a single reserve directly via PoolConfigurator.
/// @dev Calls PoolConfigurator directly from the broadcaster (deployer/multisig) so that
///      `msg.sender` holds the required ACL role. Previous version deployed an intermediate
///      payload contract whose address had no roles — that would always revert.
///      Env vars:
///        EMERGENCY_ACTION — freeze | unfreeze | pause | unpause
///        EMERGENCY_ASSET  — underlying asset address
contract ExecuteEmergencyPayload is Script {
    error UnknownAction(string action);

    function run() external {
        string memory action = vm.envString("EMERGENCY_ACTION");
        address asset = vm.envAddress("EMERGENCY_ASSET");

        IPoolConfigurator cfg = IPoolConfigurator(MegaEthMainnet.POOL_CONFIGURATOR);

        vm.startBroadcast();

        bytes32 h = keccak256(bytes(action));
        if (h == keccak256("freeze")) {
            cfg.setReserveFreeze(asset, true);
            console.log("Frozen", asset);
        } else if (h == keccak256("unfreeze")) {
            cfg.setReserveFreeze(asset, false);
            console.log("Unfrozen", asset);
        } else if (h == keccak256("pause")) {
            cfg.setReservePause(asset, true);
            console.log("Paused", asset);
        } else if (h == keccak256("unpause")) {
            cfg.setReservePause(asset, false);
            console.log("Unpaused", asset);
        } else {
            revert UnknownAction(action);
        }

        vm.stopBroadcast();
    }
}
