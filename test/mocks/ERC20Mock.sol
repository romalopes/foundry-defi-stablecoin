// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
// import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract ERC20Mock is ERC20 {
    // mapping(address account => mapping(address spender => uint256)) private _allowances;

    constructor(string memory name, string memory symbol, address initialAccount, uint256 initialBalance)
        payable
        ERC20(name, symbol)
    {
        _mint(initialAccount, initialBalance);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }

    // function _approve(address owner, address spender, uint256 amount) internal virtual override {
    //     _allowances[owner][spender] = amount;
    //     emit Approval(owner, spender, amount);
    // }

    // function approve(address spender, uint256 amount) public virtual override returns (bool) {
    //     _approve(_msgSender(), spender, amount);
    //     return true;
    // }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        // uint256 currentAllowance = allowance(_msgSender(), spender);
        console.log("_msgSender():", _msgSender());
        console.log("spender:", spender);
        console.log("amount:", amount);
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual override {
        super._approve(owner, spender, amount);
    }
}
