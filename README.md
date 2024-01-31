# A time-predictable AES hardware accelerator for real-time systems  
=======


This repository contains the HDL design of an AES hardware accelerator built for real-time systems.
The accelerator features an internal scheduler managing the execution of simultaneous requests in priority order, thereby ensuring that contentions between requests are transparent to the requesting software tasks. 
By construction, the timing behavior of the accelerator is straightforward to predict in order to enable a timing analysis. 

----------------------------------------

## Repository organisation
#### Branches
- *basedesign*: Base design of the accelerator which features no support for simultaneous request.
 This design replicates the AES accelerator of the STM32G4 microcontroller series: https://www.st.com/resource/en/reference_manual/rm0440-stm32g4-series-advanced-armbased-32bit-mcus-stmicroelectronics.pdf  
- *master*: The official design  
- *extenddesign*: An variant of the design which stores channel data on the connected RAM instead of in hardware. 
This enables support for a far higher number of channels with minimal increasing hardware costs, 
however as data need to be transferred from and to the RAM the delays are much higher. 

#### Folders
- *VHDL*:  
	The entire VHDL design of the AES unit  
	- *VHDL/Testing*:
		VHDL test scripts for single modules and for the entire design 
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
- Endianness:  

## Running the design
In Vivado:
	- Neues Projekt erstellen
	- Sämtliche VHDL-Dateien aus dem Ordner VHDL und seinen Unterordnern importieren
	- Blockdiagramm erstellen
	- Das Modul AES_Unit.vhd zum Blockdiagramm hinzufügen
	- Den Zynq-7000 IP zum Blockdiagramm hinzufügen
	- Die Blöcke über die automatische Funktion miteinander verbinden
	- Design synthethisieren und Bitstream generieren
	- Design mit Bitstream exportieren
In Vitis:
	- Neues Projekt erstellen
	- Die Treiberdateien aus dem Ordner Drivers importieren
	- Die Testdateien aus dem Ordner Vitis importieren
	- Testdatei ausführen
