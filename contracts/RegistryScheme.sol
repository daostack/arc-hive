pragma solidity >=0.5.4 <0.6.0;

import "@daostack/arc/contracts/universalSchemes/UniversalScheme.sol";
import "@daostack/arc/contracts/votingMachines/VotingMachineCallbacks.sol";
import "@daostack/infra/contracts/votingMachines/IntVoteInterface.sol";
import "@daostack/infra/contracts/votingMachines/VotingMachineCallbacksInterface.sol";
import "./DAORegistry.sol";

/**
 * @title A universal scheme for managing a registry of named addresses
 * @dev The RegistryScheme has a registry of addresses for each DAO.
 *      A DAO can add and remove names/address mappings inside its registry by voting
 */
contract RegistryScheme is UniversalScheme, VotingMachineCallbacks, ProposalExecuteInterface {

    event ProposeToRegister (
        address indexed _administrator,
        bytes32 indexed _proposalId,
        address _address,
        string _name
    );

    event ProposeToUnregister (
        address indexed _administrator,
        bytes32 indexed _proposalId,
        address _address
    );

    event ProposalExecuted(
        address indexed _administrator,
        bytes32 indexed _proposalId,
        int256 _voteOutcome,
        bytes _executionCall
    );

    // A mapping that mapes each administrator to a mapping of proposalsIds to
    // the proposal execution call (ABI encoding)
    mapping(address=>mapping(bytes32=>bytes)) public proposals;

    struct Parameters {
        bytes32 voteParams;
        IntVoteInterface intVote;
        DAORegistry daoRegistry;
    }

    // A mapping from hashes to parameters (use to store a particular configuration on the controller)
    mapping(bytes32=>Parameters) public parameters;

    /**
     * @dev execution of proposals, can only be called by the voting machine in which the vote is held.
     * @param _proposalId the ID of the proposal
     * @param _outcome the outcome of the vote; 1 is yes, all other values are no
     */
    function executeProposal(
        bytes32 _proposalId,
        int256 _outcome
    ) external onlyVotingMachine(_proposalId) returns(bool) {
        Avatar administrator = proposalsInfo[msg.sender][_proposalId].avatar;
        bytes memory executionCall = proposals[address(administrator)][_proposalId];
        // guard against re-entry
        delete proposals[address(administrator)][_proposalId];

        if (_outcome == 1) {
            Parameters memory params = parameters[getParametersFromController(administrator)];
            bool success;
            ControllerInterface controller = ControllerInterface(administrator.owner());
            (success,) =
                controller.genericCall(address(params.daoRegistry), executionCall, administrator, 0);
            require(success, "proposal external call cannot be executed");
        }
        emit ProposalExecuted(address(administrator), _proposalId, _outcome, executionCall);
        return true;
    }

    /**
    * @dev hash the parameters, save them if necessary, and return the hash value
    */
    function setParameters(
        bytes32 _voteParams,
        IntVoteInterface _intVote,
        DAORegistry _daoRegistry
    ) public returns(bytes32 paramsHash)
    {
        paramsHash = getParametersHash(_voteParams, _intVote, _daoRegistry);
        parameters[paramsHash].voteParams = _voteParams;
        parameters[paramsHash].intVote = _intVote;
        parameters[paramsHash].daoRegistry = _daoRegistry;
    }

    function getParametersHash(
        bytes32 _voteParams,
        IntVoteInterface _intVote,
        DAORegistry _daoRegistry
    ) public pure returns(bytes32)
    {
        return keccak256(abi.encodePacked(_voteParams, _intVote, address(_daoRegistry)));
    }

    /**
    * @dev Propose to register a named address in the registry
    * @param _administrator the address of the DAO owning the registry
    * @param _name the name of the address we want to add to the registry
    * @param _address the address we want to add to the registry
    * @return a proposal Id
    */
    function proposeToRegister(
        address payable _administrator,
        string memory _name,
        address _address
    ) public returns(bytes32 proposalId)
    {
        Parameters memory params = parameters[getParametersFromController(Avatar(_administrator))];

        proposalId = params.intVote.propose(
            2,
            params.voteParams,
            msg.sender,
            _administrator
        );

        bytes memory executionCall =
            abi.encodeWithSignature("register(address,string)", _address, _name);

        emit ProposeToRegister(
            _administrator,
            proposalId,
            _address,
            _name
        );

        proposals[_administrator][proposalId] = executionCall;
        proposalsInfo[address(params.intVote)][proposalId] = ProposalInfo({
            blockNumber:block.number,
            avatar: Avatar(_administrator)
        });
    }

    /**
    * @dev Propose to remove a address inside the named registry
    * @param _administrator the address of the DAO owning the registry
    * @param _address the address we want to remove from the registry
    */
    function proposeToUnregister(
        address payable _administrator,
        address _address
    ) public returns(bytes32 proposalId)
    {
        Parameters memory params = parameters[getParametersFromController(Avatar(_administrator))];

        proposalId = params.intVote.propose(
            2,
            params.voteParams,
            msg.sender,
            _administrator
        );

        bytes memory executionCall = abi.encodeWithSignature("unRegister(address)", _address);

        proposals[_administrator][proposalId] = executionCall;

        emit ProposeToUnregister(_administrator, proposalId, _address);
        proposalsInfo[address(params.intVote)][proposalId] = ProposalInfo({
            blockNumber: block.number,
            avatar: Avatar(_administrator)
        });
    }
}
