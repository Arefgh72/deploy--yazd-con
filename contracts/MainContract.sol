// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YazdParadiseNFT.sol";
import "./ParsToken.sol";

/**
 * @title MainContract
 * @dev قرارداد اصلی که منطق تعامل کاربر، مینت NFT و توکن را مدیریت می‌کند.
 * مالکیت این قرارداد در نهایت به InteractFeeProxy منتقل می‌شود.
 */
contract MainContract is Ownable {
    YazdParadiseNFT public yazdParadiseNFT;
    ParsToken public parsToken;

    event Interacted(address indexed user, uint256 nftBalanceBefore, uint256 newNftId, uint256 parsTokenMinted);

    /**
     * @dev سازنده قرارداد که آدرس قراردادهای NFT و توکن و مالک اولیه را تنظیم می‌کند.
     * @param _yazdParadiseNFTAddress آدرس قرارداد دیپلوی شده‌ی YazdParadiseNFT.
     * @param _parsTokenAddress آدرس قرارداد دیپلوی شده‌ی ParsToken.
     * @param initialOwner آدرس مالک اولیه این قرارداد (که بعداً به پروکسی منتقل می‌شود).
     */
    constructor(address _yazdParadiseNFTAddress, address _parsTokenAddress, address initialOwner)
        Ownable(initialOwner)
    {
        yazdParadiseNFT = YazdParadiseNFT(_yazdParadiseNFTAddress);
        parsToken = ParsToken(_parsTokenAddress);
    }

    /**
     * @dev تابع اصلی تعامل. فقط توسط مالک (که پروکسی خواهد بود) قابل فراخوانی است.
     * @param _originalCaller آدرس کاربری که تراکنش را از طریق پروکسی آغاز کرده.
     */
    function interact(address _originalCaller) external onlyOwner returns (uint256) {
        uint256 currentNftBalance = yazdParadiseNFT.balanceOf(_originalCaller);

        // همیشه یک NFT جدید برای کاربر مینت می‌شود.
        uint256 newNftId = yazdParadiseNFT.mint(_originalCaller);

        uint256 parsToMint = 0;
        if (currentNftBalance > 0) {
            uint256 x = currentNftBalance;
            // منطق "شانسی" برای تست‌نت (برای محیط واقعی امن نیست)
            uint256 y = (uint256(keccak256(abi.encodePacked(block.timestamp, _originalCaller, block.number, x, newNftId))) % 10) + 1;
            uint256 g_full_tokens = (100 * y) * x;
            parsToMint = g_full_tokens * (1 ether);

            if (parsToMint > 0) {
                 parsToken.mint(_originalCaller, parsToMint);
            }
        }

        emit Interacted(_originalCaller, currentNftBalance, newNftId, parsToMint);
        return newNftId;
    }

    // ========== توابع مدیریتی (اختیاری ولی کاربردی) ==========

    /**
     * @dev به مالک اجازه می‌دهد آدرس قرارداد NFT را در آینده تغییر دهد.
     */
    function setYazdParadiseNFTAddress(address _newAddress) external onlyOwner {
        yazdParadiseNFT = YazdParadiseNFT(_newAddress);
    }

    /**
     * @dev به مالک اجازه می‌دهد آدرس قرارداد توکن را در آینده تغییر دهد.
     */
    function setParsTokenAddress(address _newAddress) external onlyOwner {
        parsToken = ParsToken(_newAddress);
    }

    /**
     * @dev به مالک اجازه می‌دهد اترهای جمع‌شده در این قرارداد را برداشت کند.
     */
    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
