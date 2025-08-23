// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UsdrCoin} from "src/UsdrCoin.sol";
import {UsdrEngine} from "src/UsdrEngine.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";

contract DeployUsdr is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (UsdrCoin usdrCoin, UsdrEngine usdrEngine, HelperConfig helperConfig) {
        helperConfig = new HelperConfig();
        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wethTokenAddress,
            address wbtcTokenAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        // usdrCoin = new UsdrCoin(msg.sender);
        // console.logAddress(address(this));
        // console.logAddress(address(usdrCoin));
        // console.logAddress(address(msg.sender));
        tokenAddresses.push(wethTokenAddress);
        tokenAddresses.push(wbtcTokenAddress);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);
        // constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _UsdrAddress) {
        usdrEngine = new UsdrEngine(tokenAddresses, priceFeedAddresses); //, address(usdrCoin)
        usdrCoin = usdrEngine.getUsdrCoin();
        vm.stopBroadcast();
        return (usdrCoin, usdrEngine, helperConfig);
    }
}
