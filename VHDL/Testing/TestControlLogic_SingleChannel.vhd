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

entity TestControlLogic_SingleChannel is
--  Port ( );
end TestControlLogic_SingleChannel ;

architecture Behavioral of TestControlLogic_SingleChannel  is

signal Clock : std_logic := '1';
signal Resetn : std_logic := '0';

signal testPlaintext, testIV, testKey, testCiphertext, Susp, H, keyOut, din : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnICore, EnOCore, RdEnAXI, WrEnAXI, WrEnCore : std_logic;
signal WrDataAXI, RdDataAXI : std_logic_vector(DATA_WIDTH-1 downto 0);
signal WrAddrAXI, RdAddrAXI, WrAddrCore : std_logic_vector(ADDR_WIDTH-1 downto 0);
signal WrDataCore : std_logic_vector(KEY_SIZE-1 downto 0);


signal CL_ready, CL_valid : std_logic;
signal CL_rdData : std_logic_vector(DATA_WIDTH-1 downto 0);

signal mode : std_logic_vector(MODE_LEN-1 downto 0);
signal chaining_mode : std_logic_vector(CHMODE_LEN-1 downto 0);
signal GCMPhase : std_logic_vector(1 downto 0);



begin


testPlaintext <= x"00102030011121310212223203132333";
testKey <= x"000102030405060708090a0b0c0d0e0f";


i_ControlLogic : entity work.ControlLogic(Behavioral)
    generic map(NUM_CHANNELS => 1)
    port map(
        M_RV_ready => CL_ready,
        M_RV_valid => CL_valid,
        M_RV_rdData => testPlaintext,
        M_RV_error => '0',
        
        Clock => Clock,
        Resetn => Resetn,
        RdEn => RdEnAXI, RdAddr => RdAddrAXI, RdData => RdDataAXI,
        WrEn1 => WrEnAXI, WrAddr1 => WrAddrAXI, WrData1 => WrDataAXI, WrStrb1 => "1111",
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
    wait for 150ns;
    CL_ready <= '1';
    wait for 10ns;
end if;
end process;

process begin
-- write to ControlLogic
wait until Resetn = '1';
-- Configure Channel 0 as GCM
-- set key
WrEnAXI <= '1';
for i in 0 to 3 loop
    WrDataAXI <= testKey(127-(3-i)*32 downto 96 - (3-i)*32);
    WrAddrAXI <= std_logic_vector(to_unsigned(ADDR_KEYR0, ADDR_WIDTH)+i*4);
    wait for 10ns;
end loop;
-- set IV
for i in 0 to 3 loop
    WrDataAXI <= x"deadbeef";
    WrAddrAXI <= std_logic_vector(to_unsigned(ADDR_IVR0, ADDR_WIDTH) + i*4);
    wait for 10ns;
end loop;
-- overwrite last IV word with 0x002
WrDataAXI <= x"00000002";
wait for 10ns;

-- Start GCM Init Phase
WrDataAXI <= x"0000" & '0' & GCM_PHASE_INIT & "000" & "1" & "00" & CHAINING_MODE_GCM & MODE_ENCRYPTION & "00" & '1';
WrAddrAXI <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
wait for 10 ns;
WrEnAXI <= '0';
wait for 10ns;

-- wait until CCF is given
RdEnAXI <= '1';
RdAddrAXI <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH));
wait until RdDataAXI(8) = '1'; 



-- Prepare Header Phase:  Set datasize to 2
WrDataAXI <= x"20000000";
WrAddrAXI <= std_logic_vector(to_unsigned(ADDR_DATASIZE, ADDR_WIDTH));
WrEnAXI <= '1';
wait for 10ns;

-- Start Header phase
WrDataAXI <= x"0000" & '0' & GCM_PHASE_HEADER & "000" & "1" & "00" & CHAINING_MODE_GCM & MODE_ENCRYPTION & "00" & '1';
WrAddrAXI <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
wait for 10 ns;
WrEnAXI <= '0';
wait for 10ns;

-- wait until CCF is given
RdEnAXI <= '1';
RdAddrAXI <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH));
wait until RdDataAXI(8) = '1';

-- Start Payload phase
-- set datasize to 3 blocks
WrDataAXI <= x"30000000";
WrAddrAXI <= std_logic_vector(to_unsigned(ADDR_DATASIZE, ADDR_WIDTH));
WrEnAXI <= '1';
wait for 10ns;

WrDataAXI <= x"0000" & '0' & GCM_PHASE_PAYLOAD & "000" & "1" & "00" & CHAINING_MODE_GCM & MODE_ENCRYPTION & "00" & '1';
WrAddrAXI <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH));
wait for 10 ns;
WrEnAXI <= '0';
wait for 10ns;

-- wait until CCF is given
RdEnAXI <= '1';
RdAddrAXI <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH));
wait until RdDataAXI(8) = '1';


-- start Final phase
-- set datasize to 1 block
WrDataAXI <= x"30000000";
WrAddrAXI <= std_logic_vector(to_unsigned(ADDR_DATASIZE, ADDR_WIDTH));
WrEnAXI <= '1';
wait for 10ns;


wait;
end process;

end Behavioral;
