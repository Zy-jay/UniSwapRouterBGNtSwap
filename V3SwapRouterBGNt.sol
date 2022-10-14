//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.5;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";

interface IBGNT {
    function depositBaseToken(uint256 _amount) external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdrawBaseToken(uint) external;
}

contract Swap {

    address private constant SWAP_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private constant SWAP_ROUTER_02 =
        0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    address public constant EURT = 0x8f53e80F7e5216201EECb39b8Aa6BcF0872a0e1b; //kovan
    // address private constant EURT = 0xc778417E063141139Fce010982780140Aa0cD5Ab; // rinkeby
    address public constant BGNT = 0x112a30C7824aEf3059AA83c59D31f112F75a2f05; //kovan
    //address public constant BGNT = 0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735; // rinkeby

    ISwapRouter public immutable swapRouter = ISwapRouter(SWAP_ROUTER);
    IV3SwapRouter public immutable swapRouter02 = IV3SwapRouter(SWAP_ROUTER_02);

    function safeTransferWithApprove(uint256 amountIn, address token, address routerAddress)
        internal
    {
        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(token, routerAddress, amountIn);
    }


function swapExactInputSingle02BGNtToToken(uint256 amountIn, address token)
        external
        returns (uint256 amountOut)
    {
        require(token != EURT, 'UniswapV2Router: INVALID_PATH');
        TransferHelper.safeTransferFrom(BGNT, msg.sender, address(this), amountIn * 195583 / 100000);
        IBGNT(BGNT).withdrawBaseToken(amountIn);
        TransferHelper.safeApprove(EURT, address(swapRouter02), amountIn);
        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: EURT,
                tokenOut: token,
                fee: 3000,
                recipient: msg.sender,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter02.exactInputSingle(params);
    }



function swapExactInputSingle02TokenToBGNT(uint256 amountIn, address token)
        external
        returns (uint256 amountOut)
    {
        require(token != EURT, 'UniswapV2Router: INVALID_PATH');
        safeTransferWithApprove(amountIn, token, address(swapRouter02));

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter
            .ExactInputSingleParams({
                tokenIn: token,
                tokenOut: EURT,
                fee: 3000,
                recipient: address(this),
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = swapRouter02.exactInputSingle(params);
        TransferHelper.safeApprove(EURT, BGNT, amountIn);
        IBGNT(BGNT).depositBaseToken(amountOut);
        assert(IBGNT(BGNT).transfer(msg.sender, amountOut * 195583 / 100000));

    }

 function swapExactOutputSingleBGNtToToken(uint256 amountOut, uint256 amountInMaximum, address token) external returns (uint256 amountIn) {

        TransferHelper.safeTransferFrom(BGNT, msg.sender, address(this), amountInMaximum * 195583 / 100000);
        IBGNT(BGNT).withdrawBaseToken(amountInMaximum);
        TransferHelper.safeApprove(EURT, address(swapRouter), amountInMaximum);
        ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: EURT,
                tokenOut: token,
                fee: 3000,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountIn = swapRouter.exactOutputSingle(params);

        // For exact output swaps, the amountInMaximum may not have all been spent.
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(EURT, address(swapRouter), 0);
            TransferHelper.safeApprove(EURT, BGNT, amountInMaximum - amountIn);
            IBGNT(BGNT).depositBaseToken(amountInMaximum - amountIn);
            TransferHelper.safeTransfer(BGNT, msg.sender, (amountInMaximum - amountIn) * 195583 / 100000);
        }
    }

    function swapExactOutputSingleTokenToBGNT(uint256 amountOut, uint256 amountInMaximum, address token) external returns (uint256 amountIn) {
        // Transfer the specified amount of DAI to this contract.
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amountInMaximum);

        // Approve the router to spend the specifed `amountInMaximum` of DAI.
        // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
        TransferHelper.safeApprove(token, address(swapRouter), amountInMaximum);

        ISwapRouter.ExactOutputSingleParams memory params =
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: token,
                tokenOut: EURT,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
        amountIn = swapRouter.exactOutputSingle(params);
        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(token, address(swapRouter), 0);
            TransferHelper.safeTransfer(token, msg.sender, amountInMaximum - amountIn);
        // For exact output swaps, the amountInMaximum may not have all been spent.
        // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.     
        }
     TransferHelper.safeApprove(EURT, address(swapRouter), 0);
     TransferHelper.safeApprove(EURT, BGNT, amountOut);
     IBGNT(BGNT).depositBaseToken(amountOut);
     assert(IBGNT(BGNT).transfer(msg.sender, amountOut * 195583 / 100000));
    }

}
