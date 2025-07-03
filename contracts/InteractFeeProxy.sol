// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// یک اینترفیس برای اینکه این قرارداد بداند چگونه با MainContract صحبت کند.
interface IMainContract {
    function interact(address _user) external returns (uint256);
}

/**
 * @title InteractFeeProxy
 * @dev این قرارداد به عنوان یک پروکسی عمل می‌کند. کاربران با این قرارداد تعامل می‌کنند،
 * کارمزد پرداخت می‌کنند و این قرارداد، فراخوانی را به MainContract هدایت می‌کند.
 */
contract InteractFeeProxy {
    IMainContract public immutable mainContract;
    uint256 public immutable INTERACT_FEE;
    address public owner; // مالک پروکسی برای برداشت کارمزدها

    event FeePaid(address indexed user, uint256 amount);
    event InteractionForwarded(address indexed user, bool success);
    event Withdraw(address indexed to, uint256 amount);

    /**
     * @dev سازنده قرارداد که آدرس قرارداد اصلی را دریافت می‌کند.
     * @param _mainContractAddress آدرس قرارداد MainContract.
     */
    constructor(address _mainContractAddress) {
        require(_mainContractAddress != address(0), "Invalid MainContract address");
        mainContract = IMainContract(_mainContractAddress);
        INTERACT_FEE = 0.001 ether; // کارمزد تعامل (0.001 از توکن بومی شبکه مثل ETH یا MONAD)
        owner = msg.sender; // کسی که این پروکسی را دیپلوی می‌کند، مالک آن می‌شود
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    /**
     * @dev تابع اصلی که کاربران برای تعامل فراخوانی می‌کنند.
     * این تابع payable است تا بتواند کارمزد را در قالب توکن بومی شبکه دریافت کند.
     */
    function interactWithFee() public payable {
        require(msg.value >= INTERACT_FEE, "Insufficient fee sent");

        // اگر کاربر مبلغ بیشتری فرستاده بود، مبلغ اضافه را به او برگردان
        if (msg.value > INTERACT_FEE) {
            payable(msg.sender).transfer(msg.value - INTERACT_FEE);
        }

        emit FeePaid(msg.sender, INTERACT_FEE);

        // فراخوانی تابع interact در MainContract با آدرس کاربر اصلی (msg.sender)
        (bool success, bytes memory returnData) = address(mainContract).call(
            abi.encodeWithSignature("interact(address)", msg.sender)
        );

        // اگر فراخوانی با خطا مواجه شد، دلیل خطا را از MainContract به کاربر نمایش بده
        if (!success) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(32, returnData), mload(returnData))
                }
            } else {
                revert("Failed to call interact(address) on MainContract");
            }
        }
        emit InteractionForwarded(msg.sender, success);
    }

    /**
     * @dev به مالک پروکسی اجازه می‌دهد کارمزدهای جمع‌آوری شده را برداشت کند.
     */
    function withdrawEther() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
        emit Withdraw(owner, balance);
    }
}
