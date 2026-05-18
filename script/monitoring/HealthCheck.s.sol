// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IACLManager} from "lib/velkonix-contracts/src/contracts/interfaces/IACLManager.sol";
import {IEmissionManager} from "lib/velkonix-contracts/src/contracts/rewards/interfaces/IEmissionManager.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

interface IOwnable {
    function owner() external view returns (address);
}

interface IAccessControlRead {
    function hasRole(bytes32 role, address account) external view returns (bool);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

/// @title HealthCheck
/// @notice Post-deploy ACL + ownership audit. Prints current holders of every sensitive role.
/// @dev Read-only. Env vars:
///        CHECK_DEPLOYER — optional deployer address to flag leftover roles
///        CHECK_REWARD   — optional reward token address to look up emission admin
contract HealthCheck is Script {
    function run() external view {
        IACLManager acl = IACLManager(MegaEthMainnet.ACL_MANAGER);
        IAccessControlRead ac = IAccessControlRead(MegaEthMainnet.ACL_MANAGER);

        console.log("=== MegaETH mainnet ACL / ownership audit ===");
        console.log("");

        console.log("PoolAddressesProvider owner:", IOwnable(MegaEthMainnet.POOL_ADDRESSES_PROVIDER).owner());
        console.log("EmissionManager         owner:", IOwnable(MegaEthMainnet.EMISSION_MANAGER).owner());
        console.log("");

        address deployer = vm.envOr("CHECK_DEPLOYER", address(0));
        if (deployer != address(0)) {
            console.log("Deployer:", deployer);
            console.log("  isPoolAdmin:", acl.isPoolAdmin(deployer));
            console.log("  isRiskAdmin:", acl.isRiskAdmin(deployer));
            console.log("  isEmergencyAdmin:", acl.isEmergencyAdmin(deployer));
            console.log("  isAssetListingAdmin:", acl.isAssetListingAdmin(deployer));
            bytes32 defaultAdmin = ac.DEFAULT_ADMIN_ROLE();
            console.log("  hasDefaultAdminRole:", ac.hasRole(defaultAdmin, deployer));
            console.log("");
        }

        address reward = vm.envOr("CHECK_REWARD", address(0));
        if (reward != address(0)) {
            IEmissionManager em = IEmissionManager(MegaEthMainnet.EMISSION_MANAGER);
            console.log("Reward token:", reward);
            console.log("  emissionAdmin:", em.getEmissionAdmin(reward));
            console.log("");
        }

        console.log("Sensitive-role role IDs (from ACLManager):");
        console.log("  POOL_ADMIN_ROLE:");
        console.logBytes32(acl.POOL_ADMIN_ROLE());
        console.log("  RISK_ADMIN_ROLE:");
        console.logBytes32(acl.RISK_ADMIN_ROLE());
        console.log("  EMERGENCY_ADMIN_ROLE:");
        console.logBytes32(acl.EMERGENCY_ADMIN_ROLE());
        console.log("  ASSET_LISTING_ADMIN_ROLE:");
        console.logBytes32(acl.ASSET_LISTING_ADMIN_ROLE());
        console.log("");
        console.log("NOTE: AccessControl holders are off-chain enumerable only via event logs.");
        console.log("      Supply CHECK_DEPLOYER / multisig addresses explicitly to verify membership.");
    }
}
