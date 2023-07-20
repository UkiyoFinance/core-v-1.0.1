//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./BaseTest.sol";
import {IERC20} from "oz/contracts/token/ERC20/IERC20.sol";



contract UkiyoTest is BaseTest {
    address private _fraxEth = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public alice = address(0x1337);

    function setUp() public {
        deploy();
        deployLiquidity();
        deal(alice, 100 ether);
    }

    function testTreasuryMint(uint256 amount) public {
        vm.assume(amount > 0.001 ether && amount < 1000 ether);
        uint256 lpWethBalanceBefore = weth.balanceOf(address(uniPool));
        treasury.mint{value: amount}();
        treasury.currentBacking();
        assertEq(ukiyo.totalSupply(), 1e18 + amount);
        assertEq(weth.balanceOf(uniPool), lpWethBalanceBefore + (amount * 1500 / 10000));
        assertEq(weth.balanceOf(address(poolManager)), 0);
        assertEq(weth.balanceOf(address(treasury)), 0);
        assertEq(ukiyo.balanceOf(address(poolManager)), 0);
        assertEq(ukiyo.balanceOf(address(treasury)), 0);
        assertApproxEqAbs(1e18, treasury.currentBacking(), 100000);
        vm.expectRevert();
        treasury.mint{value: 0}();
        treasury.mint{value: amount / 2}();
        treasury.mint{value: amount / 2}();
        treasury.mint{value: amount / 2}();
        treasury.mint{value: amount / 2}();
    }

    function testTreasuryBurnFull(uint256 amount) public {
        vm.assume(amount > 0.0001 ether && amount < 10000 ether);
        uint256 lpWethBalanceBefore = weth.balanceOf(address(uniPool));
        treasury.mint{value: amount}();
        emit log_uint(poolManager.ukiyoAmountForLiquidity());
        ukiyo.approve(address(treasury), type(uint256).max);
        treasury.burn(ukiyo.balanceOf(address(this)) / 2);
        treasury.burn(ukiyo.balanceOf(address(this)));
        vm.startPrank(address(0x667ed630A19fD25fA19145bcdbb06d4D7E24228b));
        ukiyo.approve(address(treasury), type(uint256).max);
        treasury.burn(ukiyo.balanceOf(address(0x667ed630A19fD25fA19145bcdbb06d4D7E24228b)));
        vm.stopPrank();
        emit log_uint(ukiyo.balanceOf(address(uniPool)));
        assertGt(IERC20(_fraxEth).balanceOf(address(treasury)), 0);
        assertApproxEqAbs(lpWethBalanceBefore, weth.balanceOf(address(uniPool)), 100);
        assertApproxEqAbs(ukiyo.totalSupply(), 1e18, 100);
        assertEq(ukiyo.balanceOf(address(treasury)), 0);
        assertEq(ukiyo.balanceOf(address(this)), 0);
        assertEq(ukiyo.balanceOf(address(0x01)), 0);
    }

    function testRebalance() public {
        treasury.mint{value: 1e18}();
    }

    function testMigration() public {
        treasury.mint{value: 1e18}();
        treasury.initializeMigration();
        vm.expectRevert(UkiyoTreasury.Timelock.selector);
        vm.warp(1);
        treasury.migrate(address(this));
        vm.warp(1691837416);
        emit log_uint(block.timestamp);
        treasury.migrate(address(this));
    }

    function testHandler() public {}

    function testBorrow(uint256 amount) public {
        vm.assume(amount > 0.0001 ether && amount < 10000 ether);
        treasury.mint{value: amount}();
        ukiyo.approve(address(treasury), type(uint256).max);
        uint256 desiredAmount = IERC20(_fraxEth).balanceOf(address(treasury)) * 3 / 10;
        uint256 startingBalance = ukiyo.balanceOf(address(this)) / 2;
        treasury.borrow(startingBalance, desiredAmount);
        assertEq(treasury.activeLoanAmounts(), desiredAmount);
        UkiyoTreasury.Loan memory loan = UkiyoTreasury.Loan({
            collateral: uint128(startingBalance),
            borrowed: uint128(desiredAmount),
            startingDecay: 1e18
        });

        assertEq(loan.collateral, treasury.getLoan(address(this)).collateral);
        assertEq(loan.borrowed, treasury.getLoan(address(this)).borrowed);
        assertEq(loan.startingDecay, treasury.getLoan(address(this)).startingDecay);
        vm.warp(1699797415);
        treasury.addCollateral(uint128(ukiyo.balanceOf(address(this))));
        treasury.borrow(0, 100);
        assertGt(treasury.getLoan(address(this)).collateral, startingBalance);
    }

    function testBurnCallbackShouldFail(address x) public {
        vm.assume(x != address(0) && x != address(poolManager) && x != address(handler));
        vm.startPrank(x);
        vm.expectRevert();
        treasury.liquidityBurnCallback(100);
        vm.expectRevert();
        treasury.burnFees(100);
        vm.stopPrank();
    }


    function testRepay(uint256 amount) public {
        vm.assume(amount > 0.0001 ether && amount < 10000 ether);
        treasury.mint{value: amount}();

        ukiyo.approve(address(treasury), type(uint256).max);
        uint256 desiredAmount = IERC20(_fraxEth).balanceOf(address(treasury)) * 3 / 10;
        uint256 startingBalance = ukiyo.balanceOf(address(this));
        uint256 startingTreasuryBalance = IERC20(_fraxEth).balanceOf(address(treasury));
        treasury.borrow(startingBalance, desiredAmount);

        IERC20(_fraxEth).approve(address(treasury), type(uint256).max);
        treasury.repay(IERC20(_fraxEth).balanceOf(address(this)));
        treasury.removeCollateral(treasury.getLoan(address(this)).collateral / 2);
        assertEq(IERC20(_fraxEth).balanceOf(address(treasury)), startingTreasuryBalance);
        assertEq(
            ukiyo.balanceOf(address(this)),
            startingBalance - (treasury.decayedUkiyo() + treasury.getLoan(address(this)).collateral)
        );
        assertEq(treasury.getLoan(address(this)).borrowed, 0);
        assertEq(treasury.activeLoanAmounts(), 0);
        assertEq(
            ukiyo.balanceOf(address(treasury)), treasury.decayedUkiyo() + treasury.getLoan(address(this)).collateral
        );
        assertEq(
            treasury.getLoan(address(this)).collateral, ukiyo.balanceOf(address(treasury)) - treasury.decayedUkiyo()
        );
    }

    function testRemoveAllCollateral(uint256 amount) public {
        vm.assume(amount > 0.0001 ether && amount < 10000 ether);
        treasury.mint{value: amount}();
        ukiyo.approve(address(treasury), type(uint256).max);
        uint256 startingBalance = ukiyo.balanceOf(address(this));
        treasury.addCollateral(uint128(ukiyo.balanceOf(address(this))));
        emit log_uint(treasury.getLoan(address(this)).collateral);
        treasury.removeAllCollateral();
       vm.warp(1699797415);

        UkiyoTreasury.Loan memory userLoan = treasury.getLoan(address(this));
        assertEq(userLoan.collateral, 0);
        assertEq(userLoan.borrowed, 0);
        assertEq(userLoan.startingDecay, 0);
        assertEq(ukiyo.balanceOf(address(treasury)), 0);
        assertEq(ukiyo.balanceOf(address(this)), startingBalance);

        uint256 transferAmount = ukiyo.balanceOf(address(this)) / 2;
        ukiyo.transfer(alice, transferAmount);

        vm.startPrank(alice);
        ukiyo.approve(address(treasury), type(uint256).max);
        treasury.borrow(ukiyo.balanceOf(address(alice)), 100);
        vm.stopPrank();

        treasury.addCollateral(uint128(ukiyo.balanceOf(address(this))));
       vm.warp(1709797415);
        treasury.removeAllCollateral();
        UkiyoTreasury.Loan memory userLoan2 = treasury.getLoan(address(this));
        assertEq(userLoan2.collateral, 0);
        assertEq(userLoan2.borrowed, 0);
        assertEq(userLoan2.startingDecay, 0);
        assertApproxEqAbs(ukiyo.balanceOf(address(treasury)), transferAmount, 2);
        assertApproxEqAbs(ukiyo.balanceOf(address(this)), transferAmount, 2);
    }

    function testAddCollateral(uint256 amount) public {
        vm.assume(amount > 0.0001 ether && amount < 10000 ether);
        treasury.mint{value: amount}();
        ukiyo.approve(address(treasury), type(uint256).max);
        uint128 depositAmount = uint128(ukiyo.balanceOf(address(this)));
        treasury.addCollateral(depositAmount);

        UkiyoTreasury.Loan memory loan = treasury.getLoan(address(this));
        assertEq(loan.collateral, depositAmount);
        assertEq(ukiyo.balanceOf(address(treasury)), depositAmount);
    }

    function testBurnDecayed(uint256 amount) public {
        vm.assume(amount > 0.0001 ether && amount < 10000 ether);
        treasury.mint{value: amount}();
        ukiyo.approve(address(treasury), type(uint256).max);
        treasury.borrow(ukiyo.balanceOf(address(this)) / 2, amount / 7);
        emit log_uint(block.timestamp);
        vm.warp(1699797415);
        treasury.addCollateral(1);
        assertGt(treasury.decayedUkiyo(), 0);
        treasury.burnDecayedUkiyo();
        assertEq(treasury.decayedUkiyo(), 0);
    }

    function testMintNewPosition() public {
        weth.deposit{value: 1 ether}();
        treasury.mint{value: 1e18}();
        ukiyo.approve(address(poolManager), type(uint256).max);
        weth.approve(address(poolManager), type(uint256).max);
        vm.expectRevert();
        vm.prank(alice);
        poolManager.mintNewPosition(1e18, 1e18, -3000, 3000);
        poolManager.mintNewPosition(ukiyo.balanceOf(address(this)), 1e18, -3000, 4000);
        assertEq(weth.balanceOf(address(poolManager)), 0);
        assertEq(ukiyo.balanceOf(address(poolManager)), 0);
    }

    function testIncreaseLiquidity() public {
        weth.deposit{value: 1e18}();
        treasury.mint{value: 1e18}();
        uint256 amount = ukiyo.balanceOf(address(this));
        weth.transfer(address(treasury), 1e18);
        ukiyo.transfer(address(poolManager), amount);
        vm.startPrank(address(treasury));
        uint256 tokenId = poolManager.liquidityId();
        poolManager.increaseLiquidityCurrentRange(tokenId, 1e18, amount);
        vm.stopPrank();
    }
}
