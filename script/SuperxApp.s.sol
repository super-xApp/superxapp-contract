// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuperxOracle} from "../src/SuperxOracle.sol";
import {SuperxApp} from "../src/SuperxApp.sol";

contract SuperxAppScript is Script {
    function setUp() public {}

    function run() public {
        // vm.startBroadcast();
        // deploySepolia();
        // vm.stopBroadcast();

        // vm.startBroadcast();
        // deployArbitrum();
        // vm.stopBroadcast();

        // vm.startBroadcast();
        // deployBaseSepolia();
        // vm.stopBroadcast();

        vm.startBroadcast();
        deployOptimismSepolia();
        vm.stopBroadcast();
    }

    function deploySepolia() public {
        uint64[] memory _supportedChains = new uint64[](4);
        _supportedChains[0] = 10344971235874465080;
        _supportedChains[1] = 3478487238524512106;
        _supportedChains[2] = 3552045678561919002;
        _supportedChains[3] = 5224473277236331295;

        SuperxApp xapp = new SuperxApp(
            0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            0x779877A7B0D9E8603169DdbD7836e478b4624789,
            0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            16015286601757825753,
            _supportedChains,
            0x6364eC95659863D87b1150c7B6342C1A5D185273
        );

        console.log(
            "This is the address of the xapp on sepolia",
            address(xapp)
        );
    }

    function deployArbitrum() public {
        uint64[] memory _supportedChains = new uint64[](4);
        _supportedChains[0] = 10344971235874465080;
        _supportedChains[1] = 16015286601757825753;
        _supportedChains[2] = 3552045678561919002;
        _supportedChains[3] = 5224473277236331295;

        SuperxApp xapp = new SuperxApp(
            0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165,
            0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d,
            3478487238524512106,
            _supportedChains,
            0x6A1831C9E48cd407dB1c7e9AaC6ae79C16d3462F
        );

        console.log("This is the address of the xapp on ARB", address(xapp));
    }

    function deployBaseSepolia() public {
        uint64[] memory _supportedChains = new uint64[](4);
        _supportedChains[0] = 16015286601757825753;
        _supportedChains[1] = 3478487238524512106;
        _supportedChains[2] = 3552045678561919002;
        _supportedChains[3] = 5224473277236331295;

        SuperxApp xapp = new SuperxApp(
            0xD3b06cEbF099CE7DA4AcCf578aaebFDBd6e88a93,
            0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
            0x036CbD53842c5426634e7929541eC2318f3dCF7e,
            10344971235874465080,
            _supportedChains,
            0x13CfEA2CcC182C55Ee4A7954e23f8207F093eee9
        );

        console.log("This is the address of the xapp base", address(xapp));
    }

    function deployOptimismSepolia() public {
        uint64[] memory _supportedChains = new uint64[](4);
        _supportedChains[0] = 10344971235874465080;
        _supportedChains[1] = 3478487238524512106;
        _supportedChains[2] = 3552045678561919002;
        _supportedChains[3] = 16015286601757825753;

        SuperxApp xapp = new SuperxApp(
            0x114A20A10b43D4115e5aeef7345a1A71d2a60C57,
            0xE4aB69C077896252FAFBD49EFD26B5D171A32410,
            0x5fd84259d66Cd46123540766Be93DFE6D43130D7,
            5224473277236331295,
            _supportedChains,
            0x5c55DfB5f4eB4cE81b5416A071d96248c0E35aBa
        );

        console.log("This is the address of the xapp on op", address(xapp));
    }

    function deployCeloAlfajero() public {
        uint64[] memory _supportedChains = new uint64[](4);
        _supportedChains[0] = 10344971235874465080;
        _supportedChains[1] = 3478487238524512106;
        _supportedChains[2] = 16015286601757825753;
        _supportedChains[3] = 5224473277236331295;

        SuperxApp xapp = new SuperxApp(
            0xb00E95b773528E2Ea724DB06B75113F239D15Dca,
            0x32E08557B14FaD8908025619797221281D439071,
            0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
            3552045678561919002,
            _supportedChains,
            0x13CfEA2CcC182C55Ee4A7954e23f8207F093eee9
        );

        console.log("This is the address of the xapp on celo", address(xapp));
    }
}
