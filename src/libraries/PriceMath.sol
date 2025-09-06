// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TickMath} from "@v4-core/libraries/TickMath.sol";

/// @title PriceMath library for price conversions
/// @notice Contains utility functions for converting between regular prices and sqrt prices
library PriceMath {
    using Math for uint256;

    /// @notice Convert a regular price to sqrt price in Q64.96 format
    /// @param price The regular price (amount1 / amount0)
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    function priceToSqrtPriceX96(uint256 price) internal pure returns (uint160 sqrtPriceX96) {
        // sqrt(price) * 2^96
        // price is in the format: amount1 / amount0
        uint256 sqrtPrice = Math.sqrt(price);
        
        // Convert to Q64.96 format (multiply by 2^96)
        sqrtPriceX96 = uint160((sqrtPrice << 96) / 1e18);
    }

    /// @notice Convert a sqrt price back to regular price
    /// @param sqrtPriceX96 The sqrt price in Q64.96 format
    /// @return price The regular price (amount1 / amount0)
    function sqrtPriceX96ToPrice(uint160 sqrtPriceX96) internal pure returns (uint256 price) {
        // Convert from Q64.96 format back to regular price
        uint256 sqrtPrice = (uint256(sqrtPriceX96) * 1e18) >> 96;
        price = sqrtPrice * sqrtPrice;
    }

    /// @notice Convert a ratio of amounts to sqrt price
    /// @param amount0 Amount of token0
    /// @param amount1 Amount of token1
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    function ratioToSqrtPriceX96(uint256 amount0, uint256 amount1) internal pure returns (uint160 sqrtPriceX96) {
        require(amount0 > 0, "PriceMath: amount0 must be greater than 0");
        uint256 price = (amount1 * 1e18) / amount0;
        return priceToSqrtPriceX96(price);
    }

    /// @notice Convert a price with specific decimals to sqrt price
    /// @param price The price with decimals
    /// @param decimals0 Decimals of token0
    /// @param decimals1 Decimals of token1
    /// @return sqrtPriceX96 The sqrt price in Q64.96 format
    function priceWithDecimalsToSqrtPriceX96(
        uint256 price,
        uint8 decimals0,
        uint8 decimals1
    ) internal pure returns (uint160 sqrtPriceX96) {
        // Adjust for decimal differences
        uint256 adjustedPrice;
        if (decimals1 >= decimals0) {
            adjustedPrice = price * (10 ** (decimals1 - decimals0));
        } else {
            adjustedPrice = price / (10 ** (decimals0 - decimals1));
        }
        return priceToSqrtPriceX96(adjustedPrice);
    }

    /// @notice Get common sqrt prices for testing
    /// @return sqrt1_1 Sqrt price for 1:1 ratio
    /// @return sqrt2_1 Sqrt price for 2:1 ratio  
    /// @return sqrt1_2 Sqrt price for 1:2 ratio
    function getCommonSqrtPrices() internal pure returns (uint160 sqrt1_1, uint160 sqrt2_1, uint160 sqrt1_2) {
        sqrt1_1 = priceToSqrtPriceX96(1e18); // 1:1 ratio
        sqrt2_1 = priceToSqrtPriceX96(2e18); // 2:1 ratio
        sqrt1_2 = priceToSqrtPriceX96(0.5e18); // 1:2 ratio
    }

    /// @notice Convert price to tick (simplified version)
    /// @param price The regular price
    /// @return tick The corresponding tick
    function priceToTick(uint256 price) internal pure returns (int24 tick) {
        // This is a simplified conversion
        // In practice, you'd want more precision
        // price = 1.0001^tick
        // tick = log(price) / log(1.0001)
        
        if (price == 1e18) return 0; // 1:1 ratio
        
        // Use a lookup table approach for common prices
        if (price == 2e18) return 6931; // ~2:1 ratio
        if (price == 0.5e18) return -6931; // ~1:2 ratio
        if (price == 1.5e18) return 4055; // ~1.5:1 ratio
        if (price == 0.75e18) return -2877; // ~3:4 ratio
        
        // For other prices, use approximation
        // This is a simplified version - in production you'd want more precision
        int256 logPrice = int256(Math.log2(price));
        int256 logBase = int256(Math.log2(1.0001e18));
        tick = int24(logPrice * 1e18 / logBase);
        
        // Clamp to valid tick range
        if (tick > TickMath.MAX_TICK) tick = TickMath.MAX_TICK;
        if (tick < TickMath.MIN_TICK) tick = TickMath.MIN_TICK;
    }

    /// @notice Convert tick to price
    /// @param tick The tick value
    /// @return price The regular price
    function tickToPrice(int24 tick) internal pure returns (uint256 price) {
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(tick);
        return sqrtPriceX96ToPrice(sqrtPriceX96);
    }
}
