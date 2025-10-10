// Copyright (C) 2025 Toit Contributors
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.  See accompanying documentation.

import log
import serial.device as serial
import serial.registers as registers

class Husb238:
  static I2C-ADDRESS ::= 0x08

  static REG-PD-STATUS0_  ::= 0x00
  static REG-PD-STATUS1_  ::= 0x01
  static REG-SRC-PDO-5V_  ::= 0x02
  static REG-SRC-PDO-9V_  ::= 0x03
  static REG-SRC-PDO-12V_ ::= 0x04
  static REG-SRC-PDO-15V_ ::= 0x05
  static REG-SRC-PDO-18V_ ::= 0x06
  static REG-SRC-PDO-20V_ ::= 0x07
  static REG-SRC-PDO_     ::= 0x08
  static REG-GO-COMMAND_  ::= 0x09

  /** for use with REG-PD-STATUS-0 */
  static PD-STATUS0-SRC-VOLTAGE-MASK_ ::= 0b11110000
  static PD-STATUS0-SRC-CURRENT-MASK_ ::= 0b00001111

  /** PD voltage when an explicit contract is established. ($PD-STATUS0-SRC-VOLTAGE-MASK_) */
  static PD-SRC-VOLTAGE-UNATTACHED_ ::= 0b0000 // Unattached
  static PD-SRC-VOLTAGE-5V_         ::= 0b0001 // PD 5V
  static PD-SRC-VOLTAGE-9V_         ::= 0b0010 // PD 9V
  static PD-SRC-VOLTAGE-12V_        ::= 0b0011 // PD 12V
  static PD-SRC-VOLTAGE-15V_        ::= 0b0100 // PD 15V
  static PD-SRC-VOLTAGE-18V_        ::= 0b0101 // PD 18V
  static PD-SRC-VOLTAGE-20V_        ::= 0b0110 // PD 20V
  // Others = Reserved

  /** Options in $REG-PD-STATUS0_ (in $PD-STATUS0-SRC-CURRENT-MASK_)
  Common to all SRC-PDC-** registers */
  static PD-CURRENT-0-50A_ ::= 0b0000 // 0.5A
  static PD-CURRENT-0-70A_ ::= 0b0001 // 0.7A
  static PD-CURRENT-1-00A_ ::= 0b0010 // 1A
  static PD-CURRENT-1-25A_ ::= 0b0011 // 1.25A
  static PD-CURRENT-1-50A_ ::= 0b0100 // 1.5A
  static PD-CURRENT-1-75A_ ::= 0b0101 // 1.75A
  static PD-CURRENT-2-A_   ::= 0b0110 // 2A
  static PD-CURRENT-2-25A_ ::= 0b0111 // 2.25A
  static PD-CURRENT-2-5A_  ::= 0b1000 // 2.5A
  static PD-CURRENT-2-75A_ ::= 0b1001 // 2.75A
  static PD-CURRENT-3-A_   ::= 0b1010 // 3A
  static PD-CURRENT-3-25A_ ::= 0b1011 // 3.25A
  static PD-CURRENT-3-5A_  ::= 0b1100 // 3.5A
  static PD-CURRENT-4-A_   ::= 0b1101 // 4A
  static PD-CURRENT-4-5A_  ::= 0b1110 // 4.5A
  static PD-CURRENT-5-A_   ::= 0b1111 // 5A

  /** for use with REG-PD-STATUS-0 */
  static PD-STATUS1-CC-DIR-MASK_     ::= 0b10000000
  static PD-STATUS1-ATTACH-MASK_     ::= 0b01000000
  static PD-STATUS1-RESPONSE-MASK_   ::= 0b00111000
  static PD-STATUS1-5V-VOLTAGE-MASK_ ::= 0b00000100  // Voltage information of 5V contract
  static PD-STATUS1-5V-CURRENT-MASK_ ::= 0b00000011  // Current information of 5V contract

  static PD-STATUS1-RESPONSE-NO-RESPONSE_   ::= 0b000 // No Response
  static PD-STATUS1-RESPONSE-SUCCESS_       ::= 0b001 // Success
  static PD-STATUS1-RESPONSE-INVALID_       ::= 0b011 // Invalid command or argument
  static PD-STATUS1-RESPONSE-NOT-SUPPORTED_ ::= 0b100 // Command not supported
  static PD-STATUS1-RESPONSE-TRANS-FAIL_    ::= 0b101 // Transaction Fail (no good CRC)
  // Others - reserved

  static PD-STATUS1-5V-VOLTAGE-OTHERS_    ::= 0b0 // Voltage information of 5V contract
  static PD-STATUS1-5V-VOLTAGE-5V_        ::= 0b1 // Voltage information of 5V contract

  static PD-STATUS1-5V-CURRENT-DEFAULT_   ::= 0b00 // Current information of 5V contract
  static PD-STATUS1-5V-CURRENT-1-5A_      ::= 0b01 // Current information of 5V contract
  static PD-STATUS1-5V-CURRENT-2-4A_      ::= 0b10 // Current information of 5V contract
  static PD-STATUS1-5V-CURRENT-3-A_       ::= 0b11 // Current information of 5V contract

  /** SRC-PDO-*V options */
  static PDO-DETECT-MASK_  ::= 0b10000000
  static PDO-CURRENT-MASK_ ::= 0b00001111

  /** $REG-SRC-PDO_ Register */
  static PDO-SELECT-MASK_ ::= 0b11110000

  /** $REG-GO-COMMAND_ Register */
  static REG-GO-COMMAND-MASK_ ::= 0b00011111

  static REG-GO-COMMAND-REQUEST_     ::= 0b00001 // Requests the PDO set by PDO_SELECT
  static REG-GO-COMMAND-GET-SRC_CAP_ ::= 0b00100 // Send out Get_SRC_Cap command
  static REG-GO-COMMAND-HARD-RESET_  ::= 0b10000 // Send out hard reset command

  reg_/registers.Registers := ?
  logger_/log.Logger := ?

  constructor
      dev/serial.Device
      --logger/log.Logger=log.default:
    logger_ = logger.with-name "husb238"
    reg_ = dev.registers




  /**
  Reads the given register with the supplied mask.

  Given that register reads are largely similar, implemented here. If the mask
   is left at 0xFFFF and offset at 0x0, it is treated as a read from the whole
   register.
  */
  read-register_ register/int --mask/int=0xFF --offset/int=(mask.count-trailing-zeros) -> any:
    raw-value := reg_.read-u8 register
    if mask == 0xFF and offset == 0:
      return raw-value
    else:
      masked-value := (raw-value & mask) >> offset
      return masked-value

  /**
  Writes the given register with the supplied mask.

  Given that register writes are largely similar, it is implemented here.  If
   the mask is left at 0xFFFF and offset at 0x0, it is treated as a write to the
   whole register.
  */
  write-register_ register/int value/any --mask/int=0xFF --offset/int=(mask.count-trailing-zeros) -> none:
    // find allowed value range within field
    max/int := mask >> offset
    // check the value fits the field
    assert: ((value & ~max) == 0)

    if (mask == 0xFFFF) and (offset == 0):
      reg_.write-u8 register (value & 0xFF)
    else:
      new-value/int := reg_.read-u8 register
      new-value     &= ~mask
      new-value     |= (value << offset)
      reg_.write-u8 register new-value

  /**
  Clamps the supplied value to specified limit.
  */
  clamp-value_ value/any --upper/any?=null --lower/any?=null -> any:
    if upper != null: if value > upper:  return upper
    if lower != null: if value < lower:  return lower
    return value
