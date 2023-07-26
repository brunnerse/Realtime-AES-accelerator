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

entity SubBytes is -- TODO add generic whether to implement the s-box with block ram or logic
    Port ( dIn : in STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           dOut : out STD_LOGIC_VECTOR (KEY_SIZE-1 downto 0);
           encrypt : in STD_LOGIC;
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end SubBytes;



architecture Behavioral of SubBytes is

component sbox_bram is -- TODO add En-Signal to sbox_bram so output doesnt change unless EnI is set
generic (
    DATA    : integer := 8; -- TODO make block ram shorter 
    ADDR    : integer := 8; 
    ENCRYPT : boolean := true
);
port (
    -- Port A
    clka   : in std_logic;
    wea    : in std_logic;
    ena    : in std_logic;
    addra  : in std_logic_vector(ADDR-1 downto 0);
    dina   : in std_logic_vector(DATA-1 downto 0);
    douta  : out std_logic_vector(DATA-1 downto 0)
);
end component;

type s_type is array (BLOCK_SIZE-1 downto 0) of std_logic_vector(7 downto 0);
signal s_enc : s_type;
signal s_dec : s_type;
	  
begin
GEN_SBOX : 
for i in 0 to BLOCK_SIZE-1 generate
    -- encryption sbox
    sbox_i : sbox_bram generic map (
        ENCRYPT => true
    ) port map (
        clka => Clock,
        wea => '0',
        ena => EnI,
        addra => dIn(i*8+7 downto i*8),
        dina => (others => '0'),
        douta => s_enc(i) 
    );
    -- decryption sbox
    sbox_d_i : sbox_bram generic map (
        ENCRYPT => false
    ) port map (
        clka => Clock,
        wea => '0',
        ena => EnI,
        addra => dIn(i*8+7 downto i*8),
        dina => (others => '0'),
        douta => s_dec(i) -- TODO make block ram shorter  so this doesnt have to be used
    );
    
    dout(i*8+7 downto i*8) <= s_enc(i)(7 downto 0) when encrypt = '1' else s_dec(i)(7 downto 0); 
    
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
