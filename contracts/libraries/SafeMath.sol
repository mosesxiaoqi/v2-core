pragma solidity =0.5.16;

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

// SafeMath 是一个防止整数溢出/下溢的数学运算库
// 最初由 DappHub 开发，在 Uniswap V2 中使用。
// 它提供了基本算术运算的安全版本
// 在 Solidity 0.8.0 之前的版本中非常重要，因为那时 Solidity 不会自动检查整数溢出
// 重点：Solidity 0.8.0及之后版本通常不再需要使用SafeMath库**，因为编译器已经内置了算术溢出和下溢检查
library SafeMath {
    // 如果 x + y 的结果小于 x，表示发生了溢出
    // 在无符号整数加法中，只有发生溢出时，结果才会小于任一操作数
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    // 在无符号整数中，如果 y > x，减法会导致下溢
    // 正常的减法结果必须小于等于被减数
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    // 利用乘法和除法的逆运算关系
    // 若无溢出，则 (x * y) / y 应等于 x (前提是 y ≠ 0)
    // 若结果溢出，则除回后不等于原数
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}
