//SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

interface IFraxMinter {
    function submitAndDeposit(address) external payable returns (uint256 shares);
}
