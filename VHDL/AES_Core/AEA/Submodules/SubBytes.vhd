----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.08.2022 01:09:30
-- Design Name: 
-- Module Name: SubBytes - Behavioral
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
use work.aes_sbox.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity SubBytes is
    Generic (
        USE_BLOCK_RAM : boolean := true
    );
    Port ( dIn : in block_t;
           dOut : out block_t;
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end entity;



architecture RTL of SubBytes is



begin
GEN_BRAM:
if USE_BLOCK_RAM generate
GEN_SBOX : 
for i in 0 to AES_BLOCK_SIZE/8-1 generate
    -- encryption sbox
    sbox_i : entity work.sbox_bram port map (
        clka => Clock,
        ena => EnI,
        addra => encrypt & dIn(i*8+7 downto i*8),
        douta => dOut(i*8+7 downto i*8)
    );   
end generate;
end generate;

GEN_LOGIC:
if not USE_BLOCK_RAM generate
process (Clock)
begin
if rising_edge(Clock) then
    if Resetn = '0' then
        dOut <= (others => '-');
    elsif EnI = '1' then
        if encrypt = '1' then
            dOut <= SubBytesInVec(dIn);  
        else
            dOut <= InvSubBytesInVec(dIn);
        end if;
    end if;
end if;
end process;
end generate;



process (Clock)
begin
if rising_edge(Clock) then
    if Resetn = '0' then
        EnO <= '0';
    else
        EnO <= EnI;
    end if;
end if;
end process;


end architecture;
