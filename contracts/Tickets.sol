// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

pragma solidity ^0.8.20;

contract Tickets is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _ticketIds;

    string private baseURI;
    address private operator;

    mapping(uint256 => string[]) private ticketNumbers;
    mapping(uint256 => uint256) private ticketValue;

    constructor(
        string memory _name,
        string memory _symbol,
        address _coreContract,
        address _operator
    ) ERC721(_name, _symbol) Ownable() {
        operator = _operator;
        transferOwnership(_coreContract);
    }

    modifier onlyOperator() {
        _checkOperator();
        _;
    }

    function mint(
        address _to,
        uint256 _value,
        string[] memory _numbers
    ) public onlyOwner {
        require(_to != address(0), "Destination address is 0x0");

        _ticketIds.increment();
        uint256 newTicketId = _ticketIds.current();
        
        _mint(_to, newTicketId);
        ticketNumbers[newTicketId] = _numbers;
        ticketValue[newTicketId] = _value;
    }

    function setBaseURI(string memory _uri) public onlyOperator {
        baseURI = _uri;
    }

    function getTicketNumbers(
        uint256 _id
    ) public view returns (string[] memory) {
        return ticketNumbers[_id];
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _checkOperator() internal view virtual {
        require(
            (msg.sender == owner() || msg.sender == operator),
            "Only operator or owner !!"
        );
    }
}
