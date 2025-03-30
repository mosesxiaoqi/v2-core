pragma solidity =0.5.16;

import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

// uniswap 的 UniswapV2Factory合约继承了 接口合约IUniswapV2Factory
// 但是并没有完全实现接口？ why?
// 答案：另外的是 public 的状态变量，因为 public 的状态变量会自动生成对应名称的 getter 函数
contract UniswapV2Factory is IUniswapV2Factory {
    address public feeTo; // 返回协议费用接收地址
    address public feeToSetter; // 返回有权限修改费用接收地址的地址 // 这是Factory合约的管理员地址

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        // 创建合约对时，两个token地址不能相同
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');
        // 对地址进行大小排序
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        //排序后，token0如果不是0地址，两个token就都不是0地址
        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        // 如果交易对合约已经被创建了，地址就不是0地址了
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient
        // **获取 UniswapV2Pair 合约的完整部署字节码，以便后续使用低级调用动态部署合约**
        /*在 UniswapV2Factory 合约中，这通常用于：
            1. **动态合约创建**：
            - 通过内联汇编和 `create2` 操作码部署新的交易对合约
            - 避免直接使用 `new` 关键字部署合约

            2. **确定性地址生成**：
            - 与 `CREATE2` 操作码结合，可以预测交易对合约地址
            - 使地址取决于工厂地址、盐值和合约字节码

            3. **优化部署**：
            - 一次获取字节码，可以重复使用于多个交易对的创建
            - 减少冗余代码和存储开销*/
        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            // create2的计算 address = keccak256(0xff ++ deployingAddress ++ salt ++ keccak256(bytecode))[12:]
            // 在evm环境中会自动获取当前部署合约的地址，就是deployingAddress，也就是Factory地址
            // add(bytecode, 32), mload(bytecode)会获取bytecode，create2内部会做哈希计算
            // 最后对整体进行哈希计算，去最后对20字节就是pair地址
            // 需要注意的是如果你自己部署的dex合约，在这里部署是获取了pair合约的creationCode
            // 但是在UniswapV2Library中的pairFor函数中，它是硬编码了pair合约的creationCode哈希值
            // 所以在使用uniswap 的router合约时，或无法添加流动性
            // ## `:=` 的含义，在 Solidity 的内联汇编（Yul）中，`:=` 是**赋值操作符**。这与 Solidity 主语言中的 `=` 赋值操作符作用相同，但语法不同。
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IUniswapV2Pair(pair).initialize(token0, token1);
        // 在mapping中保存token与pair的地址·映射
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
