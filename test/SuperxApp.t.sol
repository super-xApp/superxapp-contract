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

        ethSuperxApp = SuperxApp(
            payable(0x0d36DD97b829069b48F97190DA264b87C3558e3b)
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

        arbSuperxApp = SuperxApp(
            payable(0x5c55DfB5f4eB4cE81b5416A071d96248c0E35aBa)
        );

        vm.startPrank(0x4312AC6CAdF4ec4eA955b133D4d29D0af4d2A773);

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

        vm.startPrank(0x4312AC6CAdF4ec4eA955b133D4d29D0af4d2A773);

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

    function test_sendUSDCFromEthToArb() public {
        bytes[] memory priceUpdateArray = new bytes[](1);
        priceUpdateArray[0] = vm.envBytes("PRICE_UPDATE");

        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(ethSuperxApp),
            30 ether
        );

        vm.startPrank(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);

        IERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238).approve(
            address(ethSuperxApp),
            1000000
        );
        IERC20(0x779877A7B0D9E8603169DdbD7836e478b4624789).approve(
            address(ethSuperxApp),
            5 ether
        );

        ethSuperxApp.sendToken(
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSuperxApp),
            bob,
            0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            1000000,
            SuperxApp.TokenType.SUPPORTED,
            SuperxApp.PayFeesIn.LINK,
            "LINK",
            priceUpdateArray
        );

        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbSepoliaFork); // THIS LINE REPLACES CHAINLINK CCIP DONs, DO NOT FORGET IT
        assertEq(vm.activeFork(), arbSepoliaFork);

        assertEq(
            IERC20(0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d).balanceOf(bob),
            1000000
        );
    }

    function test_sendDAIFromEthToArb() public {
        bytes[] memory priceUpdateArray = new bytes[](1);
        priceUpdateArray[0] = vm.envBytes("PRICE_UPDATE");

        ccipLocalSimulatorFork.requestLinkFromFaucet(
            address(0x6364eC95659863D87b1150c7B6342C1A5D185273),
            30000 ether
        );

        vm.startPrank(0x4a3aF8C69ceE81182A9E74b2392d4bDc616Bf7c7);

        IERC20(0x6b18B2c8fE8B9031aE44FCE116bA8f6290E98146).approve(
            address(ethSuperxApp),
            2 ether
        );
        IERC20(0x779877A7B0D9E8603169DdbD7836e478b4624789).approve(
            address(ethSuperxApp),
            5 ether
        );
        vm.deal(0x6364eC95659863D87b1150c7B6342C1A5D185273, 10 ether);

        ethSuperxApp.sendToken(
            arbSepoliaNetworkDetails.chainSelector,
            address(arbSuperxApp),
            bob,
            0x6b18B2c8fE8B9031aE44FCE116bA8f6290E98146,
            2,
            SuperxApp.TokenType.NOTSUPPORTED,
            SuperxApp.PayFeesIn.LINK,
            "DAI",
            priceUpdateArray
        );

        vm.stopPrank();

        ccipLocalSimulatorFork.switchChainAndRouteMessage(arbSepoliaFork); // THIS LINE REPLACES CHAINLINK CCIP DONs, DO NOT FORGET IT
        assertEq(vm.activeFork(), arbSepoliaFork);

        assertEq(
            IERC20(0x5A67F42DCE66f311B869e737cc88297284b1123A).balanceOf(bob),
            2 ether
        );
    }
}
