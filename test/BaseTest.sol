//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/src/Test.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC721Receiver} from "oz/contracts/token/ERC721/IERC721Receiver.sol";
import {Ukiyo} from "../src/Ukiyo.sol";
import {UkiyoTreasury} from "../src/UkiyoTreasury.sol";
import {UkiyoPoolManager} from "../src/UkiyoPoolManager.sol";
import {FeeHandler} from "../src/FeeHandler.sol";
import {ISwapRouter} from "../src/interfaces/ISwapRouter.sol";

contract BaseTest is Test, IERC721Receiver {
    IUniswapV3Factory public factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    ISwapRouter public router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IWETH9 public weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    Ukiyo public ukiyo;
    UkiyoTreasury public treasury;
    UkiyoPoolManager public poolManager;
    FeeHandler public handler;
    address uniPool;

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function deploy() public {
        ukiyo = new Ukiyo("Ukiyo", "UKY", 18);
        (,, address pool) = initializePool();
        handler = new FeeHandler(address(ukiyo));
        poolManager = new UkiyoPoolManager(pool);
        treasury = new UkiyoTreasury(address(ukiyo), address(poolManager), address(handler));
        ukiyo.setTreasuryAndRenounce(address(treasury));
        poolManager.setTreasuryAndHandler(address(treasury), address(handler));
        handler.setTreasuryAndPoolManager(address(treasury), address(poolManager));
    }

    function initializePool() public returns (address, address, address pool) {
        pool = factory.createPool(address(ukiyo), address(weth), 10000);
        IUniswapV3Pool(pool).initialize(2 ** 96);
        uniPool = pool;
        return (IUniswapV3Pool(pool).token0(), IUniswapV3Pool(pool).token1(), pool);
    }

    function deployLiquidity() public {
        weth.deposit{value: 2e18}();
        weth.approve(address(poolManager), type(uint256).max);
        weth.approve(address(treasury), type(uint256).max);
        ukiyo.approve(address(poolManager), type(uint256).max);
        poolManager.mintNewPosition(1e18, 1e18, -7000, 15000);
    }
}
