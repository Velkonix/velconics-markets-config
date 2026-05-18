// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IPoolConfigurator} from "lib/velkonix-contracts/src/contracts/interfaces/IPoolConfigurator.sol";
import {MegaEthMainnet} from "../../src/networks/MegaEthMainnet.sol";

contract AdminOps is Script {
    error UnknownOp(string op);

    function run() external {
        string memory op = vm.envString("ADMIN_OP");
        address asset = vm.envAddress("ADMIN_ASSET");
        uint256 value = vm.envUint("ADMIN_VALUE");

        IPoolConfigurator cfg = IPoolConfigurator(MegaEthMainnet.POOL_CONFIGURATOR);

        vm.startBroadcast();

        bytes32 h = keccak256(bytes(op));
        if (h == keccak256("supplyCap")) {
            cfg.setSupplyCap(asset, value);
            console.log("setSupplyCap", asset, value);
        } else if (h == keccak256("borrowCap")) {
            cfg.setBorrowCap(asset, value);
            console.log("setBorrowCap", asset, value);
        } else if (h == keccak256("reserveFactor")) {
            cfg.setReserveFactor(asset, value);
            console.log("setReserveFactor", asset, value);
        } else if (h == keccak256("liqProtocolFee")) {
            cfg.setLiquidationProtocolFee(asset, value);
            console.log("setLiquidationProtocolFee", asset, value);
        } else {
            revert UnknownOp(op);
        }

        vm.stopBroadcast();
    }
}
