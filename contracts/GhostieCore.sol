// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/IGhostieCore.sol";
import "./interfaces/IVRF.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITickets.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GhostieCores is IGhostieCore, Ownable {
    using Strings for string;

    IVRF private vrfCore;
    IERC20 immutable usdc;
    ITickets immutable ticket;

    struct RoundDetail {
        uint256 startDate;
        uint256 endDate;
        uint256 drawDate;
        string winningNumber;
        uint256 randomRequestId;
        address[] matchAll;
        address[] match5d;
        address[] match4d;
        address[] match3d;
    }

    struct UserLottoRound {
        string[] numbers;
        uint256 totalValue;
        uint256 ticketId;
    }

    receive() external payable {}

    uint256 public currentRound;
    uint256 public ticketPrice;
    uint256 public roundTime;

    uint8 public usdcDecimals;

    mapping(uint256 => RoundDetail) rounds;
    mapping(address => mapping(uint256 => UserLottoRound)) investorDetail;

    constructor(
        address _usdc,
        address _ticket,
        address _owner,
        address _vrfAddress
    ) Ownable() {
        usdc = IERC20(_usdc);
        ticket = ITickets(_ticket);
        vrfCore = IVRF(_vrfAddress);

        transferOwnership(_owner);

        usdcDecimals = usdc.decimals();
        ticketPrice = 10 * 10 ** usdcDecimals;
        roundTime = 10 minutes;
    }

    function startLottoRound(
        uint256 startDate,
        uint256 endDate
    ) external onlyOwner returns (uint256) {
        RoundDetail memory _roundDetail;

        if (currentRound == 0) {
            currentRound++;
        } else if (rounds[currentRound].endDate >= block.timestamp) {
            revert(
                "Cannot start a new round, the current round has not expired."
            );
        }

        _roundDetail.startDate = startDate;
        _roundDetail.endDate = endDate;
        _roundDetail.drawDate = endDate + roundTime;

        rounds[currentRound] = _roundDetail;

        emit StartNewRound(currentRound, startDate, endDate);
        return (currentRound);
    }

    function closeLottoRound() external {
        uint256 requestId = vrfCore.requestRandomWords();
        rounds[currentRound].randomRequestId = requestId;
    }

    function buyTicket(string[] memory _numbers) external {
        RoundDetail memory currRound = rounds[currentRound];

        require(
            currRound.startDate <= block.timestamp &&
                currRound.endDate >= block.timestamp,
            "Not at the time of ticket purchase"
        );

        uint256 tokenAllowance = usdc.allowance(msg.sender, address(this));
        uint256 userBalance = usdc.balanceOf(msg.sender);
        uint256 totalTicketPrice = _numbers.length * ticketPrice;

        require(tokenAllowance > 0, "Approve token is not enough!");
        require(userBalance >= totalTicketPrice, "Your balance is not enough!");

        usdc.transfer(address(this), totalTicketPrice);

        uint256 ticketId = ticket.mint(msg.sender, totalTicketPrice, _numbers);

        investorDetail[msg.sender][currentRound].numbers = _numbers;
        investorDetail[msg.sender][currentRound].ticketId = ticketId;
        investorDetail[msg.sender][currentRound].totalValue = totalTicketPrice;

        emit BuyTicketSuccess(totalTicketPrice, currentRound, ticketId);
    }

    function updateWinningNumber(uint256 winningNumber) external {
        string memory winNumber = uint256ToString(winningNumber);
        rounds[currentRound].winningNumber = winNumber;
    }

    function cliam(uint256 round) external {
        uint256 cliamState = rounds[round].endDate - block.timestamp;

        if (cliamState > 0) {
            // interest claim
        } else {
            // total cliam
            string[] memory _numbers = investorDetail[msg.sender][round]
                .numbers;
            RoundDetail memory roundDetail = rounds[round];

            string memory match5dResult = substring(
                roundDetail.winningNumber,
                1,
                6
            );

            string memory match4dResult = substring(
                roundDetail.winningNumber,
                2,
                6
            );

            string memory match3dResult = substring(
                roundDetail.winningNumber,
                3,
                6
            );

            for (uint i = 0; i < _numbers.length; i++) {
                string memory number5d = substring(_numbers[i], 1, 6);
                string memory number4d = substring(_numbers[i], 2, 6);
                string memory number3d = substring(_numbers[i], 3, 6);

                if (stringsEqual(_numbers[i], roundDetail.winningNumber)) {
                    rounds[round].matchAll.push(msg.sender);
                } else if (stringsEqual(number5d, match5dResult)) {
                    rounds[round].match5d.push(msg.sender);
                } else if (stringsEqual(number4d, match4dResult)) {
                    rounds[round].match4d.push(msg.sender);
                } else if (stringsEqual(number3d, match3dResult)) {
                    rounds[round].match3d.push(msg.sender);
                }
            }
        }
    }

    function substring(
        string memory str,
        uint startIndex,
        uint endIndex
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function stringsEqual(
        string memory a,
        string memory b
    ) public pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    function uint256ToString(uint256 _num) public pure returns (string memory) {
        if (_num == 0) {
            return "0";
        }

        uint256 temp = _num;
        uint256 digits;

        while (temp != 0) {
            temp /= 10;
            digits++;
        }

        bytes memory buffer = new bytes(digits);

        while (_num != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (_num % 10)));
            _num /= 10;
        }

        return string(buffer);
    }
}
