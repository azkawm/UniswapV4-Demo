// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PoolKey} from "@v4-core/types/PoolKey.sol";
import {IPoolInitializer_v4} from "@v4-periphery/interfaces/IPoolInitializer_v4.sol";
import {PRBLiquidityAmounts} from "../src/libraries/PRBLiquidityAmounts.sol";
import {PriceMath} from "../src/libraries/PriceMath.sol";
import {Currency} from "@v4-core/types/Currency.sol";
import {IHooks} from "@v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "@v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "@v4-periphery/interfaces/IPositionManager.sol";
import {Actions} from "@v4-periphery/libraries/Actions.sol";
import {TickMath} from "@v4-core/libraries/TickMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {MockERC20} from "../src/mocks/MockToken.sol";
import {MockUSD} from "../src/mocks/MockUSD.sol";

contract PoolTest is Test {

    IPoolManager public immutable poolManager = IPoolManager(0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32);
    IPositionManager public immutable posm = IPositionManager(0xd88F38F930b7952f2DB2432Cb002E7abbF3dD869);
    IAllowanceTransfer public immutable permit2 = IAllowanceTransfer(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IPositionManager public immutable positionManager = posm;

    MockERC20 mockToken;
    MockUSD mockUSD;
    address currency0;
    address currency1;
    uint24 lpFee;
    int24 tickSpacing;

    uint160 startingPrice = 79228162514264337593543950336;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARB_MAINNET_RPC"));

        mockUSD = new MockUSD();
        mockToken = new MockERC20("Orga Token", "OGR");

        currency0 = address(mockToken);
        currency1 = address(mockUSD);
        

        lpFee = 3000;
        tickSpacing = 60;

        deal(currency0, address(this), 1000e18);
        deal(currency1, address(this), 1000e6);
    }

    function test_PoolAndInitialize() public {
        //address currency0
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        poolManager.initialize(pool, 79228162514264337593543950336);
    }

    function test_PoolAndInitialize_Multicall() public {

        bytes[] memory params = new bytes[](2);

         PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        params[0] = abi.encodeWithSelector(
        IPoolInitializer_v4.initializePool.selector,
        pool,
        startingPrice
        );

        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        // Convert sqrt price to tick
        int24 currentTick = TickMath.getTickAtSqrtPrice(startingPrice);
        int24 tickLower = (currentTick / tickSpacing * tickSpacing) - 10 * tickSpacing; // 1000 ticks below current price
        int24 tickUpper = (currentTick / tickSpacing * tickSpacing) + 10 * tickSpacing; // 1000 ticks above current price

        uint160 sqrtPriceX96A = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceX96B = TickMath.getSqrtPriceAtTick(tickUpper);
        uint256 amount0Max = 1000e18;
        uint256 amount1Max = 1000e6;

        uint128 liquidity = PRBLiquidityAmounts.getLiquidityForAmounts(startingPrice, sqrtPriceX96A, sqrtPriceX96B, amount0Max, amount1Max);

        bytes[] memory mintParams = new bytes[](2);
        mintParams[0] = abi.encode(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, address(this), "");
        mintParams[1] = abi.encode(pool.currency0, pool.currency1);

        uint256 deadline = block.timestamp + 3600; // 1 hour deadline
        params[1] = abi.encodeWithSelector(
        posm.modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
        );

        // approve permit2 as a spender
        IERC20(currency0).approve(address(permit2), type(uint256).max);
        IERC20(currency1).approve(address(permit2), type(uint256).max);

        // approve `PositionManager` as a spender
        permit2.approve(currency0, address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(currency1, address(positionManager), type(uint160).max, type(uint48).max);

        posm.multicall(params);
    }

    function test_PoolAndInitialize_Multicall_Single() public {
        bytes[] memory params = new bytes[](2);

         PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0))
        });

        params[0] = abi.encodeWithSelector(
        IPoolInitializer_v4.initializePool.selector,
        pool,
        startingPrice
        );

        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        // Convert sqrt price to tick
        int24 currentTick = TickMath.getTickAtSqrtPrice(startingPrice);
        int24 tickLower = (currentTick / tickSpacing * tickSpacing) - 10 * tickSpacing; // 1000 ticks below current price
        int24 tickUpper = (currentTick / tickSpacing * tickSpacing) + 10 * tickSpacing; // 1000 ticks above current price

        uint160 sqrtPriceX96A = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtPriceX96B = TickMath.getSqrtPriceAtTick(tickUpper);
        uint256 amount0Max = 1000e18;
        uint256 amount1Max = 1000e6;

        uint128 liquidity = PRBLiquidityAmounts.getLiquidityForAmounts(startingPrice, sqrtPriceX96A, sqrtPriceX96B, amount0Max, amount1Max);


        bytes[] memory mintParams = new bytes[](2);
        mintParams[0] = abi.encode(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, address(this), "");
        mintParams[1] = abi.encode(pool.currency0, pool.currency1);

        uint256 deadline = block.timestamp + 3600; // 1 hour deadline
        params[1] = abi.encodeWithSelector(
        posm.modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
        );

        // approve permit2 as a spender
        IERC20(currency0).approve(address(permit2), type(uint256).max);
        IERC20(currency1).approve(address(permit2), type(uint256).max);

        // approve `PositionManager` as a spender
        permit2.approve(currency0, address(positionManager), type(uint160).max, type(uint48).max);
        permit2.approve(currency1, address(positionManager), type(uint160).max, type(uint48).max);

        posm.multicall(params);

        int24 tickSingleUpUpper = (currentTick / tickSpacing * tickSpacing) + 10 * tickSpacing;
        int24 tickSingleUpLower =  tickSingleUpUpper - (5 * tickSpacing);

        uint160 sqrtPriceX96ALower = TickMath.getSqrtPriceAtTick(tickSingleUpLower);
        uint160 sqrtPriceX96BUpper = TickMath.getSqrtPriceAtTick(tickSingleUpUpper);

        uint256 amount0MaxUpper = 1000e18;
        uint256 amount1MaxUpper = 1000e6;

        uint128 liquidityUpper = PRBLiquidityAmounts.getLiquidityForAmounts(startingPrice, sqrtPriceX96ALower, sqrtPriceX96BUpper, amount0MaxUpper, amount1MaxUpper);
        (amount0MaxUpper, amount1MaxUpper) = PRBLiquidityAmounts.getAmountsForLiquidity(startingPrice, sqrtPriceX96ALower, sqrtPriceX96BUpper, liquidityUpper);

        mintParams[0] = abi.encode(pool, tickSingleUpLower, tickSingleUpUpper, liquidityUpper, amount0MaxUpper, amount1MaxUpper, address(this), "");
        mintParams[1] = abi.encode(pool.currency0, pool.currency1);
        
        params = new bytes[](1);
        params[0] = abi.encodeWithSelector(
        posm.modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
        );

        posm.multicall(params);
    }

    function test_PriceConversion() public pure{
        // Example: Convert regular price to sqrt price
        uint256 regularPrice = 1.5e18; // 1.5:1 ratio (1.5 token1 per token0)
        uint160 sqrtPrice = PriceMath.priceToSqrtPriceX96(regularPrice);
        
        console.log("Regular price:", regularPrice);
        console.log("Sqrt price:", sqrtPrice);
        
        // Convert back to verify
        uint256 convertedBack = PriceMath.sqrtPriceX96ToPrice(sqrtPrice);
        console.log("Converted back:", convertedBack);
        
        // Example with token amounts
        uint256 amount0 = 1000e18; // 1000 token0
        uint256 amount1 = 1500e18; // 1500 token1 (1.5:1 ratio)
        uint160 sqrtPriceFromRatio = PriceMath.ratioToSqrtPriceX96(amount0, amount1);
        
        console.log("Sqrt price from ratio:", sqrtPriceFromRatio);
        
        // Example with decimals
        uint256 priceWithDecimals = 1500000000000000000; // 1.5 with 18 decimals
        uint160 sqrtPriceWithDecimals = PriceMath.priceWithDecimalsToSqrtPriceX96(
            priceWithDecimals, 
            18, // token0 decimals
            18  // token1 decimals
        );
        
        console.log("Sqrt price with decimals:", sqrtPriceWithDecimals);
        
        // Get common sqrt prices
        (uint160 sqrt1_1, uint160 sqrt2_1, uint160 sqrt1_2) = PriceMath.getCommonSqrtPrices();
        console.log("1:1 sqrt price:", sqrt1_1);
        console.log("2:1 sqrt price:", sqrt2_1);
        console.log("1:2 sqrt price:", sqrt1_2);
    }
}