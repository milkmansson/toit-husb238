# Toit driver for the HUSB238 I2C-based PD Trigger


## Overview
The HUSB238 is a USB Power Delivery (PD) controller which can be used as a ___power sink___, with a rating of up to 100W.  Different boards (such as the [AdaFruit 5807](https://learn.adafruit.com/adafruit-husb238-usb-type-c-power-delivery-breakout/arduino) pictured) have different capacities, be sure to check out your boards limits alongside those stated by the IC.

From 'Theory of Operation' in the [HUSB238 datasheet](https://en.hynetek.com/uploadfiles/site/219/news/aabbbbdb-48c9-4a44-a6dc-2c15f53282e6.pdf):
> The HUSB238 is a highly integrated USB Power Delivery (PD) controller as sink
> role. It’s compatible with PD3.0 and Type-C V1.4. It can also support Apple
> Divider 3, BC1.2 SDP, DCP and CDP while source is attached. When HUSB238 is
> connected to power source, it applies Rd to both CC lines, trying to establish
> USB Type-C connection.  After the USB Type-C connection is established, it
> monitors the CC lines to get source capabilities pack from USB PD source. If
> there is valid source capabilities pack before time out, the HUSB238 policy
> engine requests a power supply with voltage no greater than the programmed
> request voltage. If there is no valid source capabilities pack after time out,
> the HUSB238 switches to Apple divider 3 or BC1.2 mode trying to determine
> corresponding charging protocol.

### PD Introduction
To understand the the drivers' functions, basic understanding of Power Delivery (PD) is required.  A recommended introduction, including acronyms and broader information, is this [introduction to USB Power Delivery with STM32](https://wiki.st.com/stm32mcu/wiki/Introduction_to_USB_Power_Delivery_with_STM32).  Main points:
- A core differentiator of the USB Type-C interface are the Control Channel (CC) lines.  These run at 300kbps, and allow the 2 connected partners to interact and negotiate many things, including:
   - Who is supplying the power, how much, etc (power role)
   - Who is the host/guest (the data role)
   - Authentication
   - Battery information, etc.
- For this device (HUSB238) the device will begin with the voltage and current configured using the jumpers/pads/dip switches (depending on device/model). After the MCU has started I2C and requested something else from the HUSB238, it will renegotiate and move to other voltages.  I2C configurations take priority over the physical jumpers/switches.
- When changing voltages etc, there is no consistent 5V from anywhere - the attached device must be able to react to what it is recieving.

### PD Sequence Intro
1. When attaching, the power source and consumer (sink) determine roles and orientation.  The source turns on 5V and advertises current options. (If an electronically marked cable is used, it's capabilities are read.)
2. PD Signaling starts. Source sends source 'Power Delivery Options'. The sink picks one, and sends a 'Request'.
3. The source sends back an 'Accept', changes the power, and then signals 'Ready'. At this point the situation is referred to as a 'contract'.
4. During operation, the sink can request voltage fine tuning, in steps as low as 20 mV/50 mA steps.  Either side can soft-reset, the source may resend capabilities, and faults can trigger Hard Reset which drops back to 5 V default.
5. A further specifications exist (eg PD3.1) allowing up to 240W, and 'role swap' features, for changing which partner is providing power.  Both of these are beyond the scope/capabilities of this IC.

## Typical Usage
To use this feature to power your 5V ESP32 project:
- After cabling, wait for 5 V present (Type-C attach via CC) to get the ESP32 up and able to listen/interact on I2C.
- Use the IC and this driver to list the source's advertised power capabilities, then send a request for the desired option (e.g., 20 V/5 A).
- After Accept + PS_RDY, the VBUS will be as at the new voltage.
- The current contract details can be queried from the IC.  Renegotiation is also possible.

### Example
...what an offer looks like...

### Voltage Options
The capabilities offered and supported by the Driver/IC are listed.  Not all current/voltage combinations may be offered by any given device, capabilities vary:
#### Current
  - 0.5A
  - 0.7A
  - 1A
  - 1.25A
  - 1.5A
  - 1.75A
  - 2A
  - 2.25A
  - 2.5A
  - 2.75A
  - 3A
  - 3.25A
  - 3.5A
  - 4A
  - 4.5A
  - 5A
#### Voltage
  - 5V
  - 9V
  - 12V
  - 15V
  - 18V
  - 20V


## Links
- [Introduction to USB Power Delivery with STM32](https://wiki.st.com/stm32mcu/wiki/Introduction_to_USB_Power_Delivery_with_STM32) - A good introduction, even if for a different product than this specific driver.
- TI Whitepaper on [USB PD Negotiations](https://www.ti.com/lit/an/slva842/slva842.pdf).
- [Hynetek HUSB238 Page](https://en.hynetek.com/2421.html) with links to the  [Datasheet](https://www.hynetek.com/uploadfiles/site/219/news/aabbbbdb-48c9-4a44-a6dc-2c15f53282e6.pdf) and [Register List](https://en.hynetek.com/uploadfiles/site/219/news/eb6cc420-847e-40ec-a352-a86fbeedd331.pdf).

## Issues
If there are any issues, changes, or any other kind of feedback, please
[raise an issue](toit-husb238/issues).  Feedback welcome and appreciated.

## Disclaimer
- This driver has been written and tested with an HUSB238 integrated into a Adafruit 5807 breakout board.
- All trademarks belong to their respective owners.
- No warranties for this work, express or implied.
