pragma solidity ^0.6.11;
import "./Unihold.sol";

//Uniswap factory interface
interface UniswapFactoryInterface {
    // Create Exchange
    function createExchange(address token) external returns (address exchange);
    // Get Exchange and Token Info
    function getExchange(address token) external view returns (address exchange);
    function getToken(address exchange) external view returns (address token);
    function getTokenWithId(uint256 tokenId) external view returns (address token);

}

//Uniswap Interface
interface UniswapExchangeInterface {
    // Address of ERC20 token sold on this exchange
    function tokenAddress() external view returns (address token);
    // Address of Uniswap Factory
    function factoryAddress() external view returns (address factory);

    function getEthToTokenInputPrice(uint256 eth_sold) external view returns (uint256 tokens_bought);
    function getEthToTokenOutputPrice(uint256 tokens_bought) external view returns (uint256 eth_sold);
    function getTokenToEthInputPrice(uint256 tokens_sold) external view returns (uint256 eth_bought);
    function getTokenToEthOutputPrice(uint256 eth_bought) external view returns (uint256 tokens_sold);
}

contract UniholdFactory {

  // index of created contracts
  address[] public contracts;
  mapping(address => address) public uniholdToToken;
  mapping(address => address) public TokenToUnihold;
  mapping(uint256 => address) public idToUnihold;
  uint256 public count;
  uint256 public initialEthToTokenValue;

 address internal uniFactoryAddress = 0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95;
 UniswapFactoryInterface internal uniFactoryInterface = UniswapFactoryInterface(uniFactoryAddress);

  // deploy a new unihold contract
  function createNewContract(address token, string memory name, string memory symbol, uint8 decimals)
    public
    payable
    returns(address newContract)
  {
    require(TokenToUnihold[token] == address(0), Only 1 unihold contract can be created per token);

    address exchangeAddress = uniFactoryInterface.getExchange(token);
    
    require(exchangeAddress != address(0), "This token doesn't exist on uniswap");
    UniswapExchangeInterface uniXInterface = UniswapExchangeInterface(exchangeAddress);
    //1 eth value of tokens
    initialEthToTokenValue = uniXInterface.getEthToTokenInputPrice(1);

    address uni = address(new UniHold(
        token,
        name,
        symbol,
        decimals,
        initialEthToTokenValue
    ));
    contracts.push(uni);
    
    uniholdToToken[uni] = token;
    TokenToUnihold[token] = uni;
    
    uint256 tokenID = count + 1;
    idToUnihold[tokenID] = uni;

    return uni;
  }
}