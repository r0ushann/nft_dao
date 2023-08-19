//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract CryptoDevsNFT is ERC721Enumerable{

    // Initialize the ERC-721 contract
    constructor() ERC721("CryptoDevs", "CD") {}

    // public mint function anyone can call to get an NFT i.e due to {public keyword}
    function mint() public {
        _safeMint(msg.sender, totalSupply());
    }

}