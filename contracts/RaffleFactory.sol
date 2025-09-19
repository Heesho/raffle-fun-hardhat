// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721, ERC721Enumerable, IERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropyV2} from "@pythnetwork/entropy-sdk-solidity/IEntropyV2.sol";

contract Raffle is ERC721, ERC721Enumerable, IERC721Receiver, IEntropyConsumer, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant DIVISOR = 100;
    uint256 public constant FEE = 5;
    uint256 public constant SPLIT = 50;

    address public immutable sponsor;
    address public immutable treasury;
    address public immutable entropy;
    address public immutable quote;
    address public immutable prizeToken;
    uint256 public immutable prizeId;
    uint256 public immutable ticketPrice;
    uint256 public immutable minimumTickets;
    uint256 public immutable endTimestamp;

    uint256 public nextTicketId;
    uint256 public winnerTicketId;

    error Raffle__ZeroTo();
    error Raffle__ZeroAmount();
    error Raffle__Drawn();
    error Raffle__InProgress();

    event Raffle__Buy(address indexed from, address indexed to, uint256 indexed ticketId);
    event Raffle__ProviderFeePaid(address indexed provider, uint256 amount);
    event Raffle__TreasuryFeePaid(address indexed treasury, uint256 amount);
    event Raffle__Draw(uint256 indexed winningTicketId);
    event Raffle__SettlementMinimumMet(address indexed owner, address indexed winner, uint256 amount);
    event Raffle__SettlementMinimumNotMet(address indexed owner, address indexed winner, uint256 winnerShare, uint256 ownerShare);

    constructor(
        string memory name,
        string memory symbol,
        address _sponsor,
        address _treasury,
        address _quote,
        address _entropy,
        address _prizeToken,
        uint256 _prizeId,
        uint256 _duration,
        uint256 _ticketPrice,
        uint256 _minimumTickets
    ) ERC721(name, symbol) {
        sponsor = _sponsor;
        treasury = _treasury;
        entropy = _entropy;
        quote = _quote;
        prizeToken = _prizeToken;
        prizeId = _prizeId;
        endTimestamp = block.timestamp + _duration;
        ticketPrice = _ticketPrice;
        minimumTickets = _minimumTickets;
    }

    function buy(address to, address provider, uint256 amount) external nonReentrant {
        if (to == address(0)) revert Raffle__ZeroTo();
        if (amount == 0) revert Raffle__ZeroAmount();
        if (winnerTicketId != 0) revert Raffle__Drawn();

        for (uint256 i = 0; i < amount; i++) {
            nextTicketId++;
            _safeMint(to, nextTicketId);
            emit Raffle__Buy(msg.sender, to, nextTicketId);
        }

        uint256 totalCost = amount * ticketPrice;
        uint256 fee = totalCost * FEE / DIVISOR;

        if (provider != address(0)) {
            IERC20(quote).safeTransferFrom(msg.sender, provider, fee);
            emit Raffle__ProviderFeePaid(provider, fee);
            totalCost -= fee;
        }
        
        if (treasury != address(0)) {
            IERC20(quote).safeTransferFrom(msg.sender, treasury, fee);
            emit Raffle__TreasuryFeePaid(treasury, fee);
            totalCost -= fee;
        }

        IERC20(quote).safeTransferFrom(msg.sender, address(this), totalCost);
    }

    function draw() external payable nonReentrant {
        if (winnerTicketId != 0) revert Raffle__Drawn();
        if (block.timestamp < endTimestamp) revert Raffle__InProgress();

        if (entropy != address(0)) {
            uint256 entropyFee = IEntropyV2(entropy).getFeeV2();
            IEntropyV2(entropy).requestV2{value: entropyFee}();
        } else {
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
            mockCallback(randomNumber);
        }
    }

    function settle() external nonReentrant {
        if (winnerTicketId == 0) revert Raffle__InProgress();

        uint256 balance = IERC20(quote).balanceOf(address(this));
        address winner = ownerOf(winnerTicketId);
        if (nextTicketId < minimumTickets) {
            IERC20(quote).transfer(sponsor, balance);
            IERC721(prizeToken).transferFrom(address(this), winner, prizeId);
            emit Raffle__SettlementMinimumMet(sponsor, winner, balance);
        } else {
            uint256 winnerShare = balance * SPLIT / DIVISOR;
            uint256 ownerShare = balance - winnerShare;
            IERC20(quote).transfer(winner, winnerShare);
            IERC20(quote).transfer(sponsor, ownerShare);
            IERC721(prizeToken).transferFrom(address(this), sponsor, prizeId);
            emit Raffle__SettlementMinimumNotMet(sponsor, winner, winnerShare, ownerShare);
        }
    }
      
    function entropyCallback(uint64, address, bytes32 randomNumber) internal override {
        winnerTicketId = (uint256(randomNumber) % (nextTicketId - 1)) + 1;
        emit Raffle__Draw(winnerTicketId);
    }

    function mockCallback(uint256 randomNumber) internal {
        winnerTicketId = (randomNumber % (nextTicketId - 1)) + 1;
        emit Raffle__Draw(winnerTicketId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
            return IERC721Receiver.onERC721Received.selector;
    }

    function getEntropy() internal view override returns (address) {
        return entropy;
    }

    function getEntropyFee() external view returns (uint256) {
        return IEntropyV2(entropy).getFeeV2();
    }
}

contract RaffleFactory is Ownable {

    address public immutable quote;
    address public immutable entropy;

    uint256 public immutable duration;
    uint256 public immutable ticketPrice;

    address public treasury;

    uint256 public index;
    mapping(uint256 => address) public index_Raffle;
    mapping(address => uint256) public raffle_Index;

    event RaffleFactory__Created(address indexed raffle);
    event RaffleFactory__TreasurySet(address indexed treasury);

    constructor(address _quote, address _entropy, uint256 _duration, uint256 _ticketPrice) {
        quote = _quote;
        entropy = _entropy;
        duration = _duration;
        ticketPrice = _ticketPrice;
    }

    function create(
        string memory name,
        string memory symbol,
        address sponsor,
        address prizeToken,
        uint256 prizeId,
        uint256 minimumTickets
    ) external returns (address) {
        Raffle raffle = new Raffle(name, symbol, sponsor, treasury, quote, entropy, prizeToken, prizeId, duration, ticketPrice, minimumTickets);
        IERC721(prizeToken).safeTransferFrom(msg.sender, address(raffle), prizeId);

        index++;
        index_Raffle[index] = address(raffle);
        raffle_Index[address(raffle)] = index;
        emit RaffleFactory__Created(address(raffle));
        return (address(raffle));
    }

    function buy(address raffle, address provider, uint256 amount) external {
        uint256 totalCost = amount * ticketPrice;

        IERC20(quote).transferFrom(msg.sender, address(this), totalCost);
        IERC20(quote).approve(raffle, totalCost);
        Raffle(raffle).buy(msg.sender, provider, amount);
    }
        
    function draw(address raffle) external payable {
        if (entropy != address(0)) {
            uint256 entropyFee = Raffle(raffle).getEntropyFee();
            require(msg.value >= entropyFee, "Insufficient ETH for entropy fee");
            Raffle(raffle).draw{value: entropyFee}();
        } else {
            Raffle(raffle).draw{value: 0}();
        }
    }

    function settle(address raffle) external {
        Raffle(raffle).settle();
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit RaffleFactory__TreasurySet(treasury);
    }

}
