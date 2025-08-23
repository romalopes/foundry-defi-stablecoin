// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployUsdr} from "script/DeployUsdr.s.sol";
import {UsdrEngine} from "src/UsdrEngine.sol";
import {UsdrCoin} from "src/UsdrCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "openzeppelin-contracts/mocks/token/ERC20Mock.sol";
import {console} from "forge-std/console.sol";

contract UsdrEngineTest is Test {
    uint256 private AMOUNT = 1 ether;
    address public user = makeAddr("user");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant AMONT_COLLATERAL = 10 ether;

    DeployUsdr deployUsdr;
    UsdrCoin usdrCoin;
    UsdrEngine usdrEngine;
    HelperConfig helperConfig;
    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address wethTokenAddress;
    address wbtcTokenAddress;
    uint256 deployerKey;

    function setUp() external {
        deployUsdr = new DeployUsdr();
        (usdrCoin, usdrEngine, helperConfig) = deployUsdr.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, wethTokenAddress, wbtcTokenAddress, deployerKey) =  helperConfig.activeNetworkConfig();
         if (block.chainid == 31337) {
            vm.deal(user, STARTING_USER_BALANCE);
            ERC20Mock(wethTokenAddress).mint(user, STARTING_USER_BALANCE);
            ERC20Mock(wbtcTokenAddress).mint(user, STARTING_USER_BALANCE);
        }
    }

    function testGetUsdValue() public view {
        if (block.chainid == 31337) {
            uint256 ethAmount = 1.5e18;
            uint256 usdValue = usdrEngine.getUsdValue(wethTokenAddress, AMOUNT);
            console.log("AMOUNT:", AMOUNT);
            console.log("usdValue:", usdValue);
            assertEq(usdValue, 4000e18);
            usdValue = usdrEngine.getUsdValue(wethTokenAddress, ethAmount);
            console.log("ethAmount:", ethAmount);
            console.log("usdValue:", usdValue);
            assertEq(usdValue, 6000e18);
            usdValue = usdrEngine.getUsdValue(wbtcTokenAddress, AMOUNT);
            console.log("usdValue:", usdValue);
            assertEq(usdValue, 100000e18);
            uint256 btcAmount = 1.5e18;
            usdValue = usdrEngine.getUsdValue(wbtcTokenAddress, btcAmount);
            console.log("usdValue:", usdValue);
            assertEq(usdValue, 150000e18);
        }
    }

    function testRevertIfCollateralIsZero() public {
        vm.prank(user);
        ERC20Mock(wethTokenAddress).approve(user, AMONT_COLLATERAL);
        // vm.expectRevert(UsdrEngine.UsdrEngine_ErrorAmountMustBeMoreThanZero(AMONT_COLLATERAL).selector);
        vm.expectRevert(abi.encodeWithSelector(UsdrEngine.UsdrEngine_ErrorAmountMustBeMoreThanZero.selector, 0));
        usdrEngine.depositCollateral(wethTokenAddress, 0);

    }

    function testDepositCollateral() public {
        // usdrEngine.depositCollateral(wethTokenAddress, AMOUNT);
        // assertEq(usdrCoin.balanceOf(user), AMOUNT);
        // usdrEngine.depositCollateral(wbtcTokenAddress, AMOUNT);
        // assertEq(usdrCoin.balanceOf(user), 2 * AMOUNT);

    }
}

