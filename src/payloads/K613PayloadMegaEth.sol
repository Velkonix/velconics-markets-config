// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AaveV3Payload} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/AaveV3Payload.sol";
import {
    IAaveV3ConfigEngine
} from "lib/velkonix-contracts/src/contracts/extensions/v3-config-engine/IAaveV3ConfigEngine.sol";
import {MegaEthMainnet} from "../networks/MegaEthMainnet.sol";

/// @title K613PayloadMegaEth
/// @notice Base `AaveV3Payload` wired to the MegaETH mainnet `AaveV3ConfigEngine` instance.
/// @dev Concrete payloads inherit this and override only the hooks they need.
abstract contract K613PayloadMegaEth is AaveV3Payload {
    /// @notice Wires the payload base to `MegaEthMainnet.CONFIG_ENGINE`.
    constructor() AaveV3Payload(IAaveV3ConfigEngine(MegaEthMainnet.CONFIG_ENGINE)) {}

    /// @notice Returns display strings used by the config engine for this deployment.
    /// @return Pool context with network name `MegaETH` and abbreviation `Mega`.
    function getPoolContext() public pure override returns (IAaveV3ConfigEngine.PoolContext memory) {
        return IAaveV3ConfigEngine.PoolContext({networkName: "MegaETH", networkAbbreviation: "Mega"});
    }
}
