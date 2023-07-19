//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import "./BaseTest.sol";

contract HandlerTest is BaseTest {

    address alice = address(0x1337);

    function setUp() public {
        deploy();
        deployLiquidity();
        deal(alice, 100 ether);
    }

    // function testPurchaseFail(uint256 x) external {
    //     vm.expectRevert();
    //     handler.purchaseTokens(x, 100, address(this));
    // }

    // function testInitializeFail(address x) public {
    //     vm.expectRevert();
    //     vm.prank(x);
    //     handler.inititalizeAuction(0, 0,0,0);
    // } 

    // function testSetTreasuryFail(address x, address y) external {
    //     vm.expectRevert();
    //     vm.prank(y);
    //     handler.setTreasuryAndPoolManager(x, x);

    // }

    // function testStartRebalance(address x) public {
    //     vm.expectRevert();
    //     vm.prank(x);
    //     handler.rebalancing();
    // }

    //   function testEndRebalance(address x) public {
    //     vm.expectRevert();
    //     vm.prank(x);
    //     handler.doneRebalancing();
    // }

    // function testRebalance(address x) public {
    //     vm.expectRevert();
    //     vm.prank(x);
    //     handler.rebalancePool(1, 1, 1, 1, false, false);
    // }

    function testRewards(uint256 x) external {
        vm.assume(x > .001 ether && x < 10000 ether);
        weth.deposit{value: x}();
        treasury.mint{value: x}();
        vm.prank(address(handler));
        ukiyo.approve(address(treasury), type(uint256).max);
        ukiyo.transfer(address(handler), x / 2);
        weth.transfer(address(handler), x);
        handler.distributeWeth();
        handler.distributeUkiyo();
        assertEq(ukiyo.balanceOf(address(handler)), 0);
        assertEq(weth.balanceOf(address(handler)), 0);
    }
}