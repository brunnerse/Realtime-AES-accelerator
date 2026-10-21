----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:09:30
-- Design Name: 
-- Module Name: MixColumns - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.common.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;


entity MixColumns is
    Port ( dIn : in block_t;
           dOut : out block_t;
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end entity;

architecture RTL of MixColumns is

constant ZERO : std_logic_vector(3 downto 0) := x"0";

constant POLYGF : std_logic_vector(8 downto 0) := '1' & x"1b";

-- The AES state is Nb columns with four rows (32 bit) each 
type state_t is array(0 to AES_NB-1) of STD_LOGIC_VECTOR(31 downto 0);

function vector2state (vec : block_t) return state_t is 
    variable state : state_t;
begin
    for i in state_t'RANGE loop
        state(i) := vec(AES_BLOCK_SIZE-1 - i*32 downto AES_BLOCK_SIZE-32 - i*32); 
    end loop;
    return state;
end function;

function state2vector (state : state_t) return block_t is 
    variable vec : block_t;
begin
    for i in state_t'RANGE loop
        vec(AES_BLOCK_SIZE-1 - i*32 downto AES_BLOCK_SIZE-32 - i*32) := state(i); 
    end loop;
    return vec;
end function;




-- Multiplication functions in the Galois field
function mulGFby2(val : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable c : std_logic_vector(7 downto 0);
begin
    c := val(6 downto 0) & '0';
    if val >= x"80" then
        return c xor x"1b";
    else
        return c;
    end if;
end function;

function mulGFBy3(val : std_logic_vector(7 downto 0)) return std_logic_vector is
begin
    return mulGFby2(val) xor val;
end function;

function mulGF(val : std_logic_vector(7 downto 0); prod : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable c : std_logic_vector(10 downto 0); -- val has 8 bits, which can maximum be shifted 3 bits -> max. 11 bits
begin
    c := (others => '0');
    -- Polynomial Multiplication
    for i in 0 to 3 loop
        if prod(i) = '1' then
            c := c xor (ZERO(2-i downto 0) & val & ZERO(i-1 downto 0)); -- Shift the value by attaching the right amount of zeros
        end if;
    end loop;
    -- Polynomial Division
    for i in 10 downto 8 loop
        -- if bit c(i) is set, substract the shifted polynomial
        if c(i) = '1' then
            c := c xor (ZERO(9-i downto 0 ) & POLYGF & ZERO(i-9 downto 0));
        end if;
    end loop;
    return c(7 downto 0);
end function;

signal stateIn, stateOut : state_t; 

begin


stateIn <= vector2state(dIn);
dOut <= state2vector(stateOut);


process (Clock)

variable extendedCol : std_logic_vector(55 downto 0);
variable extColLine : integer;

begin
if rising_edge(Clock) then
    if Resetn = '0' then
        EnO <= '0';
        stateOut <= (others => (others => '-'));
    else
        EnO <= EnI;
        if EnI = '1' then
            if encrypt = '1' then
                for col in AES_NB-1 downto 0 loop
                    -- Extend the column by its first three elements for simpler indexing
                    extendedCol := stateIn(col)(31 downto 0) & stateIn(col)(31 downto 8);

                    for line in 3 downto 0 loop
                        extColLine := line + 3;
                        stateOut(col)(line*8+7 downto line*8) <= 
                            mulGFby2(extendedCol(extColLine*8+7 downto extColLine*8)) -- Multiply the byte in the current cell [line, col] by 2
                            xor mulGFby3(extendedCol(extColLine*8-1 downto extColLine*8-8)) -- Multiply next byte by 3
                            xor extendedCol(extColLine*8-9 downto extColLine*8-16)
                            xor extendedCol(extColLine*8-17 downto extColLine*8-24);
                    end loop;               
                end loop;
            else
                -- decrypt
                for col in AES_NB-1 downto 0 loop
                    -- Extend the column by its first three elements for simpler indexing
                    extendedCol := stateIn(col)(31 downto 0) & stateIn(col)(31 downto 8);

                    for line in 3 downto 0 loop
                        extColLine := line + 3;
                        stateOut(col)(line*8+7 downto line*8) <= 
                            mulGF(extendedCol(extColLine*8+7 downto extColLine*8), x"e")
                            xor mulGF(extendedCol(extColLine*8-1 downto extColLine*8-8), x"b")
                            xor mulGF(extendedCol(extColLine*8-9 downto extColLine*8-16), x"d")
                            xor mulGF(extendedCol(extColLine*8-17 downto extColLine*8-24), x"9");
                    end loop;          
                end loop;
                
            end if;
        end if;
    end if;
end if;
end process;


end architecture;
