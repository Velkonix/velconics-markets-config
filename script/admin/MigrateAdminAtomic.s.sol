// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IACLManager} from "lib/velkonix-contracts/src/contracts/interfaces/IACLManager.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

interface IAccessControl {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
}

interface IOwnable {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/// @title MigrateAdminAtomic
/// @notice One-shot admin migration: grants every role to the multisig + emergency hot,
///         transfers contract ownerships, then revokes the deployer's roles and renounces
///         `DEFAULT_ADMIN_ROLE` — all in a single broadcast.
/// @dev IRREVERSIBLE for `DEFAULT_ADMIN_ROLE`. If the multisig is misconfigured the market
///      is bricked. Verify env values carefully. Set `CONFIRM_IRREVERSIBLE=YES` to acknowledge.
///
///      End state:
///        - DEFAULT/POOL/RISK admin + Provider/EmissionManager ownership → `MAIN_MULTISIG`
///        - EMERGENCY_ADMIN → `EMERGENCY_HOT`
///        - deployer keeps EMERGENCY_ADMIN **iff** `EMERGENCY_HOT == deployer` (the
///          "deployer is the online emergency hot wallet" pattern — cold multisig governs,
///          deployer key only retains fast pause/freeze)
///        - deployer otherwise has zero privileges
///
///      Env vars:
///        MAIN_MULTISIG         — recipient of POOL/RISK/DEFAULT admin + ownerships
///        EMERGENCY_HOT         — recipient of EMERGENCY_ADMIN (may equal deployer or
///                                MAIN_MULTISIG)
///        CONFIRM_IRREVERSIBLE  — must equal "YES"
///        PRIVATE_KEY           — optional; otherwise first `vm.getWallets()` entry is used
contract MigrateAdminAtomic is Script {
    error ZeroAddress(string field);
    error NotConfirmed();
    error DeployerEqualsMultisig();
    error DeployerLacksDefaultAdmin();
    error DeployerLacksPoolAdmin();
    error PostCheckFailed(string what);

    function run() external {
        address mainMultisig = vm.envAddress("MAIN_MULTISIG");
        address emergencyHot = vm.envAddress("EMERGENCY_HOT");
        if (mainMultisig == address(0)) revert ZeroAddress("MAIN_MULTISIG");
        if (emergencyHot == address(0)) revert ZeroAddress("EMERGENCY_HOT");

        if (keccak256(bytes(vm.envString("CONFIRM_IRREVERSIBLE"))) != keccak256(bytes("YES"))) {
            revert NotConfirmed();
        }

        IACLManager acl = IACLManager(MegaEthMainnet.ACL_MANAGER);
        IAccessControl aclAC = IAccessControl(MegaEthMainnet.ACL_MANAGER);
        bytes32 adminRole = aclAC.DEFAULT_ADMIN_ROLE();

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

        if (deployer == mainMultisig) revert DeployerEqualsMultisig();
        if (!aclAC.hasRole(adminRole, deployer)) revert DeployerLacksDefaultAdmin();
        if (!acl.isPoolAdmin(deployer)) revert DeployerLacksPoolAdmin();

        console.log("=== MigrateAdminAtomic ===");
        console.log("ACLManager:        ", MegaEthMainnet.ACL_MANAGER);
        console.log("Deployer (lose all):", deployer);
        console.log("Main multisig:     ", mainMultisig);
        console.log("Emergency hot:     ", emergencyHot);
        console.log("");

        if (pkResolved) vm.startBroadcast(pk);
        else vm.startBroadcast();

        // 1. Grant DEFAULT_ADMIN to the multisig FIRST so it can backstop the rest if needed.
        if (!aclAC.hasRole(adminRole, mainMultisig)) {
            aclAC.grantRole(adminRole, mainMultisig);
            console.log("+ DEFAULT_ADMIN_ROLE granted to multisig");
        }

        // 2. Grant operational roles to multisig + emergency hot.
        if (!acl.isPoolAdmin(mainMultisig)) {
            acl.addPoolAdmin(mainMultisig);
            console.log("+ POOL_ADMIN granted to multisig");
        }
        if (!acl.isRiskAdmin(mainMultisig)) {
            acl.addRiskAdmin(mainMultisig);
            console.log("+ RISK_ADMIN granted to multisig");
        }
        if (!acl.isEmergencyAdmin(emergencyHot)) {
            acl.addEmergencyAdmin(emergencyHot);
            console.log("+ EMERGENCY_ADMIN granted to emergency hot");
        }

        // 3. Transfer contract ownerships.
        _transferIfNeeded(MegaEthMainnet.POOL_ADDRESSES_PROVIDER, mainMultisig, "PoolAddressesProvider");
        _transferIfNeeded(MegaEthMainnet.EMISSION_MANAGER, mainMultisig, "EmissionManager");

        // 4. Revoke deployer's operational roles.
        if (acl.isPoolAdmin(deployer)) {
            acl.removePoolAdmin(deployer);
            console.log("- POOL_ADMIN revoked from deployer");
        }
        if (acl.isRiskAdmin(deployer)) {
            acl.removeRiskAdmin(deployer);
            console.log("- RISK_ADMIN revoked from deployer");
        }
        // Keep EMERGENCY_ADMIN on the deployer iff that is exactly the desired hot wallet.
        if (acl.isEmergencyAdmin(deployer) && emergencyHot != deployer) {
            acl.removeEmergencyAdmin(deployer);
            console.log("- EMERGENCY_ADMIN revoked from deployer");
        }

        // 5. Renounce DEFAULT_ADMIN_ROLE LAST — point of no return for the deployer.
        aclAC.renounceRole(adminRole, deployer);
        console.log("- DEFAULT_ADMIN_ROLE renounced by deployer");

        vm.stopBroadcast();

        // 6. Post-checks — fail loudly if anything didn't stick.
        if (!aclAC.hasRole(adminRole, mainMultisig)) revert PostCheckFailed("multisig DEFAULT_ADMIN");
        if (!acl.isPoolAdmin(mainMultisig)) revert PostCheckFailed("multisig POOL_ADMIN");
        if (!acl.isRiskAdmin(mainMultisig)) revert PostCheckFailed("multisig RISK_ADMIN");
        if (!acl.isEmergencyAdmin(emergencyHot)) revert PostCheckFailed("emergency EMERGENCY_ADMIN");
        if (aclAC.hasRole(adminRole, deployer)) revert PostCheckFailed("deployer still DEFAULT_ADMIN");
        if (acl.isPoolAdmin(deployer)) revert PostCheckFailed("deployer still POOL_ADMIN");
        if (acl.isRiskAdmin(deployer)) revert PostCheckFailed("deployer still RISK_ADMIN");
        // EMERGENCY_ADMIN may still belong to the deployer if it was the chosen hot wallet.
        if (acl.isEmergencyAdmin(deployer) && emergencyHot != deployer) {
            revert PostCheckFailed("deployer still EMERGENCY_ADMIN");
        }
        if (IOwnable(MegaEthMainnet.POOL_ADDRESSES_PROVIDER).owner() != mainMultisig) {
            revert PostCheckFailed("PoolAddressesProvider owner");
        }
        if (IOwnable(MegaEthMainnet.EMISSION_MANAGER).owner() != mainMultisig) {
            revert PostCheckFailed("EmissionManager owner");
        }

        console.log("");
        if (emergencyHot == deployer) {
            console.log("=== DONE. Deployer kept EMERGENCY_ADMIN only (hot-wallet pattern). ===");
        } else {
            console.log("=== DONE. Deployer has no privileges left. ===");
        }
    }

    function _transferIfNeeded(address target, address newOwner, string memory label) private {
        address current = IOwnable(target).owner();
        if (current == newOwner) {
            console.log(string.concat("= ", label, " already owned by multisig"));
            return;
        }
        IOwnable(target).transferOwnership(newOwner);
        console.log(string.concat("+ ", label, " ownership -> multisig"));
    }
}
