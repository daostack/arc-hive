pragma solidity >=0.5.4 <0.6.0;

import "@daostack/arc/contracts/universalSchemes/UniversalScheme.sol";
import "@daostack/arc/contracts/votingMachines/VotingMachineCallbacks.sol";
import "@daostack/infra/contracts/votingMachines/IntVoteInterface.sol";
import "@daostack/infra/contracts/votingMachines/VotingMachineCallbacksInterface.sol";
import "./DAORegistry.sol";

/**
 * @title A universal scheme for letting organizations manage a registrar of named DAOs
 * @dev The DAORegistryScheme has a registry of DAOs for each organization.
 *      The organizations can through a vote choose to register allowing them to add/remove names inside the registry.
 */
contract DAORegistryScheme is UniversalScheme, VotingMachineCallbacks, ProposalExecuteInterface {

    event NewDAOProposal (
        address indexed _avatar,
        bytes32 indexed _proposalId,
        address _proposedAvatarAddress,
        string _proposedAvatarName
    );

    event RemoveDAOProposal (
        address indexed _avatar,
        bytes32 indexed _proposalId,
        address _proposedAvatarAddress
    );

    event ProposalExecuted(address indexed _avatar, bytes32 indexed _proposalId, int256 _param, bytes _returnValue);
    event ProposalDeleted(address indexed _avatar, bytes32 indexed _proposalId);

    // a DAORegistryProposal is a proposal to add or remove a named DAO to/from an organization
    struct DAORegistryProposal {
        bytes callData; //The abi encode data for the call to registry contracts
        uint256 value;
    }

    // A mapping from the organization (Avatar) address to the saved data of the organization:
    mapping(address=>mapping(bytes32=>DAORegistryProposal)) public organizationsProposals;

    // A mapping from hashes to parameters (use to store a particular configuration on the controller)
    struct Parameters {
        bytes32 voteParams;
        IntVoteInterface intVote;
        DAORegistry daoRegistry;
    }

    mapping(bytes32=>Parameters) public parameters;

    /**
     * @dev execution of proposals, can only be called by the voting machine in which the vote is held.
     * @param _proposalId the ID of the voting in the voting machine
     * @param _param a parameter of the voting result, 1 yes and 2 is no.
     */
    function executeProposal(bytes32 _proposalId, int256 _param) external onlyVotingMachine(_proposalId) returns(bool) {
        Avatar avatar = proposalsInfo[msg.sender][_proposalId].avatar;
        DAORegistryProposal memory proposal = organizationsProposals[address(avatar)][_proposalId];
        delete organizationsProposals[address(avatar)][_proposalId];
        emit ProposalDeleted(address(avatar), _proposalId);

        if (_param == 1) {
            Parameters memory params = parameters[getParametersFromController(avatar)];
            bytes memory genericCallReturnValue;
            bool success;
            ControllerInterface controller = ControllerInterface(avatar.owner());
            (success, genericCallReturnValue) =
                controller.genericCall(address(params.daoRegistry), proposal.callData, avatar, proposal.value);
            require(success, "proposal external call cannot be executed");
            emit ProposalExecuted(address(avatar), _proposalId, _param, genericCallReturnValue);
        }

        return true;
    }

    /**
    * @dev hash the parameters, save them if necessary, and return the hash value
    */
    function setParameters(
        bytes32 _voteParams,
        IntVoteInterface _intVote,
        DAORegistry _daoRegistry
    ) public returns(bytes32)
    {
        bytes32 paramsHash = getParametersHash(_voteParams, _intVote, _daoRegistry);
        parameters[paramsHash].voteParams = _voteParams;
        parameters[paramsHash].intVote = _intVote;
        parameters[paramsHash].daoRegistry = _daoRegistry;
        return paramsHash;
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
    * @dev create a proposal to register a DAO in the registry
    * @param _avatar the address of the organization owning the registry
    * @param _proposedAvatarName the name of the organization we want to add to the registry
    * @param _proposedAvatar the organization we want to add to the registry
    * @param _value value(ETH) to transfer with the call
    * @return a proposal Id
    */
    function proposeToAddDAO(
        Avatar _avatar,
        string memory _proposedAvatarName,
        Avatar _proposedAvatar,
        uint256 _value
    ) public returns(bytes32)
    {
        Parameters memory controllerParams = parameters[getParametersFromController(_avatar)];

        bytes32 proposalId = controllerParams.intVote.propose(
            2,
            controllerParams.voteParams,
            msg.sender,
            address(_avatar)
        );

        bytes memory callData =
            abi.encodeWithSignature("register(address, string memory)", address(_proposedAvatar), _proposedAvatarName);

        DAORegistryProposal memory proposal = DAORegistryProposal({
            callData: callData,
            value: _value
        });

        emit NewDAOProposal(
            address(_avatar),
            proposalId,
            address(_proposedAvatar),
            _proposedAvatarName
        );

        organizationsProposals[address(_avatar)][proposalId] = proposal;
        proposalsInfo[address(controllerParams.intVote)][proposalId] = ProposalInfo({
            blockNumber:block.number,
            avatar:_avatar
        });

        return proposalId;
    }

    /**
    * @dev propose to remove a DAO inside a named registry
    * @param _avatar the address of the controller from which we want to remove a scheme
    * @param _proposedAvatar the organization we want to remove from the registry
    * @param _value value(ETH) to transfer with the call
    */
    function proposeToRemoveDAO(
        Avatar _avatar,
        Avatar _proposedAvatar,
        uint256 _value
    ) public returns(bytes32)
    {
        bytes32 paramsHash = getParametersFromController(_avatar);
        Parameters memory params = parameters[paramsHash];

        bytes memory callData = abi.encodeWithSignature("unRegister(address)", address(_proposedAvatar));

        IntVoteInterface intVote = params.intVote;
        bytes32 proposalId = intVote.propose(2, params.voteParams, msg.sender, address(_avatar));
        organizationsProposals[address(_avatar)][proposalId].callData = callData;
        organizationsProposals[address(_avatar)][proposalId].value = _value;

        emit RemoveDAOProposal(address(_avatar), proposalId, address(_proposedAvatar));
        proposalsInfo[address(params.intVote)][proposalId] = ProposalInfo({
            blockNumber: block.number,
            avatar: _avatar
        });
        return proposalId;
    }
}
