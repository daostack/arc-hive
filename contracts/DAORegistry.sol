pragma solidity ^0.5.4;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

contract DAORegistry is Ownable {

    event Register(address indexed _avatar, string _name);
    event UnRegister(address indexed _avatar);

    mapping(string=>bool) private registry;

    constructor(address _owner) public {
        transferOwnership(_owner);
    }

    function register(address _avatar, string memory _name) public onlyOwner {
        require(!registry[_name]);
        registry[_name] = true;
        emit Register(_avatar, _name);
    }

    function unRegister(address _avatar) public onlyOwner {
        emit UnRegister(_avatar);
    }

    //This getter is needed because Dynamically-sized keys for public mappings are not supported.
    function isRegistered(string memory _name) public view returns(bool) {
        return registry[_name];
    }

}
