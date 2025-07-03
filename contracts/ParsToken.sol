// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ParsToken
 * @dev یک قرارداد استاندارد توکن ERC20 با نام "Pars Token" و نماد "PARS".
 * مینت کردن توکن‌ها فقط برای مالک قرارداد امکان‌پذیر است.
 */
contract ParsToken is ERC20, Ownable {
    /**
     * @dev سازنده قرارداد که نام، نماد و مالک اولیه را تنظیم می‌کند.
     * @param initialOwner آدرس کیف پولی که در ابتدا مالک قرارداد خواهد بود.
     */
    constructor(address initialOwner)
        ERC20("Pars Token", "PARS")
        Ownable(initialOwner)
    {}

    /**
     * @dev مقدار مشخصی توکن جدید برای یک آدرس ایجاد می‌کند.
     * فقط توسط مالک قرارداد قابل فراخوانی است.
     * @param to آدرسی که توکن‌ها را دریافت می‌کند.
     * @param amount مقداری از توکن که باید مینت شود.
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
