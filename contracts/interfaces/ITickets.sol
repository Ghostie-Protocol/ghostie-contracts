// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface ITickets {
    event Mint(address indexed _to, uint256 _value, string[] _numbers);

    function mint(
        address _to,
        uint256 _value,
        string[] memory _numbers
    ) external returns (uint256);

    function setBaseURI(string memory _uri) external;

    function getTicketNumbers(
        uint256 _id
    ) external view returns (string[] memory);
}
