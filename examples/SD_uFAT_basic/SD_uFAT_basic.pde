/*
 * SD_uFAT Basic - Basic use of SD Cards
 *
 * Copyright (C) 2008 Libelium Comunicaciones Distribuidas S.L.
 * http://www.libelium.com
 *
 * This example allows manipulating one file stored in the SD card called "hola.txt"
 * I have chosen "hola", meaning "hello" in Spanish, just because I was a little 
 * tired of the classic "hello world". The file should be stored in the card and comes
 * in the ZIP file containing this example. You manipulate the file by simple commands
 * over the serial port. Here a list:
 *
 * - H: prints a help message with all commands implemented in the example
 * - L: lists the file's info, calls the ls("hola.txt") function
 * - D: deletes the file, calls del("hola.txt")
 * - P: prints a string to the file, in this case "hola caracola"
 * - W: allows you intialize the file entering text by hand through the serial terminal
 *      (beware, it erases the file)
 * - R: dumps the contents of "hola.txt" to the serial port
 * - A: append data interactively to the end of the file
 *
 * BUT HOW DOES IT WORK?
 * I use the SD uFAT approach, this example offers a series of functions  
 * to manipulate the content of SD cards. The only premise is that the
 * files in the card must be pre-existing. A good way is to add text
 * documents created with gedit (LIN), textedit (MAC) or notepad (WIN)
 *
 * The documents could be filled up with any characters of your choice
 * and should have a certain size. The uFAT approach to controlling SD
 * cards won't allow listing directories, or modifying the file size. I
 * fill up my files with blank spaces (0x20), it makes easier to look at
 * the files in a text editor later
 *
 * The end of files will be marked with the character End Of Text, we choose
 * it to be 0x03 as in ASCII. This will be the programatical trick to look
 * for the end of file. Just to make things easier for you, it is possible
 * to download some pre-made empty files in different sizes with the 0x03
 * character in first position from http://blushingboy.net, also there are some
 * coming in the ZIP where you got this example from
 *
 * The functions implemented for this library can be categorized in basic,
 * advanced, and experimental (unstable); they are:
 *
 * BASIC
 * - ls(filename): lists the size, amount of sectors, and real use of a file
 * - del(filename): erases a file by putting a NULL character at the beginning 
 *                  of all its sectors
 * - print(filename, string): appends a string at the end of a file [1]
 * - println(filename, string): appends a string + EOL at the end of a file
 * - cat(filename): prints out the contents of a file to the serial port
 * - append(filename): will listen to the serial port and append the data to the file
 *
 * ADVANCED
 * - usedBytes(filename): answers how many bytes are actually in use in the card
 * - startSector(filename): answers the sector on the SD card where a file starts
 * - verbose(mode): mode == ON (default) will print out help strings to the port
 *                  mode == OFF will get the functions to work in silent mode
 *
 * EXPERIMENTAL (unstable or not implemented)
 * - append(filename1, filename2): appends filename2 at the end of filename1
 * - indexOf(filename, string): looks for a string in a file answering the position
 * - indexOfLine(filename, int): gets the offset in the file to the line determined by the parameter
 *
 * HOW TO USE THIS PROGRAM
 * The way to interact with this example is through a serial monitor. Arduino's is good
 * but any others will also work. I recommend the following: GtkTerm (LIN), ZTerm (MAC),
 * and Brayterminal (WIN). All are free or freeware and can be obtained from different
 * sources
 *
 * MAKING YOUR OWN CODE OUT OF THIS ONE
 * To make this example I have been streching the variable space to the limit, you can
 * easily implement programs reading analog sensors or buttons and store that data
 * as in the SD card. You can probably read information from the serial port
 * or sensors hanging on I2C and push it into the card. If you ran into problems, just
 * remember the issue about the variable space. You cannot reduce the buffer[512] variable,
 * but you could work out with DATABUFFERSIZE (defaulting to 32) to get some extra room
 *
 * HACKING THE LIBRARY
 * The code compiles to a small sized library (7KB), however, it can be even smaller if you
 * you just erase the functions you don't need from the library, customizing it to fit
 * your needs. Also, even if the buffer[512] cannot be changed in size, you can use it for
 * other things during the time it is not used to access the SD card. In this way it could be
 * e.g. the temporary memory for a graphical display, swap for some of your processes, etc
 *
 * This code has been kindly commissioned by Libelium.com and has been executed
 * by D.J. Cuartielles -aka BlushingBoy-. The code was written in Sweden, Spain
 * Mexico, Korea, and Singapore. It is based on previous work by others
 * 
 *LICENSE
 * SD_uFAT Basic - Basic use of SD Cards
 *
 * Copyright (C) 2008 Libelium Comunicaciones Distribuidas S.L.
 * http://www.libelium.com
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *   
 * However, D.J. Cuartielles has to credit the following people, since 
 * the library with this example is a wrapper on code written by others, 
 * who deserve all the credit for their effort making this possible:
 *
 *  ** sd2iec - SD/MMC to Commodore serial bus interface/controller
 *     Copyright (C) 2007,2008  Ingo Korb <ingo@akana.de>
 *
 *  ** Inspiration and low-level SD/MMC access based on code from MMC2IEC
 *     by Lars Pontoppidan, Aske Olsson, Pascal Dufour, DTU, Denmark
 *
 * (c) 2009 David J. Cuartielles -aka BlushingBoy- for Libelium.com
 */

#include "SDuFAT.h"

// define the pin that powers up the SD card
#define MEM_PW 8

// help string to be sent to the serial port
#define HELP "H help\nL file info\nD delete\nP append string\nW init file and write\nR dump to serial\nA append text\n"

// variable used when reading from serial
byte inSerByte = 0;

void setup(void)
{
  // on my MicroSD Module the power comes from a digital pin
  // I activate it at all times
  pinMode(MEM_PW, OUTPUT);
  digitalWrite(MEM_PW, HIGH);
  
  // configure the serial port to command the card and read data
  Serial.begin(19200);
}

void loop(void)
{
  // Arduino expects one of a series of one-byte commands
  // you can get some help by sending an 'H' over the serial port
  if (Serial.available() > 0) {
    int result = 0;
    inSerByte = Serial.read();
    switch (inSerByte) {
    case 'H':
      Serial.println(HELP);
      result = 3; // special output for help message
      break;
    case 'L':
      result = SD.ls("hola.txt");
      break;
    case 'R':
      result = SD.cat("hola.txt");
      break;
    case 'W':
      result = SD.write("hola.txt");
      break;
    case 'A':
      result = SD.append("hola.txt");
      break;
    case 'P':
      result = SD.println("hola.txt","\nhola caracola");
      break;
    case 'D':
      result = SD.del("hola.txt");
      break;
    default:
      result = 2; // value for unknown operation
      break;
    }
    
    // print a status message for the last issued command
    // for help (result == 3) won't print anything
    if (result == 1) SD.printEvent(ERROR, "hola.txt");
    else if (result == 2) SD.printEvent(WARNING, "unknown command");
    else if (result == 0) SD.printEvent(SUCCESS, "hola.txt");
  }
}


