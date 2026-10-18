----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:09:30
-- Design Name: 
-- Module Name: ShiftRows - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

use work.common.ALL;



entity ShiftRows is
    Generic (
        synchronous : boolean := false
        );
    Port ( dIn : in block_t;
           dOut : out block_t;
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end ShiftRows;

architecture Behavioral of ShiftRows is

type rows_t is array(0 to 3) of std_logic_vector(AES_NB*8-1 downto 0);

function vector2rows (vec : block_t) return rows_t is 
    variable rows : rows_t;
    variable row, col : integer;
begin
    for i in 0 to AES_BLOCK_SIZE/8-1 loop 
        row := i rem 4; 
        col := i / 4; 
        rows(row)(31-col*8 downto 24-col*8) := vec(127-i*8 downto 120-i*8);
    end loop;
    return rows;
end function;

function rows2vec (rows : rows_t) return block_t is 
    variable vec : block_t;
    variable row, col : integer;
begin
    for i in 0 to AES_BLOCK_SIZE/8-1 loop 
        row := i rem 4; 
        col := i / 4; 
        vec(127-i*8 downto 120-i*8) := rows(row)(31-col*8 downto 24-col*8); 
    end loop;
    return vec;
end function;

function shift_rows(vec : block_t; do_encrypt : boolean) return block_t is
    variable rows : rows_t;
begin
    rows := vector2rows(vec);

    if do_encrypt then
        for i in rows_t'RANGE loop
            rows(i) := std_logic_vector(unsigned(rows(i)) rol i*8);
        end loop;
    else
        for i in rows_t'RANGE loop
            rows(i) := std_logic_vector(unsigned(rows(i)) ror i*8);
        end loop;
    end if;

    return rows2vec(rows);
end function;


begin


GenAsync: if not synchronous generate
    EnO <= EnI;
    dOut <= shift_rows(dIn, encrypt = '1');
end generate;


GenSync:  if synchronous generate
    
process (Clock)
begin

if rising_edge(Clock) then
    if Resetn = '0' then
        EnO <= '0';
        dOut <= (others => '-');
    else
        EnO <= EnI;
        dOut <= shift_rows(dIn, encrypt = '1');
    end if;

end if;
end process;

end generate;

end Behavioral;
