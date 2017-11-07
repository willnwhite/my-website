import babel_polyfill from "babel-polyfill"; // TODO move into configuration file (it's only here because I've chosen to use ES2015+)
import Web3 from "web3";
import abi from "./contract/Y_sol_Y.abi"; // FIXME manual build step: having to rename ABI file extension to .abi.json by hand
import bigRat from "big-rational";

// const web3 = new Web3(Web3.givenProvider); // from web3 v1 docs

window.addEventListener("load", function() {
  // Checking if Web3 has been injected by the browser (Mist/MetaMask)
  if (typeof web3 !== "undefined") {
    // Use Mist/MetaMask's provider
    window.web3 = new Web3(web3.currentProvider);
  } else {
    // console.log("No web3? You should consider trying MetaMask!");
    // fallback - use your fallback strategy (local node / hosted node + in-dapp id mgmt / fail)
    // window.web3 = new Web3(
    //   new Web3.providers.HttpProvider("http://localhost:8545")
    // );
  }

  // Now you can start your app & access web3 freely:

  // Rinkeby
  // const contractAddress = "0xF4C3aC68Af170E71D2CDFcd3e04964053827A2f8"; // contract address on Rinkeby QUESTION This is a checksum address (has capitals). What's a checksum address for?
  // const payee = "0xa751fDbcBE2c6Cdcb9aCa517789C3974f930587c"; // NOTE Rinkeby address, not main net

  // testrpc
  const contractAddress = "0xe0805a8d107c45625a624b5284915C0A45F85d5e";
  const payee = "0x15be789665c03105c81130d884d5fa223d6f1260";

  const app = Elm.Main.embed(document.getElementById("main"), {
    ethereum: typeof web3 !== "undefined",
    payee
  });

  // setInterval(() => app.ports.ethereum.send(typeof web3 !== "undefined"), 1000); // TODO Raise issue with MetaMask that this doesn't work because enabling MetaMask does not make it inject web3 unless the page is reloaded.

  if (typeof web3 !== "undefined") {
    setInterval(
      async () => {
        const account = (await web3.eth.getAccounts())[0];
        app.ports.selectedAccount.send(account === undefined ? null : account);
      },
      100 // 100 is from https://github.com/MetaMask/faq/blob/master/DEVELOPERS.md#ear-listening-for-selected-account-changes
    );
  }

  app.ports.getPercent.subscribe(async () => {
    const contract = new web3.eth.Contract(abi, contractAddress);
    const numAndDenom = await Promise.all([
      contract.methods.nums(payee).call(),
      contract.methods.denoms(payee).call() // NOTE two calls here. Does using a struct for num and denom (one call) cost more gas to set? UPDATE: It's about whether payAndDonate is cheaper or not, as that's the most frequent.
    ]);
    app.ports.gotPercent.send(
      bigRat(numAndDenom[0], numAndDenom[1])
        .multiply(100) // 7% -> 7
        .toDecimal()
    );
  });

  // call validAddress only if address is valid
  app.ports.validateAddress.subscribe(input =>
    app.ports.validAddress.send({
      input,
      valid: web3.utils.isAddress(input)
    })
  );

  app.ports.pay.subscribe(async ({ amount, donee }) => {
    const contract = new web3.eth.Contract(abi, contractAddress);
    const payer = (await web3.eth.getAccounts())[0];
    contract.methods
      .payAndDonate(payee, donee)
      .send({
        from: payer,
        value: web3.utils.toWei(amount, "ether")
      })
      .on("transactionHash", _ => app.ports.paying.send(null))
      .on("receipt", async receipt => {
        const message =
          "This will prove that you own the paying account without revealing your private key.";
        app.ports.paid.send({
          txHash: receipt.transactionHash,
          signature: {
            signature: await web3.eth.personal.sign(message, payer),
            message
          } // NOTE "Many of these functions send sensitive information, like password. Never call these functions over a unsecured Websocket or HTTP provider, as your password will be send in plain text!" http://web3js.readthedocs.io/en/1.0/web3-eth-personal.html?highlight=sign#web3-eth-personal QUESTION Does MetaMask take care of this? What about fallback nodes? Are they secure?
        });
      });
  });

  app.ports.portsReady.send(null);
});
