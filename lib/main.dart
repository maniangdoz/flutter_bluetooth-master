// For performing some operations asynchronously
import 'dart:async';

// For using PlatformException
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BluetoothApp(),
    );
  }
}

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp>{
  // Initializing the Bluetooth connection state to be unknown
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  // Initializing a global key, as it would help us in showing a SnackBar later
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  // Get the instance of the Bluetooth
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  // Track the Bluetooth connection with the remote device
  BluetoothConnection connection;

  int _deviceState;

  bool isDisconnecting = false;

  Map<String, Color> colors = {
    'onBorderColor': Colors.green,
    'offBorderColor': Colors.red,
    'neutralBorderColor': Colors.transparent,
    'onTextColor': Colors.green[700],
    'offTextColor': Colors.red[700],
    'neutralTextColor': Colors.blue,
  };

  // To track whether the device is still connected to Bluetooth
  bool get isConnected => connection != null && connection.isConnected;

  // Define some variables, which will be required later
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice _device ;
  bool _connected = false;
  bool _isButtonUnavailable = false;

  @override
  void initState() {
    super.initState();
    print(isConnected);
    // Get current state


    try {
      FlutterBluetoothSerial.instance.state.then((state) {
        setState(() {
          _bluetoothState = state;
        });
      });
    } on Exception catch (e) {
      print('erreur 5 : $e');
    }

    _deviceState = 0; // neutral

    // If the bluetooth of the device is not enabled,
    // then request permission to turn on bluetooth
    // as the app starts up
    enableBluetooth();

    // Listen for further state changes
    try {
      FlutterBluetoothSerial.instance
          .onStateChanged()
          .listen((BluetoothState state) {
        setState(() {
          _bluetoothState = state;
          if (_bluetoothState == BluetoothState.STATE_OFF) {
            _isButtonUnavailable = true;
          }
          getPairedDevices();
        });
      });
    } on Exception catch (e) {
      print('erreur 4 $e');
    }
  }

  @override
  void dispose() {
    // Avoid memory leak and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }

    super.dispose();
  }

  // Request Bluetooth permission from the user
  Future<void> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    try {
      _bluetoothState = await FlutterBluetoothSerial.instance.state;
    } on Exception catch (e) {
      print('erreur 9 : $e');
    }

    // If the bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    try {
      if (_bluetoothState == BluetoothState.STATE_OFF) {
        await FlutterBluetoothSerial.instance.requestEnable();
        await getPairedDevices();
        return true;
      } else {
        await getPairedDevices();
      }
    } on Exception catch (e) {
      print('Erreur 8 : $e');
    }
    return false;
  }

  // For retrieving and storing the paired devices
  // in a list.
  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    // To get the list of paired devices
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    // It is an error to call [setState] unless [mounted] is true.
    if (!mounted) {
      return;
    }

    // Store the [devices] list in the [_devicesList] for accessing
    // the list outside this class
    setState(() {
      _devicesList = devices;
    });
  }

  // Now, its time to build the UI
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("Flutter Bluetooth"),
          backgroundColor: Colors.deepPurple,
          actions: <Widget>[
            FlatButton.icon(
              icon: Icon(
                Icons.refresh,
                color: Colors.white,
              ),
              label: Text(
                "Actualiser",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.deepPurple,
              onPressed: () async {
                // So, that when new devices are paired
                // while the app is running, user can refresh
                // the paired devices list.
                try {
                  await getPairedDevices().then((_) {
                    show('Device list refreshed');
                  });
                } on Exception catch (e) {
                  print('Erreur 7 : $e');
                }
              },
            ),
          ],
        ),
        body: Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Visibility(
                visible: _isButtonUnavailable &&
                    _bluetoothState == BluetoothState.STATE_ON,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.yellow,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Enable Bluetooth',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Switch(
                      value: _bluetoothState.isEnabled,
                      onChanged: (bool value) {
                        future() async {
                          if (value) {
                            await FlutterBluetoothSerial.instance
                                .requestEnable();
                          } else {
                            await FlutterBluetoothSerial.instance
                                .requestDisable();
                          }

                          await getPairedDevices();
                          _isButtonUnavailable = false;

                          if (_connected) {
                            _disconnect();
                          }
                        }

                        future().then((_) {
                          setState(() {});
                        });
                      },
                    )
                  ],
                ),
              ),
              Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          "PAIRED DEVICES",
                          style: TextStyle(fontSize: 24, color: Colors.blue),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Device:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButton(
                              items: _getDeviceItems(),
                              onChanged: (value) =>
                                  setState(() => _device = value),
                              value: _devicesList.isNotEmpty ? _device : null,
                            ),
                            RaisedButton(
                              onPressed: _isButtonUnavailable
                                  ? null
                                  : _connected ? _disconnect : _connect,
                              child:
                                  Text(_connected ? 'Disconnect' : 'Connect'),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                      ),
                    ],
                  ),
                  Container(
                    color: Colors.blue,
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          "NOTE: If you cannot find the device in the list, please pair the device by going to the bluetooth settings",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        SizedBox(height: 15),
                        RaisedButton(
                          elevation: 2,
                          child: Text("Bluetooth Settings"),
                          onPressed: () async {
                            try {
                              await FlutterBluetoothSerial.instance.openSettings();
                            } on Exception catch (e) {
                              print('Erreur 6 : $e');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Create the List of devices to be shown in Dropdown Menu
  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('Vide'),
      ));
    } else {
      if(_connected){
        items.add(DropdownMenuItem(
            child: Text(_device.name),
            value: _device,
        ));
      }else{
        _devicesList.forEach((device) {
          items.add(DropdownMenuItem(
            child: Text(device.name),
            value: device,
          ));
        });
      }
    }
    return items;
  }

  // Method to connect to bluetooth
  void _connect() async {
    setState(() {
      _isButtonUnavailable = true;
    });
    if (_device == null) {
      show('Aucun appareil sélectionné');
    } else {
      if (!isConnected) {

        try{
          await BluetoothConnection.toAddress(_device.address)
              .then((_connection) {
            print('Connected to the device');
            show('Connected to the device');
            connection = _connection;
            setState(() {
              _connected = true;
            });

            try{
              connection.input.listen(null).onDone(() {
                try {
                  if (isDisconnecting) {
                    print('Disconnecting locally!');
                  } else {
                    print('Disconnected remotely!');
                    show('Déconnexion à distance...');
                  }
                  if (this.mounted) {
                    setState(() {});
                  }
                } on Exception catch (e) {
                  print('erreur 3 : $e');
                }
              });
            }catch(Exception){
              print("Erreur 2 : $Exception");
            }

          }).catchError((error) {
            print('Cannot connect, exception occurred');
            // show('Connexion impossible');
            print(error);
          });

        }catch(Exception){
          print('Erreur 1 : $Exception');
        }

        setState(() => _isButtonUnavailable = false);
      }
    }
  }

  // Method to disconnect bluetooth
  void _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
      _deviceState = 0;
    });

    await connection.close();
    show('Device disconnected');
    if (!connection.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
      });
    }
  }


  // Method to show a Snackbar,
  // taking message as the text
  Future show(
    String message, {
    Duration duration: const Duration(seconds: 3),
  }) async {
    await new Future.delayed(new Duration(milliseconds: 100));
    _scaffoldKey.currentState.showSnackBar(
      new SnackBar(
        content: new Text(
          message,
        ),
        duration: duration,
      ),
    );
  }
}
