// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployUsdr} from "script/DeployUsdr.s.sol";
import {UsdrEngine} from "src/UsdrEngine.sol";
import {UsdrCoin} from "src/UsdrCoin.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";

contract UsdrEngineTest is Test {
    uint256 private AMOUNT = 1 ether;
    address public user = makeAddr("user");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    uint256 private constant ADDITIONAL_FEE_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralization
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;

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
        (wethUsdPriceFeed, wbtcUsdPriceFeed, wethTokenAddress, wbtcTokenAddress, deployerKey) =
            helperConfig.activeNetworkConfig();
        if (block.chainid == 31337) {
            vm.deal(user, STARTING_USER_BALANCE);
            ERC20Mock(wethTokenAddress).mint(user, STARTING_USER_BALANCE);
            ERC20Mock(wbtcTokenAddress).mint(user, STARTING_USER_BALANCE);
        }
    }

    address[] tokenAddresses;
    address[] priceFeedAddresses;

    function testConstructoRevertIfTokenLenghtDoesntMatchPriceFeedsLenght() public {
        tokenAddresses = [wbtcTokenAddress];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.expectRevert(
            abi.encodeWithSelector(
                UsdrEngine.UsdrEngine_ErrorArrayofAddressesAreDifferent.selector,
                tokenAddresses.length,
                priceFeedAddresses.length
            )
        );
        new UsdrEngine(tokenAddresses, priceFeedAddresses);
        // if (_tokenAddresses.length != _priceFeedAddresses.length) {
        //             revert UsdrEngine_ErrorArrayofAddressesAreDifferent(_tokenAddresses.length, _priceFeedAddresses.length);
        //         }
        // assertEq(usdrEngine.getUsdrCoin(), usdrCoin);
    }

    function testConstructoWithTokenLenghtMatchingPriceFeedsLenght() public {
        tokenAddresses = [wbtcTokenAddress, wbtcTokenAddress];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        new UsdrEngine(tokenAddresses, priceFeedAddresses);
    }

    function testGetUsdrCoin() public view {
        // assertEq(usdrEngine.getUsdrCoin(), usdrCoin);
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
        bool success = ERC20Mock(wethTokenAddress).approve(address(usdrEngine), AMOUNT_COLLATERAL);
        require(success, "Approval failed");
        vm.expectRevert(abi.encodeWithSelector(UsdrEngine.UsdrEngine_ErrorAmountMustBeMoreThanZero.selector, 0));
        usdrEngine.depositCollateral(wethTokenAddress, 0);
        vm.stopPrank();
    }

    function testCollateralGreaterThanZeroSuccess() public {
        console.log("msg.sender:", msg.sender);
        vm.prank(user);
        // console.log("owner:", UsdrCoin(wethTokenAddress).owner());
        bool success = ERC20Mock(wethTokenAddress).approve(address(usdrEngine), AMOUNT_COLLATERAL);
        require(success, "Approval failed");
        console.log("address(usdrEngine):", address(usdrEngine));
        console.log("address(this):", address(this));
        console.log("allowance: ", ERC20Mock(wethTokenAddress).allowance(address(this), address(this)));
        uint256 allowanceAmount = ERC20Mock(wethTokenAddress).allowance(
            address(0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D), address(usdrEngine)
        );
        console.log("allowanceAmount:", allowanceAmount);

        usdrEngine.depositCollateral(wethTokenAddress, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether; // usd
        // 100 / 4000
        uint256 expectedWeth = 0.025 ether;
        uint256 actualWeth = usdrEngine.getTokenAmountFromUsd(wethTokenAddress, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    function testDepositCollateral() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(UsdrEngine.UsdrEngine_ErrorAmountMustBeMoreThanZero.selector, 0));
        usdrEngine.depositCollateral(wethTokenAddress, 0);
        vm.stopPrank();
        // assertEq(usdrCoin.balanceOf(user), AMOUNT);
        // usdrEngine.depositCollateral(wbtcTokenAddress, AMOUNT);
        // assertEq(usdrCoin.balanceOf(user), 2 * AMOUNT);
    }

    // function testDepositCollateralSuccess() public {
    //     vm.prank(user);
    //     ERC20Mock(wethTokenAddress).approve(address(usdrEngine), 100 ether);
    //     usdrEngine.depositCollateral(wethTokenAddress, AMOUNT_COLLATERAL);
    //     vm.stopPrank();
    //     assertEq(usdrCoin.balanceOf(user), AMOUNT);
    //     usdrEngine.depositCollateral(wbtcTokenAddress, AMOUNT);
    //     assertEq(usdrCoin.balanceOf(user), 2 * AMOUNT);
    // }

    function testRevertWithUnapprovedCollateralAddress() public {
        vm.prank(user);
        ERC20Mock randomToken = new ERC20Mock("Test", "Test", user, AMOUNT_COLLATERAL);
        vm.expectRevert(abi.encodeWithSelector(UsdrEngine.UsdrEngine_TokenNotAlowed.selector, randomToken));
        usdrEngine.depositCollateral(address(randomToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollaral() {
        vm.prank(user);
        // ERC20Mock(wethTokenAddress).approve(address(usdrEngine), AMOUNT_COLLATERAL);
        bool success = ERC20Mock(wethTokenAddress).approve(address(usdrEngine), AMOUNT_COLLATERAL);
        require(success, "Approval failed");
        usdrEngine.depositCollateral(wethTokenAddress, AMOUNT_COLLATERAL);
        vm.stopPrank();

        _;
    }

    // error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    // function testCanDepositCollateralAndGetInfoAccont() public depositedCollaral {
    //     (uint256 totalUsdrMinted, uint256 totalCollateralValueInUsdr) = usdrEngine.getAccountInformation(user);

    //     uint256 expectedTotalUsdrMinder = 0;
    //     // 10ether * $4000 = $40000
    //     uint256 expectedTotalCollateralValueInUsdr =
    //         usdrEngine.getTokenAmountFromUsd(wethTokenAddress, totalCollateralValueInUsdr);
    //     assertEq(totalUsdrMinted, expectedTotalUsdrMinder);
    //     assertEq(AMOUNT_COLLATERAL, expectedTotalCollateralValueInUsdr);
    // }

    // function testLiquidateSuccess() public {
    //     // Arrange
    //     uint256 debtToCover = 100 ether;
    //     uint256 tokenAmountFromDebtCovered = usdrEngine.getTokenAmountFromUsd(wethTokenAddress, debtToCover);
    //     uint256 bonusColateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
    //     uint256 totalCollateraltoRedeem = tokenAmountFromDebtCovered + bonusColateral;

    //     // Act
    //     vm.prank(address(this));
    //     usdrEngine.liquidate(wethTokenAddress, user, debtToCover);

    //     // Assert
    //     assertEq(usdrEngine.getCollateralBalanceOfUser(user, wethTokenAddress), totalCollateraltoRedeem);
    //     assertEq(usdrEngine.getCollateralBalanceOfUser(user), 0);
    // }

    // function testLiquidate_HealthFactorTooHigh_Reverts() public {
    //     // Arrange
    //     uint256 debtToCover = 100 ether;
    //     vm.prank(address(this));
    //     // usdrEngine.mint(user, 200 ether); // Increase health factor above MIN_HEALTH_FACTOR

    //     // Act and Assert
    //     vm.expectRevert(UsdrEngine.UsdrEngine_HealthFactorTooHigh.selector);
    //     vm.prank(address(this));
    //     usdrEngine.liquidate(wethTokenAddress, user, debtToCover);
    // }

    // function testLiquidate_DebtToCoverIsZero_Reverts() public {
    //     // Arrange
    //     uint256 debtToCover = 0;

    //     // Act and Assert
    //     vm.expectRevert(UsdrEngine.UsdrEngine_ErrorAmountMustBeMoreThanZero.selector, debtToCover);
    //     vm.prank(address(this));
    //     usdrEngine.liquidate(wethTokenAddress, user, debtToCover);
    // }

    // function testLiquidate_EndingHealthFactorNotImproved_Reverts() public {
    //     // Arrange
    //     uint256 debtToCover = 100 ether;
    //     vm.prank(address(this));
    //     usdrEngine.mint(user, 100 ether); // Decrease health factor

    //     // Act and Assert
    //     vm.expectRevert(UsdrEngine.UsdrEngine_ErrorHealthFactorNotImproved.selector, 0, 0);
    //     vm.prank(address(this));
    //     usdrEngine.liquidate(wethTokenAddress, user, debtToCover);
    // }
}

// uint256 startingUserHealthFactor, uint256 endingUserHealthFactor);
