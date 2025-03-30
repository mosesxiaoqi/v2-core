pragma solidity >=0.5.0;

interface IUniswapV2Factory {
    // 创建新交易对时触发
    // 记录两个代币地址、新创建的交易对合约地址及该交易对的索引
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    // 返回协议费用接收地址
    function feeTo() external view returns (address);

    // 返回有权限修改费用接收地址的地址
    // 这是Factory合约的管理员地址
    function feeToSetter() external view returns (address);

    // 查询由两个代币组成的交易对的合约地址
    // 顺序无关（输入A-B或B-A返回同一地址）
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    // 查询所有交易对的合约地址
    // 按索引获取已创建的交易对地址
    // 为枚举所有交易对提供方法
    function allPairs(uint) external view returns (address pair);

    // 返回已创建的交易对总数量
    // 用于遍历所有交易对
    function allPairsLength() external view returns (uint);

    // 创建新的交易对合约
    // 返回新创建的交易对合约地址
    // 防止同一对代币重复创建交易对
    function createPair(address tokenA, address tokenB) external returns (address pair);

    // 设置协议费用接收地址
    function setFeeTo(address) external;

    // 更改有权修改费用设置的管理员地址
    // 相当于转移Factory的管理权限
    function setFeeToSetter(address) external;
}
