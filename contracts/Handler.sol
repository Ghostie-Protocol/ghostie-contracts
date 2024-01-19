// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.20;

contract Handler is Ownable {
    address private operator;

    constructor(address _coreContract, address _operator) Ownable() {
        transferOwnership(_coreContract);
        operator = _operator;
    }

    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    function _checkOperator() internal view virtual {
        require(
            (msg.sender == owner() || msg.sender == operator),
            "Only operator or owner !!"
        );
    }
}
