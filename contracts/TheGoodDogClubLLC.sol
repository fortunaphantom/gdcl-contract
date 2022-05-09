// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title A contract for TheGoodDogClubLLC
/// @author Adam Lee
/// @notice NFT Minting

contract TheGoodDogClubLLC is ERC721, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMath for uint16;
    using SafeMath for uint8;
    uint16 private _tokenId;

    // Team wallet
    address[] teamWalletList = [
        0x775958f2478C2E0f8219D184B99Db7720686BbC0, // Wallet 1 address - The Good Dog Club LLC
        0x56Cea2250a0B6Fe52D2a5d683Cc30f3dbdD9A584, // Wallet 2 address - community wallet
        0x1B81829B7f682D1A22d7719870F6c49cCe501c79, // Wallet 3 address - Adam's wallet
        0x8ff33273020cC1a82fa0a24c1168fCd184C28a64, // Wallet 4 address - Artist
        0x88eC23121FaE1fbC00e7f4ae8Afe578aA2e9625b // Wallet 5 address - Josie wallet - social media manager
    ];
    mapping(address => uint16) teamWalletPercent;

    // Mint Counter for Each Wallet
    mapping(address => uint8) addressFreeMintCountMap; // Up to 10
    mapping(address => uint8) addressPreSaleCountMap; // Up to 10
    mapping(address => uint8) addressPublicSaleCountMap; // Up to 20

    // uint8 private LIMIT10 = 10;
    // uint8 private LIMIT20 = 20;

    uint8 private LIMIT_FREE_MINT_COUNT = 15;
    uint8 private LIMIT_PRE_SALE_COUNT = 10;
    uint8 private LIMIT_PUBLIC_SALE_COUNT = 5;

    // Minting Limitation
    uint16 public normalFreeMintLimit = 5000;
    uint16 public preSaleNormalLimit = 5000;
    uint16 public totalLimit = 25000;

    /**
     * Mint Step flag
     * 0:   freeMint,
     * 1:   preSale - normal,
     * 2:   publicSale,
     * 3:   reveal,
     * 4:   paused
     */
    uint8 public mintStep = 0;

    // Merkle Tree Root
    bytes32 private merkleRoot;

    // Mint Price
    uint256 public mintPricePreSale = 0.098 ether;
    uint256 public mintPricePublicSale = 0.14 ether;

    // BaseURI (real, placeholder)
    string private realBaseURI = "https://gateway.pinata.cloud/ipfs/QmVd9z3usF2FM9jA4N3BPNxAGPJCTrPtdf4qpHbgDWn7pX/";
    string private placeholderBaseURI = "https://gateway.pinata.cloud/ipfs/QmVd9z3usF2FM9jA4N3BPNxAGPJCTrPtdf4qpHbgDWn7pX/";

    constructor() ERC721("TheGoodDogClubLLC", "TGDC") {
        teamWalletPercent[teamWalletList[0]] = 682; // The Good Dog Club LLC percent
        teamWalletPercent[teamWalletList[1]] = 300; // community wallet percent
        teamWalletPercent[teamWalletList[2]] = 7; // Adam's wallet 3 percent
        teamWalletPercent[teamWalletList[3]] = 7; // Artist Wallet 4 percent
        teamWalletPercent[teamWalletList[4]] = 4; // Josie wallet - social media manager 5 percent
    }

    event Mint(
        address indexed _from,
        uint8 _mintStep,
        uint256 _tokenId,
        uint256 _mintPrice,
        uint8 _mintCount,
        uint8 _freeMintCount,
        uint8 _preSaleCount,
        uint8 _publicSaleCount
    );
    event Setting(
        uint8 _mintStep,
        uint256 _mintPricePreSale,
        uint256 _mintPricePublicSale,
        uint16 _totalLimit,
        uint8 _limit_free_mint_count,
        uint8 _limit_pre_sale_count,
        uint8 _limit_public_sale_count
    );

    /**
     * Override _baseURI
     * mintStep:    0~2 - Unreveal
     *              3 - Reveal
     */
    function _baseURI() internal view override returns (string memory) {
        if (mintStep == 3)
            // Reveal
            return realBaseURI;
        return placeholderBaseURI;
    }

    /**
     * Override tokenURI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return string(abi.encodePacked(_baseURI(), Strings.toString(tokenId), ".json"));
    }

    /**
     * GET BALANCE
     */
    function getBalance() external view onlyOwner returns (uint256) {
        return address(this).balance;
    }

    /**
     * Get totalSupply
     */
    function totalTokenSupply() external view returns(uint16) {
      return _tokenId;
    }

    /**
     * SET REAL BASE URI
     */
    function setRealBaseURI(string memory _realBaseURI) external onlyOwner returns (string memory) {
        realBaseURI = _realBaseURI;
        return realBaseURI;
    }

    /**
     * SET PLACEHOLDER BASE URI
     */
    function setPlaceholderBaseURI(string memory _placeholderBaseURI) external onlyOwner returns (string memory) {
        placeholderBaseURI = _placeholderBaseURI;
        return placeholderBaseURI;
    }

    /**
     * SET MERCLETREE ROOT
     */
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner returns (bytes32) {
        merkleRoot = _merkleRoot;
        return merkleRoot;
    }

    /**
     * Address -> leaf for MerkleTree
     */
    function _leaf(address account) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(account));
    }

    /**
     * Verify WhiteList using MerkleTree
     */
    function verifyWhitelist(bytes32 leaf, bytes32[] memory proof) private view returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash < proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }

        // Check if the computed hash (root) is equal to the provided root
        return computedHash == merkleRoot;
    }

    /**
     * Set status of mintStep
     * mintStep:    0 - freeMint,
     *              1 - preSale
     *              2 - publicSale,
     *              3 - reveal,
     *              4 - paused
     */
    function setMintStep(uint8 _mintStep) external onlyOwner returns (uint8) {
        require(_mintStep >= 0 && _mintStep <= 4);
        mintStep = _mintStep;
        emit Setting(
            mintStep,
            mintPricePreSale,
            mintPricePublicSale,
            totalLimit,
            LIMIT_FREE_MINT_COUNT,
            LIMIT_PRE_SALE_COUNT,
            LIMIT_PUBLIC_SALE_COUNT
        );
        return mintStep;
    }

    /**
     * Get Setting
     *  0 :     mintStep
     *  1 :     mintPricePreSale
     *  2 :     mintPricePublicSale
     *  3 :     totalLimit
     *  4 :     LIMIT_FREE_MINT_COUNT
     *  5 :     LIMIT_PRE_SALE_COUNT
     *  6 :     LIMIT_PUBLIC_SALE_COUNT
     */
    function getSetting() external view returns (uint256[] memory) {
        uint256[] memory setting = new uint256[](7);
        setting[0] = mintStep;
        setting[1] = mintPricePreSale;
        setting[2] = mintPricePublicSale;
        setting[3] = totalLimit;
        setting[4] = LIMIT_FREE_MINT_COUNT;
        setting[5] = LIMIT_PRE_SALE_COUNT;
        setting[6] = LIMIT_PUBLIC_SALE_COUNT;
        return setting;
    }

    /**
     * Withdraw
     */
    function withdraw() external onlyOwner {
        require(address(this).balance != 0);
        uint256 balance = address(this).balance;
        for (uint8 i = 0; i < teamWalletList.length; i++) {
            payable(teamWalletList[i]).transfer(balance.div(1000).mul(teamWalletPercent[teamWalletList[i]]));
        }
    }

    /**
     * Get Status by sender
     *  0 :     freeMintCount
     *  1 :     presaleCount
     *  2 :     publicSaleCount
     */
    function getAccountStatus(address account) external view returns (uint8[] memory) {
        require(msg.sender != address(0));
        require(account != address(0));

        address selectedAccount = msg.sender;
        if (owner() == msg.sender) selectedAccount = account;

        uint8[] memory status = new uint8[](3);

        if (balanceOf(selectedAccount) == 0) return status;

        status[0] = addressFreeMintCountMap[selectedAccount];
        status[1] = addressPreSaleCountMap[selectedAccount];
        status[2] = addressPublicSaleCountMap[selectedAccount];

        return status;
    }

    /**
     * Get TokenList by sender
     */
    function getTokenList(address account) external view returns (uint256[] memory) {
        require(msg.sender != address(0));
        require(account != address(0));

        address selectedAccount = msg.sender;
        if (owner() == msg.sender) selectedAccount = account;

        uint256 count = balanceOf(selectedAccount);
        uint256[] memory tokenIdList = new uint256[](count);

        if (count == 0) return tokenIdList;

        uint256 cnt = 0;
        for (uint256 i = 1; i < (_tokenId + 1); i++) {
            if (_exists(i) && (ownerOf(i) == selectedAccount)) {
                tokenIdList[cnt++] = i;
            }

            if (cnt == count) break;
        }

        return tokenIdList;
    }

    /**
     * Secret Free Mint
     * mintStep:    0
     * mintCount:   Up to LIMIT_FREE_MINT_COUNT
     */
    function mintFreeNormal(uint8 _mintCount, bytes32[] memory _proof) external nonReentrant returns (uint256) {
        require(mintStep == 0 && _mintCount > 0 && _mintCount <= LIMIT_FREE_MINT_COUNT, "mint count error !");
        require(msg.sender != address(0), "Address error !");
        require(addressFreeMintCountMap[msg.sender] + _mintCount <= LIMIT_FREE_MINT_COUNT, "address map error !");
        require(_mintCount <= normalFreeMintLimit, "Step total limit over !");
        require(verifyWhitelist(_leaf(msg.sender), _proof) == true, "Failed verification white list.");

        for (uint8 i = 0; i < _mintCount; i++) {
            _tokenId++;
            _safeMint(msg.sender, _tokenId);
        }

        addressFreeMintCountMap[msg.sender] += _mintCount;
        normalFreeMintLimit -= _mintCount;
        totalLimit -= _mintCount;

        emit Mint(msg.sender, 
                    mintStep, 
                    _tokenId,
                    0,  // _mintPrice
                    _mintCount,
                    addressFreeMintCountMap[msg.sender],
                    addressPreSaleCountMap[msg.sender],
                    addressPublicSaleCountMap[msg.sender]);

        return _tokenId;
    }

    /**
     * Presale with WhiteList
     * mintStep:    1
     * mintCount:   Up to LIMIT_PRE_SALE_COUNT
     */
    function mintPresale(uint8 _mintCount, bytes32[] memory _proof) external payable nonReentrant returns (uint256) {          
        require(_mintCount > 0 && _mintCount <= LIMIT_PRE_SALE_COUNT, "mint count error !");
        require(msg.sender != address(0), "Address error !");
        require(addressPreSaleCountMap[msg.sender] + _mintCount <= LIMIT_PRE_SALE_COUNT, "address map error !");
        require((mintStep == 1) && (_mintCount <= preSaleNormalLimit) && (msg.value == (mintPricePreSale * _mintCount)), "Price error !");
        require(verifyWhitelist(_leaf(msg.sender), _proof) == true, "Failed verification white list.");

        for (uint8 i = 0; i < _mintCount; i++) {
            _tokenId++;
            _safeMint(msg.sender, _tokenId);
        }
        
        addressPreSaleCountMap[msg.sender] += _mintCount;
        preSaleNormalLimit -= _mintCount;
        totalLimit -= _mintCount;

        emit Mint(msg.sender, 
                    mintStep, 
                    _tokenId,
                    mintPricePreSale,
                    _mintCount,
                    addressFreeMintCountMap[msg.sender],
                    addressPreSaleCountMap[msg.sender],
                    addressPublicSaleCountMap[msg.sender]);
        
        return _tokenId;
    }

    /**
     * Public Sale
     * mintStep:    2
     * mintCount:   Up to LIMIT_PUBLIC_SALE_COUNT
     */
    function mintPublic(uint8 _mintCount) external payable nonReentrant returns (uint256) {  
        require(mintStep >= 2 && mintStep <= 3 && _mintCount > 0 && _mintCount <= LIMIT_PUBLIC_SALE_COUNT, "mint count error !");
        require(msg.sender != address(0), "Address error !");
        require(addressPublicSaleCountMap[msg.sender] + _mintCount <= LIMIT_PUBLIC_SALE_COUNT, "address map error !");
        require(msg.value == (mintPricePublicSale * _mintCount), "Price error !");
        require(_mintCount <= totalLimit, "mint count error !");

        for (uint8 i = 0; i < _mintCount; i++) {
            _tokenId++;
            _safeMint(msg.sender, _tokenId);
        }
        
        addressPublicSaleCountMap[msg.sender] += _mintCount;
        totalLimit -= _mintCount;

        emit Mint(msg.sender, 
                    mintStep, 
                    _tokenId,
                    mintPricePublicSale,
                    _mintCount,
                    addressFreeMintCountMap[msg.sender],
                    addressPreSaleCountMap[msg.sender],
                    addressPublicSaleCountMap[msg.sender]);
        
        return _tokenId;
    }
}
