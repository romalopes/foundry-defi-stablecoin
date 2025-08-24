// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/*
 * @title: Decentralized Stabe Coin
 * Collateral: BTC & ether
 * Minting: Algoritimic
 * Relative stability: Pegged to USD
 * @dev
 *
 */
contract UsdrCoin is ERC20Burnable, Ownable {
    //Errors
    error UsdrCoin_ErrorAmountMustBeMoreThanZero(uint256);
    error UsdrCoin_BalanceLowerThanAmount(uint256, uint256);
    error UsdrCoin_ErrorNotZeroAddress();

    constructor(address account) ERC20("USD Stable Coin Roma", "USRD") Ownable(account) {}

    /*
        Burn the amount 
    */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert UsdrCoin_ErrorAmountMustBeMoreThanZero(_amount);
        }
        if (balance < _amount) {
            revert UsdrCoin_BalanceLowerThanAmount(balance, _amount);
        }
        super.burn(_amount);
    }

    function burnFromContract(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert UsdrCoin_ErrorNotZeroAddress();
        }
        if (_amount <= 0) {
            revert UsdrCoin_ErrorAmountMustBeMoreThanZero(_amount);
        }

        _mint(_to, _amount);
        return true;
    }

    function burnFrom(address account, uint256 amount) public override onlyOwner {
        uint256 balance = balanceOf(account);
        if (amount == 0) {
            revert UsdrCoin_ErrorAmountMustBeMoreThanZero(amount);
        }
        if (balance < amount) {
            revert UsdrCoin_BalanceLowerThanAmount(balance, amount);
        }
        _burn(account, amount); // Direct burn, no allowance needed
    }

    function burnMyCoin(uint256 amount) public {
        uint256 balance = balanceOf(msg.sender);
        if (amount == 0) {
            revert UsdrCoin_ErrorAmountMustBeMoreThanZero(amount);
        }
        if (balance < amount) {
            revert UsdrCoin_BalanceLowerThanAmount(balance, amount);
        }
        _burn(msg.sender, amount); // Direct burn, no allowance needed
    }
}
