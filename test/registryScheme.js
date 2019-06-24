import * as helpers from "./helpers";
const constants = require("./constants");
const ERC20Mock = artifacts.require("ERC20Mock");

const RegistryScheme = artifacts.require("RegistryScheme");
const DAORegistry = artifacts.require("DAORegistry");

const DaoCreator = artifacts.require("DaoCreator");
const ControllerCreator = artifacts.require("ControllerCreator");

const setupRegistrySchemeParams = async (
  registryScheme,
  daoRegistryAddress
) => {
  const votingMachine = await helpers.setupAbsoluteVote();
  await registryScheme.setParameters(
    votingMachine.params,
    votingMachine.absoluteVote.address,
    daoRegistryAddress
  );
  const paramsHash = await registryScheme.getParametersHash(
    votingMachine.params,
    votingMachine.absoluteVote.address,
    daoRegistryAddress
  );

  return { votingMachine, paramsHash };
};

const setup = async accounts => {
  const permissions = "0x00000010";
  const fee = 10;
  const controllerCreator = await ControllerCreator.new({
    gas: constants.ARC_GAS_LIMIT
  });
  const daoCreator = await DaoCreator.new(controllerCreator.address, {
    gas: constants.ARC_GAS_LIMIT
  });
  const standardTokenMock = await ERC20Mock.new(accounts[1], 100);
  const registryScheme = await RegistryScheme.new();
  const reputationArray = [20, 40, 70];
  const org = await helpers.setupOrganizationWithArrays(
    daoCreator,
    [accounts[0], accounts[1], accounts[2]],
    [1000, 0, 0],
    reputationArray
  );

  const daoRegistry = await DAORegistry.new(org.avatar.address);
  const registrySchemeParams = await setupRegistrySchemeParams(
    registryScheme,
    daoRegistry.address
  );

  const testSetup = {
    fee,
    standardTokenMock,
    registryScheme,
    daoCreator,
    reputationArray,
    org,
    daoRegistry,
    registrySchemeParams
  };
  await testSetup.daoCreator.setSchemes(
    testSetup.org.avatar.address,
    [testSetup.registryScheme.address],
    [testSetup.registrySchemeParams.paramsHash],
    [permissions],
    "metaData"
  );

  return testSetup;
};

