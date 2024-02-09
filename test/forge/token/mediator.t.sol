// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;
import {LocalTestSetup, GlacisAxelarAdapter, GlacisRouter, AxelarGatewayMock, AxelarGasServiceMock, LayerZeroGMPMock} from "../LocalTestSetup.sol";
import {GlacisClientSample} from "../../contracts/samples/GlacisClientSample.sol";
import {GlacisTokenClientSampleSource} from "../../contracts/samples/GlacisTokenClientSampleSource.sol";
import {GlacisTokenClientSampleDestination} from "../../contracts/samples/GlacisTokenClientSampleDestination.sol";
import {GlacisRouter__ClientDeniedRoute} from "../../../contracts/routers/GlacisRouter.sol";
import {GlacisTokenMediator__OnlyTokenMediatorAllowed} from "../../../contracts/mediators/GlacisTokenMediator.sol";
import {GlacisCommons} from "../../../contracts/commons/GlacisCommons.sol";

import {GlacisTokenMediator, GlacisTokenClientSampleSource, GlacisTokenClientSampleDestination, XERC20Sample, ERC20Sample, XERC20LockboxSample, XERC20NativeLockboxSample} from "../LocalTestSetup.sol";

contract TokenMediatorTests is LocalTestSetup {
    AxelarGatewayMock internal axelarGatewayMock;
    AxelarGasServiceMock internal axelarGasServiceMock;
    GlacisAxelarAdapter internal axelarAdapter;
    GlacisRouter internal glacisRouter;
    GlacisClientSample internal clientSample;
    GlacisTokenMediator internal glacisTokenMediator;
    XERC20Sample internal xERC20Sample;

    function setUp() public {
        glacisRouter = deployGlacisRouter();
        (glacisTokenMediator, xERC20Sample,,,,,) = deployGlacisTokenFixture(glacisRouter);
        (axelarGatewayMock, axelarGasServiceMock) = deployAxelarFixture();
        axelarAdapter = deployAxelarAdapters(
            glacisRouter,
            axelarGatewayMock,
            axelarGasServiceMock
        );
        LayerZeroGMPMock lzEndpoint = deployLayerZeroFixture();
        deployLayerZeroAdapters(glacisRouter, lzEndpoint);
    }

    function addRemoteMediator(uint256 chainId, address addr) internal {
        uint256[] memory chainIdArr = new uint256[](1);
        chainIdArr[0] = chainId;
        address[] memory addrArr = new address[](1);
        addrArr[0] = addr;

        glacisTokenMediator.addRemoteMediators(chainIdArr, addrArr);
    }

    function test__TokenMediator_AddsRemoteAddress(address addr, uint256 chainId) external {
        vm.assume(chainId != 0);
        addRemoteMediator(chainId, addr);
        assertEq(glacisTokenMediator.remoteMediators(chainId), addr);
    }

    function test__TokenMediator_RemovesRemoteAddress(address addr, uint256 chainId) external {
        vm.assume(chainId != 0);
        addRemoteMediator(chainId, addr);
        glacisTokenMediator.removeRemoteMediator(chainId);
        assertEq(glacisTokenMediator.remoteMediators(chainId), address(0));
    }

    function test__TokenMediator_NonOwnersCannotAddRemote() external {
        vm.startPrank(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        addRemoteMediator(block.chainid, address(0x123));
    }

    function test__TokenMediator_NonOwnersCannotRemoveRemote() external {
        vm.startPrank(address(0x123));
        vm.expectRevert("Ownable: caller is not the owner");
        glacisTokenMediator.removeRemoteMediator(block.chainid);
    }

    function test__TokenMediator_RejectsExecuteFromNonMediatorSources(address addr, address otherAddr, uint256 chainId) external {
        vm.assume(addr != otherAddr);
        vm.assume(chainId != 0);

        addRemoteMediator(chainId, addr);

        // Message is being received by the router
        vm.startPrank(address(glacisRouter));

        uint8[] memory gmpArray = new uint8[](1);
        gmpArray[0] = 1;

        vm.expectRevert(GlacisTokenMediator__OnlyTokenMediatorAllowed.selector);
        glacisTokenMediator.receiveMessage(
            gmpArray,
            chainId,
            address(otherAddr), // fromAddress; this is what we're testing for
            bytes("")
        );
    }

    function test__TokenMediator_AcceptsExecuteFromMediatorSource(address addr, uint256 chainId) external {
        vm.assume(chainId != 0);

        addRemoteMediator(chainId, addr);

        // Message is being received by the router
        vm.startPrank(address(glacisRouter));

        uint8[] memory gmpArray = new uint8[](1);
        gmpArray[0] = 1;

        glacisTokenMediator.receiveMessage(
            gmpArray,
            chainId,
            addr,
            abi.encode(address(0x123), address(0x123), address(xERC20Sample), address(xERC20Sample), 1, bytes(""))
        );
        assertEq(xERC20Sample.balanceOf(address(0x123)), 1);
    }
}

