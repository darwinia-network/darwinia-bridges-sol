// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "./Fp2.sol";

struct G2Point {
    Fp2 x;
    Fp2 y;
}

library G2 {
    using FP2 for Fp2;

    uint8 private constant G2_ADD = 0x0D;
    uint8 private constant G2_MUL = 0x0E;
    uint8 private constant MAP_FP2_TO_G2 = 0x12;

    function eq(G2Point memory p, G2Point memory q)
        internal
        pure
        returns (bool)
    {
        return (p.x.eq(q.x) && p.y.eq(q.y));
    }

    function is_zero(G2Point memory p) internal pure returns (bool) {
        return p.x.is_zero() && p.y.is_zero();
    }

    function is_infinity(G1Point memory p) internal pure returns (bool) {
        return is_zero(p);
    }

    function add(G2Point memory p, G2Point memory q) internal view returns (G2Point memory) {
        uint[16] memory input;
        input[0]  = p.x.c0.a;
        input[1]  = p.x.c0.b;
        input[2]  = p.x.c1.a;
        input[3]  = p.x.c1.b;
        input[4]  = p.y.c0.a;
        input[5]  = p.y.c0.b;
        input[6]  = p.y.c1.a;
        input[7]  = p.y.c1.b;
        input[8]  = q.x.c0.a;
        input[9]  = q.x.c0.b;
        input[10] = q.x.c1.a;
        input[11] = q.x.c1.b;
        input[12] = q.y.c0.a;
        input[13] = q.y.c0.b;
        input[14] = q.y.c1.a;
        input[15] = q.y.c1.b;
        uint[8] memory output;

        assembly {
            if iszero(staticcall(800, G2_ADD, input, 512, output, 256)) {
                 returndatacopy(0, 0, returndatasize())
                 revert(0, returndatasize())
            }
        }

        return from(output);
    }

    function mul(G2Point memory p, uint scalar) internal view returns (G2Point memory) {
        uint[9] memory input;
        input[0] = p.x.c0.a;
        input[1] = p.x.c0.b;
        input[2] = p.x.c1.a;
        input[3] = p.x.c1.b;
        input[4] = p.y.c0.a;
        input[5] = p.y.c0.b;
        input[6] = p.y.c1.a;
        input[7] = p.y.c1.b;
        input[8] = scalar;
        uint[8] memory output;

        assembly {
            if iszero(staticcall(45000, G2_MUL, input, 288, output, 256)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        return from(output);
    }

    function map_to_curve(Fp2 memory f) internal view returns (G2Point memory) {
        uint[4] memory input;
        input[0] = f.c0.a;
        input[1] = f.c0.b;
        input[2] = f.c1.a;
        input[3] = f.c1.b;
        uint[8] memory output;

        assembly {
            if iszero(staticcall(75000, MAP_FP2_TO_G2, input, 128, output, 256)) {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
        }

        return from(output);
    }

    function from(uint[8] memory x) internal view returns (G2Point memory) {
        return G2Point(
            Fp2(
                Fp(x[0], x[1]),
                Fp(x[2], x[3])
            ),
            Fp2(
                Fp(x[4], x[5]),
                Fp(x[6], x[7])
            )
        );
    }

    // Take a 192 byte array and convert to G2 point (x, y)
    function deserialize(bytes memory g2) internal pure returns (G2Point memory) {
        require(g1.length == 192, "!g2");
        uint8 byt = g1[0];
        require(byt & COMPRESION_FLAG != 0, "compressed");
        require(byt & INFINITY_FLAG != 0, "infinity");
        require(byt & Y_FLAG != 0, "!y_flag");

        g1[0] = byt & 31;

        // Convert from array to FP2
        Fp memory x_imaginary = Fp(FP.slice_to_uint(g1, 0, 16), FP.slice_to_uint(g1, 16, 48));
        Fp memory x_real = Fp(FP.slice_to_uint(g1, 48, 64), FP.slice_to_uint(g1, 64, 96));
        Fp memory y_imaginary = Fp(FP.slice_to_uint(g1, 0, 16), FP.slice_to_uint(g1, 16, 48));
        Fp memory y_real = Fp(FP.slice_to_uint(g1, 48, 64), FP.slice_to_uint(g1, 64, 96));

        // Require elements less than field modulus
        require(x_imaginary.is_valid() &&
                x_real.is_valid() &&
                y_imaginary.is_valid() &&
                y_real.is_valid()
                , "!pnt");

        Fp2 memory x = Fp2(x_real, x_imaginary);
        let memory y = Fp2(y_real, y_imaginary);

        G2Point memory p = G2Point(x, y);
        require(!p.is_infinity(), "infinity");
        return p;

    }
}
