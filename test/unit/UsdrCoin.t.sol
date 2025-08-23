// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {UsdrCoin} from "../../src/USDRCoin.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract UsdrCoinTest is Test {
    UsdrCoin private dsc;
    address account = makeAddr("Romario");

    function setUp() public {
        dsc = new UsdrCoin(msg.sender);
    }

    function testMustMintMoreThanZero() public {
        // vm.prank(dsc.owner);
        vm.startPrank(dsc.owner());
        vm.expectRevert();
        dsc.mint(address(this), 0);
        vm.stopPrank();
    }

    function testCanBurnLessThanYouHave() public {
        // vm.prank(dsc.owner);
        vm.startPrank(dsc.owner());
        dsc.mint(account, 10);
        // vm.expectRevert();
        dsc.burnFrom(account, 9);
        vm.stopPrank();
    }

    function testCantBurnMoreThanYouHave() public {
        vm.startPrank(dsc.owner());
        dsc.mint(account, 10);
        vm.expectRevert();
        dsc.burnFrom(account, 11);
        vm.stopPrank();
    }

    function testCantBurnFromOtherAccount() public {
        // vm.prank(dsc.owner);
        vm.startPrank(dsc.owner());
        dsc.mint(address(this), 10);
        vm.expectRevert();
        dsc.burn(9);
        vm.stopPrank();
    }

    function testCanBurnMyCoin() public {
        // vm.prank(dsc.owner);
        vm.startPrank(msg.sender);
        dsc.mint(msg.sender, 10);
        // vm.expectRevert();
        dsc.burnMyCoin(9);
        vm.stopPrank();
    }
}
