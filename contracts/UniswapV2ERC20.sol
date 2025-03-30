pragma solidity =0.5.16;

import './interfaces/IUniswapV2ERC20.sol';
import './libraries/SafeMath.sol';

contract UniswapV2ERC20 is IUniswapV2ERC20 {
    // 将 `SafeMath` 库附加到所有 `uint` 类型上
    using SafeMath for uint;

    // 使用 `constant` 表示这些值是不可变的，节省gas
    string public constant name = 'Uniswap V2';
    string public constant symbol = 'UNI-V2';
    // 代币精度为18位小数（与ETH相同）
    uint8 public constant decimals = 18;
    /*- 声明了记录代币总供应量的状态变量
    - 这个值会随着流动性的添加和移除而变化
    - 没有设定最大供应上限*/
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    /* 在 Uniswap 中：
    - 用户想交换代币 A 换取代币 B
    - 无需先发送 approve 交易授权 Uniswap 使用代币 A
    - 而是签署 permit 消息，与交换操作一起提交
    - Uniswap 合约先执行 permit，然后执行交换，全部在一个交易中完成*/
    bytes32 public DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    constructor() public {
        uint chainId;
        assembly {
            chainId := chainid
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this)
            )
        );
    }

    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) external returns (bool) {
        if (allowance[from][msg.sender] != uint(-1)) {
            // 如果不是无限授权就减少授权的额度， 一般都是先修改记录在执行操作
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    // `permit` 函数实现了 EIP-2612 标准，允许用户通过签名来授权代币，无需直接发送交易，从而省去 gas 费用
    function permit(
        address owner, // 代币持有者地址
        address spender, // 被授权使用代币的地址
        uint value, // 授权的代币数量
        uint deadline, // 签名有效期截止时间
        uint8 v, // 签名的恢复参数
        bytes32 r, // 签名的 r 值
        bytes32 s // 签名的 s 值
    ) external {
        // 检查签名是否过期 如果deadline小于当前时间说明已经过期了
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
        // 构建消息摘要（按照 EIP-712 标准）
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01', // EIP-712 前缀
                DOMAIN_SEPARATOR, // 合约特定域分隔符
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH, // permit 操作的类型哈希， PERMIT_TYPEHASH并不是permit的函数签名哈希
                        // 一个是在permit没有nonce，而是在这里构建712规范交易时获取合约当前的nonce
                        owner,
                        spender,
                        value,
                        nonces[owner]++, // 持有者的当前 nonce（使用后立即递增）
                        deadline // 截止时间
                    )
                )
            )
        );
        // 从签名恢复签名者地址
        address recoveredAddress = ecrecover(digest, v, r, s);
        // 验证恢复的地址有效且匹配声称的所有者
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}
