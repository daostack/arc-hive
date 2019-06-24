var DAORegistry = artifacts.require("./DAORegistry.sol");

function assertVMException(error) {
    let condition = (
        error.message.search('VM Exception') > -1
    );
    assert.isTrue(condition, 'Expected a VM Exception, got this instead:' + error.message);
}
contract('DAORegistry', accounts => {

    it("register", async () => {
      var daoRegistry = await DAORegistry.new(accounts[0]);
      var tx = await daoRegistry.register(accounts[0],"test");
      assert.equal(tx.logs.length, 1);
      assert.equal(tx.logs[0].event, "Register");
      assert.equal(tx.logs[0].args._avatar,accounts[0]);
      assert.equal(await daoRegistry.isRegistered("test"),true);
      try {
          await daoRegistry.register(accounts[0],"test");
          assert(false, 'dao with the same name already registered');
        } catch (ex) {
          assertVMException(ex);
        }
    });

    it("register onlyOwner", async () => {
      var daoRegistry = await DAORegistry.new(accounts[1]);
      try {
          await daoRegistry.register(accounts[0],"test");
          assert(false, 'wrong owner');
        } catch (ex) {
          assertVMException(ex);
        }
    });

    it("unRegister onlyOwner", async () => {
      var daoRegistry = await DAORegistry.new(accounts[1]);
      await daoRegistry.register(accounts[0],"test",{from:accounts[1]});
      try {
          await daoRegistry.unRegister(accounts[0]);
          assert(false, 'wrong owner');
        } catch (ex) {
          assertVMException(ex);
        }
    });

    it("unRegister", async () => {
      var daoRegistry = await DAORegistry.new(accounts[0]);
      await daoRegistry.register(accounts[0],"test");
      var tx = await daoRegistry.unRegister(accounts[0]);
      assert.equal(tx.logs.length, 1);
      assert.equal(tx.logs[0].event, "UnRegister");
      assert.equal(tx.logs[0].args._avatar,accounts[0]);
      assert.equal(await daoRegistry.isRegistered("test"),true);
    });
});
