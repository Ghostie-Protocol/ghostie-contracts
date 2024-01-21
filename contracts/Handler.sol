// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IHandler.sol";
import "./interfaces/IPool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITickets.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

pragma solidity ^0.8.20;

contract Handler is IHandler, Ownable, IERC721Receiver {
    using SafeMath for uint256;
    address private operator;

    address public poolAddress; //AAVE V3 POOL (MOCK)
    address public borrowTokenAddress; //GHO
    address public aTokenAddress; //aUSDC
    address public tokenAddress; //USDC
    address public ticketAddress; // ERC721

    uint256 public preYieldSupply;
    mapping(uint256 => uint256) private ticketClaimed;
    mapping(uint256 => uint256) private ticketWithdrawed;
    mapping(uint256 => uint256) private ticketClaimeStamp;
    mapping(uint256 => mapping(uint256 => uint256)) private ticketDept; // round -> ticket id -> amout
    mapping(uint256 => uint256) private farmAmount;
    mapping(uint256 => uint256) private farmStopAmount;

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

    function addPreYieldSupply(uint256 _amount) public onlyOperator {
        require(_amount > 0, "Supply amount must more than 0");
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount);
        preYieldSupply = _amount;
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
        farmAmount[_round] -= ticketYield;
        IERC20(aTokenAddress).approve(poolAddress, ticketYield);
        IPool(poolAddress).withdraw(
            tokenAddress,
            ticketYield,
            address(this),
            _to
        );
    }

    function withdraw(
        uint256 _round,
        uint256 _ticketId,
        address _to,
        uint256 _prize
    ) public onlyOwner {
        uint256 ticketValue = ITickets(ticketAddress).getTicketValue(_ticketId);
        require(ticketValue > 0, "This ticket's value is 0 or invalid ID");

        uint256 aBalance = IERC20(aTokenAddress).balanceOf(address(this));
        uint256 farmAmount_ = farmAmount[_round];
        uint256 prizePool = (aBalance.sub(farmAmount_)).mul(4).div(5); // 80%

        uint256 winPrize = prizePool.mul(_prize).div(10 ** 6);
        uint256 withdrawAmount = ticketValue.add(winPrize);

        ticketWithdrawed[_ticketId] += withdrawAmount;
        farmAmount[_round] -= withdrawAmount;
        IERC20(aTokenAddress).approve(poolAddress, withdrawAmount);
        IPool(poolAddress).withdraw(
            tokenAddress,
            withdrawAmount,
            address(this),
            _to
        );
    }

    function borrow(
        uint256 _round,
        uint256 _ticketId,
        address _borrower,
        uint256 _amount
    ) public onlyOwner {
        uint256 ticketValue = ITickets(ticketAddress).getTicketValue(_ticketId);
        uint256 maximum = (ticketValue * 7) / 10;

        require(_amount <= maximum, "Maximum borrow amount > maximum");
        require(
            !(ticketDept[_round][_ticketId] != 0),
            "Ticket dept is not paid"
        );

        ticketDept[_round][_ticketId] += _amount;

        // borrower approve erc721 to handler
        IERC721(ticketAddress).safeTransferFrom(
            _borrower,
            address(this),
            _ticketId
        );

        IPool(poolAddress).borrow(
            borrowTokenAddress,
            _amount,
            2,
            0,
            address(this)
        );

        IERC20(borrowTokenAddress).transfer(_borrower, _amount);
    }

    function repay(
        uint256 _round,
        uint256 _ticketId,
        address _borrower
    ) public onlyOwner {
        // Borrower must approve to handler
        IERC20(borrowTokenAddress).transferFrom(
            _borrower,
            address(this),
            ticketDept[_round][_ticketId]
        );

        IERC721(ticketAddress).safeTransferFrom(
            address(this),
            _borrower,
            _ticketId
        );
    }

    function stopFarm(uint256 _round) public onlyOwner returns (uint256) {
        uint256 aBalance = IERC20(aTokenAddress).balanceOf(address(this));
        require(aBalance > 0, "Farming amount is 0");
        farmStopAmount[_round] = aBalance;

        IERC20(aTokenAddress).approve(poolAddress, aBalance);
        IPool(poolAddress).withdraw(
            tokenAddress,
            aBalance,
            address(this),
            address(this)
        );

        return aBalance;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
