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
use work.addresses.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TestCL is
--  Port ( );
end TestCL;

architecture Behavioral of TestCL is

type vector_array is array(natural range<>) of std_logic_vector(127 downto 0);

constant rCipher : std_logic_vector(127 downto 0) := x"37c2539128699009617d4d8935e66c12";

signal Clock : std_logic := '1';
signal Resetn : std_logic := '0';



signal testPlaintext, testIV, testKey, testCiphertext, Susp, H, keyOut, din : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnICore, EnOCore, IRdEn, IWrEn, WrEnCore : std_logic;
signal IWrData, IRdData : std_logic_vector(DATA_WIDTH-1 downto 0);
signal IWrAddr, IRdAddr, WrAddrCore :  std_logic_vector(ADDR_WIDTH-1 downto 0);
signal WrDataCore : std_logic_vector(KEY_SIZE-1 downto 0);

signal aes_introut : std_logic;


signal mode : std_logic_vector(MODE_LEN-1 downto 0);
signal chaining_mode : std_logic_vector(CHMODE_LEN-1 downto 0);
signal GCMPhase : std_logic_vector(1 downto 0);

begin

testPlaintext <=  x"00102030011121310212223203132333";
testKey <= x"000102030405060708090a0b0c0d0e0f";


i_ControlLogic : entity work.ControlLogic(Behavioral) 
port map(
        RdEn => IRdEn,
        RdAddr => IRdAddr,
        RdData => IRdData, 
        WrEn1 => IWrEn,
        WrAddr1 => IWrAddr,
        WrData1 => IWrData,
        WrStrb1 => "1111",
        WrEn2 => WrEnCore,
        WrAddr2 => WrAddrCore,
        WrData2 => WrDataCore, 
        key => keyOut,
        IV => testIV,
        H => H,
        Susp => Susp,
        DIN => din,
        DOUT => testCiphertext,
        EnOCore => EnOCore,
        EnICore => EnICore,
        mode => mode,
        chaining_mode => chaining_mode,
        GCMPhase => GCMPhase,
        interrupt => aes_introut,
        Clock => Clock,
        Resetn => Resetn
    );

core: entity work.AES_Core (Behavioral) 
generic map(ADDR_IV => ADDR_IVR0, ADDR_SUSP => ADDR_SUSPR0, ADDR_H => ADDR_HR0)
port map (testKey, testIV, H, Susp, WrEnCore, WrAddrCore, WrDataCore, din, testCiphertext, EnICore, EnOCore, mode, chaining_mode, GCMPhase, Clock, Resetn);



-- processes for Clock and reset signal
Clock <= not Clock after 5ns;
process begin
wait for 10 ns;
Resetn <= '1'; wait;
end process;



process
begin
-- write to ControlLogic
wait until Resetn = '1';
IWrEn <= '1';
-- set CR
IWrData <= x"00000" & "0010" & '0' & CHAINING_MODE_ECB & MODE_ENCRYPTION & "00" & '1';
IWrAddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
wait for 10 ns;
IWrEn <= '0';
wait for 10ns;
for i in 3 downto 0 loop
    IWrEn <= '1';
    IWrAddr <= std_logic_vector(to_unsigned(ADDR_DINR, ADDR_WIDTH));
    IWrData <= testPlaintext((i+1)*32-1 downto i*32);
    wait for 10ns;
end loop;
IWrEn <= '0';
IRdEn <= '1';
IRdAddr <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH));
wait until IRdData(0) = '1'; -- wait until CCF is set
-- clear CCF
IWrEn <= '1';
IWrAddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
IWrData <= x"000000" & '0' & CHAINING_MODE_ECB & MODE_ENCRYPTION & "00" & '1';
IWrData(7) <= '1';
wait for 10ns;
IWrEn <= '0';

-- Check correctness
for i in 3 downto 0 loop
    IRdAddr <= std_logic_vector(to_unsigned(ADDR_DOUTR, ADDR_WIDTH));
    IRdEn <= '1';
    wait for 10ns;
    IRdEn <= '0';
    wait until rising_edge(Clock);
    report "[Checking] ciphertext = " & to_hstring(to_bitvector(rCipher(i*32+31 downto i*32)));
    assert IRdData = rCipher(i*32+31 downto i*32)
        report "IRdData is wrong!"
        severity failure;
end loop;
IRdEn <= '0';

-- disable
IWrEn <= '1';
IWrAddr <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
IWrData <= x"000000" & '0' & CHAINING_MODE_ECB & MODE_ENCRYPTION & "00" & '0';
wait for 10ns;
IWrEn <= '0';
wait;
end process;


end Behavioral;
