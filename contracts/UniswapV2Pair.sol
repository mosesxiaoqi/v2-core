pragma solidity =0.5.16;

import './interfaces/IUniswapV2Pair.sol';
import './UniswapV2ERC20.sol';
import './libraries/Math.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IUniswapV2Callee.sol';

// 继承UniswapV2ERC20 实现了流动性代币（LP 代币）的无缝集成
contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20 {
    using SafeMath for uint; // 将库函数应用于uint类型
    using UQ112x112 for uint224; //同理

    // 10 ** 3表示10的3次方，即 103=100010^3 = 100010^3 = 1000
    /*
    防止流动性池耗尽：在Uniswap V2中，MINIMUM_LIQUIDITY（值为1000）被用作首次添加流动性的最小要求。
    首次提供流动性的用户会收到一个初始的流动性代币（LP Token），
    但其中1000个单位会被永久锁定（烧毁），以避免池子被完全清空或出现极端的价格滑点。
    数值意义：10 ** 3 = 1000 是一个相对小的值，通常与代币的精度（decimals）结合使用。
    例如，如果代币精度是18位，那么 1000 表示 1000×10−181000 \times 10^{-18}1000 \times 10^{-18}个代币单位。
    */
    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;

    // 池子中代币（token0）的储备量
    uint112 private reserve0; // uses single storage slot, accessible via getReserves
    // 池子中代币（token1）的储备量
    uint112 private reserve1; // uses single storage slot, accessible via getReserves
    // 记录储备量（reserve0 和 reserve1）最后一次更新的区块时间戳
    uint32 private blockTimestampLast; // uses single storage slot, accessible via getReserves

    // price0CumulativeLast计算的是时间加权平均值随时间累加的总和
    // 计算时间加权平均值还需要取时间段内的总和与时间的比值
    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    // kLast记录的是上一次流动性操作（添加或移除流动性）后的k值
    uint public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    // 串行执行并不能完全防止重入攻击。
    // 重入攻击发生在单个交易内，当合约调用外部地址（例如另一个合约或用户地址）时，外部代码可能在控制权返回之前重新调用原合约。
    // 这种情况与交易之间的串行性无关，而是与调用栈和状态更新的时机有关。
    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // 通过低级调用（call）与外部代币合约交互，并包含错误检查机制以确保转账成功
    function _safeTransfer(address token, address to, uint value) private {
        /*检查转账是否安全完成，条件是：
        success == true：调用没有抛出异常。
        (data.length == 0 || abi.decode(data, (bool)))：返回值要么为空，要么解码为 true。
        如果条件不满足，抛出 'UniswapV2: TRANSFER_FAILED' 错误。
        */
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'UniswapV2: TRANSFER_FAILED');
    }

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

    constructor() public {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
    }

    // update reserves and, on the first call per block, price accumulators
    // update的理解在自己的笔记本里
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'UniswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        /*
        计算流动性代币:
        公式：liquidity=totalSupply * (rootK - rootKLast)/rootK * 5 + rootKLast
        分子：totalSupply * (rootK - rootKLast)，表示增长部分的占比。
        分母：rootK * 5 + rootKLast，实现 1/6 的分配比例
        这个公式还不理解 链接https://learnblockchain.cn/article/3987有讲解，还没看懂
        */
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(5).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    // mint是没有告诉存入了多少代币的
    // 用户需先调用 token0.transfer 和 token1.transfer 将代币发送到 Pair 合约
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            // liquidity: 铸造的流动性代币数量。
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            /*
            LP 代币本身不是池子中的 token0 或 token1，它只是代表用户在池子中的份额。
            所谓“怕池子耗尽”，并不是指 LP 代币耗尽，而是指池子中的代币储备（reserve0 和 reserve1）可能被完全移除，
            导致池子失去功能。锁定 MINIMUM_LIQUIDITY 是为了避免这种情况

            如果没有锁定一定数量的lp代币，也没有其他人加池子，
            用户就拥有100%的lp，在撤销时就会把交易池子里的代币全部撤回
            导致池子无法交易
            */
            _mint(address(0), MINIMUM_LIQUIDITY): 将 1000 个代币永久锁定（烧毁）
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            /*
            在已经创建了池子后，在存入token需要按比例来，即：amount0/_reserve0 = amount1/_reserve1
            在乘上lp _totalSupply总量就是要铸造的数量
            为防止amount0和amount1不成比例，用min取最小值方式保证成比例
            */
            liquidity = Math.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        /*销毁前的步骤：
        用户必须先将要销毁的 LP 代币发送回 Pair 合约（address(this)）。
        通常通过调用 transfer(address(this), liquidityAmount) 实现，其中 liquidityAmount 是用户希望销毁的数量。
        调用 burn：
        用户随后调用 burn(to)，告诉 Pair 合约将这些代币销毁并提取对应的 token0 和 token1。
        */
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        // 这个算法就是用户持有的lp数量占总量的比例✖️token的总量，获得的就是用户存入的总量，
        // 第一个用户不会取出100%，因为有锁定量
        // 因此，初始存入量越大，相对损失越小
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'UniswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        /*
        由于在burn前需要先将lp转给pair合约，所以当前合约里只有用户的lp数量
        在按比例计算完后需要销毁lp
        就调用_burn
        在_burn中会减掉balanceOf[address(this)]和totalSupply里liquidity数量的值
        */
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'UniswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'UniswapV2: INVALID_TO');
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'UniswapV2: INSUFFICIENT_INPUT_AMOUNT');
        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            require(
                balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000 ** 2),
                'UniswapV2: K'
            );
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /*skim 函数的主要作用是：
    清理多余的代币：
        将 Pair 合约中实际持有的代币余额（balanceOf）与记录的储备量（reserve0 和 reserve1）之间的差额提取出来，
        发送给调用者指定的地址。
    强制同步：确保合约的实际余额不超过记录的储备量，防止多余代币滞留在合约中。
    */
    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() external lock {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}
