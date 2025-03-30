pragma solidity >=0.5.0;

// 这个接口综合了 ERC-20 功能和 AMM(自动做市商)功能，使交易对既可作为流动性代币，又能处理代币交换和流动性管理。

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    // 最小流动性锁定量(10^-15)，防止首个流动性提供者操纵价格
    function MINIMUM_LIQUIDITY() external pure returns (uint);

    // 返回创建此交易对的工厂合约地址
    function factory() external view returns (address);

    // 交易对中两个代币的地址
    function token0() external view returns (address);

    function token1() external view returns (address);

    // 返回池中两种代币的当前储备量
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    // 用于时间加权平均价格(TWAP)计算
    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    // 最后一次交互时的 k 值(reserve0 * reserve1)，用于协议费计算
    function kLast() external view returns (uint);

    // 添加流动性，为流动性提供者铸造 LP 代币
    function mint(address to) external returns (uint liquidity);

    // 移除流动性，销毁 LP 代币并返回相应代币
    function burn(address to) external returns (uint amount0, uint amount1);

    // 执行代币交换操作
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    // 提取超额代币(防止溢出和攻击)
    function skim(address to) external;

    // 同步储备金与合约余额(安全机制)
    function sync() external;

    // 初始化交易对，设置两种代币地址
    function initialize(address, address) external;
}
