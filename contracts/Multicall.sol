// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract Multicall {

    address public immutable raffleFactory;

    struct Raffle {
        string name;
        string symbol;

        address sponsor;
        address treasury;
        address entropy;
        address quote;
        address prizeToken;
        uint256 prizeId;

        uint256 ticketPrice;
        uint256 minimumTickets;
        uint256 endTimestamp;

        uint256 winnerTicketId;
        uint256 nextTicketId;

        bool drawn;
        bool settled;

        uint256 accountQuoteBalance;
        uint256 accountTicketBalance;
        uint256[] accountTicketIds;
        bool accountWinner;
    }

    constructor(address _raffleFactory) {
        raffleFactory = _raffleFactory;
    }


}
