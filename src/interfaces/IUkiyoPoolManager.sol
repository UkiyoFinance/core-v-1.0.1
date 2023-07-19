//SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IUkiyoPoolManager {
    function handlerRebalance(int24, int24, uint256, uint256, bool, bool) external;
    function liquidityId() external returns (uint256);
}
