var App = artifacts.require("./App.sol");
var Package = artifacts.require("./Package.sol");
var Avatar = artifacts.require("./Avatar.sol");
var Avatar2 = artifacts.require("./Avatar2.sol");
var ProxyAdmin = artifacts.require("./ProxyAdmin.sol");
var AdminUpgradeabilityProxy = artifacts.require("./AdminUpgradeabilityProxy.sol");
var ImplementationDirectory = artifacts.require("./ImplementationDirectory.sol");
var Proxy = artifacts.require("./Proxy.sol");
function assertVMException(error) {
    let condition = (
        error.message.search('VM Exception') > -1
    );
    assert.isTrue(condition, 'Expected a VM Exception, got this instead:' + error.message);
}
const NULL_HASH = '0x0000000000000000000000000000000000000000000000000000000000000000';
contract('AvatarFactory', accounts => {
    it("senario 1", async () => {
      var app = await App.new();
      var packageName = "DAOstack";
      var contractName = "Avatar";
      var admin = accounts[0];
      var avatar = await Avatar.new();
      var packageC = await Package.new();
      var implementationDirectory = await ImplementationDirectory.new();

      await implementationDirectory.setImplementation(contractName,avatar.address);

      await packageC.addVersion([0,1,0],implementationDirectory.address,NULL_HASH);
      await app.setPackage(packageName,packageC.address,[0,1,0]);
      var providerAddress = await app.getProvider(packageName);
      console.log(providerAddress,avatar.address);

      // Construct the call data for the initialize method of Avatar.sol.
      // This call data consists of the contract's `initialize` method with the value of `genesis`.
      var data = await new web3.eth.Contract(avatar.abi).methods.initialize("genesis").encodeABI();
    //  string memory packageName, string memory contractName, address admin, bytes memory data
      var tx = await app.create(packageName,contractName,admin,data);
      assert.equal(tx.logs.length, 1);
      assert.equal(tx.logs[0].event, "ProxyCreated");
      var avatarProxy1 = tx.logs[0].args.proxy;

      data = await new web3.eth.Contract(avatar.abi).methods.initialize("genesis2").encodeABI();
      tx = await app.create(packageName,contractName,admin,data);
      assert.equal(tx.logs.length, 1);
      assert.equal(tx.logs[0].event, "ProxyCreated");
      var avatarProxy2 = tx.logs[0].args.proxy;
      //  function getImplementation(string memory packageName, string memory contractName) public view returns (address) {
      var impInstance1 = await Avatar.at(avatarProxy1);
      var impInstance2 = await Avatar.at(avatarProxy2);
      var adminUpgradeabilityProxy  = await  AdminUpgradeabilityProxy.at(avatarProxy1);


    //  console.log("impInstance1",await adminUpgradeabilityProxy.implementation());

      // Retrieve the value stored in the instance contract.
      // Note that we cannot make the call using the same address that created the proxy
      // because of the transparent proxy problem. See: https://docs.openzeppelin.com/sdk/2.5/faq#why-am-i-getting-the-error-cannot-call-fallback-function-from-the-proxy-admin
      assert.equal("genesis",await impInstance1.orgName({from:accounts[1]}));
      assert.equal("genesis2",await impInstance2.orgName({from:accounts[1]}));
      var avatar2 = await Avatar2.new();
      console.log("avatarProxy1", avatar2.address);
      var proxyAdmin = await ProxyAdmin.new();
      //AdminUpgradeabilityProxy proxy, address implementation, bytes memory data
      data = await new web3.eth.Contract(avatar2.abi).methods.initialize().encodeABI();

      await adminUpgradeabilityProxy.upgradeToAndCall(avatar2.address,data,{from:accounts[0]});

      var impInstance3 = await Avatar2.at(avatarProxy1);
      //data = await new web3.eth.Contract(avatar2.abi).methods.initialize().encodeABI();
      //tx = await app.create(packageName,contractName,admin,data);
      //await impInstance3.initialize({from:accounts[1]});
      assert.equal("upgraded",await impInstance3.orgName({from:accounts[1]}));
      //assert.equal(true,false);

    });
});
