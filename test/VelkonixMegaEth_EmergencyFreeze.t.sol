// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IPoolConfigurator} from "lib/velkonix-contracts/src/contracts/interfaces/IPoolConfigurator.sol";
import {MegaEthMainnet} from "../src/networks/MegaEthMainnet.sol";

/// @title VelkonixMegaEth_EmergencyFreezeTest
/// @notice Verifies direct `PoolConfigurator.setReserveFreeze` calls as the broadcaster would.
///         The script no longer deploys an intermediate payload contract — it calls the
///         configurator directly so `msg.sender` holds the ACL role.
contract VelkonixMegaEth_EmergencyFreezeTest is Test {
    address internal constant ASSET = address(0xBEEF);

    function test_FreezeCallsConfiguratorDirectly() public {
        vm.mockCall(
            MegaEthMainnet.POOL_CONFIGURATOR,
            abi.encodeWithSelector(IPoolConfigurator.setReserveFreeze.selector, ASSET, true),
            ""
        );
        vm.expectCall(
            MegaEthMainnet.POOL_CONFIGURATOR,
            abi.encodeWithSelector(IPoolConfigurator.setReserveFreeze.selector, ASSET, true)
        );
        IPoolConfigurator(MegaEthMainnet.POOL_CONFIGURATOR).setReserveFreeze(ASSET, true);
    }

    function test_UnfreezeCallsConfiguratorDirectly() public {
        vm.mockCall(
            MegaEthMainnet.POOL_CONFIGURATOR,
            abi.encodeWithSelector(IPoolConfigurator.setReserveFreeze.selector, ASSET, false),
            ""
        );
        vm.expectCall(
            MegaEthMainnet.POOL_CONFIGURATOR,
            abi.encodeWithSelector(IPoolConfigurator.setReserveFreeze.selector, ASSET, false)
        );
        IPoolConfigurator(MegaEthMainnet.POOL_CONFIGURATOR).setReserveFreeze(ASSET, false);
    }
}
