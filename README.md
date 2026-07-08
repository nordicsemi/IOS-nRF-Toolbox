# IOS-nRF-Toolbox

[![Download on the App Store](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg)](https://apps.apple.com/us/app/nrf-toolbox/id820906058)

**nRF Toolbox** is a holistic application designed to demonstrate Nordic Semiconductor's Bluetooth Low Energy (Bluetooth LE) capabilities.

It serves a dual purpose: providing a user-friendly interface for connecting to Nordic-based peripherals and acting as a reference implementation for developers utilizing Nordic’s libraries.

## Supported Bluetooth LE Profiles

The application includes distinct modules for the following standard and proprietary profiles:

* **Cycling Speed and Cadence**
* **Running Speed and Cadence**
* **Heart Rate Monitor**
* **Blood Pressure Monitor**
* **Health Thermometer Monitor**
* **Glucose Monitor**
* **Continuous Glucose Monitor**
* **Nordic UART**
* **Throughput**
* **Monitoring & Diagnostic**
* **Quick Start**

## Key Features

- Connects to one or multiple peripherals simultaneously.
- Parses and displays characteristic data in an intuitive, readable format.
- Modifys peripheral settings and parameters where supported.
- Code examples demonstrating communication with Nordic's peripherals.

## Nordic UART Service

The **Nordic UART** module acts as a serial port emulator over Bluetooth LE, offering communication features:

- Sends and receives text strings or byte arrays to and from a peripheral.
- Defines custom macros for quick execution.
- Exports and imports macro configurations via XML for easy sharing and backup.

## Simulation

This project integrates [Core Bluetooth Mock](https://github.com/NordicSemiconductor/IOS-CoreBluetooth-Mock), facilitating development and testing without physical hardware.

- The app can emulate peripheral behavior directly within the iOS Simulator.
- All supported profiles (excluding *Throughput*) include predefined mock responses that are available automatically when running on the simulator.
- The client-side BLE logic remains identical regardless of whether the app is communicating with a mock object or a physical device.

## Requirements

| Requirement | Details |
| :--- | :--- |
| **OS Version** | iOS 18.0 or newer |
| **Hardware** | A peripheral with one of the supported services installed |

## Resources

nRF5340, as well as the nRF52 and nRF54 series development kits, can be ordered from [Nordic](http://www.nordicsemi.com/eng/Buy-Online).
