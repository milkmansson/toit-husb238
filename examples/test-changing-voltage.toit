// Copyright (C) 2025 Toit Contributors
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import gpio
import i2c
import ina226 show *
import husb238 show *

/**
Toit Example for the HUSB238 PD Sink/Trigger Module

In this example, we run queries to PD via the HUSB238.  However, we have an
INA226 wired together, which will validate the PD voltage change carried out
by the HUSB238.

Assumption:
  - We are NOT intending to power the ESP32 with the HUSB238 in this case.
  - If you know what you are doing with a boost/buck converter, you can use your
    voltmeter alongside this test and prove that it works appropriately.

Wiring:
  - Connect SCL/SDA I2C pins as normal
  - Put 3v3 and GND onto the INA226 as normal.
  - Connect GND from the HUSB238 to the common GND (ESP32 and INA226)
  - On the INA226, leave IN+ and IN- floating.
  - On the INA226, connect vBUS to V+ on the HUSB238

Double check your wiring.  Getting this wrong could burn out your ESP32, even
with just the 3v3 alone being wired in the wrong way.

Given there is no load, there are no shunt values etc to be retrieved from the
INA226.

*/

main:
  frequency := 400_000
  sda := gpio.Pin 19
  scl := gpio.Pin 20
  bus := i2c.Bus --sda=sda --scl=scl --frequency=frequency
  scandevices := bus.scan

  husb238-device := ?
  husb238-driver := ?
  if not scandevices.contains Husb238.I2C_ADDRESS:
    print "No HUSB238 found"
    return

  husb238-device = bus.device Husb238.I2C_ADDRESS
  husb238-driver = Husb238 husb238-device

  print
  print "HUSB238 Test:"
  result := 0
  bus-voltage := 0.0
  if husb238-driver.read-cc-direction != null:
    print "- Cable Orientation:  CC$husb238-driver.read-cc-direction"
  else:
    print "- Cable Orientation:  <Not USBC>"

  print "- Legacy 5v:          $(husb238-driver.is-legacy-5v)"
  print "- Voltage Status:     $(husb238-driver.read-status-voltage)"
  print "- Current Status:     $(husb238-driver.read-status-current)"
  print "- Is Cable Attached:  $(husb238-driver.is-cable-attached)"
  print "- Is PD Present:      $(husb238-driver.is-pd-present)"
  capabilities := husb238-driver.get-capabilities
  print "- PD Options:         $(capabilities)"
  print "- PD Voltage:         $(husb238-driver.read-status-voltage)"
  print "- PD Current:         $(husb238-driver.read-status-current)"
  print

  ina226-device := null
  ina226-driver := null
  if not scandevices.contains Ina226.I2C_ADDRESS:
    print "No INA226 found"
  else:
    ina226-device = bus.device Ina226.I2C_ADDRESS
    ina226-driver = Ina226 ina226-device
    ina226-driver.set-measure-mode Ina226.MODE-CONTINUOUS
    ina226-driver.trigger-measurement --wait

  if ina226-driver != null:
    bus-voltage = ina226-driver.read-bus-voltage
    print "- INA226 Measurement Check: $(%0.3f bus-voltage)v"
    print

  // For each reported capability, switch to it, and measure with the INA226.
  capabilities.keys.do:
    print "Selecting $(it)v @$(capabilities[it])a"
    result = husb238-driver.request-pdo it

    // Manually check the results:
    if result == Husb238.PD-STATUS1-RESPONSE-NO-RESPONSE_: print " No Response"
    if result == Husb238.PD-STATUS1-RESPONSE-SUCCESS: print " Success"
    if result == Husb238.PD-STATUS1-RESPONSE-INVALID_: print " Invalid command or argument"
    if result == Husb238.PD-STATUS1-RESPONSE-NOT-SUPPORTED_: print " Command not supported"
    if result == Husb238.PD-STATUS1-RESPONSE-TRANS-FAIL_: print " Transaction Fail (no good CRC)"

    // Check with INA226 (if present)
    bus-voltage = 0.0
    if ina226-driver != null:
      5.repeat:
        bus-voltage = ina226-driver.read-bus-voltage
        print "- INA226 Measurement Check $(it + 1): $(%0.3f bus-voltage)v"
        sleep --ms=500
      print


  print "Resetting to 5v..."
  result = husb238-driver.request-pdo 5

  // Manually check the results:
  if result == Husb238.PD-STATUS1-RESPONSE-NO-RESPONSE_: print " No Response"
  if result == Husb238.PD-STATUS1-RESPONSE-SUCCESS: print " Success"
  if result == Husb238.PD-STATUS1-RESPONSE-INVALID_: print " Invalid command or argument"
  if result == Husb238.PD-STATUS1-RESPONSE-NOT-SUPPORTED_: print " Command not supported"
  if result == Husb238.PD-STATUS1-RESPONSE-TRANS-FAIL_: print " Transaction Fail (no good CRC)"

  bus-voltage = 0.0
  if ina226-driver != null:
    5.repeat:
      bus-voltage = ina226-driver.read-bus-voltage
      print "- INA226 Measurement Check $(it + 1): $(%0.3f bus-voltage)v"
      sleep --ms=500
    print
