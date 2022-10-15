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

entity TestControlLogic is
--  Port ( );
end TestControlLogic;

architecture Behavioral of TestControlLogic is


signal Clock : std_logic := '1';
signal Resetn : std_logic := '0';

signal testPlaintext, testIV, testKey, testCiphertext, Susp, H, keyOut, din : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnICore, EnOCore, RdEnAHB, WrEnAHB, WrEnCore : std_logic;
signal WrDataAHB, RdDataAHB : std_logic_vector(DATA_WIDTH-1 downto 0);
signal WrAddrAHB, RdAddrAHB, WrAddrCore : std_logic_vector(ADDR_WIDTH-1 downto 0);
signal WrDataCore : std_logic_vector(KEY_SIZE-1 downto 0);


signal CL_ready, CL_valid : std_logic;

signal mode : std_logic_vector(MODE_LEN-1 downto 0) := MODE_KEYEXPANSION_AND_DECRYPTION;
signal chaining_mode : std_logic_vector(CHMODE_LEN-1 downto 0) := CHAINING_MODE_CBC;
signal GCMPhase : std_logic_vector(1 downto 0) := GCM_PHASE_INIT;

begin


testPlaintext <= x"00102030011121310212223203132333";
testKey <= x"000102030405060708090a0b0c0d0e0f";


i_ControlLogic : entity work.ControlLogic(Behavioral)
    port map(
        M_RW_ready => CL_ready,
        M_RW_valid => CL_valid,
        M_RW_rdData => (others => '0'),
        M_RW_error => '0',
        
        Clock => Clock,
        Resetn => Resetn,
        RdEn => RdEnAHB, RdAddr => RdAddrAHB, RdData => RdDataAHB,
        WrEn1 => WrEnAHB, WrAddr1 => WrAddrAHB, WrData1 => WrDataAHB, WrStrb1 => "1111",
        WrEn2 => WrEnCore, WrAddr2 => WrAddrCore, WrData2 => WrDataCore,
        key => keyOut, IV => testIV, H => H, Susp => Susp, DIN => din, DOUT => testCiphertext, 
        EnICore => EnICore, EnOCore => EnOCore, mode => mode, chaining_mode => chaining_mode, GCMPhase => GCMPhase
    );
   

core: entity work.AES_Core (Behavioral) 
generic map(ADDR_IV => ADDR_IVR0, ADDR_SUSP => ADDR_SUSPR0, ADDR_H => ADDR_SUSPR4)
port map (testKey, testIV, H, Susp, WrEnCore, WrAddrCore, WrDataCore, din, testCiphertext, EnICore, EnOCore, mode, chaining_mode, GCMPhase, Clock, Resetn);



-- processes for Clock and reset signal
Clock <= not Clock after 5ns;
process begin
wait for 20 ns;
Resetn <= '1'; wait;
end process;


-- process that sets ready signal after valid was asserted
process
begin
CL_ready <= '0';
wait for 10ns;
if CL_valid = '1' then
    wait for 50ns;
    CL_ready <= '1';
    wait for 10ns;
end if;
end process;

process begin
-- write to ControlLogic
wait until Resetn = '1';
-- set control
WrEnAHB <= '1';
WrDataAHB <= x"50000000"; 
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_DATASIZE, ADDR_WIDTH));
wait for 10ns;
-- set control
WrDataAHB <= x"000000" & '0' & CHAINING_MODE_ECB(0 to 1) & MODE_ENCRYPTION & "00" & '1'; -- TODO Chaining mode definition needs downto?
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
wait for 10 ns;
WrEnAHB <= '0';
wait for 10ns;

WrEnAHB <= '0';
RdEnAHB <= '1';
RdAddrAHB <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH));
wait until RdDataAHB(0) = '1'; -- wait until CCF is set
wait;
-- clear CCF
WrEnAHB <= '1';
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
WrDataAHB <= x"000000" & '0' & CHAINING_MODE_ECB(0 to 1) & MODE_ENCRYPTION & "00" & '1';
WrDataAHB(7) <= '1';
wait for 10ns;
RdEnAHB <= '0';
WrEnAHB <= '0'; -- TODO stop write process earlier?

wait for 50ns;

-- set the enable bit again
WrEnAHB <= '1';
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
WrDataAHB <= x"000000" & '0' & CHAINING_MODE_ECB(0 to 1) & MODE_ENCRYPTION & "00" & '1';
wait;
end process;


end Behavioral;
