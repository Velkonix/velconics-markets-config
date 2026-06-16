// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IACLManager} from "lib/velkonix-contracts/src/contracts/interfaces/IACLManager.sol";
import {MegaEthMainnet} from "../src/networks/MegaEthMainnet.sol";

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

/// @title MigrateAdminAtomicForkTest
/// @notice Fork integration test for the atomic admin migration sequence. Skips when
///         `MEGAETH_RPC_URL` is not set, so `forge test` stays fast in non-fork runs.
/// @dev Why a fork test (not a unit test): `vm.startPrank` only substitutes `msg.sender`
///      on direct calls from the test contract. Calls made by `MigrateAdminAtomic.run()`
///      itself would NOT be re-pranked at the ACLManager boundary, so the test executes
///      the exact same sequence as the script directly under prank. The sequence here is
///      the spec — keep it in lockstep with the production script. Impersonating the live
///      deployer requires no private key — `vm.startPrank` overrides `msg.sender` purely
///      via cheatcodes, against the forked state.
contract MigrateAdminAtomicForkTest is Test {
    /// @dev Real on-chain deployer (`setMarketReport` sender + current ACLManager admin).
    address internal constant DEPLOYER = 0xF18Fcc2dCDCdc197B036b290BEcBeD692B9d2678;
    address internal constant MAIN_MULTISIG = address(0xBEEF);
    address internal constant EMERGENCY_HOT = address(0xCAFE);

    IACLManager internal acl;
    IAccessControl internal aclAC;
    bytes32 internal adminRole;

    bool internal forkAvailable;

    function setUp() public {
        string memory rpc = vm.envOr("MEGAETH_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            // No RPC — leave forkAvailable=false; the test will exit early.
            return;
        }
        vm.createSelectFork(rpc);
        forkAvailable = true;
        acl = IACLManager(MegaEthMainnet.ACL_MANAGER);
        aclAC = IAccessControl(MegaEthMainnet.ACL_MANAGER);
        adminRole = aclAC.DEFAULT_ADMIN_ROLE();
    }

    function test_AtomicMigration_FullSweep() public {
        if (!forkAvailable) {
            emit log("MEGAETH_RPC_URL not set; skipping fork test.");
            return;
        }

        // ──────── Pre-flight: confirm the live state we are migrating from ────────
        assertTrue(aclAC.hasRole(adminRole, DEPLOYER), "pre: deployer must hold DEFAULT_ADMIN");
        assertTrue(acl.isPoolAdmin(DEPLOYER), "pre: deployer must hold POOL_ADMIN");
        assertFalse(aclAC.hasRole(adminRole, MAIN_MULTISIG), "pre: fake multisig must NOT have admin");
        assertFalse(acl.isPoolAdmin(MAIN_MULTISIG), "pre: fake multisig must NOT have POOL_ADMIN");
        assertEq(
            IOwnable(MegaEthMainnet.POOL_ADDRESSES_PROVIDER).owner(),
            DEPLOYER,
            "pre: PoolAddressesProvider owner != deployer"
        );
        assertEq(IOwnable(MegaEthMainnet.EMISSION_MANAGER).owner(), DEPLOYER, "pre: EmissionManager owner != deployer");

        // ──────── Run the migration sequence as the live deployer ────────
        vm.startPrank(DEPLOYER);

        // 1. DEFAULT_ADMIN to the multisig FIRST so it can backstop everything else.
        aclAC.grantRole(adminRole, MAIN_MULTISIG);

        // 2. Operational roles.
        acl.addPoolAdmin(MAIN_MULTISIG);
        acl.addRiskAdmin(MAIN_MULTISIG);
        acl.addEmergencyAdmin(EMERGENCY_HOT);

        // 3. Ownerships.
        IOwnable(MegaEthMainnet.POOL_ADDRESSES_PROVIDER).transferOwnership(MAIN_MULTISIG);
        IOwnable(MegaEthMainnet.EMISSION_MANAGER).transferOwnership(MAIN_MULTISIG);

        // 4. Revoke deployer's operational roles.
        if (acl.isPoolAdmin(DEPLOYER)) acl.removePoolAdmin(DEPLOYER);
        if (acl.isRiskAdmin(DEPLOYER)) acl.removeRiskAdmin(DEPLOYER);
        if (acl.isEmergencyAdmin(DEPLOYER)) acl.removeEmergencyAdmin(DEPLOYER);

        // 5. Renounce DEFAULT_ADMIN — point of no return for the deployer.
        aclAC.renounceRole(adminRole, DEPLOYER);

        vm.stopPrank();

        // ──────── Post-state assertions ────────
        assertTrue(aclAC.hasRole(adminRole, MAIN_MULTISIG), "post: multisig missing DEFAULT_ADMIN");
        assertTrue(acl.isPoolAdmin(MAIN_MULTISIG), "post: multisig missing POOL_ADMIN");
        assertTrue(acl.isRiskAdmin(MAIN_MULTISIG), "post: multisig missing RISK_ADMIN");
        assertTrue(acl.isEmergencyAdmin(EMERGENCY_HOT), "post: emergency hot missing EMERGENCY_ADMIN");

        assertFalse(aclAC.hasRole(adminRole, DEPLOYER), "post: deployer still DEFAULT_ADMIN");
        assertFalse(acl.isPoolAdmin(DEPLOYER), "post: deployer still POOL_ADMIN");
        assertFalse(acl.isRiskAdmin(DEPLOYER), "post: deployer still RISK_ADMIN");
        assertFalse(acl.isEmergencyAdmin(DEPLOYER), "post: deployer still EMERGENCY_ADMIN");

        assertEq(
            IOwnable(MegaEthMainnet.POOL_ADDRESSES_PROVIDER).owner(), MAIN_MULTISIG, "post: PoolAddressesProvider owner"
        );
        assertEq(IOwnable(MegaEthMainnet.EMISSION_MANAGER).owner(), MAIN_MULTISIG, "post: EmissionManager owner");
    }
}
