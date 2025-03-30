pragma solidity >=0.5.0;

// IUniswapV2ERC20 实现了 EIP-2612 permit 功能，允许用户通过签名授权而非交易
interface IUniswapV2ERC20 {
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

    // `DOMAIN_SEPARATOR()`、`PERMIT_TYPEHASH()` - EIP-712 相关
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    // 用于防重放攻击
    function nonces(address owner) external view returns (uint);

    // 允许无需 gas 的授权机制
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}
