module pcg;

// ******************** PCG ********************
/**
* Class for a PCG: a simple, fast, space-efficient statistically good algotiyhm
* for random number generation
*/
class PCG
{
    ulong state, inc;
    /**
    * Build a PCG from a seed and a sequence
    * Params: 
    *   initState = (ulong)
    *   initSeq  = (ulong)
    */
    pure nothrow @nogc @safe this(
        in ulong initState = 42, in ulong initSeq = 54
        )
    {
        inc = (initSeq << 1) | 1;
        this.random();
        state += initState;
        this.random();
    }

    /**
    * Build a PCG from another PCG
    * Params: 
    *   rhs = (PCG)
    */
    pure nothrow @nogc @safe this(ref return scope inout PCG rhs) inout
    {
        state = rhs.state;
        inc = rhs.inc;
    }

    /**
    * Returns: a pseudo-random number (uint)
    */
    pure nothrow @nogc @safe uint random()
    {
        immutable ulong oldState = state;
        state = oldState * 6_364_136_223_846_793_005 + inc;

        immutable xorShifted = cast(uint)(((oldState >> 18) ^ oldState) >> 27);
        immutable uint rot = oldState >> 59;

        return (xorShifted >> rot) | (xorShifted << ((-rot) & 31));
    }

    /**
    * Returns: a pseudo-random floating point number (float)
    */
    pure nothrow @nogc @safe float randomFloat()
    {
        return cast(float)(random) / uint.max;
    }
}

///
unittest
{
    auto pcg = new PCG();
    assert(pcg.state == 1_753_877_967_969_059_832);
    assert(pcg.inc == 109);

    foreach(uint expected; [
        2_707_161_783, 2_068_313_097,
        3_122_475_824, 2_211_639_955,
        3_215_226_955, 3_421_331_566
        ]) assert(pcg.random == expected);
}