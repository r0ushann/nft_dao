//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface INFTMarketplace {
    function getPrice() external view returns (uint256);

    // @return Returns a boolean value, true if available else false
    function available(uint256 _tokenId) external view returns (bool);

    // @param _tokenId, the fake NFT tokenID to purchase
    function purchase(uint256 _tokenId) external payable;
}

/* 
    interface for cryptoDevsNFT containing only two functions that we are interested in
    */

interface ICryptoDevsNFT {
    // @dev balanceOf returns the number of NFTs owned by an address
    //@param owner, address to fetch number of NFTs
    //@return Returns the number of NFTs owned by an address
    function balanceOf(address owner) external view returns (uint256);

    //@dev tokenOfOwnerByIndex returns a tokenId at given index for owner
    //@param owner - address to fetch the NFT tokenId for
    //@param index - index of NFT in owned tokens array to fetch
    //@return Returns the NFT tokenId
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);
}

contract CryptoDevsDAO is Ownable {
    INFTMarketplace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    /**
    functionality we need in the DAO contract.
        ->Store created proposals in the contract
        ->Allow holders of CryptoDevs NFT to create new proposals
        ->Allow holders of CryptoDevs NFT to vote on proposals
        ->Allow holders of CryptoDevs NFT to execute a proposal after deadline has passed if the proposal passed
    */
    struct Proposal {
        uint256 nftTokenId;
        uint256 deadline;
        uint256 yayVotes;
        uint256 nayVotes;
        bool executed;
        mapping(uint256 => bool) voters; //a mapping of CryptoDevsNFT tokenIDs to booleans indicating whether that NFT has already been used to cast a vote or not
    }

    mapping(uint256 => Proposal) public proposals; // create a mapping of ID to proposals;
    uint256 public numProposals; // number of proposals that have been created

    /* @dev  payable constructor which initializes the contracts
        instances for NFTMarketplace and CryptoDevsNFT
        the payable keyword allows the constructor to accept ETH deposit when it is being deployed
    */
    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = INFTMarketplace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    /* 
    modifier which only allows a function to be 
    called by someone who owns at least 1 CryptoDevsNFT 
    */
    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT_A_DAO_MEMBER");
        _;
    }

    function createProposal(
        uint256 _nftTokenId
    ) external nftHolderOnly returns (uint256) {
        require(nftMarketplace.available(_nftTokenId), "NFT_NOT_FOR_SALE");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nftTokenId;
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;
        return numProposals - 1; // 0 based indexing
    }

    modifier activeProposalsOnly(uint256 proposalsIndex) {
        require(
            proposals[proposalsIndex].deadline > block.timestamp,
            "DEADLINE_EXCEEDED"
        );
        _;
    }

    enum Vote {
        YAY, // 0
        NAY // 1
    }

    function voteOnProposal(
        uint256 proposalIndex,
        Vote vote
    ) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        // Calculate how many NFTs are owned by the voter
        // that haven't already been used for voting on this proposal
        for (uint256 i = 0; i < voterNFTBalance; i++) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "ALREADY_VOTED");

        if (vote == Vote.YAY) {
            proposal.yayVotes += numVotes;
        } else {
            proposal.nayVotes += numVotes;
        }
    }

    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "DEADLINE_NOT_EXCEEDED"
        );
        require(
            proposals[proposalIndex].executed == false,
            "PROPOSAL_ALREADY_EXECUTED"
        );
        _;
    }

    function executeProposal(
        uint256 proposalIndex
    ) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];

        // If the proposal has more YAY votes than NAY votes
        // purchase the NFT from the FakeNFTMarketplace
        if (proposal.yayVotes > proposal.nayVotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw, contract balance empty");
        (bool sent, ) = payable(owner()).call{value: amount}("");
        require(sent, "FAILED_TO_WITHDRAW_ETHER");
    }

    receive() external payable {}

    fallback() external payable {}
}
