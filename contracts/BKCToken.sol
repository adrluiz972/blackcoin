pragma solidity ^0.4.11;

import "./zeppelin/token/StandardToken.sol";
import "./zeppelin/ownership/Ownable.sol";

// Black Coin Token
// www.blackcoin.com
//
// BKC token is a virtual token, governed by ERC20-compatible Ethereum Smart Contract and secured by Ethereum Blockchain
// The official website is https://www.blackcoin.com/
//
// The uints are all in wei and atto tokens (*10^-18)

contract BKCToken is StandardToken, Ownable {
    using SafeMath for uint;

    //--------------   Info for ERC20 explorers  -----------------//
    string public name = "Black Coin";
    string public symbol = "BKC";
    uint public decimals = 18;

    //---------------------   Constants   ------------------------//
    bool public constant TEST_MODE = false;
    uint public constant atto = 1000000000000000000;
    uint public constant INITIAL_SUPPLY = 15000000 * atto; // 15 mln BKC. Impossible to mint more than this
    address public teamWallet = 0xb79F963f200f85D0e3dD60C82ABB8F80b5869CB9;
    // Made up ICO address (designating the token pool reserved for ICO, no one has access to it)
    address public ico_address = 0x1c01C01C01C01c01C01c01c01c01C01c01c01c01;
    uint public constant ICO_START_TIME = 1499810400;

    //----------------------  Variables  -------------------------//
    uint public current_supply = 0; // Holding the number of all the coins in existence
    uint public ico_starting_supply = 0; // How many atto tokens *were* available for sale at the beginning of the ICO
    uint public current_price_atto_tokens_per_wei = 0; // Holding current price (determined by the algorithm in buy())

    //-------------   Flags describing ICO stages   --------------//
    bool public preSoldSharesDistributed = false; // Prevents accidental re-distribution of shares
    bool public isICOOpened = false;
    bool public isICOClosed = false;
    // 3 stages:
    // Contract has just been deployed and initialized. isICOOpened == false, isICOClosed == false
    // ICO has started, now anybody can buy(). isICOOpened == true, isICOClosed == false
    // ICO has finished, now the team can receive the ether. isICOOpened == false, isICOClosed == true

    //---------------------   Premiums   -------------------------//
    uint[] public premiumPacks;
    mapping(address => uint) premiumPacksPaid;

    //----------------------   Events  ---------------------------//
    event ICOOpened();
    event ICOClosed();
    event PriceChanged(uint old_price, uint new_price);
    event SupplyChanged(uint supply, uint old_supply);
    event BKCAcquired(address account, uint amount_in_wei, uint amount_in_bkc);

    // ***************************************************************************

    // Constructor
    function BKCToken() {
        // Some percentage of the tokens is already reserved by early employees and investors
        // Here we're initializing their balances
        distributePreSoldShares();

        // Starting price
        current_price_atto_tokens_per_wei = calculateCurrentPrice(1);

        // Some other initializations
        premiumPacks.length = 0;
    }

    // Sending ether directly to the contract invokes buy() and assigns tokens to the sender
    function () payable {
        buy();
    }

    // ***************************************************************************

    // Buy token by sending ether here
    //
    // Price is being determined by the algorithm in recalculatePrice()
    // You can also send the ether directly to the contract address
    function buy() payable {
        if (msg.value == 0) throw; // no tokens for you

        // Only works in the ICO stage, after that the token is going to be traded on the exchanges
        if (!isICOOpened) throw;
        if (isICOClosed) throw;

        // Deciding how many tokens can be bought with the ether received
        uint tokens = getAttoTokensAmountPerWeiInternal(msg.value);

        // Don't allow to buy more than 1% per transaction (secures from huge investors swalling the whole thing in 1 second)
        uint allowedInOneTransaction = current_supply / 100;
        if (tokens > allowedInOneTransaction) throw;

        // Just in case
        if (tokens > balances[ico_address]) throw;

        // Transfer from the ICO pool
        balances[ico_address] = balances[ico_address].sub(tokens); // if not enough, will throw
        balances[msg.sender] = balances[msg.sender].add(tokens);

        // Kick the price changing algo
        uint old_price = current_price_atto_tokens_per_wei;
        current_price_atto_tokens_per_wei = calculateCurrentPrice(getAttoTokensBoughtInICO());
        if (current_price_atto_tokens_per_wei == 0) current_price_atto_tokens_per_wei = 1; // in case it is too small that it gets rounded to zero
        if (current_price_atto_tokens_per_wei > old_price) current_price_atto_tokens_per_wei = old_price; // in case some weird overflow happens

        // Broadcasting price change event
        if (old_price != current_price_atto_tokens_per_wei) PriceChanged(old_price, current_price_atto_tokens_per_wei);

        // Broadcasting the buying event
        BKCAcquired(msg.sender, msg.value, tokens);
    }

    // Formula for the dynamic price change algorithm
    function calculateCurrentPrice(uint attoTokensBought) constant returns (uint result) {
        // see http://www.wolframalpha.com/input/?i=f(x)+%3D+395500000+%2F+(x+%2B+150000)+-+136
        return (395500000 / ((attoTokensBought / atto) + 150000)).sub(136); // mixing safe and usual math here because the division will throw on inconsistency
    }

    // ***************************************************************************

    // Functions for the contract owner

    function openICO() onlyOwner {
        if (isICOOpened) throw;
        if (isICOClosed) throw;
        isICOOpened = true;

        ICOOpened();
    }
    function closeICO() onlyOwner {
        if (isICOClosed) throw;
        if (!isICOOpened) throw;

        isICOOpened = false;
        isICOClosed = true;

        // Redistribute ICO Tokens that were not bought as the first premiums
        premiumPacks.length = 1;
        premiumPacks[0] = balances[ico_address];
        balances[ico_address] = 0;

        ICOClosed();
    }
    function pullEtherFromContract() onlyOwner {
        // Only when ICO is closed
        if (!isICOClosed) throw;

        if (!teamWallet.send(this.balance)) {
            throw;
        }
    }

    // ***************************************************************************

    // Some percentage of the tokens is already reserved by early employees and investors
    // Here we're initializing their balances
    function distributePreSoldShares() onlyOwner {
        // Making it impossible to call this function twice
        if (preSoldSharesDistributed) throw;
        preSoldSharesDistributed = true;

        // Values are in atto tokens
        balances[0x7A3c869603E28b0242c129440c9dD97F8A5bEe80] = 7508811 * atto;
        balances[0x24a541dEAe0Fc87C990A208DE28a293fb2A982d9] = 4025712 * atto;
        balances[0xEcF843458e76052E6363fFb78C7535Cd87AA3AB2] = 300275 * atto;
        balances[0x947963ED2da750a0712AE0BF96E08C798813F277] = 150000 * atto;
        balances[0x82Bc8452Ab76fBA446e16b57C080F5258F557734] = 150000 * atto;
        balances[0x0959Ed48d55e580BB58df6E5ee01BAa787d80848] = 90000 * atto;
        balances[0x530A8016fB5B3d7A0F92910b4814e383835Bd51E] = 75000 * atto;
        balances[0xC3e934D3ADE0Ab9F61F824a9a824462c790e47B0] = 202 * atto;
        current_supply = (7508811 + 4025712 + 300275 + 150000 + 150000 + 90000 + 75000 + 202) * atto;

        // Sending the rest to ICO pool
        balances[ico_address] = INITIAL_SUPPLY.sub(current_supply);

        // Initializing the supply variables
        ico_starting_supply = balances[ico_address];
        current_supply = INITIAL_SUPPLY;
        SupplyChanged(0, current_supply);
    }

    // ***************************************************************************

    // Some useful getters (although you can just query the public variables)

    function getCurrentPriceAttoTokensPerWei() constant returns (uint result) {
        return current_price_atto_tokens_per_wei;
    }
    function getAttoTokensAmountPerWeiInternal(uint value) payable returns (uint result) {
        return value * current_price_atto_tokens_per_wei;
    }
    function getAttoTokensAmountPerWei(uint value) constant returns (uint result) {
        return value * current_price_atto_tokens_per_wei;
    }
    function getSupply() constant returns (uint result) {
        return current_supply;
    }
    function getAttoTokensLeftForICO() constant returns (uint result) {
        return balances[ico_address];
    }
    function getAttoTokensBoughtInICO() constant returns (uint result) {
        return ico_starting_supply - getAttoTokensLeftForICO();
    }
    function getBalance(address addr) constant returns (uint balance) {
        return balances[addr];
    }
    function getPremiumPack(uint index) constant returns (uint premium) {
        return premiumPacks[index];
    }
    function getPremiumCount() constant returns (uint length) {
        return premiumPacks.length;
    }
    function getBalancePremiumsPaid(address account) constant returns (uint result) {
        return premiumPacksPaid[account];
    }

    // ***************************************************************************

    // Premiums

    function sendPremiumPack(uint amount) onlyOwner allowedPayments(msg.sender, amount) {
        premiumPacks.length += 1;
        premiumPacks[premiumPacks.length-1] = amount;
        balances[msg.sender] = balances[msg.sender].sub(amount); // will throw and revert the whole thing if doesn't have this amount
    }

    function updatePremiums(address account) private {
        if (premiumPacks.length > premiumPacksPaid[account]) {
            uint startPackIndex = premiumPacksPaid[account];
            uint finishPackIndex = premiumPacks.length - 1;
            for(uint i = startPackIndex; i <= finishPackIndex; i++) {
                if (current_supply != 0) { // just in case
                    uint owing = balances[account] * premiumPacks[i] / current_supply;
                    balances[account] = balances[account].add(owing);
                }
            }
            premiumPacksPaid[account] = premiumPacks.length;
        }
    }

    // ***************************************************************************

    // Overriding payment functions to take control over the logic

    modifier allowedPayments(address payer, uint value) {
        // Don't allow to transfer coins until the ICO ends
        if (isICOOpened) throw;
        if (!isICOClosed) throw;

        // Limit the quick dump possibility
        uint diff = 0;
        uint allowed = 0;
        if (balances[payer] > current_supply / 100) { // for balances > 1% of total supply
            if (block.timestamp > ICO_START_TIME) {
                diff = block.timestamp - ICO_START_TIME;
            } else {
                diff = ICO_START_TIME - block.timestamp;
            }

            allowed = (current_supply / 20) * (diff / (60 * 60 * 24 * 30)); // 5% unlocked every month

            if (value > allowed) throw;
        }

        _;
    }

    function transferFrom(address _from, address _to, uint _value) allowedPayments(_from, _value) {
        updatePremiums(_from);
        updatePremiums(_to);
        super.transferFrom(_from, _to, _value);
    }
    function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) allowedPayments(msg.sender, _value) {
        updatePremiums(msg.sender);
        updatePremiums(_to);
        super.transfer(_to, _value);
    }

}
