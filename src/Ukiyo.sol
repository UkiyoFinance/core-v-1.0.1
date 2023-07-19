//SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract Ukiyo is ERC20 {
    error NotOwner();
    error NotTreasury();
    error TestError();
    error UnderInitialSupply();

    event SetAndRenounce(address indexed sender, address indexed treasury, address indexed newOwner, bool renounced);

    struct Owner {
        address controller;
        bool renounced;
    }

    Owner public owner;
    address public treasury;

    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol, decimals) {
        owner.controller = msg.sender;
        owner.renounced = false;
        _mint(msg.sender, 1e18);
    }

    modifier onlyTreasury() {
        if (msg.sender != address(treasury)) revert NotTreasury();
        _;
    }

    function setTreasuryAndRenounce(address _treasury) external {
        if (msg.sender != owner.controller || owner.renounced == true) revert NotOwner();
        treasury = _treasury;
        owner.controller = address(0);
        owner.renounced = true; //Just incase someone ever finds the private key to address(0) :)
        emit SetAndRenounce(msg.sender, _treasury, owner.controller, owner.renounced);
    }

    function mint(uint256 amount, address to) external onlyTreasury {
        _mint(to, amount);
    }

    function burn(uint256 amountToBurn, address from) external onlyTreasury {
        _burn(from, amountToBurn);
        if (totalSupply < 1e18) revert UnderInitialSupply();
    }

    function burnExcess(uint256 amount) external onlyTreasury {
        _burn(treasury, amount);
    }

    function supply() external view returns (uint256) {
        return totalSupply;
    }
}
