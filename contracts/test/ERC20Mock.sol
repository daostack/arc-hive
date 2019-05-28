//  Copied from: https://github.com/daostack/arc/blob/master/contracts/test/ERC20Mock.sol

pragma solidity ^0.5.4;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";


// mock class using ERC20
contract ERC20Mock is ERC20 {

    constructor(address initialAccount, uint256 initialBalance) public {
        _mint(initialAccount, initialBalance);
    }
}
