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
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Reset : in STD_LOGIC);
end MixColumns;

architecture Behavioral of MixColumns is

component VectorToTable Port
    ( vector : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           table  : out TABLE
    );
end component;
component TableToVector is
    Port (           
        table  : in TABLE;
        vector : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0)
    );
end component;


function multiplyBy2(val : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable c : std_logic_vector(7 downto 0);
begin
    c := val(6 downto 0) & '0';
    if val >= x"80" then
        return c xor x"1b";
    else
        return c;
    end if;
end function;

signal tableIn, tableOut : TABLE;

begin

dinToTable:   VectorToTable port map(dIn, tableIn);
tableToDout : TableToVector port map(tableOut, dOut);


process (Clock, Reset)

variable times2, times3, a3 : std_logic_vector(7 downto 0);
variable temp1, temp2, temp3, temp4 : std_logic_vector(7 downto 0);
variable extendedCol : std_logic_vector(55 downto 0);
variable extColLine : integer;

begin
if Reset = '0' then
    EnO <= '0';
elsif rising_edge(Clock) then
    EnO <= EnI;
    if EnI = '1' then
        if encrypt = '1' then
            for col in KEY_SIZE/32-1 downto 0 loop
                -- Extend the column by its first three elements for simpler indexing
                extendedCol := tableIn(col)(31 downto 0) & tableIn(col)(31 downto 8);

                for line in 3 downto 0 loop
                    extColLine := line + 3;
                    -- Multiply the byte in the current cell [line, col] by 2
                    times2 := multiplyBy2(extendedCol(extColLine*8+7 downto extColLine*8));
                    -- Multiply the byte in the next cell by 2
                    a3 := extendedCol(extColLine*8-1 downto extColLine*8-8);
                    times3 := multiplyBy2(a3) xor a3;
                    -- xor all the results
                    tableOut(col)(line*8+7 downto line*8) <= times2 xor times3
                        xor extendedCol(extColLine*8-9 downto extColLine*8-16)
                        xor extendedCol(extColLine*8-17 downto extColLine*8-24);
                end loop;               
            end loop;
        else
            -- decrypt
            for col in KEY_SIZE/32-1 downto 0 loop
                -- Extend the column by its first three elements for simpler indexing
                extendedCol := tableIn(col)(31 downto 0) & tableIn(col)(31 downto 8);

                for line in 3 downto 0 loop
                    extColLine := line + 3;
                    -- Multiply the byte in the current cell [line, col] by 2
                    times2 := multiplyBy2(extendedCol(extColLine*8+7 downto extColLine*8));
                    -- Multiply the byte in the next cell by 2
                    a3 := extendedCol(extColLine*8-1 downto extColLine*8-8);
                    times3 := multiplyBy2(a3) xor a3;
                    -- xor all the results
                    tableOut(col)(line*8+7 downto line*8) <= times2 xor times3
                        xor extendedCol(extColLine*8-9 downto extColLine*8-16)
                        xor extendedCol(extColLine*8-17 downto extColLine*8-24);
                end loop;               
            end loop;
            
        end if;
    end if;
end if;
end process;


end Behavioral;
