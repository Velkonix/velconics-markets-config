// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

interface IAccessControl {
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role, address account) external;
}

/// @title RotateDefaultAdmin
/// @notice Rotate `DEFAULT_ADMIN_ROLE` on the MegaETH ACLManager from deployer to the main multisig.
/// @dev Two-mode safety pattern matching `GrantRoles`:
///        ROTATE_MODE=grantOnly     — grant role to multisig, deployer keeps it for rollback safety.
///        ROTATE_MODE=grantRenounce — grant to multisig (idempotent) AND renounce on deployer.
///                                    Irreversible. Run only after multisig is verified working.
///      Env vars:
///        ROTATE_MODE   — grantOnly | grantRenounce
///        MAIN_MULTISIG — recipient multisig address
///        PRIVATE_KEY   — optional; otherwise the first wallet from `vm.getWallets()` is used.
contract RotateDefaultAdmin is Script {
    error UnknownMode(string mode);
    error ZeroMultisig();
    error DeployerLacksDefaultAdmin();
    error MultisigGrantFailed();
    error DeployerStillAdmin();
    error DeployerEqualsMultisig();

    function run() external {
        string memory mode = vm.envString("ROTATE_MODE");
        address mainMultisig = vm.envAddress("MAIN_MULTISIG");
        if (mainMultisig == address(0)) revert ZeroMultisig();

        bytes32 h = keccak256(bytes(mode));
        bool renounce;
        if (h == keccak256("grantOnly")) {
            renounce = false;
        } else if (h == keccak256("grantRenounce")) {
            renounce = true;
        } else {
            revert UnknownMode(mode);
        }

        IAccessControl acl = IAccessControl(MegaEthMainnet.ACL_MANAGER);
        bytes32 adminRole = acl.DEFAULT_ADMIN_ROLE();

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
        if (!acl.hasRole(adminRole, deployer)) revert DeployerLacksDefaultAdmin();

        console.log("ACLManager:", MegaEthMainnet.ACL_MANAGER);
        console.log("Deployer:", deployer);
        console.log("Main multisig:", mainMultisig);
        console.log("Mode:", mode);
        console.log("");

        if (pkResolved) vm.startBroadcast(pk);
        else vm.startBroadcast();

        if (!acl.hasRole(adminRole, mainMultisig)) {
            acl.grantRole(adminRole, mainMultisig);
            console.log("+ DEFAULT_ADMIN_ROLE granted to main multisig");
        } else {
            console.log("= main multisig already DEFAULT_ADMIN");
        }
        if (!acl.hasRole(adminRole, mainMultisig)) revert MultisigGrantFailed();

        if (renounce) {
            acl.renounceRole(adminRole, deployer);
            if (acl.hasRole(adminRole, deployer)) revert DeployerStillAdmin();
            console.log("- DEFAULT_ADMIN_ROLE renounced by deployer");
            console.log("");
            console.log("Rotation complete. Deployer no longer holds DEFAULT_ADMIN_ROLE.");
        } else {
            console.log("");
            console.log("grantOnly mode: deployer still holds DEFAULT_ADMIN_ROLE.");
            console.log("Re-run with ROTATE_MODE=grantRenounce after multisig is verified.");
        }

        vm.stopBroadcast();
    }
}
