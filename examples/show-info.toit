// Copyright (C) 2025 Toit Contributors
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import gpio
import i2c
import husb238 show *

/**


In this example, we run queries to PD via the HUSB238.

Assumption: - We are NOT intending to power the ESP32 with the HUSB238 in this
  case, unless it is with a boost/buck converter that can keep consistent 5
  volts to the ESP32, even when it is higher or lower than 5.0v

Wiring:
  - Connect SCL/SDA I2C pins as normal
  - Connect GND from the HUSB238 to the common GND
  - Connect the HUSB238 to a PD USB source.

Double check your wiring.  Getting this wrong could burn out your ESP32, even
with just the 3v3 alone being wired.

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
