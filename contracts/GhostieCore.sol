// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/IGhostieCore.sol";
import "./interfaces/IVRF.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITicket.sol";

contract GhostieCore is IGhostieCore {
    IVRF private immutable vrfCore;
    IERC20 immutable usdc;
    ITicket immutable ticket;

    enum RoundStep {
        SELLING,
        STAKING,
        END
    }

    struct RoundDetail {
        uint256 startDate;
        uint256 endDate;
        // RoundStep roundStep;
    }

    receive() external payable {}

    uint256 public currentRound;
    uint256 public ticketPrice;

    mapping(uint256 => RoundDetail) rounds;
    mapping(uint256 => mapping(string => address[])) ticketsDetails;

    constructor(address _vrfAddress, address _usdc, address _ticket) {
        vrfCore = IVRF(_vrfAddress);
        usdc = IERC20(_usdc);
        ticket = ITicket(_ticket);

        currentRound = 1;
        ticketPrice = 10 * 10 ** 18;
    }

    function startLottoRound(
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256) {
        rounds[currentRound] = RoundDetail({
            startDate: startDate,
            endDate: endDate
            // roundStep: RoundDetail.SELLING
        });
        currentRound++;
        return (currentRound);
    }

    function buyTicket(string[] memory _numbers) external {
        uint256 tokenAllowance = usdc.allowance(msg.sender, address(this));
        uint256 userBalance = usdc.balanceOf(msg.sender);
        uint256 totalTicketPrice = _numbers.length * ticketPrice;

        require(tokenAllowance > 0, "Approve token is not enough!");
        require(userBalance >= totalTicketPrice, "Your balance is not enough!");

        usdc.transfer(address(this), _numbers.length * ticketPrice);

        for (uint i = 0; i < _numbers.length; i++) {
            ticketsDetails[currentRound][_numbers[i]].push(msg.sender);
        }

        uint256 ticketId = ticket.mint(msg.sender, totalTicketPrice);

        emit BuyTicketSuccess(totalTicketPrice, currentRound);
    }
}
