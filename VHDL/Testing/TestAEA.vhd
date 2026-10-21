----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03.08.2022 21:58:39
-- Design Name: 
-- Module Name: TestAEA - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TestAEA is
--  Port ( );
end TestAEA;

architecture Behavioral of TestAEA is

component AEA is
    Port ( dIn : in block_t;
           dOut : out block_t;
           key : in key_t;
           encrypt : in STD_LOGIC;
           keyExpandFlag : in STD_LOGIC; 
           EnI : in STD_LOGIC;
           EnO : out STD_LOGIC;
           Clock : in STD_LOGIC;
           Resetn : in STD_LOGIC);
end component;

constant key1 : std_logic_vector(255 downto 0) := 
    x"000102030405060708090a0b0c0d0e0f_101112131415161718191a1b1c1d1e1f"; 
constant key2 : std_logic_vector(255 downto 0) := 
    (others => '0');

constant plaintext1 : block_t := x"00102030_01112131_02122232_03132333";
constant plaintext2 : block_t := x"00010203_10111213_20212223_30313233";
constant plaintext3 : block_t := (others => '0');


signal Clock, Resetn : std_logic := '0';

signal dIn, dOut: block_t;
signal testKey : key_t;
signal EnI, EnO : std_logic := '0';
signal encrypt : std_logic := '1';
signal keyExpandFlag : std_logic := '0';

begin

testKey <= key1(255 downto 256-testKey'length); 

aeaEnc : AEA port map (dIn => dIn, dOut => dOut, key => testKey, 
        encrypt => encrypt, 
        keyExpandFlag => keyExpandFlag, 
        EnI => EnI, EnO => EnO, 
        Clock => Clock, Resetn => Resetn);

Clock <= not Clock after 5 ns;

process begin
Resetn <= '0';
EnI <= '0'; 
wait for 30 ns;
Resetn <= '1';
--wait for 50  ns; -- Wait until Resetn is over
EnI <= '1'; 
encrypt <= '1';
dIn <= plaintext1; 
wait for 10  ns;
report "Started encryption with dIn = " & to_hstring(to_bitvector(dIn));
EnI <= '0'; 
wait until EnO = '1';
report "Encryption finished with dOut = " & to_hstring(to_bitvector(dOut));

wait for 20 ns;
EnI <= '1';
dIn <= dOut;
encrypt <= '0';
keyExpandFlag <= '0';
wait for 10 ns;
EnI <= '0';
report "Started decryption with dIn = " & to_hstring(to_bitvector(dIn));
wait until EnO = '1';
report "Decryption finished with dOut = " & to_hstring(to_bitvector(dOut));

report "Resetting round keys...";
Resetn <= '0'; -- Reset round keys
wait for 30 ns;
Resetn <= '1'; 
EnI <= '1';
--dIn <= dOut; -- dIn should keep its value
encrypt <= '0';
keyExpandFlag <= '0';
wait for 10 ns;
EnI <= '0';
report "Started decryption (keyexp=0) with dIn = " & to_hstring(to_bitvector(dIn));
wait until EnO = '1';
report "Decryption finished with dOut = " & to_hstring(to_bitvector(dOut));

report "Resetting round keys...";
Resetn <= '0'; -- Reset round keys
wait for 30 ns;
Resetn <= '1'; 
--dIn <= dOut;
EnI <= '1';
encrypt <= '0';
keyExpandFlag <= '1';
wait for 10 ns;
EnI <= '0';
report "Started decryption (keyexp=1) with dIn = " & to_hstring(to_bitvector(dIn));
wait until EnO = '1';
report "Decryption finished with dOut = " & to_hstring(to_bitvector(dOut));

--testPlaintext <= plaintext2; 
--wait for 10  ns;
wait;
end process;


end Behavioral;
