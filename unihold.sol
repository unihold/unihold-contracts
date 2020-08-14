//SPDX-License-Identifier: MIT
pragma solidity ^0.6.11;
 /**
 * @dev Interface to interact with ERC20 tokens (X)
 */
interface ERC20{
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8) ;
}

contract UniHold {
    /**
     *  Modifiers
     */
    // only people with tokens
    modifier onlywithtokens () {
        require(myTokens() > 0, "You don't have any tokens");
        _;
    }
    
    // only people with profits
    modifier onlyholder() {
        require(myDividends() > 0, "You don't have enough profits");
        _;
    }
    
    /**
     * Events
     */
    event onTokenPurchase(
        address indexed customerAddress,
        uint256 incomingX,
        uint256 tokensMinted
    );
    
    event onTokenSell(
        address indexed customerAddress,
        uint256 tokensBurned,
        uint256 xEarned
    );
    
    event onReinvestment(
        address indexed customerAddress,
        uint256 xReinvested,
        uint256 tokensMinted
    );
    
    event onWithdraw(
        address indexed customerAddress,
        uint256 xWithdrawn
    );
    
    // ERC20
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 tokens
    );
    
    
    /**
     * Variables
     */
    string public name;
    string public symbol;
    uint8 public decimals; // Get the value from the contract 
    uint8 constant internal dividendFee_ = 10;
    address token; 
    uint256 internal tokenPriceInitial_; 
    uint256 internal tokenPriceIncremental_; 
    uint256 constant internal magnitude = 2**64;
    address constant internal creator = 0xda6a9CA017D493DF28292c7e796555d0EAB75272;

    mapping(address => uint256) internal tokenBalanceLedger_;
    mapping(address => int256) internal payoutsTo_;
    uint256 internal tokenSupply_ = 0;
    uint256 internal profitPerShare_;

    /**
     * Public Functions
     */
    constructor(address _token, string memory _name, string memory _symbol, uint8 _decimals, uint256 _currentEthToToken)
        public
    {
        name = string(abi.encodePacked("Uni",_name));
        symbol = string(abi.encodePacked("UNI",_symbol));
        decimals = _decimals;
        token = _token;
        
        //calculate start value and increment based on current uniswap price
        tokenPriceInitial_ = _currentEthToToken / 1000; // approx 0.0000001 ether worth of tokens
        tokenPriceIncremental_ = _currentEthToToken / 10000000; //approx 0.00000001 ether worth of tokens

        //Initial fee to creator, 100% of all other fees are distributed to shareholders as dividends
        tokenBalanceLedger_[creator] = 1000; 
    }
        
    /**
     * Converts all of caller's dividends to tokens.
     */
    function reinvest()
        onlyholder()
        public
    {
        // fetch dividends
        uint256 _dividends = myDividends(); 
        
        // pay out the dividends virtually
        address _customerAddress = msg.sender;
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        
        // dispatch a buy order with the virtualized withdrawn dividends
        uint256 _tokens = purchaseTokens(_dividends);
        
        emit onReinvestment(_customerAddress, _dividends, _tokens);
    }
    
    /**
     * Alias of sell() and withdraw().
     */
    function exit()
        public
    {
        // get token count for caller & sell them all
        address _customerAddress = msg.sender;
        uint256 _tokens = tokenBalanceLedger_[_customerAddress];
        if(_tokens > 0) sell(_tokens);
        
        withdraw();
    }

    /**
     * Withdraws all of the callers earnings.
     */
    function withdraw()
        onlyholder()
        public
    {
        address _customerAddress = msg.sender;
        uint256 _dividends = myDividends(); 
        
        // update dividend tracker
        payoutsTo_[_customerAddress] +=  (int256) (_dividends * magnitude);
        
        require(ERC20(token).transfer(_customerAddress, _dividends), "Transfer failed");
        
        emit onWithdraw(_customerAddress, _dividends);
    }
    
    /**
     * Liquifies tokens to X.
     */
    function sell(uint256 _amountOfTokens)
        onlywithtokens ()
        public
    {
        address _customerAddress = msg.sender;
       
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress], "You don't have enough tokens");
        uint256 _tokens = _amountOfTokens;
        uint256 _x = tokensToX_(_tokens);
        uint256 _dividends = SafeMath.div(_x, dividendFee_);
        uint256 _taxedX = SafeMath.sub(_x, _dividends);
        
        // burn the sold tokens
        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokens);
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _tokens);
        
        // update dividends
        int256 _updatedPayouts = (int256) (profitPerShare_ * _tokens + (_taxedX * magnitude));
        payoutsTo_[_customerAddress] -= _updatedPayouts;       
        
        if (tokenSupply_ > 0) {
            // update the amount of dividends per token
            profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        }
        
        emit onTokenSell(_customerAddress, _tokens, _taxedX);
    }
    
    
    /**
     * Transfer tokens from the caller to a new holder.
     * there's a 10% fee here as well.
     */
    function transfer(address _toAddress, uint256 _amountOfTokens)
        onlywithtokens ()
        public
        returns(bool)
    {
        address _customerAddress = msg.sender;
        
        require(_amountOfTokens <= tokenBalanceLedger_[_customerAddress], "You don't have the requested tokens");
        
        // withdraw all outstanding dividends first
        if(myDividends() > 0) withdraw();
        
        // liquify 10% of the tokens that are transfered
        // these are dispersed to shareholders
        uint256 _tokenFee = SafeMath.div(_amountOfTokens, dividendFee_);
        uint256 _taxedTokens = SafeMath.sub(_amountOfTokens, _tokenFee);
        uint256 _dividends = tokensToX_(_tokenFee);
  
        // burn the fee tokens
        tokenSupply_ = SafeMath.sub(tokenSupply_, _tokenFee);

        // exchange tokens
        tokenBalanceLedger_[_customerAddress] = SafeMath.sub(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        tokenBalanceLedger_[_toAddress] = SafeMath.add(tokenBalanceLedger_[_toAddress], _taxedTokens);
        
        // update dividend trackers
        payoutsTo_[_customerAddress] -= (int256) (profitPerShare_ * _amountOfTokens);
        payoutsTo_[_toAddress] += (int256) (profitPerShare_ * _taxedTokens);
        
        // disperse dividends among holders
        profitPerShare_ = SafeMath.add(profitPerShare_, (_dividends * magnitude) / tokenSupply_);
        
        emit Transfer(_customerAddress, _toAddress, _taxedTokens);
        return true;
       
    }
    
    /*----------  HELPERS AND CALCULATORS  ----------*/
    /**
     * Method to view the current amount of tokens stored in the contract
     */
    function totalTokenBalance()
        public
        view
        returns(uint)
    {
        return ERC20(token).balanceOf(address(this));
    }
    
    /**
     * Retrieve the total token supply.
     */
    function totalSupply()
        public
        view
        returns(uint256)
    {
        return tokenSupply_;
    }
    
    /**
     * Retrieve the tokens owned by the caller.
     */
    function myTokens()
        public
        view
        returns(uint256)
    {
        address _customerAddress = msg.sender;
        return balanceOf(_customerAddress);
    }
    
    /**
     * Retrieve the dividends owned by the caller.
       */ 
    function myDividends() 
        public 
        view 
        returns(uint256)
    {
        address _customerAddress = msg.sender;
        dividendsOf(_customerAddress) ;
    }
    
    /**
     * Retrieve the token balance of any single address.
     */
    function balanceOf(address _customerAddress)
        view
        public
        returns(uint256)
    {
        return tokenBalanceLedger_[_customerAddress];
    }
    
    /**
     * Retrieve the dividend balance of any single address.
     */
    function dividendsOf(address _customerAddress)
        view
        public
        returns(uint256)
    {
        return (uint256) ((int256)(profitPerShare_ * tokenBalanceLedger_[_customerAddress]) - payoutsTo_[_customerAddress]) / magnitude;
    }
    
    /**
     * Return the buy price of 1 individual token.
     */
    function sellPrice() 
        public 
        view 
        returns(uint256)
    {
       
        if(tokenSupply_ == 0){
            return tokenPriceInitial_ - tokenPriceIncremental_;
        } else {
            uint256 _x = tokensToX_(1e18);
            uint256 _dividends = SafeMath.div(_x, dividendFee_  );
            uint256 _taxedX = SafeMath.sub(_x, _dividends);
            return _taxedX;
        }
    }
    
    /**
     * Return the sell price of 1 individual token.
     */
    function buyPrice() 
        public 
        view 
        returns(uint256)
    {
        
        if(tokenSupply_ == 0){
            return tokenPriceInitial_ + tokenPriceIncremental_;
        } else {
            uint256 _x = tokensToX_(1e18);
            uint256 _dividends = SafeMath.div(_x, dividendFee_  );
            uint256 _taxedX = SafeMath.add(_x, _dividends);
            return _taxedX;
        }
    }
    
   
    function calculateTokensReceived(uint256 _xToSpend) 
        public 
        view 
        returns(uint256)
    {
        uint256 _dividends = SafeMath.div(_xToSpend, dividendFee_);
        uint256 _taxedX = SafeMath.sub(_xToSpend, _dividends);
        uint256 _amountOfTokens = xToTokens_(_taxedX);
        
        return _amountOfTokens;
    }
    
   
    function calculateXReceived(uint256 _tokensToSell) 
        public 
        view 
        returns(uint256)
    {
        require(_tokensToSell <= tokenSupply_, "Not enough tokens to sell");
        uint256 _x = tokensToX_(_tokensToSell);
        uint256 _dividends = SafeMath.div(_x, dividendFee_);
        uint256 _taxedX = SafeMath.sub(_x, _dividends);
        return _taxedX;
    }
    
    
    /**
     * Internal Functions
     */
    function purchaseTokens(uint256 _incomingX)
        internal
        returns(uint256)
    {
        // data setup
        address _customerAddress = msg.sender;
        uint256 _dividends = SafeMath.div(_incomingX, dividendFee_);
        uint256 _taxedX = SafeMath.sub(_incomingX, _dividends);
        uint256 _amountOfTokens = xToTokens_(_taxedX);
        uint256 _fee = _dividends * magnitude;
 
      
        require(_amountOfTokens > 0 && (SafeMath.add(_amountOfTokens,tokenSupply_) > tokenSupply_), "Not enough tokens to sell");
    
        _fee = _dividends * magnitude;
        
        
        // we can't give people infinite X
        if(tokenSupply_ > 0){
            
            // add tokens to the pool
            tokenSupply_ = SafeMath.add(tokenSupply_, _amountOfTokens);
 
            // take the amount of dividends gained through this transaction, and allocates them evenly to each shareholder
            profitPerShare_ += (_dividends * magnitude / (tokenSupply_));
            
            // calculate the amount of tokens the customer receives over his purchase 
            _fee = _fee - (_fee-(_amountOfTokens * (_dividends * magnitude / (tokenSupply_))));
        
        } else {
            // add tokens to the pool
            tokenSupply_ = _amountOfTokens;
        }
        
        // update circulating supply & the ledger address for the customer
        tokenBalanceLedger_[_customerAddress] = SafeMath.add(tokenBalanceLedger_[_customerAddress], _amountOfTokens);
        
        
        int256 _updatedPayouts = (int256) ((profitPerShare_ * _amountOfTokens) - _fee);
        payoutsTo_[_customerAddress] += _updatedPayouts;

        require(ERC20(token).transferFrom(msg.sender, address(this), _incomingX), "Transfer failed.");
        
        emit onTokenPurchase(_customerAddress, _incomingX, _amountOfTokens);
        
        return _amountOfTokens;
    }

    /**
     * Calculate Token price based on an amount of incoming X
     */
    function xToTokens_(uint256 _x)
        internal
        view
        returns(uint256)
    {
        uint256 _tokenPriceInitial = tokenPriceInitial_ * 1e18;
        uint256 _tokensReceived = 
         (
            (
                // underflow attempts BTFO
                SafeMath.sub(
                    (sqrt
                        (
                            (_tokenPriceInitial**2)
                            +
                            (2*(tokenPriceIncremental_ * 1e18)*(_x * 1e18))
                            +
                            (((tokenPriceIncremental_)**2)*(tokenSupply_**2))
                            +
                            (2*(tokenPriceIncremental_)*_tokenPriceInitial*tokenSupply_)
                        )
                    ), _tokenPriceInitial
                )
            )/(tokenPriceIncremental_)
        )-(tokenSupply_)
        ;
  
        return _tokensReceived;
    }
    
    /**
     * Calculate token sell value.
    */
     function tokensToX_(uint256 _tokens)
        internal
        view
        returns(uint256)
    {

        uint256 tokens_ = (_tokens + 1e18);
        uint256 _tokenSupply = (tokenSupply_ + 1e18);
        uint256 _etherReceived =
        (
            SafeMath.sub(
                (
                    (
                        (
                            tokenPriceInitial_ +(tokenPriceIncremental_ * (_tokenSupply/1e18))
                        )-tokenPriceIncremental_
                    )*(tokens_ - 1e18)
                ),(tokenPriceIncremental_*((tokens_**2-tokens_)/1e18))/2
            )
        /1e18);
        return _etherReceived;
    }
    
    
    
    function sqrt(uint x) internal pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

   
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

   
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

   
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
    
}