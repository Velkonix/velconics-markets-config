// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IACLManager} from "lib/velkonix-contracts/src/contracts/interfaces/IACLManager.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

interface IOwnable {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

contract GrantRoles is Script {
    error UnknownMode(string mode);
    error ZeroMultisig();
    error DeployerNotPoolAdmin();
    error MultisigGrantFailed(string role);

    function run() external {
        string memory mode = vm.envString("GRANT_MODE");
        address mainMultisig = vm.envAddress("MAIN_MULTISIG");
        address emergencyHot = vm.envAddress("EMERGENCY_HOT");
        if (mainMultisig == address(0) || emergencyHot == address(0)) revert ZeroMultisig();

        bytes32 h = keccak256(bytes(mode));
        bool revoke;
        if (h == keccak256("grantOnly")) {
            revoke = false;
        } else if (h == keccak256("grantRevoke")) {
            revoke = true;
        } else {
            revert UnknownMode(mode);
        }

        IACLManager acl = IACLManager(MegaEthMainnet.ACL_MANAGER);

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

        if (!acl.isPoolAdmin(deployer)) revert DeployerNotPoolAdmin();

        console.log("Deployer:", deployer);
        console.log("Main multisig:", mainMultisig);
        console.log("Emergency hot:", emergencyHot);
        console.log("Mode:", mode);
        console.log("");

        if (pkResolved) vm.startBroadcast(pk);
        else vm.startBroadcast();

        if (!acl.isPoolAdmin(mainMultisig)) {
            acl.addPoolAdmin(mainMultisig);
            console.log("+ POOL_ADMIN granted to main multisig");
        } else {
            console.log("= main multisig already POOL_ADMIN");
        }
        if (!acl.isPoolAdmin(mainMultisig)) revert MultisigGrantFailed("POOL_ADMIN");

        if (!acl.isRiskAdmin(mainMultisig)) {
            acl.addRiskAdmin(mainMultisig);
            console.log("+ RISK_ADMIN granted to main multisig");
        } else {
            console.log("= main multisig already RISK_ADMIN");
        }
        if (!acl.isRiskAdmin(mainMultisig)) revert MultisigGrantFailed("RISK_ADMIN");

        if (!acl.isEmergencyAdmin(emergencyHot)) {
            acl.addEmergencyAdmin(emergencyHot);
            console.log("+ EMERGENCY_ADMIN granted to emergency hot wallet");
        } else {
            console.log("= emergency hot wallet already EMERGENCY_ADMIN");
        }
        if (!acl.isEmergencyAdmin(emergencyHot)) revert MultisigGrantFailed("EMERGENCY_ADMIN");

        _transferIfNeeded(MegaEthMainnet.POOL_ADDRESSES_PROVIDER, mainMultisig, "PoolAddressesProvider");
        _transferIfNeeded(MegaEthMainnet.EMISSION_MANAGER, mainMultisig, "EmissionManager");

        if (revoke) {
            console.log("");
            console.log("Revoking deployer roles (grantRevoke mode):");

            if (acl.isPoolAdmin(deployer)) {
                acl.removePoolAdmin(deployer);
                console.log("- POOL_ADMIN revoked from deployer");
            }
            if (acl.isRiskAdmin(deployer)) {
                acl.removeRiskAdmin(deployer);
                console.log("- RISK_ADMIN revoked from deployer");
            }
            if (acl.isEmergencyAdmin(deployer)) {
                acl.removeEmergencyAdmin(deployer);
                console.log("- EMERGENCY_ADMIN revoked from deployer");
            }

            console.log("");
            console.log("NOTE: DEFAULT_ADMIN_ROLE is still held by deployer.");
            console.log("Transfer it manually after verifying the multisig can call grantRole.");
        } else {
            console.log("");
            console.log("grantOnly mode: deployer roles kept for rollback safety.");
            console.log("Re-run with GRANT_MODE=grantRevoke after verifying the multisig works.");
        }

        vm.stopBroadcast();
    }

    function _transferIfNeeded(address target, address newOwner, string memory label) private {
        address current = IOwnable(target).owner();
        if (current == newOwner) {
            console.log(string.concat("= ", label, " already owned by multisig"));
            return;
        }
        IOwnable(target).transferOwnership(newOwner);
        console.log(string.concat("+ ", label, " ownership transferred to multisig"));
    }
}
