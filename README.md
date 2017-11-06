Y: https://github.com/willnwhite/Y

## Development

Do as little in JS as possible. Only using JS for web3.

Contract is designed to minimise payAndDonate execution cost at all costs, as it will tend to be the most frequently called function.

In the following command prompts, this means in the `my-website` directory:
```shell
my-website $
```

To serve on localhost:
```shell
public $ python -m SimpleHTTPServer
```

To transpile and bundle js.js every time it's saved:
```shell
my-website $ npx watchify js.js -t babelify -o public/bundle.js
```

To compile Main.elm:
```shell
my-website $ elm make Main.elm --output public/main.js
```

To run testrpc and keep the blockchain (else you'll have to deploy Y on a new blockchain every time):
```shell
contract $ mkdir chain
contract $ testrpc --db chain
```
Paste the payee's address into js.js.
Save the HD wallet mnemonic to file, so you don't have to import accounts into MetaMask more than once. Save the mnemonic OUTSIDE the project directory, as accidentally publishing the mnemonic will give hackers your private keys, and you may go on to use the same addresses on other networks, even the main network.

To deploy Y and set payee's donation percent:
```shell
contract $ node deploy_Y.js [Y's owner's address] [payee's address] [donation percent num] [donation percent denom]
```
Paste Y's address and payee's address into js.js.

To start testrpc with the same addresses:
```shell
contract $ testrpc --db chain -m "the HD wallet mnemonic"
```

To compile Y.sol:
```shell
contract $ npx solcjs Y.sol --bin
```

To get Y.sol's ABI:
```shell
contract $ npx solcjs Y.sol --abi
```
You have to rename ABI file from .abi to .json.
