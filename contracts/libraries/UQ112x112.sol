pragma solidity =0.5.16;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112
/*
    计算price0 (USDC/ETH价格):
    ```solidity
    price0 = encode(20000).uqdiv(10)
        = (20000 * 2^112) / 10
        = 2000 * 2^112
    ```
    实际价格 = price0 / 2^112
            = (2000 * 2^112) / 2^112
            = 2000
*/
library UQ112x112 {
    uint224 constant Q112 = 2 ** 112;

    // encode a uint112 as a UQ112x112
    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112; // never overflows
    }

    // divide a UQ112x112 by a uint112, returning a UQ112x112
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}
