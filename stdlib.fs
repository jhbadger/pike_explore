\ -- Variable and Constant defined in Forth ------------------------
: variable create 1 allot does> ;
: constant create ! does> @ ;

\ - Boolean constants ----------------------------------------------
-1 constant true
0  constant false


\ -- Arithmetic helpers ----------------------------------------------
: 1+   1 + ;
: 1-   1 - ;
: 2+   2 + ;
: 2-   2 - ;
: 2*   2 * ;
: 2/   2 / ;
: negate   0 swap - ;
: abs   dup 0 < if negate then ;
: min   2dup < if drop else swap drop then ;
: max   2dup > if drop else swap drop then ;

\ -- Stack helpers ---------------------------------------------------
: 2dup   over over ;
: 2drop  drop drop ;
: 2swap  rot >r rot r> ;
: nip    swap drop ;
: tuck   swap over ;

\ -- Logic -----------------------------------------------------------
: and   * 0= 0= ;
: or    + 0= 0= ;
: not   0= ;
: <>    = not ;
: <=    > not ;
: >=    < not ;

\ -- Output helpers --------------------------------------------------
: space    32 emit ;
: spaces   0 do space loop ;
: .cr      . cr ;

\ -- Loop helpers ----------------------------------------------------
: between   ( n lo hi -- flag )  rot tuck > rot rot > not and ;

