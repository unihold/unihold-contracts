Ropsten contracts can be used for testing:
//0x9c83dCE8CA20E9aAF9D3efc003b2ea62aBC08351 - uniswap ropsten v1 factory address
//0x60B10C134088ebD63f80766874e2Cade05fc987B BAT ropsten
//0x7d5E6A841Ec195F30911074d920EEc665A973A2D DAI ropsten
//0x7FffaC23d59D287560DFecA7680B5393426Cf503 BEE ropsten
//0x2f45b6Fb2F28A73f110400386da31044b2e953D4 TEST ropsten

# unihold-contracts
Smart contracts including factory and template


## uniholdfactory.sol
Determines if token has an existing uniswap pair and allows creation of new unihold staking contract based on current token value

## unihold.sol
A new contract for each token is created based on this contract template.
