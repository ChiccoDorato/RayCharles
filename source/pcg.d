module pcg;

class PCG
{
    ulong state, inc;

    pure nothrow this(in ulong initState = 42, in ulong initSeq = 54)
    {
        inc = (initSeq << 1) | 1;
        this.random();
        state += initState;
        this.random();
    }

    pure nothrow uint random()
    {
        immutable ulong oldState = state;
        state = oldState * 6_364_136_223_846_793_005 + inc;

        immutable uint xorShifted = cast(uint)(((oldState >> 18) ^ oldState) >> 27);
        immutable uint rot = oldState >> 59;

        return (xorShifted >> rot) | (xorShifted << ((-rot) & 31));
    }

    pure nothrow float randomFloat()
    {
        return cast(float)(random) / uint.max;
    }
}

unittest
{
    PCG pcg = new PCG();
    assert(pcg.state == 1_753_877_967_969_059_832);
    assert(pcg.inc == 109);

    foreach(uint expected; [2_707_161_783, 2_068_313_097,
                    3_122_475_824, 2_211_639_955,
                    3_215_226_955, 3_421_331_566])
        assert(expected == pcg.random);
}