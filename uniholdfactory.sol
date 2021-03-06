//SPDX-License-Identifier: MIT
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

  address internal creator;
  address internal owner;

  // index of created contracts
  address[] public contracts;
  mapping(address => address) public uniholdToToken;
  mapping(address => address) public TokenToUnihold;
  mapping(uint256 => address) public idToUnihold;
  uint256 public count = 0;
  uint256 public initialEthToTokenValue;

 address internal uniFactoryAddress = 0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351; //ropsten
 UniswapFactoryInterface internal uniFactoryInterface = UniswapFactoryInterface(uniFactoryAddress);

 event details(string name, string symbol, uint8 decimals);

 modifier onlyOwner() {
  require(msg.sender == owner, "Only contract owner can call this function");
  _;
 }

 modifier onlyUnihold() {
  require(uniholdToToken(msg.sender) != address(0), "Only unihold contract can call this function");
 }

 constructor() {
  owner = msg.sender;
 }

  function getContracts() 
    public
    view
    returns(address[] memory)
    {
      return contracts;
    }
    
  function setCreator(address newCreator) 
    onlyOwner
  {
    require(creator != address(0), "Creator can not be the 0 address");
    newCreator = creator;
  }

  function getCreator()
    external
    returns(address)
    onlyUnihold
  {
      return creator;
  }
    
  // deploy a new unihold contract
  function createNewContract(address token)
    public
    payable
    returns(address newContract)
  {
    require(TokenToUnihold[token] == address(0), "Only 1 unihold contract can be created per token");

    address exchangeAddress = uniFactoryInterface.getExchange(token);
    
    require(exchangeAddress != address(0), "This token doesn't exist on uniswap");
    UniswapExchangeInterface uniXInterface = UniswapExchangeInterface(exchangeAddress);
    //1 eth value of tokens
    initialEthToTokenValue = uniXInterface.getEthToTokenInputPrice(1);

    emit details(ERC20(token).name(), ERC20(token).symbol(),  ERC20(token).decimals());
    
    address uni = address(new UniHold(
        token,
        ERC20(token).name(),
        ERC20(token).symbol(),
        ERC20(token).decimals(),
        initialEthToTokenValue,
        address(this)
    ));
    
    contracts.push(uni);
    
    uniholdToToken[uni] = token;
    TokenToUnihold[token] = uni;
    
    idToUnihold[count] = uni;
    count++;

    return uni;
  }
}