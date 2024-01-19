// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHandler.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITickets.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

pragma solidity ^0.8.20;

contract Handler is IHandler, Ownable {
    address private operator;

    address public poolAddress; //AAVE V3 POOL
    address public borrowTokenAddress; //GHO
    address public aTokenAddress; //aUSDC
    address public tokenAddress; //USDC
    address private ticketAddress;

    mapping(uint256 => uint256) private ticketDept;
    mapping(uint256 => uint256) private ticketClaimed;
    // mapping(uint256 => address) private farmContract;
    mapping(uint256 => uint256) private farmAmount;

    constructor(FarmConfig memory _farmConfig) Ownable() {
        transferOwnership(_farmConfig.coreContract);
        operator = _farmConfig.operator;
        poolAddress = _farmConfig.operator;
        borrowTokenAddress = _farmConfig.borrowTokenAddress;
        aTokenAddress = _farmConfig.aTokenAddress;
        tokenAddress = _farmConfig.tokenAddress;
        ticketAddress = _farmConfig.ticketAddress;
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

    function getTicketYield(
        uint256 _round,
        uint256 _ticketId
    ) public view returns (uint256) {
        uint256 aBalance = IERC20(aTokenAddress).balanceOf(address(this));
        uint256 ticketValue = ITickets(ticketAddress).getTicketValue(_ticketId);
        uint256 farmAmount_ = farmAmount[_round];

        uint256 farmYield = (aBalance - farmAmount_) / 5; // 20%
        uint256 ticketYield = farmYield / (ticketValue / farmAmount_);

        return ticketYield;
    }

    function farm(uint256 _round, uint256 _amount) public onlyOwner {
        require(_amount > 0, "Farm amount must more than 0");
        farmAmount[_round] = _amount;
        IPool(poolAddress).supply(tokenAddress, _amount, address(this), 0);
        emit Farm(_round, poolAddress, _amount);
    }

    function claim(
        uint256 _round,
        uint256 _ticketId,
        address _to
    ) public onlyOwner {
        uint256 ticketYield = getTicketYield(_round, _ticketId);
        require(ticketYield > 0, "This ticket's yield is 0 or invalid ID");

        ticketClaimed[_ticketId] += ticketYield;
        IPool(poolAddress).withdraw(tokenAddress, ticketYield, _to);
    }

    function withdraw(uint256 _ticketId, address _to) public onlyOwner {
        uint256 ticketValue = ITickets(ticketAddress).getTicketValue(_ticketId);
        require(ticketValue > 0, "This ticket's value is 0 or invalid ID");

        ticketClaimed[_ticketId] += ticketValue;
        IPool(poolAddress).withdraw(tokenAddress, ticketValue, _to);
    }

    function borrow(
        uint256 _ticketId,
        address _borrower,
        uint256 _amount
    ) public onlyOwner {
        uint256 ticketValue = ITickets(ticketAddress).getTicketValue(_ticketId);
        uint256 maximum = (ticketValue * 7) / 10;

        require(_amount <= maximum, "Maximum borrow amount > maximum");
        require(!(ticketDept[_ticketId] != 0), "Ticket dept is not paid");

        ticketDept[_ticketId] += _amount;

        IERC721(ticketAddress).safeTransferFrom(
            _borrower,
            address(this),
            _ticketId
        );

        // IPool(poolAddress).borrow(borrowTokenAddress, _amount, 2, 0, _borrower); // recheck onBehalfOf
        IPool(poolAddress).borrow(
            borrowTokenAddress,
            _amount,
            2,
            0,
            address(this)
        );

        IERC20(borrowTokenAddress).transfer(_borrower, _amount);
    }
}
