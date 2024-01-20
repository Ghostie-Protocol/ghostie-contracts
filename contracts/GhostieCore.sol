// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./interfaces/IGhostieCore.sol";
import "./interfaces/IVRF.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ITickets.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GhostieCore is IGhostieCore, Ownable {
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
        uint256 ticketPrice;
        uint256 totalBalance;
        bool isCheckWinnerPrice;
        address[] matchAll;
        address[] match5d;
        address[] match4d;
        address[] match3d;
    }

    struct InvestorLottoRound {
        string[] numbers;
        uint256 totalValue;
        uint256 ticketId;
    }

    receive() external payable {}

    uint256 public currentRound;
    uint256 public ticketPrice;
    uint256 public roundTime;

    uint256 public usdcDecimals;

    mapping(uint256 => RoundDetail) public rounds;

    // mapping(address userAddr => mapping(uint256 round => uint256[])) investorTickets;
    // mapping(address userAddr => mapping(uint256 round => string[])) investorNumbers;
    // mapping(address userAddr => mapping(uint256 round => mapping(uint256 => string[]))) investorTicketDetail;
    // mapping(address userAddr => mapping(uint256 round => uint256)) investorRoundBalance;

    enum WinnerPrice {
        JACKPOT,
        LAST_FIVE_DIGITS,
        LAST_FOUR_DIGITS,
        LAST_THREE_DIGITS,
        ZERO
    }

    struct UserTicketDetail {
        uint256 ticketId;
        string[] numbers;
        WinnerPrice[] winnerType;
        uint256 totalBalance;
    }

    mapping(address userAddr => mapping(uint256 round => UserTicketDetail[])) investors;

    constructor(address _usdc, address _ticket, address _vrfAddress) Ownable() {
        usdc = IERC20(_usdc);
        ticket = ITickets(_ticket);
        vrfCore = IVRF(_vrfAddress);

        usdcDecimals = uint256(usdc.decimals());
        ticketPrice = 10 * 10 ** usdcDecimals;
        roundTime = 10 minutes;
    }

    function startLottoRound(
        uint256 startDate,
        uint256 endDate
    ) external onlyOwner returns (uint256) {
        RoundDetail memory _roundDetail;

        if (
            rounds[currentRound].endDate >= block.timestamp && currentRound != 0
        ) {
            revert(
                "Cannot start a new round, the current round has not expired."
            );
        }

        currentRound++;

        _roundDetail.startDate = startDate;
        _roundDetail.endDate = endDate;
        _roundDetail.drawDate = endDate + roundTime;
        _roundDetail.ticketPrice = ticketPrice;

        rounds[currentRound] = _roundDetail;

        emit StartNewRound(currentRound, startDate, endDate);
        return (currentRound);
    }

    function closeLottoRound() external {
        RoundDetail memory _roundDetail = rounds[currentRound];
        require(
            _roundDetail.endDate <= block.timestamp,
            "The sale time has not yet expired."
        );

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

        usdc.transferFrom(msg.sender, address(this), totalTicketPrice);

        uint256 ticketId = ticket.mint(msg.sender, totalTicketPrice, _numbers);
        // investorTickets[msg.sender][currentRound].push(ticketId);

        // for (uint i = 0; i < _numbers.length; i++) {
        //     investorNumbers[msg.sender][currentRound].push(_numbers[i]);
        // }
        // investorTicketDetail[msg.sender][currentRound][ticketId] = _numbers;

        // rounds[currentRound].totalBalance += totalTicketPrice;

        // investorRoundBalance[msg.sender][currentRound] += totalTicketPrice;

        uint256 totalTicketLength = investors[msg.sender][currentRound].length;
        UserTicketDetail memory userTickets = investors[msg.sender][
            currentRound
        ][totalTicketLength];

        userTickets.numbers = _numbers;
        userTickets.ticketId = ticketId;
        userTickets.totalBalance = totalTicketPrice;

        investors[msg.sender][currentRound].push(userTickets);

        emit BuyTicketSuccess(totalTicketPrice, currentRound, ticketId);
    }

    function updateWinningNumber(uint256 winningNumber) external {
        RoundDetail memory _round = rounds[currentRound];

        if (stringsEqual(_round.winningNumber, "")) {
            string memory winNumber = uint256ToString(winningNumber);

            winNumber = zeroDigit(winNumber);
            rounds[currentRound].winningNumber = winNumber;

            checkWinningDrawPrice(currentRound);

            rounds[currentRound].isCheckWinnerPrice = true;
        }
    }

    // function getAllTicketsPerRound(uint256 round) external {
    //     RoundDetail memory roundDetail = rounds[round];
    // }

    function zeroDigit(string memory s) public pure returns (string memory) {
        do {
            s = concatenateStrings("0", s);
        } while (bytes(s).length <= 6);
        return s;
    }

    function cliam(uint256 round) external view {
        uint256 cliamState = rounds[round].drawDate - block.timestamp;

        if (cliamState > 0) {
            // interest claim
        } else {
            // total cliam
            RoundDetail memory _round = rounds[round];

            address[] memory matchAll = _round.matchAll;
            address[] memory match5d = _round.match5d;
            address[] memory match4d = _round.match4d;
            address[] memory match3d = _round.match3d;

            for (uint i = 0; i < matchAll.length; i++) {
                if (matchAll[i] == msg.sender) {}
            }
            for (uint i = 0; i < match5d.length; i++) {
                if (match5d[i] == msg.sender) {}
            }
            for (uint i = 0; i < match4d.length; i++) {
                if (match4d[i] == msg.sender) {}
            }
            for (uint i = 0; i < match3d.length; i++) {
                if (match3d[i] == msg.sender) {}
            }
        }
    }

    function checkWinningDrawPrice(uint256 round) internal {
        // string[] memory _numbers = investorNumbers[msg.sender][round];

        RoundDetail memory roundDetail = rounds[round];

        UserTicketDetail[] memory userTiecks = investors[msg.sender][round];

        string memory jackpotResult = roundDetail.winningNumber;
        string memory match5dResult = substring(jackpotResult, 1, 6);
        string memory match4dResult = substring(jackpotResult, 2, 6);
        string memory match3dResult = substring(jackpotResult, 3, 6);

        for (uint i = 0; i < userTiecks.length; i++) {
            string[] memory numbers = userTiecks[i].numbers;

            for (uint j = 0; j < numbers.length; j++) {
                string memory number5d = substring(numbers[i], 1, 6);
                string memory number4d = substring(numbers[i], 2, 6);
                string memory number3d = substring(numbers[i], 3, 6);

                WinnerPrice resultWinPrice = investors[msg.sender][round][i]
                    .winnerType[j];

                if (stringsEqual(numbers[i], jackpotResult)) {
                    resultWinPrice = WinnerPrice.JACKPOT;
                } else if (stringsEqual(number5d, match5dResult)) {
                    resultWinPrice = WinnerPrice.LAST_FIVE_DIGITS;
                } else if (stringsEqual(number4d, match4dResult)) {
                    resultWinPrice = WinnerPrice.LAST_FOUR_DIGITS;
                } else if (stringsEqual(number3d, match3dResult)) {
                    resultWinPrice = WinnerPrice.LAST_THREE_DIGITS;
                } else {
                    resultWinPrice = WinnerPrice.ZERO;
                }

                investors[msg.sender][round][i].winnerType[j] = resultWinPrice;
            }
        }

        // for (uint i = 0; i < _numbers.length; i++) {
        //     string memory number5d = substring(_numbers[i], 1, 6);
        //     string memory number4d = substring(_numbers[i], 2, 6);
        //     string memory number3d = substring(_numbers[i], 3, 6);
        //     if (stringsEqual(_numbers[i], jackpotResult)) {
        //         rounds[round].matchAll.push(msg.sender);
        //     } else if (stringsEqual(number5d, match5dResult)) {
        //         rounds[round].match5d.push(msg.sender);
        //     } else if (stringsEqual(number4d, match4dResult)) {
        //         rounds[round].match4d.push(msg.sender);
        //     } else if (stringsEqual(number3d, match3dResult)) {
        //         rounds[round].match3d.push(msg.sender);
        //     }
        // }
    }

    function history() external {}

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

    function concatenateStrings(
        string memory a,
        string memory b
    ) public pure returns (string memory) {
        bytes memory concatenatedBytes = abi.encodePacked(a, b);
        return string(concatenatedBytes);
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
