//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "./BaseTest.sol";

contract UkiyoPoolManagerTest is BaseTest {
    address alice = address(0x1337);

    function setUp() public {
        deploy();
        deployLiquidity();
        deal(alice, 100 ether);
    }

    // function testRebalance(uint256 x) public {
    //     vm.assume(x > .001 ether && x < 10000 ether);
    //     treasury.mint{value: x}();
    //     uint256 uBalance = ukiyo.balanceOf(address(uniPool));
    //     uint256 wBalance = weth.balanceOf(address(uniPool));
    //     vm.expectRevert();
    //     vm.prank(alice);
    //     poolManager.rebalance();
    //     poolManager.rebalance();
    //     assertApproxEqAbs(weth.balanceOf(uniPool), 0, 10);
    //     assertApproxEqAbs(ukiyo.balanceOf(uniPool), 0, 10);
    //     assertApproxEqAbs(ukiyo.balanceOf(address(handler)), uBalance, 10);
    //     assertApproxEqAbs(weth.balanceOf(address(handler)), wBalance, 10);
    // }

    function testRebalanceExecution(uint256 x) public {
        vm.assume(x > .0001 ether && x < 10000 ether);
        handler.approvals();
        poolManager.rebalance();
        assertEq(handler.currentlyRebalancing(), true);
        treasury.mint{value: x}();
        weth.deposit{value: x}();
        ukiyo.transfer(address(handler), ukiyo.balanceOf(address(this)));
        weth.transfer(address(handler), weth.balanceOf(address(this)));
        vm.expectRevert();
        handler.distributeUkiyo();
        vm.expectRevert();
        handler.distributeWeth();
        vm.expectRevert();
        vm.prank(alice);
        handler.rebalancePool(-1000, 1000, x / 2, x / 2, true, false);
        handler.rebalancePool(-1000, 1000, x / 2, x / 2, true, false);
        assertEq(handler.currentlyRebalancing(), true);
        handler.rebalancePool(-1000, 1000, x / 5, x / 5, false, false);
        assertEq(handler.currentlyRebalancing(), true);
        handler.rebalancePool(0, 0, 0, 0, false, true);
        assertEq(handler.currentlyRebalancing(), false);
        handler.distributeWeth();
    }

    function testMigration() public {}
}