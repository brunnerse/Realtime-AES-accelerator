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
use work.sbox_definition.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity SubBytes is
    Generic (
        USE_BLOCK_RAM : boolean := true
    );
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end SubBytes;



architecture Behavioral of SubBytes is

component sbox_bram is
generic (
    DATA    : integer := 8;
    ADDR    : integer := 8; 
    ENCRYPT : boolean := true
);
port (
    -- Port A
    clka   : in std_logic;
    ena    : in std_logic;
    addra  : in std_logic_vector(ADDR-1 downto 0);
    douta  : out std_logic_vector(DATA-1 downto 0)
);
end component;

type s_type is array (BLOCK_SIZE-1 downto 0) of std_logic_vector(7 downto 0);
signal s_enc : s_type;
signal s_dec : s_type;
	  
begin
GEN_BRAM:
if USE_BLOCK_RAM generate
GEN_SBOX : 
for i in 0 to BLOCK_SIZE-1 generate
    -- encryption sbox
    sbox_i : sbox_bram generic map (
        ENCRYPT => true
    ) port map (
        clka => Clock,
        ena => EnI,
        addra => dIn(i*8+7 downto i*8),
        douta => s_enc(i) 
    );
    -- decryption sbox
    sbox_d_i : sbox_bram generic map (
        ENCRYPT => false
    ) port map (
        clka => Clock,
        ena => EnI,
        addra => dIn(i*8+7 downto i*8),
        douta => s_dec(i)
    );
    
    dout(i*8+7 downto i*8) <= s_enc(i) when encrypt = '1' else s_dec(i);
    
end generate;
end generate;
GEN_LOGIC:
if not USE_BLOCK_RAM generate
process (Clock)
begin
if rising_edge(Clock) and EnI = '1' then
    for i in BLOCK_SIZE-1 downto 0 loop
        if encrypt = '1' then
            dout(i*8+7 downto i*8) <= sbox_encrypt(to_integer(unsigned(dIn(i*8+7 downto i*8))));
        else
            dout(i*8+7 downto i*8) <= sbox_decrypt(to_integer(unsigned(dIn(i*8+7 downto i*8))));
        end if;
    end loop;
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


end Behavioral;
