pragma solidity >=0.5.0;

// 这是支持 Uniswap V2 闪电交换的回调接口
interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}
