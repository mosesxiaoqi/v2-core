pragma solidity =0.5.16;

// a library for performing various math operations

library Math {
    /*
        **应用场景**：
        - 在 Uniswap 中用于确保流动性提供和取出时按比例操作
        - 计算交易时可用的最大数量
        - 防止溢出和错误计算
    */
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // 计算无符号整数的平方根，向下取整
    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    /*
        **实现**：
        - 采用巴比伦迭代法（牛顿-拉弗森方法的特例）
        - 特殊处理 0-3 的特殊情况：
        - 输入为 0 时返回 0
        - 输入为 1-3 时返回 1
        - 对于大于 3 的值使用迭代逼近：
        - 初始猜测值 z = y
        - 迭代计算 x = (y/x + x)/2
        - 当 x < z 时更新 z = x 并继续迭代
        - 当满足精度要求时停止迭代

        **应用场景**：
        - **核心流动性计算**：在 Uniswap 的恒定乘积公式 (x·y=k) 中，添加流动性时计算 LP 代币数量
        - **计算最优路径**：确定多跳交易的最佳路径
        - **价格影响计算**：评估交易对价格的影响

        计算平方根公式是x = (y / x + x) / 2
        第一次迭代：(y/y + y)/2， 因为还没有计算出x值
        代码中第一次采用了y/2 + 1
        以计算 √100 为例：

        **使用 y 作为初始值**:
        - 初始 z = 100
        - 第一次迭代: x = (100/100 + 100)/2 = 50.5
        - 需要多次迭代才能接近 10

        **使用 y/2 + 1 作为初始值**:
        - 初始 x = 100/2 + 1 = 51

        至于两种方式哪个更好不知道？

        特殊处理 0-3**：
          - 0 的平方根是 0
          - 1 的平方根是 1
          - 2 和 3 的平方根在整数向下取整后也是 1
          - 这样处理可以节省 gas，避免不必要的计算
    */
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
