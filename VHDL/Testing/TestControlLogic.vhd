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

constant channel : unsigned(2 downto 0) := "011";
constant CHANNEL_0_OFFSET : unsigned(9 downto 0) := (others => '0');
constant CHANNEL_3_OFFSET : unsigned(9 downto 0) := channel & "0000000";
constant CHANNEL_1_OFFSET : unsigned(9 downto 0) := "001"   & "0000000";
constant CHANNEL_6_OFFSET : unsigned(9 downto 0) := "110"   & "0000000";

signal Clock : std_logic := '1';
signal Resetn : std_logic := '0';

signal testPlaintext, testIV, testKey, testCiphertext, Susp, H, keyOut, din : std_logic_vector(KEY_SIZE-1 downto 0);
signal EnICore, EnOCore, RdEnAHB, WrEnAHB, WrEnCore : std_logic;
signal WrDataAHB, RdDataAHB : std_logic_vector(DATA_WIDTH-1 downto 0);
signal WrAddrAHB, RdAddrAHB: std_logic_vector(ADDR_WIDTH-1 downto 0);
signal WrAddrCore : std_logic_vector(6 downto 0);
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
    generic map (
        NUM_CHANNELS => 17
    )
    port map(
        M_RV_ready => CL_ready,
        M_RV_valid => CL_valid,
        M_RV_rdData => testPlaintext,
        M_RV_error => '0',
        
        Clock => Clock,
        Resetn => Resetn,
        RdEn => RdEnAHB, RdAddr => RdAddrAHB, RdData => RdDataAHB,
        WrEn1 => WrEnAHB, WrAddr1 => WrAddrAHB, WrData1 => WrDataAHB, WrStrb1 => "1111",
        WrEn2 => WrEnCore, WrAddr2 => WrAddrCore, WrData2 => WrDataCore,
        key => keyOut, IV => testIV, H => H, Susp => Susp, DIN => din, DOUT => testCiphertext, 
        EnICore => EnICore, EnOCore => EnOCore, mode => mode, chaining_mode => chaining_mode, GCMPhase => GCMPhase
    );
   

core: entity work.AES_Core (Behavioral) 
generic map(ADDR_IV => ADDR_IVR0, ADDR_SUSP => ADDR_SUSPR0, ADDR_H => ADDR_HR0)
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
-- Configure Channel 0 as GCM Header mode
-- set key
WrEnAHB <= '1';
for i in 0 to 3 loop
    WrDataAHB <= testKey(127-(3-i)*32 downto 96 - (3-i)*32);
    WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_KEYR0, ADDR_WIDTH) + CHANNEL_0_OFFSET + i*4);
    wait for 10ns;
end loop;
-- set H
for i in 0 to 3 loop
    WrDataAHB <= x"12341234";
    WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_HR0, ADDR_WIDTH) + CHANNEL_0_OFFSET + i*4);
    wait for 10ns;
end loop;
WrEnAHB <= '0';
-- set data size
WrEnAHB <= '1';
WrDataAHB <= x"60000000"; 
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_DATASIZE, ADDR_WIDTH) + CHANNEL_0_OFFSET);
wait for 10ns;
-- set start addr
WrDataAHB <= x"00000010"; 
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_DINADDR, ADDR_WIDTH) + CHANNEL_0_OFFSET);
wait for 10ns;
-- set dest addr
WrDataAHB <= x"00000020"; 
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_DOUTADDR, ADDR_WIDTH) + CHANNEL_0_OFFSET);
wait for 10ns;
wait for 10ns;
-- set control
WrDataAHB <= x"0000" & '0' & GCM_PHASE_HEADER & "00" & "11" & "00" & CHAINING_MODE_GCM & MODE_ENCRYPTION & "00" & '1';
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_0_OFFSET);
wait for 10 ns;
WrEnAHB <= '0';
wait for 10ns;


-- configure second channel in CBC encryption mode
-- set data size
WrEnAHB <= '1';
WrDataAHB <= x"10000000"; 
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_DATASIZE, ADDR_WIDTH) + CHANNEL_1_OFFSET);
wait for 10ns;
-- set start addr
WrDataAHB <= x"00000110"; 
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_DINADDR, ADDR_WIDTH) + CHANNEL_1_OFFSET);
wait for 10ns;
-- set dest addr
WrDataAHB <= x"00000120"; 
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_DINADDR, ADDR_WIDTH) + CHANNEL_1_OFFSET);
wait for 10ns;
-- set IV
for i in 0 to 3 loop
    WrDataAHB <= x"deadbeef";
    WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_IVR0, ADDR_WIDTH) + CHANNEL_1_OFFSET + i*4);
    wait for 10ns;
end loop;
WrEnAHB <= '0';
wait for 350ns;
-- Priority 1
WrDataAHB <= x"0001" & '0' & GCM_PHASE_PAYLOAD & "00" & "11" & "00" & CHAINING_MODE_CBC & MODE_ENCRYPTION & "00" & '1';
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_1_OFFSET);
WrEnAHB <= '1';
wait for 10 ns;
WrEnAHB <= '0';

-- wait until CCF of first channel is set
RdEnAHB <= '1';
RdAddrAHB <= std_logic_vector(to_unsigned(ADDR_SR, ADDR_WIDTH) + CHANNEL_3_OFFSET);
wait until RdDataAHB(0) = '1'; 
-- clear CCF of first channel
wait for 50ns;
WrEnAHB <= '1';
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_3_OFFSET);
WrDataAHB <= x"000000" & '1' & CHAINING_MODE_ECB(0 to 1) & MODE_ENCRYPTION & "00" & '0';
WrDataAHB(7) <= '1';
wait for 10ns;
RdEnAHB <= '0';
WrEnAHB <= '0';
wait for 50ns;
-- start new encryption in channel 3
WrEnAHB <= '1';
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_3_OFFSET);
WrDataAHB <= x"000000" & '0' & CHAINING_MODE_CBC & MODE_ENCRYPTION & "00" & '1';
wait for 10ns;
WrEnAHB <= '0';
wait for 50ns;
-- start new encryption in channel 6
WrEnAHB <= '1';
WrAddrAHB <= std_logic_vector(to_unsigned(ADDR_CR, ADDR_WIDTH) + CHANNEL_6_OFFSET);
WrDataAHB <= x"000000" & '0' & CHAINING_MODE_CTR & MODE_ENCRYPTION & "00" & '1';
wait for 10ns;
WrEnAHB <= '0';
end process;


end Behavioral;
