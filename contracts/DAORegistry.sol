pragma solidity ^0.5.14;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";

contract DAORegistry is Ownable {

    event Propose(address indexed _avatar);
    event Register(address indexed _avatar, string _name);
    event UnRegister(address indexed _avatar);

    mapping(string=>bool) private registry;

    function propose(address _avatar) public {
        emit Propose(_avatar);
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
    function isRegister(string memory _name) public view returns(bool) {
        return registry[_name];
    }

}
