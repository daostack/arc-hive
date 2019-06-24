pragma solidity >=0.5.4 <0.6.0;

import "@daostack/arc/contracts/universalSchemes/UniversalScheme.sol";
import "@daostack/arc/contracts/votingMachines/VotingMachineCallbacks.sol";
import "@daostack/infra/contracts/votingMachines/IntVoteInterface.sol";
import "@daostack/infra/contracts/votingMachines/VotingMachineCallbacksInterface.sol";

interface INameRegistry {
    function register(address _address, string calldata _name) external;
    function unRegister(address _address) external;
    function isRegistered(string calldata _name) external view returns(bool);
}

/**
 * @title A universal scheme for managing a registry of named addresses
 * @dev The RegistryScheme uses generic actions to interact with a INameRegistry the Avatar owns.
 */
contract RegistryScheme is UniversalScheme, VotingMachineCallbacks, ProposalExecuteInterface {

    event ProposeToRegister (
        address indexed _avatar,
        bytes32 indexed _proposalId,
        address indexed _address,
        string _name
    );

    event ProposeToUnregister (
        address indexed _avatar,
        bytes32 indexed _proposalId,
        address indexed _address
    );

    event ProposalExecuted(
        address indexed _avatar,
        bytes32 indexed _proposalId,
        int256 _voteOutcome,
        bytes _executionCall
    );

    // A mapping that maps each administrator to a mapping of proposalsIds to
    // the proposal execution call (ABI encoding)
    mapping(address=>mapping(bytes32=>bytes)) public proposals;

    struct Parameters {
        bytes32 voteParams;
        IntVoteInterface intVote;
        INameRegistry registry;
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
        Avatar avatar = proposalsInfo[msg.sender][_proposalId].avatar;
        bytes memory executionCall = proposals[address(avatar)][_proposalId];
        // guard against re-entry
        delete proposals[address(avatar)][_proposalId];

        if (_outcome == 1) {
            Parameters memory params = parameters[getParametersFromController(avatar)];
            ControllerInterface controller = ControllerInterface(avatar.owner());
            bool success;
            (success,) =
                controller.genericCall(address(params.registry), executionCall, avatar, 0);
            require(success, "proposal external call cannot be executed");
        }

        emit ProposalExecuted(address(avatar), _proposalId, _outcome, executionCall);
        return true;
    }

    /**
    * @dev hash the parameters, save them if necessary, and return the hash value
    */
    function setParameters(
        bytes32 _voteParams,
        IntVoteInterface _intVote,
        INameRegistry _registry
    ) public returns(bytes32 paramsHash)
    {
        paramsHash = getParametersHash(_voteParams, _intVote, _registry);
        parameters[paramsHash].voteParams = _voteParams;
        parameters[paramsHash].intVote = _intVote;
        parameters[paramsHash].registry = _registry;
    }

    function getParametersHash(
        bytes32 _voteParams,
        IntVoteInterface _intVote,
        INameRegistry _registry
    ) public pure returns(bytes32 paramsHash)
    {
        paramsHash = keccak256(abi.encodePacked(_voteParams, _intVote, address(_registry)));
    }

    /**
    * @dev Propose to register a named address in the registry
    * @param _avatar the avatar of the DAO owning the registry
    * @param _name the name of the address we want to add to the registry
    * @param _address the address we want to add to the registry
    * @return a proposal Id
    */
    function proposeToRegister(
        Avatar _avatar,
        string memory _name,
        address _address
    ) public returns(bytes32 proposalId)
    {
        Parameters memory params = parameters[getParametersFromController(_avatar)];

        proposalId = params.intVote.propose(
            2,
            params.voteParams,
            msg.sender,
            address(_avatar)
        );

        bytes memory executionCall =
            abi.encodeWithSignature("register(address,string)", _address, _name);

        emit ProposeToRegister(
            address(_avatar),
            proposalId,
            _address,
            _name
        );

        proposals[address(_avatar)][proposalId] = executionCall;
        proposalsInfo[address(params.intVote)][proposalId] = ProposalInfo({
            blockNumber:block.number,
            avatar: _avatar
        });
    }

    /**
    * @dev Propose to remove a address inside the named registry
    * @param _avatar the Avatar of the DAO owning the registry
    * @param _address the address we want to remove from the registry
    */
    function proposeToUnregister(
        Avatar _avatar,
        address _address
    ) public returns(bytes32 proposalId)
    {
        Parameters memory params = parameters[getParametersFromController(_avatar)];

        proposalId = params.intVote.propose(
            2,
            params.voteParams,
            msg.sender,
            address(_avatar)
        );

        bytes memory executionCall = abi.encodeWithSignature("unRegister(address)", _address);

        proposals[address(_avatar)][proposalId] = executionCall;

        emit ProposeToUnregister(address(_avatar), proposalId, _address);
        proposalsInfo[address(params.intVote)][proposalId] = ProposalInfo({
            blockNumber: block.number,
            avatar: _avatar
        });
    }
}
