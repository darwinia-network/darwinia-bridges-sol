// This file is part of Darwinia.
// Copyright (C) 2018-2022 Darwinia Network
// SPDX-License-Identifier: GPL-3.0
//
// Darwinia is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Darwinia is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Darwinia. If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.17;

interface IMsgport {
    event DappError(
        address _fromDappAddress,
        address _toDappAddress,
        bytes _message,
        string _reason
    );

    function send(
        address _toDappAddress,
        bytes memory _messagePayload,
        uint256 _executionGas, // 0 means using defaultExecutionGas,
        uint256 _gasPrice
    ) external payable returns (uint256);

    function recv(
        address _fromDappAddress,
        address _toDappAddress,
        bytes memory _message
    ) external;

    function estimateFee(
        address _fromDappAddress,
        bytes memory _messagePayload,
        uint256 _executionGas, // 0 means using defaultExecutionGas
        uint256 _gasPrice
    ) external view returns (uint256);
}