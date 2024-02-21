# A time-predictable AES hardware accelerator for real-time systems  
=======


This repository contains the HDL design of an AES hardware accelerator built for real-time systems.
The accelerator features an internal scheduler managing the execution of simultaneous requests in priority order, thereby ensuring that contentions between requests are transparent to the requesting software tasks. 
By construction, the timing behavior of the accelerator is straightforward to predict in order to enable a timing analysis. 

----------------------------------------

## Repository organisation
#### Branches
- *master*: The official design  
- *baseArch*: Base design of the accelerator which features no support for simultaneous requests.  
 This design replicates the AES accelerator of the STM32G4 microcontroller series: 
 https://www.st.com/resource/en/reference_manual/rm0440-stm32g4-series-advanced-armbased-32bit-mcus-stmicroelectronics.pdf  
- *extendArch*: An variant of the design which stores channel data on the connected RAM instead of in hardware. 
This enables support for a far higher number of channels with minimal increasing hardware costs, 
however as data need to be transferred from and to the RAM the delays are much higher. 

#### Folders
- *VHDL*:  
	The entire VHDL design of the AES unit  
	- *VHDL/AES_Core*: VHDL modules implementing the AES algorithm 
	- *VHDL/ControlLogic*: VHDL modules for the central control logic
	- *VHDL/Interface*: VHDL modules implementing the AXI ports
	- *VHDL/Testing*: VHDL test scripts for single modules and for the entire design 
	- *common.vhd*: Common definitions for all VHDL files  
	- *AES_Unit.vhd*: The VHDL top module.
- *ip_repo*:
	Some interface definitions that can optionally be imported into the Vivado Design Suite for a clearer layout 
- *Drivers*:  
	The driver of the accelerator, written in C.  
	*AES_Unit.h* contains all function and struct definitions implemented by the driver. 
- *helper_scripts*:
	Scripts in c and python used as an aid to develop and verify the AES core.
- *Diagrams*:  
	Some design and testing result files.
- *Test*:  
	Contains a c program *aes_test.c* which tests the accelerator's functionalities.


## Configuring the design
The top VHDL module *AES_Unit.vhd* has several generic configuration options.

- *LITTLE_ENDIAN*:  True if the AXI bus uses little endian byte order for its data bus   
- *NUM_CHANNELS*:  The number of channels the accelerator is supposed to have  
- *C_S_AXI_xx*:   Configuration of the AXI slave port  
- *C_M_AXI_xx*:   Configuration of the AXI master port  

## Running the design
Using Xilinx Vivado:  

	- Create new project for the desired target board (e.g. Zynq Ultrascale ZCU 104)    
	- Import all VHDL files from the *VHDL* folder and its subfolders   
	- In a block diagram, insert the module AES_Unit.vhd   
	- Connect the module's AXI master and slave ports to corresponding ports of the processor  
	 (e.g. the Zynq-7000 IP)  
	- Synthesize the design and load the bitstream to the FPGA board  

Continue in Vitis:  

	- Create new project with the synthesized bitstream as the platform   
	- Import the driver files from the folder *Drivers*   
	- For testing the accelerator, you can use *Tests/aes_app/src/aes_test.c* as the main source file.  