contract("RegistryScheme", accounts => {
  it("setParameters", async () => {
    const { registryScheme, registrySchemeParams, daoRegistry } = await setup(
      accounts
    );
    const parameters = await registryScheme.parameters(
      registrySchemeParams.paramsHash
    );

    assert.equal(
      parameters[1],
      registrySchemeParams.votingMachine.absoluteVote.address
    );

    assert.equal(parameters[2], daoRegistry.address);
  });

  it("proposeToRegister log", async function() {
    const { registryScheme, org } = await setup(accounts);

    // the registering entity
    const nameToRegister = "dOrg";
    const addressToRegister = "0xd3e184783ed99df8dc2c48944cd9127088983c22";

    const tx = await registryScheme.proposeToRegister(
      org.avatar.address,
      nameToRegister,
      addressToRegister
    );
    assert.equal(tx.logs.length, 1);
    assert.equal(tx.logs[0].event, "ProposeToRegister");
    const { _avatar, _proposalId, _address, _name } = tx.logs[0].args;
    assert.strictEqual(
      _avatar.toLowerCase(),
      org.avatar.address.toLowerCase(),
      "Expect the _avatar to be the DAO's address"
    );
    assert.strictEqual(
      _address.toLowerCase(),
      addressToRegister.toLowerCase(),
      "Expect the _address to equal the address provided for registration"
    );
    assert.strictEqual(
      _name,
      nameToRegister,
      "Expect the _name to equal the name provided for registration"
    );
    assert.isNotEmpty(_proposalId);
  });

  it("check that a proposal with that id exists", async function() {
    const { registryScheme, org } = await setup(accounts);

    // the registering entity
    const nameToRegister = "dOrg";
    const addressToRegister = "0xd3e184783ed99df8dc2c48944cd9127088983c22";

    const tx = await registryScheme.proposeToRegister(
      org.avatar.address,
      nameToRegister,
      addressToRegister
    );
    const { _proposalId } = tx.logs[0].args;
    const proposal = await registryScheme.proposals.call(
      org.avatar.address,
      _proposalId
    );

    assert.exists(proposal, "There exists a proposal with this id");
  });

  it("proposeToUnregister log", async function() {
    const { registryScheme, org } = await setup(accounts);

    const addressToUnregister = "0xd3e184783ed99df8dc2c48944cd9127088983c22";

    const tx = await registryScheme.proposeToUnregister(
      org.avatar.address,
      addressToUnregister
    );
    assert.equal(tx.logs.length, 1);
    assert.equal(tx.logs[0].event, "ProposeToUnregister");
    const { _avatar, _proposalId, _address } = tx.logs[0].args;
    assert.strictEqual(
      _avatar.toLowerCase(),
      org.avatar.address.toLowerCase(),
      "Expect the _avatar to be the DAO's address"
    );
    assert.strictEqual(
      _address.toLowerCase(),
      addressToUnregister.toLowerCase(),
      "Expect the _address to equal the address provided for registration"
    );
    assert.isNotEmpty(_proposalId);

    const proposal = await registryScheme.proposals.call(
      org.avatar.address,
      _proposalId
    );

    assert.exists(proposal, "There exists a proposal with this id");
  });

  it("propose to register and execute registration", async function() {
    const {
      registryScheme,
      org,
      registrySchemeParams,
      daoRegistry
    } = await setup(accounts);

    // the registering entity
    const nameToRegister = "dOrg";
    const addressToRegister = "0xd3e184783ed99df8dc2c48944cd9127088983c22";

    const tx = await registryScheme.proposeToRegister(
      org.avatar.address,
      nameToRegister,
      addressToRegister
    );
    const { _proposalId } = tx.logs[0].args;
    assert.isFalse(await daoRegistry.isRegistered("dOrg"));
    const vote = 1; // vote yes
    const amount = 0; // no payment
    const voter = helpers.NULL_ADDRESS; // not used, voting as myself
    await registrySchemeParams.votingMachine.absoluteVote.vote(
      _proposalId,
      vote,
      amount,
      voter,
      { from: accounts[2] }
    );
    assert.isTrue(await daoRegistry.isRegistered("dOrg"));
  });

  it("propose to register and execute registration, then propose to unregister and execute unregistration", async function() {
    const {
      registryScheme,
      org,
      registrySchemeParams,
      daoRegistry
    } = await setup(accounts);

    // the registering entity
    const nameToRegister = "dOrg";
    const addressToRegister = "0xd3e184783ed99df8dc2c48944cd9127088983c22";

    // register
    const registerTx = await registryScheme.proposeToRegister(
      org.avatar.address,
      nameToRegister,
      addressToRegister
    );
    const { _proposalId: registerProposal } = registerTx.logs[0].args;
    const registerVote = 1; // vote yes
    const registerAmount = 0; // no payment
    const registerVoter = helpers.NULL_ADDRESS; // not used, voting as myself
    await registrySchemeParams.votingMachine.absoluteVote.vote(
      registerProposal,
      registerVote,
      registerAmount,
      registerVoter,
      { from: accounts[2] }
    );

    assert.isTrue(
      await daoRegistry.isRegistered("dOrg"),
      "dOrg should be registered"
    );

    // unregister
    const unregisterTx = await registryScheme.proposeToUnregister(
      org.avatar.address,
      addressToRegister
    );
    const { _proposalId: unregisterProposal } = unregisterTx.logs[0].args;
    const unregisterVote = 1; // vote yes
    const unregisterAmount = 0; // no payment
    const unregisterVoter = helpers.NULL_ADDRESS; // not used, voting as myself

    await registrySchemeParams.votingMachine.absoluteVote.vote(
      unregisterProposal,
      unregisterVote,
      unregisterAmount,
      unregisterVoter,
      { from: accounts[2] }
    );

    const allEvents = await daoRegistry.getPastEvents("allEvents", { fromBlock: 0, toBlock: "latest" });
    const unregisterEvent = allEvents[3];

    assert.equal(unregisterEvent.event, "UnRegister");
    const { _avatar } = unregisterEvent.args;
    assert.equal(
      _avatar.toLowerCase(),
      addressToRegister.toLowerCase(),
      "the unregister event should be for the correct address"
    );
  });
});
