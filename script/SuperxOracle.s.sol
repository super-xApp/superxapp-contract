// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SuperxOracle} from "../src/SuperxOracle.sol";

contract SuperxAppScript is Script {
    SuperxOracle.TokenData[] public tokenDatas;

    SuperxOracle.TokenData public DAIUSD =
        SuperxOracle.TokenData(
            bytes32(
                0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd
            ),
            "DAI"
        );

    SuperxOracle.TokenData public LINKUSD =
        SuperxOracle.TokenData(
            bytes32(
                0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221
            ),
            "LINK"
        );

    SuperxOracle.TokenData public WETHUSD =
        SuperxOracle.TokenData(
            bytes32(
                0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6
            ),
            "WETH"
        );

    SuperxOracle.TokenData public USDCUSD =
        SuperxOracle.TokenData(
            bytes32(
                0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a
            ),
            "USDC"
        );

    SuperxOracle.TokenData public ETHUSD =
        SuperxOracle.TokenData(
            bytes32(
                0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
            ),
            "ETH"
        );

    SuperxOracle.TokenData public CELOUSD =
        SuperxOracle.TokenData(
            bytes32(
                0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
            ),
            "CELO"
        );

    SuperxOracle.TokenData public WCELOUSD =
        SuperxOracle.TokenData(
            bytes32(
                0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace
            ),
            "WCELO"
        );

    function setUp() public {
        tokenDatas.push(DAIUSD);
        tokenDatas.push(LINKUSD);
        tokenDatas.push(WETHUSD);
        tokenDatas.push(USDCUSD);
        tokenDatas.push(ETHUSD);
    }

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
        address[] memory tokens = new address[](5);
        tokens[0] = 0x6b18B2c8fE8B9031aE44FCE116bA8f6290E98146;
        tokens[1] = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        tokens[2] = 0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534;
        tokens[3] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        tokens[4] = address(1);

        SuperxOracle oracle = new SuperxOracle(
            0xDd24F84d36BF92C65F92307595335bdFab5Bbd21,
            tokenDatas,
            tokens
        );

        console.log(
            "This is the address of the oracle on sepolia",
            address(oracle)
        );
    }

    function deployArbitrum() public {
        address[] memory tokens = new address[](5);
        tokens[0] = 0x5A67F42DCE66f311B869e737cc88297284b1123A;
        tokens[1] = 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E;
        tokens[2] = 0xE591bf0A0CF924A0674d7792db046B23CEbF5f34;
        tokens[3] = 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d;
        tokens[4] = address(1);

        SuperxOracle oracle = new SuperxOracle(
            0x4374e5a8b9C22271E9EB878A2AA31DE97DF15DAF,
            tokenDatas,
            tokens
        );

        console.log(
            "This is the address of the oracle on ARB",
            address(oracle)
        );
    }

    function deployBaseSepolia() public {
        address[] memory tokens = new address[](5);
        tokens[0] = 0x1999654469856017612c077E917476A7aa740eD6;
        tokens[1] = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
        tokens[2] = 0x4200000000000000000000000000000000000006;
        tokens[3] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
        tokens[4] = address(1);

        SuperxOracle oracle = new SuperxOracle(
            0xA2aa501b19aff244D90cc15a4Cf739D2725B5729,
            tokenDatas,
            tokens
        );

        console.log(
            "This is the address of the oracle on Base",
            address(oracle)
        );
    }

    function deployOptimismSepolia() public {
        address[] memory tokens = new address[](5);
        tokens[0] = 0xa67972265516E4BFEA3d4f9c70749768be2d29F8;
        tokens[1] = 0xE4aB69C077896252FAFBD49EFD26B5D171A32410;
        tokens[2] = 0x4200000000000000000000000000000000000006;
        tokens[3] = 0x5fd84259d66Cd46123540766Be93DFE6D43130D7;
        tokens[4] = address(1);

        SuperxOracle oracle = new SuperxOracle(
            0x0708325268dF9F66270F1401206434524814508b,
            tokenDatas,
            tokens
        );

        console.log("This is the address of the oracle on OP", address(oracle));
    }

    function deployCeloAlfajero() public {
        address[] memory tokens = new address[](5);
        tokens[0] = 0x6b18B2c8fE8B9031aE44FCE116bA8f6290E98146;
        tokens[1] = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
        tokens[2] = 0x097D90c9d3E0B50Ca60e1ae45F6A81010f9FB534;
        tokens[3] = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
        tokens[4] = address(1);

        SuperxOracle oracle = new SuperxOracle(
            0xDd24F84d36BF92C65F92307595335bdFab5Bbd21,
            tokenDatas,
            tokens
        );

        console.log(
            "This is the address of the oracle on Celo",
            address(oracle)
        );
    }
}
