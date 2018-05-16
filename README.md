# Royal Kingdom Coin
RKC Token Smart Contract

Deployed contract is here: https://etherscan.io/address/0x6ccb56947ea1d6efdc81acfbacd8263ddfa9b202

See https://github.com/uvarovserge/royalkingdomcoin/blob/master/contracts/RKCToken.sol for the main contract code

How to test on testrpc
======================

* Make sure RKCTokenTest.sol has almost identical code (just with test values) - you can diff them

* run testnet with `testrpc --account="0x07e5c9513ee195edffd3fe77a4ae4af67da4a0884b03671cd9099bea80d355b4, 1000000000000000000000" --account="0x5f0443851368ce73912a59d3a9101806c36181e0368659580888e81c7423735e, 100"`

* run `truffle test --network testrpc`

You will probably also need `npm i web3` if you have an error message about web3 (I'll include it later in package.json)

Verification with Etherscan
===========================

To concatenate the code, you need this command:

```
awk 1 contracts/zeppelin/SafeMath.sol contracts/zeppelin/token/ERC20Basic.sol contracts/zeppelin/token/BasicToken.sol contracts/zeppelin/token/ERC20.sol contracts/zeppelin/token/StandardToken.sol contracts/zeppelin/ownership/Ownable.sol contracts/RKCToken.sol | sed '/^\(pragma\|import\)/ d' > build/source-code-bundle.sol   
```
