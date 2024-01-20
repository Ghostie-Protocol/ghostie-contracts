// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHandler.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITickets.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

pragma solidity ^0.8.20;

contract Handler is IHandler, Ownable {
    using SafeMath for uint256;
    address private operator;

    address public poolAddress; //AAVE V3 POOL
    address public borrowTokenAddress; //GHO
    address public aTokenAddress; //aUSDC
    address public tokenAddress; //USDC
    address private ticketAddress;

    mapping(uint256 => uint256) private ticketDept;
    mapping(uint256 => uint256) private ticketClaimed;
    mapping(uint256 => uint256) private ticketClaimeStamp;
    // mapping(uint256 => address) private farmContract;
    mapping(uint256 => uint256) private farmAmount;

    constructor(FarmConfig memory _farmConfig) Ownable() {
        transferOwnership(_farmConfig.coreContract);
        operator = _farmConfig.operator;
        poolAddress = _farmConfig.poolAddress;
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

    function getFarmAmount(uint256 _round) public view returns (uint256) {
        return farmAmount[_round];
    }

    function getTicketClaimed(uint256 _ticketId) public view returns (uint256) {
        return ticketClaimed[_ticketId];
    }

    function getTicketYield(
        uint256 _round,
        uint256 _ticketId
    ) public view returns (uint256) {
        uint256 aBalance = IERC20(aTokenAddress).balanceOf(address(this));
        uint256 ticketValue = ITickets(ticketAddress).getTicketValue(_ticketId);
        uint256 farmAmount_ = farmAmount[_round];

        uint256 farmYield = aBalance.sub(farmAmount_).div(5); // 20%
        uint256 ticketYield = farmYield.mul(ticketValue).div(farmAmount_);
        uint256 ticketClaimeds = ticketClaimed[_ticketId];

        if (ticketClaimeds > ticketYield) {
            return 0;
        } else {
            return ticketYield.sub(ticketClaimeds);
        }
    }

    function farm(uint256 _round, uint256 _amount) public onlyOwner {
        require(_amount > 0, "Farm amount must more than 0");
        farmAmount[_round] = _amount;
        IERC20(tokenAddress).approve(poolAddress, _amount);
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
        ticketClaimeStamp[_ticketId] = block.timestamp;
        IERC20(aTokenAddress).approve(poolAddress, ticketYield);
        IPool(poolAddress).withdraw(
            tokenAddress,
            ticketYield,
            address(this),
            _to
        );
    }

    function withdraw(uint256 _ticketId, address _to) public onlyOwner {
        uint256 ticketValue = ITickets(ticketAddress).getTicketValue(_ticketId);
        require(ticketValue > 0, "This ticket's value is 0 or invalid ID");

        ticketClaimed[_ticketId] += ticketValue;
        IERC20(aTokenAddress).approve(poolAddress, ticketValue);
        IPool(poolAddress).withdraw(
            tokenAddress,
            ticketValue,
            address(this),
            _to
        );
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
