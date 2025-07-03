// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title YazdParadiseNFT
 * @dev یک قرارداد ساده برای توکن ERC721 که فقط توسط مالک قابل مینت است.
 */
contract YazdParadiseNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    /**
     * @dev سازنده قرارداد که نام، نماد و مالک اولیه را تنظیم می‌کند.
     * @param initialOwner آدرس کیف پولی که در ابتدا مالک قرارداد خواهد بود.
     */
    constructor(address initialOwner)
        ERC721("Yazd Paradise NFT", "YPNFT")
        Ownable(initialOwner)
    {}

    /**
     * @dev یک NFT جدید برای یک آدرس مشخص مینت (ایجاد) می‌کند.
     * فقط توسط مالک قرارداد قابل فراخوانی است.
     * @param to آدرسی که NFT جدید را دریافت می‌کند.
     * @return آی‌دی توکن جدید ایجاد شده.
     */
    function mint(address to) public onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        return tokenId;
    }
}
