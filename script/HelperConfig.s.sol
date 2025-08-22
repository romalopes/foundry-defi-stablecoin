// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "openzeppelin-contracts/mocks/token/ERC20Mock.sol";

contract HelperConfig is Script {
    // BTC/USD 0x85355da30ee4b35F4B30759Bd49a1EBE3fc41Bdb. 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
    // ETH/USD 0x5147eA642CAEF7BD9c1265AadcA78f997AbB9649 0x694AA1769357215DE4FAC081bf1f309aDC325306
    // LINK/USD 0x76F8C9E423C228E83DCB11d17F0Bd8aEB0Ca01bb 0xc59E3633BAAC79493d908e63626716e204A45EdF
    // USDC/USD 0xfB6471ACD42c91FF265344Ff73E88353521d099F 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
    struct NetworkConfig {
        // address wethUsdPriceFeed from chainlink;
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address wethTokenAddress;
        address wbtcTokenAddress;
        uint256 deployerKey;
    }
    // address usdcAddress;
    // address linkAddress;

    NetworkConfig public activeNetworkConfig;

    uint8 public DECIMALS = 8;
    int256 public ETH_USD_PRICE = 4000e8;
    int256 public BTC_USD_PRICE = 100000e8; //30000000000000000000000000000;
    int256 public ANVIL_PRIVATE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    constructor() {
        // if (block.chainid == 1) {
        //     activeNetworkConfig = getMainnetConfig();
        // }
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
            // } else if (block.chainid == 4) {
            //     if (vm.envUint("ANVIL_FORK_BLOCK_NUMBER") != 0) {
            //         activeNetworkConfig = getOrCreateAnvilConfig();
            //     }
            // } else if (block.chainid == 3) {
            //     activeNetworkConfig = getRopstenConfig();
            // } else if (block.chainid == 5) {
            //     activeNetworkConfig = getGoerliConfig();
            // } else if (block.chainid == 80001) {
            //     activeNetworkConfig = getMumbaiConfig();
            // } else if (block.chainid == 137) {
            //     activeNetworkConfig = getPolygonConfig();
            // } else if (block.chainid == 42161) {
            //     activeNetworkConfig = getArbitrumConfig();
            // } else if (block.chainid == 421613) {
            //     activeNetworkConfig = getArbitrumTestnetConfig();
            // } else if (block.chainid == 10) {
            //     activeNetworkConfig = getOptimismConfig();
            // } else if (block.chainid == 420) {
            //     activeNetworkConfig = getOptimismGoerliConfig();
        } else if (block.chainid == 31337) {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory networkConfig) {
        networkConfig.wethUsdPriceFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
        networkConfig.wbtcUsdPriceFeed = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
        // https://sepolia.etherscan.io/address/0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9
        // https://sepolia.etherscan.io/token/0xdd13E55209Fd76AfE204dBda4007C227904f0a81
        networkConfig.wethTokenAddress = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81;
        // https://sepolia.etherscan.io/address/0xa035b9e130F2B1AedC733eEFb1C67Ba4c503491F
        networkConfig.wbtcTokenAddress = 0xa035b9e130F2B1AedC733eEFb1C67Ba4c503491F;
        networkConfig.deployerKey = vm.envUint("SEPOLIA_DEPLOYER_KEY");

        return networkConfig;
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory networkConfig) {
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        MockV3Aggregator ethPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        MockV3Aggregator btcPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wethToken = new ERC20Mock(); //("WETH", "WETH");
        ERC20Mock wbtcToken = new ERC20Mock(); //("WBTC", "WBTC");
        networkConfig.wethUsdPriceFeed = address(ethPriceFeed); //ethPriceFeed;
        networkConfig.wbtcUsdPriceFeed = address(btcPriceFeed); // btcPriceFeed;
        networkConfig.wethTokenAddress = address(wethToken); //wethToken;
        networkConfig.wbtcTokenAddress = address(wbtcToken); //wbtcToken;
        networkConfig.deployerKey = vm.envUint("ANVIL_PRIVATE_KEY");
        // networkConfig.deployerKey = ANVIL_DEPLOYER_KEY;
        vm.stopBroadcast();
        return networkConfig;
    }
}
