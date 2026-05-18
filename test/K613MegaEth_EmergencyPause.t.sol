// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IPoolConfigurator} from "lib/velkonix-contracts/src/contracts/interfaces/IPoolConfigurator.sol";
import {MegaEthMainnet} from "../src/networks/MegaEthMainnet.sol";

/// @title K613MegaEth_EmergencyPauseTest
/// @notice Verifies direct `PoolConfigurator.setReservePause` calls as the broadcaster would.
contract K613MegaEth_EmergencyPauseTest is Test {
    address internal constant ASSET = address(0xBEEF);

    bytes4 internal constant SET_RESERVE_PAUSE_2ARG = bytes4(keccak256("setReservePause(address,bool)"));

    function test_PauseCallsConfiguratorDirectly() public {
        vm.mockCall(MegaEthMainnet.POOL_CONFIGURATOR, abi.encodeWithSelector(SET_RESERVE_PAUSE_2ARG, ASSET, true), "");
        vm.expectCall(MegaEthMainnet.POOL_CONFIGURATOR, abi.encodeWithSelector(SET_RESERVE_PAUSE_2ARG, ASSET, true));
        IPoolConfigurator(MegaEthMainnet.POOL_CONFIGURATOR).setReservePause(ASSET, true);
    }

    function test_UnpauseCallsConfiguratorDirectly() public {
        vm.mockCall(MegaEthMainnet.POOL_CONFIGURATOR, abi.encodeWithSelector(SET_RESERVE_PAUSE_2ARG, ASSET, false), "");
        vm.expectCall(MegaEthMainnet.POOL_CONFIGURATOR, abi.encodeWithSelector(SET_RESERVE_PAUSE_2ARG, ASSET, false));
        IPoolConfigurator(MegaEthMainnet.POOL_CONFIGURATOR).setReservePause(ASSET, false);
    }
}
