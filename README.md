# ICO

Ethereum contracts for ICO [ico.selfie-go.com](https://ico.selfie-go.com) and [ico.clashgo.com](https://ico.clashgo.com).

# Test
* Make sure npm and truffle are available in path 
* git clone https://github.com/ElylandLLC/ico.git
* cd ico
* npm install
* cd test
* truffle test 

# Token contract notes
GoToken is based on ERC20 Burnable StandardToken from 
[OpenZeppelin framework](https://github.com/OpenZeppelin/zeppelin-solidity) with following additional features:
* Token has limited bitcoin-style emission, which is implemented in Token smart contract
* User input address in SelfieGo and ClashGo may be set AutoForward, so all tokens sent to are forwarded to special address.
Setting AutoForward is secured by Elliptic Curves Signatures, by the same way as secured ethereum transactions.
This feature facilitates token input into SelfieGo and ClashGo. 
* Token has ability to register some addresses as TokenReceiver. Such contracts are notified 
when tokens are received (Similar to ERC23 tokens). 
This feature is needed for SelfieGo EasyICO. 
* It is possible to transfer tokens to TokenReceiver contract (SelfieGo EasyICO sale) on behalf of other address. 
Other address may be a user input address (AutoForward), in that case sold tokens are going directly into SelfieGo user wallet.
This feature is also needed for SelfieGo EasyICO.   
