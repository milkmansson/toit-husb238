// Copyright (C) 2025 Toit Contributors
// Use of this source code is governed by an MIT-style license that can be
// found in the package's LICENSE file.  See accompanying documentation.

import log
import serial.device as serial
import serial.registers as registers

/**
Driver for the HUSB238 USB Power Delivery sink controller.

Communicates over I2C to read PD status, query source capabilities, and request
  specific voltage/current PDOs from an attached USB-C power source.

The HUSB238 supports PD3.0 and Type-C V1.4 with fixed PDO
  voltages of 5V, 9V, 12V, 15V, 18V, and 20V.
*/
class Husb238:
  /** The default I2C slave address of the HUSB238. */
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

  static PDO-REGISTERS_ ::= [
      [5,  REG-SRC-PDO-5V_],
      [9,  REG-SRC-PDO-9V_],
      [12, REG-SRC-PDO-12V_],
      [15, REG-SRC-PDO-15V_],
      [18, REG-SRC-PDO-18V_],
      [20, REG-SRC-PDO-20V_],
    ]

  /** for use with REG-PD-STATUS0 */
  static PD-STATUS0-SRC-VOLTAGE-MASK_ ::= 0b11110000
  static PD-STATUS0-SRC-CURRENT-MASK_ ::= 0b00001111

  /** PD voltage when an explicit contract is established. ($PD-STATUS0-SRC-VOLTAGE-MASK_) */
  static PD-SRC-VOLTAGE-UNATTACHED_ ::= 0b0000 // Unattached.
  static PD-SRC-VOLTAGE-5V_         ::= 0b0001 // PD 5V.
  static PD-SRC-VOLTAGE-9V_         ::= 0b0010 // PD 9V.
  static PD-SRC-VOLTAGE-12V_        ::= 0b0011 // PD 12V.
  static PD-SRC-VOLTAGE-15V_        ::= 0b0100 // PD 15V.
  static PD-SRC-VOLTAGE-18V_        ::= 0b0101 // PD 18V.
  static PD-SRC-VOLTAGE-20V_        ::= 0b0110 // PD 20V.
  // Others = Reserved.


  /** Options in $REG-PD-STATUS0_ (in $PD-STATUS0-SRC-CURRENT-MASK_)
    Common to all SRC-PD0-** registers */
  static PD-CURRENT-0-50A_ ::= 0b0000 // 0.5A.
  static PD-CURRENT-0-70A_ ::= 0b0001 // 0.7A.
  static PD-CURRENT-1-00A_ ::= 0b0010 // 1A.
  static PD-CURRENT-1-25A_ ::= 0b0011 // 1.25A.
  static PD-CURRENT-1-50A_ ::= 0b0100 // 1.5A.
  static PD-CURRENT-1-75A_ ::= 0b0101 // 1.75A.
  static PD-CURRENT-2-00A_ ::= 0b0110 // 2A.
  static PD-CURRENT-2-25A_ ::= 0b0111 // 2.25A.
  static PD-CURRENT-2-50A_ ::= 0b1000 // 2.5A.
  static PD-CURRENT-2-75A_ ::= 0b1001 // 2.75A.
  static PD-CURRENT-3-00A_ ::= 0b1010 // 3A.
  static PD-CURRENT-3-25A_ ::= 0b1011 // 3.25A.
  static PD-CURRENT-3-50A_ ::= 0b1100 // 3.5A.
  static PD-CURRENT-4-00A_ ::= 0b1101 // 4A.
  static PD-CURRENT-4-50A_ ::= 0b1110 // 4.5A.
  static PD-CURRENT-5-00A_ ::= 0b1111 // 5A.

  /** for use with REG-PD-STATUS0 */
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

  static PD-STATUS1-5V-VOLTAGE-OTHERS_ ::= 0b0 // Voltage information of 5V contract
  static PD-STATUS1-5V-VOLTAGE-5V_     ::= 0b1 // Voltage information of 5V contract

  static PD-STATUS1-5V-CURRENT-DEFAULT_ ::= 0b00 // Current information of 5V contract
  static PD-STATUS1-5V-CURRENT-1-5A_    ::= 0b01 // Current information of 5V contract
  static PD-STATUS1-5V-CURRENT-2-4A_    ::= 0b10 // Current information of 5V contract
  static PD-STATUS1-5V-CURRENT-3-A_     ::= 0b11 // Current information of 5V contract

  static PDO-SRC-DETECT-MASK_  ::= 0b10000000
  static PDO-SRC-CURRENT-MASK_ ::= 0b00001111

  static PD-SELECT-VOLTAGE-MASK_       ::= 0b11110000
  static PD-SELECT-VOLTAGE-UNSELECTED_ ::= 0b0000 // Unselected
  static PD-SELECT-VOLTAGE-5V_         ::= 0b0001 // PD 5V
  static PD-SELECT-VOLTAGE-9V_         ::= 0b0010 // PD 9V
  static PD-SELECT-VOLTAGE-12V_        ::= 0b0011 // PD 12V
  static PD-SELECT-VOLTAGE-15V_        ::= 0b1000 // PD 15V
  static PD-SELECT-VOLTAGE-18V_        ::= 0b1001 // PD 18V
  static PD-SELECT-VOLTAGE-20V_        ::= 0b1010 // PD 20V


  /** $REG-GO-COMMAND_ Register */
  static REG-GO-COMMAND-MASK_ ::= 0b00011111

  static REG-GO-COMMAND-REQUEST-PDO_ ::= 0b00001   // Requests the PDO saved in PDO_SELECT register
  static REG-GO-COMMAND-GET-SRC-CAP_ ::= 0b00100   // Get_SRC_Cap command
  static REG-GO-COMMAND-HARD-RESET_  ::= 0b10000   // Hard reset command

  reg_/registers.Registers := ?
  logger_/log.Logger := ?
  capabilities_/Map := {:}
  previous-request_/int := 0

  /**
  Constructs a HUSB238 driver using the given I2C $dev.

  Reads the source capability registers on creation. Use
    $get-capabilities with --force-refresh to issue a fresh
    Get_SRC_Cap command if needed after construction.
  */
  constructor
      dev/serial.Device
      --logger/log.Logger=log.default:
    logger_ = logger.with-name "husb238"
    reg_ = dev.registers
    get-capabilities

  /**
  Returns the currently contracted PD voltage in volts.

  If no explicit PD contract is active, returns 5.0 if a legacy
    5V connection is detected, or 0.0 if unattached.

  If $code is set, returns the raw register code instead of the
    voltage in volts.

  Returns null if the register contains an unexpected value.
  */
  read-status-voltage --code=false -> float?:
    raw-voltage := read-register_ REG-PD-STATUS0_ --mask=PD-STATUS0-SRC-VOLTAGE-MASK_
    raw-current := read-register_ REG-PD-STATUS0_ --mask=PD-STATUS0-SRC-CURRENT-MASK_
    if (raw-voltage == 0) and (raw-current == 0):
      // No explicit PD contract
      return (is-legacy-5v ? 5.0 : 0.0)
    value := convert-code-to-voltage_ raw-voltage
    if value == null:
      logger_.error "read-status-voltage: unexpected value" --tags={"PD-STATUS0-SRC-VOLTAGE-MASK" : bits-16_ raw-voltage}
      return null
    if code: return raw-voltage.to-float
    return value

  /**
  Returns the currently contracted PD current in amps.

  If no explicit PD contract is active, returns the legacy 5V
    current if a legacy connection is detected, or 0.0 if
    unattached.

  If $code is set, returns the raw register code instead of the
    current in amps.

  Returns null if the register contains an unexpected value.
  */
  read-status-current --code=false -> float?:
    raw-voltage := read-register_ REG-PD-STATUS0_ --mask=PD-STATUS0-SRC-VOLTAGE-MASK_
    raw-current := read-register_ REG-PD-STATUS0_ --mask=PD-STATUS0-SRC-CURRENT-MASK_
    if (raw-voltage == 0) and (raw-current == 0):
      // Device is in unattached mode: return legacy information:
      return (is-legacy-5v ? legacy-5v-current : 0.0)
    value := convert-code-to-current_ raw-current
    if value == null:
      logger_.error "read-status-current: unexpected value" --tags={"PD-STATUS0-SRC-CURRENT-MASK" : bits-16_ raw-current}
      return null
    if code: return raw-current.to-float
    return value

  /**
  Returns whether the device has a legacy (non-PD) 5V connection.

  Returns false if an explicit PD contract is present. Otherwise
    checks the 5V_VOLTAGE field in PD_STATUS1.
  */
  is-legacy-5v -> bool:
    if is-pd-present: return false
    raw := read-register_ REG-PD-STATUS1_ --mask=PD-STATUS1-5V-VOLTAGE-MASK_
    return (raw == 1)

  /**
  Returns the current capability of a legacy 5V connection in amps.

  Reads the 5V_CURRENT field from PD_STATUS1. Returns 1.5, 2.4,
    or 3.0 for the respective Type-C current advertisements, or
    0.0 for the default USB current.
  */
  legacy-5v-current -> float:
    raw := read-register_ REG-PD-STATUS1_ --mask=PD-STATUS1-5V-CURRENT-MASK_
    if raw == 0b01: return 1.5
    else if raw == 0b10: return 2.4
    else if raw == 0b11: return 3.0
    else: return 0.0

  /**
  Returns which CC line is connected: 1 for CC1 or 2 for CC2.

  Indicates the physical orientation of the USB-C cable.

  Returns null and logs an error if no cable is attached.
  */
  read-cc-direction -> int?:
    if is-cable-attached:
      raw := read-register_ REG-PD-STATUS1_ --mask=PD-STATUS1-CC-DIR-MASK_
      return raw + 1  // 1=CC1, 2=CC2
    else:
      logger_.error "read-cc-direction: reading CC direction, but cable not attached."
      return null

  /**
  Returns Type-C physical attach state.

  It goes 1 whenever the HUSB238 sees an Rp on CC (i.e., a cable/source is
    present), even if there is no PD explicit contract. It’s only 0 in the true
    'unattached mode.'
  */
  is-cable-attached -> bool:
    raw := read-register_ REG-PD-STATUS1_ --mask=PD-STATUS1-ATTACH-MASK_
    return (raw == 1)

  /**
  Returns whether there is a current PD contract in operation.
  */
  is-pd-present -> bool:
    raw := read-register_ REG-PD-STATUS0_ --mask=PD-STATUS0-SRC-VOLTAGE-MASK_
    return raw != 0

  /**
  Requests a PD contract at the given $voltage.

  Writes the voltage selection to the SRC_PDO register and issues
    a Request PDO command. The $voltage must be an integer (5, 9,
    12, 15, 18, or 20) that is present in the current capabilities.

  Returns the PD_RESPONSE code from PD_STATUS1. Compare against
    $PD-STATUS1-RESPONSE-SUCCESS_ to check for success.

  # Errors
  It is an error if the $voltage is not in the capabilities map or if no cable
    is attached.
  */
  request-pdo voltage/int -> int:
    // check selection is in the capabilities list:
    assert: capabilities_.contains voltage
    assert: is-cable-attached
    pdo-code := convert-voltage-to-pdo-code_ voltage
    assert: pdo-code != null

    // Send the request value to the register:
    write-register_ REG-SRC-PDO_ pdo-code --mask=PD-SELECT-VOLTAGE-MASK_
    // Execute request command:
    write-register_ REG-GO-COMMAND_ REG-GO-COMMAND-REQUEST-PDO_ --mask=REG-GO-COMMAND-MASK_
    sleep --ms=100

    // Retrieve result
    result := read-register_ REG-PD-STATUS1_ --mask=PD-STATUS1-RESPONSE-MASK_
    if result == PD-STATUS1-RESPONSE-SUCCESS_:
      logger_.info "request-pdo: requested PDO Success." --tags={ "voltage" : voltage }
      previous-request_ = voltage
    else:
      logger_.error "request-pdo: PDO Not Successful." --tags={
        "voltage" : voltage,
        "code": result,
        "result": (get-string-result-code result)}
    return result


  /**
  Returns the source capabilities advertised by the attached PD source.

  The returned map has integer voltage keys (5, 9, 12, 15, 18, 20) mapped
    to the maximum current (as a float) the source offers at that voltage.
    Only detected PDOs are included.

  If $force-refresh is set, sends a Get_SRC_Cap command to the source
    to refresh the capability registers before reading them. If a previous
    PDO request was active and the refreshed contract no longer matches,
    the previous request is re-issued.
  */
  get-capabilities --force-refresh=false -> Map:
    if force-refresh:
      write-register_ REG-GO-COMMAND_ REG-GO-COMMAND-GET-SRC-CAP_ --mask=REG-GO-COMMAND-MASK_
      // After refresh the source may renegotiate, dropping the previous
      // contract.  Re-request if it was lost.
      if is-pd-present and (capabilities_.contains previous-request_):
        current-voltage := read-status-voltage
        if current-voltage != null and current-voltage.to-int != previous-request_:
          request-pdo previous-request_
      sleep --ms=250

    capabilities_.clear
    PDO-REGISTERS_.do: | entry |
      voltage := entry[0]
      register := entry[1]
      if (read-register_ register --mask=PDO-SRC-DETECT-MASK_) == 1:
        capabilities_[voltage] = convert-code-to-current_
            (read-register_ register --mask=PDO-SRC-CURRENT-MASK_)
    return capabilities_

  /**
  Sends a USB PD hard reset command.

  Discharges VIN and reboots the HUSB238. Blocks for 300ms to
    allow the chip to complete the reset sequence before returning.
  */
  hard-reset -> none:
    write-register_ REG-GO-COMMAND_ REG-GO-COMMAND-HARD-RESET_ --mask=REG-GO-COMMAND-MASK_
    // Back off while VIN is being discharged and the chip reboots.
    sleep --ms=300

  convert-code-to-current_ raw-value -> float?:
    if raw-value == PD-CURRENT-0-50A_: return 0.5
    else if raw-value == PD-CURRENT-0-70A_: return 0.7
    else if raw-value == PD-CURRENT-1-00A_: return 1.0
    else if raw-value == PD-CURRENT-1-25A_: return 1.25
    else if raw-value == PD-CURRENT-1-50A_: return 1.5
    else if raw-value == PD-CURRENT-1-75A_: return 1.75
    else if raw-value == PD-CURRENT-2-00A_: return 2.0
    else if raw-value == PD-CURRENT-2-25A_: return 2.25
    else if raw-value == PD-CURRENT-2-50A_: return 2.5
    else if raw-value == PD-CURRENT-2-75A_: return 2.75
    else if raw-value == PD-CURRENT-3-00A_: return 3.0
    else if raw-value == PD-CURRENT-3-25A_: return 3.25
    else if raw-value == PD-CURRENT-3-50A_: return 3.5
    else if raw-value == PD-CURRENT-4-00A_: return 4.0
    else if raw-value == PD-CURRENT-4-50A_: return 4.5
    else if raw-value == PD-CURRENT-5-00A_: return 5.0
    else:
      return null

  convert-code-to-voltage_ raw-value -> float?:
    if raw-value == PD-SRC-VOLTAGE-5V_: return 5.0
    else if raw-value == PD-SRC-VOLTAGE-9V_: return 9.0
    else if raw-value == PD-SRC-VOLTAGE-12V_: return 12.0
    else if raw-value == PD-SRC-VOLTAGE-15V_: return 15.0
    else if raw-value == PD-SRC-VOLTAGE-18V_: return 18.0
    else if raw-value == PD-SRC-VOLTAGE-20V_: return 20.0
    else if raw-value == PD-SRC-VOLTAGE-UNATTACHED_: return 0.0
    else:
      return null

  convert-voltage-to-code_ voltage/float -> int?:
    if voltage == 5.0: return PD-SRC-VOLTAGE-5V_
    else if voltage == 9.0: return PD-SRC-VOLTAGE-9V_
    else if voltage == 12.0: return PD-SRC-VOLTAGE-12V_
    else if voltage == 15.0: return PD-SRC-VOLTAGE-15V_
    else if voltage == 18.0: return PD-SRC-VOLTAGE-18V_
    else if voltage == 20.0: return PD-SRC-VOLTAGE-20V_
    else:
      return null

  /**
  Returns a default of $PD-SELECT-VOLTAGE-UNSELECTED_ as when empty this is the
    actual value.
  */
  convert-voltage-to-pdo-code_ voltage/int -> int:
    if voltage == 5: return PD-SELECT-VOLTAGE-5V_
    else if voltage == 9: return PD-SELECT-VOLTAGE-9V_
    else if voltage == 12: return PD-SELECT-VOLTAGE-12V_
    else if voltage == 15: return PD-SELECT-VOLTAGE-15V_
    else if voltage == 18: return PD-SELECT-VOLTAGE-18V_
    else if voltage == 20: return PD-SELECT-VOLTAGE-20V_
    else:
      return PD-SELECT-VOLTAGE-UNSELECTED_

  /**
  Returns a human-readable string for the given PD response $result code.

  Maps the PD_RESPONSE field values from PD_STATUS1 to descriptive
    strings for logging and diagnostics.
  */
  get-string-result-code result/int -> string:
    if result == PD-STATUS1-RESPONSE-NO-RESPONSE_: return "No Response"
    else if result == PD-STATUS1-RESPONSE-SUCCESS_: return "Success"
    else if result == PD-STATUS1-RESPONSE-INVALID_: return "Invalid command or argument"
    else if result == PD-STATUS1-RESPONSE-NOT-SUPPORTED_: return "Command not supported"
    else if result == PD-STATUS1-RESPONSE-TRANS-FAIL_: return "Transaction Fail (no good CRC)"
    return "Unknown result code (0x$(%02x result))"

  /**
  Reads the given register with the supplied mask.

  Given that register reads are largely similar, implemented here. If the mask
   is left at 0xFF and offset at 0x0, it is treated as a read from the whole
   register.
  */
  read-register_ register/int --mask/int=0xFF --offset/int=(mask.count-trailing-zeros) -> int:
    raw-value := reg_.read-u8 register
    return-value := ?
    if mask == 0xFF and offset == 0:
      return-value = raw-value
    else:
      masked-value := (raw-value & mask) >> offset
      return-value = masked-value
    sleep --ms=25
    return return-value

  /**
  Writes the given register with the supplied mask.

  Given that register writes are largely similar, it is implemented here.  If
   the mask is left at 0xFF and offset at 0x0, it is treated as a write to the
   whole register.
  */
  write-register_ register/int value/int --mask/int=0xFF --offset/int=(mask.count-trailing-zeros) -> none:
    // find allowed value range within field
    max/int := mask >> offset
    // check the value fits the field
    assert: ((value & ~max) == 0)

    if (mask == 0xFF) and (offset == 0):
      reg_.write-u8 register (value & 0xFF)
    else:
      new-value/int := reg_.read-u8 register
      new-value     &= ~mask
      new-value     |= (value << offset)
      reg_.write-u8 register new-value
    sleep --ms=25

  /**
  Provides strings to display bitmasks nicely when testing.
  */
  bits-16_ x/int --min-display-bits/int=0 -> string:
    if (x > 255) or (min-display-bits > 8):
      out-string := "$(%b x)"
      out-string = out-string.pad --left 16 '0'
      out-string = "$(out-string[0..4]).$(out-string[4..8]).$(out-string[8..12]).$(out-string[12..16])"
      return out-string
    else if (x > 15) or (min-display-bits > 4):
      out-string := "$(%b x)"
      out-string = out-string.pad --left 8 '0'
      out-string = "$(out-string[0..4]).$(out-string[4..8])"
      return out-string
    else:
      out-string := "$(%b x)"
      out-string = out-string.pad --left 4 '0'
      out-string = "$(out-string[0..4])"
      return out-string
