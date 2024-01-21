// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVRF {
    function requestRandomWords(
        uint256 round
    ) external returns (uint256 requestId);

    function getRequestStatus(
        uint256 _requestId
    ) external view returns (bool fulfilled, uint256[] memory randomWords);
}
