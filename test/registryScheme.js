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

contract("DaoRegistryScheme", accounts => {
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
    const { _administrator, _proposalId, _address , _name} = tx.logs[0].args;
    assert.strictEqual(_administrator.toLowerCase(), org.avatar.address.toLowerCase(), "Expect the _administrator to be the DAO's address");
    assert.strictEqual(_address.toLowerCase(), addressToRegister.toLowerCase(), "Expect the _address to equal the address provided for registration");
    assert.strictEqual(_name, nameToRegister, "Expect the _name to equal the name provided for registration");
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
    const proposal = await registryScheme.proposals.call(org.avatar.address, _proposalId);

    assert.exists(proposal, "There exists a proposal with this id");
  });
});
