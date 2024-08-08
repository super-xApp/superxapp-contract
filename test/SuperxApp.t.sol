// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SuperxApp} from "../src/SuperxApp.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract SuperxAppTest is Test {
    CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
    uint256 ethSepoliaFork;
    uint256 arbSepoliaFork;
    Register.NetworkDetails ethSepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    address alice;
    address bob;

    SuperxApp public ethSuperxApp;
    SuperxApp public arbSuperxApp;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        string memory ETHEREUM_SEPOLIA_RPC_URL = vm.envString(
            "ETHEREUM_SEPOLIA_RPC_URL"
        );
        string memory ARBITRUM_SEPOLIA_RPC_URL = vm.envString(
            "ARBITRUM_SEPOLIA_RPC_URL"
        );
        ethSepoliaFork = vm.createSelectFork(ETHEREUM_SEPOLIA_RPC_URL);
        arbSepoliaFork = vm.createFork(ARBITRUM_SEPOLIA_RPC_URL);

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));

        assertEq(vm.activeFork(), ethSepoliaFork);

        ethSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        assertEq(
            ethSepoliaNetworkDetails.chainSelector,
            16015286601757825753,
            "Sanity check: Ethereum Sepolia chain selector should be 16015286601757825753"
        );

        ethSuperxApp = new SuperxApp(
            ethSepoliaNetworkDetails.routerAddress,
            ethSepoliaNetworkDetails.linkAddress,
            ethSepoliaNetworkDetails.chainSelector
        );

        vm.selectFork(arbSepoliaFork);
        assertEq(vm.activeFork(), arbSepoliaFork);

        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(
            block.chainid
        );
        assertEq(
            arbSepoliaNetworkDetails.chainSelector,
            3478487238524512106,
            "Sanity check: Arbitrum Sepolia chain selector should be 421614"
        );

        arbSuperxApp = new SuperxApp(
            arbSepoliaNetworkDetails.routerAddress,
            arbSepoliaNetworkDetails.linkAddress,
            arbSepoliaNetworkDetails.chainSelector
        );

        arbSuperxApp.allowlistDestinationChain(
            ethSepoliaNetworkDetails.chainSelector,
            true
        );
        arbSuperxApp.allowlistSourceChain(
            ethSepoliaNetworkDetails.chainSelector,
            true
        );
        arbSuperxApp.allowlistSender(address(ethSuperxApp), true);

        vm.selectFork(ethSepoliaFork);
        assertEq(vm.activeFork(), ethSepoliaFork);

        ethSuperxApp.allowlistDestinationChain(
            arbSepoliaNetworkDetails.chainSelector,
            true
        );
        ethSuperxApp.allowlistSourceChain(
            arbSepoliaNetworkDetails.chainSelector,
            true
        );
        ethSuperxApp.allowlistSender(address(arbSuperxApp), true);
    }

    function test_sendWethFromEthToArb() public {
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(ethSuperxApp),
            30 ether
        );

        vm.startPrank(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);

        IERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238).approve(
            address(ethSuperxApp),
            1000000
        );

        ethSuperxApp.sendToken(
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSuperxApp),
            bob,
            0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            1000000,
            SuperxApp.PayFeesIn.LINK
        );

        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbSepoliaFork); // THIS LINE REPLACES CHAINLINK CCIP DONs, DO NOT FORGET IT
        assertEq(vm.activeFork(), arbSepoliaFork);

        assertEq(
            IERC20(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d).balanceOf(bob),
            1000000
        );
    }
}
